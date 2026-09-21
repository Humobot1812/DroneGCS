#include "DroneVehicle.h"

// MAVLink v2 headers
#include <ardupilotmega/mavlink.h>

#include <QTimer>
#include <QDateTime>
#include <QDebug>
#include <cstring>
#include <cmath>

DroneVehicle::DroneVehicle(quint8 sysId, QObject *parent)
    : QObject(parent)
    , m_sysId(sysId)
    , m_name(QString("Drone SYS:%1").arg(sysId))
{
    // Heartbeat watchdog: mark disconnected if no heartbeat for 3s
    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(3000);
    connect(m_heartbeatTimer, &QTimer::timeout, this, [this]() {
        if (m_connected) {
            m_connected = false;
            m_heartbeatHz = 0;
            emit connectionChanged();
        }
    });
    m_heartbeatTimer->start();
}

void DroneVehicle::setName(const QString &n)  { if (m_name  != n) { m_name  = n; emit nameChanged();  } }
void DroneVehicle::setColor(const QString &c) { if (m_color != c) { m_color = c; emit colorChanged(); } }

void DroneVehicle::disconnect()
{
    m_connected = false;
    emit connectionChanged();
}

// ─── Packet routing ───────────────────────────────────────────────────────────

void DroneVehicle::processPacket(const QByteArray &rawPacket)
{
    mavlink_message_t msg;
    mavlink_status_t  status;

    for (int i = 0; i < rawPacket.size(); ++i) {
        uint8_t byte = static_cast<uint8_t>(rawPacket.at(i));
        if (mavlink_parse_char(MAVLINK_COMM_0, byte, &msg, &status)) {
            // Only process messages from this drone's sysId
            if (msg.sysid != m_sysId) continue;

            switch (msg.msgid) {
            case MAVLINK_MSG_ID_HEARTBEAT: {
                mavlink_heartbeat_t hb;
                mavlink_msg_heartbeat_decode(&msg, &hb);

                qint64 now = QDateTime::currentMSecsSinceEpoch();
                if (m_lastHeartbeat > 0) {
                    qint64 diff = now - m_lastHeartbeat;
                    m_heartbeatHz = (diff > 0) ? static_cast<int>(1000.0 / diff) : 1;
                }
                m_lastHeartbeat = now;
                m_heartbeatTimer->start(); // reset watchdog

                bool wasConnected = m_connected;
                m_connected = true;

                // ── Autopilot type detection ───────────────────────────────────
                QString apType;
                switch (hb.autopilot) {
                    case MAV_AUTOPILOT_ARDUPILOTMEGA: apType = "ArduPilot"; break;
                    case MAV_AUTOPILOT_PX4:           apType = "PX4";       break;
                    case MAV_AUTOPILOT_GENERIC:       apType = "Generic";   break;
                    case MAV_AUTOPILOT_PPZ:           apType = "Paparazzi"; break;
                    case MAV_AUTOPILOT_UDB:           apType = "MatrixPilot"; break;
                    default:                          apType = QString("AP:%1").arg(hb.autopilot); break;
                }
                if (apType != m_autopilotType) {
                    m_autopilotType = apType;
                    emit autopilotTypeChanged();
                }

                // ── Vehicle / frame type detection ────────────────────────────
                QString vType;
                switch (hb.type) {
                    case MAV_TYPE_FIXED_WING:        vType = "Fixed Wing";    break;
                    case MAV_TYPE_QUADROTOR:         vType = "Quadrotor";     break;
                    case MAV_TYPE_COAXIAL:           vType = "Coaxial";       break;
                    case MAV_TYPE_HELICOPTER:        vType = "Helicopter";    break;
                    case MAV_TYPE_HEXAROTOR:         vType = "Hexarotor";     break;
                    case MAV_TYPE_OCTOROTOR:         vType = "Octorotor";     break;
                    case MAV_TYPE_TRICOPTER:         vType = "Tricopter";     break;
                    case MAV_TYPE_GROUND_ROVER:      vType = "Rover";         break;
                    case MAV_TYPE_SURFACE_BOAT:      vType = "Boat";          break;
                    case MAV_TYPE_SUBMARINE:         vType = "Submarine";     break;
                    case MAV_TYPE_VTOL_TAILSITTER_DUOROTOR: vType = "VTOL Duo"; break;
                    case MAV_TYPE_VTOL_TAILSITTER_QUADROTOR: vType = "VTOL Quad"; break;
                    case MAV_TYPE_VTOL_TILTROTOR:   vType = "Tiltrotor";     break;
                    case MAV_TYPE_AIRSHIP:           vType = "Airship";       break;
                    default:                         vType = QString("Type:%1").arg(hb.type); break;
                }
                if (vType != m_vehicleType) {
                    m_vehicleType = vType;
                    emit vehicleTypeChanged();
                }

                m_mavType = hb.type;

                // Armed state (bit 7 of base_mode)
                bool armed = (hb.base_mode & MAV_MODE_FLAG_SAFETY_ARMED) != 0;
                if (armed != m_armed) { m_armed = armed; emit armedChanged(); }

                // ── Flight mode decode (autopilot-aware) ──────────────────────
                QString mode;
                if (m_autopilotType == "PX4") {
                    // PX4: custom_mode packs main_mode (bits 16-23) + sub_mode (bits 24-31)
                    uint8_t mainMode = (hb.custom_mode >> 16) & 0xFF;
                    uint8_t subMode  = (hb.custom_mode >> 24) & 0xFF;
                    // PX4 main modes
                    static const QMap<uint8_t, QString> px4Main = {
                        {1,"MANUAL"},{2,"ALTCTL"},{3,"POSCTL"},{4,"AUTO"},
                        {5,"ACRO"},{6,"OFFBOARD"},{7,"STABILIZED"},{8,"RATTITUDE"},
                    };
                    // PX4 AUTO sub-modes
                    static const QMap<uint8_t, QString> px4AutoSub = {
                        {2,"TAKEOFF"},{3,"LOITER"},{4,"MISSION"},{5,"RTL"},
                        {6,"LAND"},{8,"FOLLOW_ME"},{9,"PRECLAND"},
                    };
                    if (mainMode == 4 && px4AutoSub.contains(subMode))
                        mode = px4AutoSub.value(subMode);
                    else
                        mode = px4Main.value(mainMode, QString("PX4:%1").arg(mainMode));
                } else {
                    // ArduPilot / Generic custom_mode numbers
                    static const QMap<uint32_t, QString> ardupilotModes = {
                        {0,"STABILIZE"},{1,"ACRO"},{2,"ALT_HOLD"},{3,"AUTO"},
                        {4,"GUIDED"},{5,"LOITER"},{6,"RTL"},{7,"CIRCLE"},
                        {9,"LAND"},{11,"DRIFT"},{13,"SPORT"},{14,"FLIP"},
                        {15,"AUTOTUNE"},{16,"POSHOLD"},{17,"BRAKE"},{18,"THROW"},
                        {19,"AVOID_ADSB"},{20,"GUIDED_NOGPS"},{21,"SMARTRTL"},
                        {22,"FLOWHOLD"},{23,"FOLLOW"},{24,"ZIGZAG"},
                    };
                    mode = ardupilotModes.value(hb.custom_mode,
                               QString("MODE:%1").arg(hb.custom_mode));
                }
                if (mode != m_flightMode) { m_flightMode = mode; emit flightModeChanged(); }

                if (!wasConnected) emit connectionChanged();
                emit heartbeatReceived();
                break;
            }
            case MAVLINK_MSG_ID_GLOBAL_POSITION_INT: {
                mavlink_global_position_int_t pos;
                mavlink_msg_global_position_int_decode(&msg, &pos);
                m_lat    = pos.lat  / 1e7;
                m_lon    = pos.lon  / 1e7;
                m_alt    = pos.alt  / 1000.0;
                m_relAlt = pos.relative_alt / 1000.0;
                m_heading = pos.hdg / 100.0;
                emit positionChanged();
                emit headingChanged();
                break;
            }
            case MAVLINK_MSG_ID_ATTITUDE: {
                mavlink_attitude_t att;
                mavlink_msg_attitude_decode(&msg, &att);
                m_roll  = att.roll  * 180.0 / M_PI;
                m_pitch = att.pitch * 180.0 / M_PI;
                m_yaw   = att.yaw   * 180.0 / M_PI;
                emit attitudeChanged();
                break;
            }
            case MAVLINK_MSG_ID_VFR_HUD: {
                mavlink_vfr_hud_t hud;
                mavlink_msg_vfr_hud_decode(&msg, &hud);
                m_airSpeed    = hud.airspeed;
                m_groundSpeed = hud.groundspeed;
                m_climbRate   = hud.climb;
                if (!std::isnan(hud.heading))
                    m_heading = hud.heading;
                emit speedChanged();
                break;
            }
            case MAVLINK_MSG_ID_SYS_STATUS: {
                mavlink_sys_status_t sys;
                mavlink_msg_sys_status_decode(&msg, &sys);
                m_batteryPercent = sys.battery_remaining;
                m_batteryVoltage = sys.voltage_battery / 1000.0;
                emit batteryChanged();
                break;
            }
            case MAVLINK_MSG_ID_GPS_RAW_INT: {
                mavlink_gps_raw_int_t gps;
                mavlink_msg_gps_raw_int_decode(&msg, &gps);
                m_gpsSats    = gps.satellites_visible;
                m_gpsFixType = gps.fix_type;
                m_gpsHDOP    = gps.eph / 100.0;
                emit gpsChanged();
                break;
            }
            case MAVLINK_MSG_ID_MISSION_CURRENT: {
                mavlink_mission_current_t mc;
                mavlink_msg_mission_current_decode(&msg, &mc);
                m_missionCurrent = mc.seq;
                emit missionProgressChanged();
                break;
            }
            case MAVLINK_MSG_ID_MISSION_COUNT: {
                mavlink_mission_count_t mc;
                mavlink_msg_mission_count_decode(&msg, &mc);
                m_missionTotal = mc.count;
                emit missionProgressChanged();
                break;
            }
            case MAVLINK_MSG_ID_STATUSTEXT: {
                mavlink_statustext_t st;
                mavlink_msg_statustext_decode(&msg, &st);
                m_lastStatusText = QString::fromLatin1(st.text, strnlen(st.text, 50));
                emit statusTextReceived();
                break;
            }
            case MAVLINK_MSG_ID_HOME_POSITION: {
                mavlink_home_position_t hp;
                mavlink_msg_home_position_decode(&msg, &hp);
                m_homeLat = hp.latitude  / 1e7;
                m_homeLon = hp.longitude / 1e7;
                m_homeAlt = hp.altitude  / 1000.0;
                emit homePositionChanged();
                break;
            }
            default:
                break;
            }
        }
    }
}

// ─── Commands ─────────────────────────────────────────────────────────────────

QByteArray DroneVehicle::buildCommandLong(uint16_t cmd,
    float p1, float p2, float p3, float p4, float p5, float p6, float p7) const
{
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    mavlink_msg_command_long_pack(
        k_gcsSystemId, k_gcsCompId, &msg,
        m_sysId, MAV_COMP_ID_AUTOPILOT1,
        cmd, 0, p1, p2, p3, p4, p5, p6, p7);

    int len = mavlink_msg_to_send_buffer(buf, &msg);
    return QByteArray(reinterpret_cast<char*>(buf), len);
}

void DroneVehicle::arm()
{
    emit sendBytes(buildCommandLong(MAV_CMD_COMPONENT_ARM_DISARM, 1.0f));
    m_armed = true;
    m_lastStatusText = QString("[%1] ARMED — Throttle enabled").arg(m_name);
    emit armedChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] ARM command sent";
}

void DroneVehicle::disarm()
{
    emit sendBytes(buildCommandLong(MAV_CMD_COMPONENT_ARM_DISARM, 0.0f));
    m_armed = false;
    m_lastStatusText = QString("[%1] DISARMED — Motors stopped").arg(m_name);
    emit armedChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] DISARM command sent";
}

void DroneVehicle::takeoff(double altitudeM)
{
    // ArduPilot requires GUIDED mode before accepting NAV_TAKEOFF.
    // Step 1 – switch to GUIDED
    {
        mavlink_message_t msg;
        uint8_t buf[MAVLINK_MAX_PACKET_LEN];
        mavlink_msg_set_mode_pack(
            k_gcsSystemId, k_gcsCompId, &msg,
            m_sysId,
            MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
            4 /* GUIDED */);
        int len = mavlink_msg_to_send_buffer(buf, &msg);
        emit sendBytes(QByteArray(reinterpret_cast<char*>(buf), len));
    }

    // Step 2 – arm (in case not already armed)
    emit sendBytes(buildCommandLong(MAV_CMD_COMPONENT_ARM_DISARM, 1.0f));

    // Step 3 – NAV_TAKEOFF
    emit sendBytes(buildCommandLong(MAV_CMD_NAV_TAKEOFF, 0, 0, 0, 0, 0, 0,
                                    static_cast<float>(altitudeM)));

    m_flightMode = "GUIDED";
    m_lastStatusText = QString("[%1] TAKEOFF → GUIDED → %2 m")
                           .arg(m_name).arg(altitudeM, 0, 'f', 1);
    emit flightModeChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] GUIDED + ARM + TAKEOFF sent to" << altitudeM << "m";
}


void DroneVehicle::returnToLaunch()
{
    emit sendBytes(buildCommandLong(MAV_CMD_NAV_RETURN_TO_LAUNCH));
    m_flightMode = "RTL";
    m_lastStatusText = QString("[%1] RETURNING TO LAUNCH (RTL)").arg(m_name);
    emit flightModeChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] RTL command sent";
}

void DroneVehicle::land()
{
    emit sendBytes(buildCommandLong(MAV_CMD_NAV_LAND));
    m_flightMode = "LAND";
    m_lastStatusText = QString("[%1] LANDING initiated").arg(m_name);
    emit flightModeChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] LAND command sent";
}

void DroneVehicle::emergencyKill()
{
    emit sendBytes(buildCommandLong(MAV_CMD_COMPONENT_ARM_DISARM, 0.0f, 21196.0f));
    m_armed = false;
    m_lastStatusText = QString("⚠️ [%1] EMERGENCY KILL EXECUTED").arg(m_name);
    emit armedChanged();
    emit statusTextReceived();
    qWarning() << "[Drone" << m_sysId << "] EMERGENCY KILL EXECUTED";
}

void DroneVehicle::gotoLocation(double lat, double lon, double alt)
{
    emit sendBytes(buildCommandLong(MAV_CMD_DO_REPOSITION, -1, 1, 0, 0, static_cast<float>(lat), static_cast<float>(lon), static_cast<float>(alt)));
    m_flightMode = "GUIDED";
    m_lastStatusText = QString("[%1] Guided Fly-To: %2, %3 (%4m)").arg(m_name).arg(lat, 0, 'f', 5).arg(lon, 0, 'f', 5).arg(alt, 0, 'f', 1);
    emit flightModeChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] Goto Location:" << lat << lon << alt;
}

void DroneVehicle::startMission()
{
    emit sendBytes(buildCommandLong(MAV_CMD_MISSION_START, 0, 0));
    m_flightMode = "AUTO";
    m_lastStatusText = QString("[%1] Mission Started").arg(m_name);
    emit flightModeChanged();
    emit statusTextReceived();
}

void DroneVehicle::uploadWaypoints(const QVariantList &waypoints)
{
    if (waypoints.isEmpty()) return;

    // 1. MISSION_COUNT
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    int len;

    // Item 0 is always home (takeoff_home), items 1..N are the user waypoints
    int totalItems = waypoints.size() + 1;

    mavlink_msg_mission_count_pack(
        k_gcsSystemId, k_gcsCompId, &msg,
        m_sysId, MAV_COMP_ID_AUTOPILOT1,
        static_cast<uint16_t>(totalItems),
        MAV_MISSION_TYPE_MISSION,
        0 /* opaque_id */);
    len = mavlink_msg_to_send_buffer(buf, &msg);
    emit sendBytes(QByteArray(reinterpret_cast<char*>(buf), len));

    // 2. Item 0 — HOME (dummy, autopilot ignores lat/lon if 0)
    mavlink_msg_mission_item_int_pack(
        k_gcsSystemId, k_gcsCompId, &msg,
        m_sysId, MAV_COMP_ID_AUTOPILOT1,
        0, MAV_FRAME_GLOBAL_RELATIVE_ALT_INT,
        MAV_CMD_NAV_WAYPOINT,
        1, 1,           // current=1 for home, autocontinue=1
        0, 0, 0, 0,     // params 1-4
        0, 0,           // lat=0, lon=0 → use current home
        static_cast<float>(m_relAlt > 5 ? m_relAlt : 10.0),
        MAV_MISSION_TYPE_MISSION);
    len = mavlink_msg_to_send_buffer(buf, &msg);
    emit sendBytes(QByteArray(reinterpret_cast<char*>(buf), len));

    // 3. Waypoints from user
    for (int i = 0; i < waypoints.size(); ++i) {
        QVariantMap wp = waypoints.at(i).toMap();
        double lat = wp.value("lat", 0.0).toDouble();
        double lon = wp.value("lon", 0.0).toDouble();
        double alt = wp.value("alt", 15.0).toDouble();

        mavlink_msg_mission_item_int_pack(
            k_gcsSystemId, k_gcsCompId, &msg,
            m_sysId, MAV_COMP_ID_AUTOPILOT1,
            static_cast<uint16_t>(i + 1),
            MAV_FRAME_GLOBAL_RELATIVE_ALT_INT,
            MAV_CMD_NAV_WAYPOINT,
            0, 1,                   // current=0, autocontinue=1
            0.0f, 0.0f, 0.0f, 0.0f,  // hold, accept_radius, pass_through, yaw
            static_cast<int32_t>(lat * 1e7),
            static_cast<int32_t>(lon * 1e7),
            static_cast<float>(alt),
            MAV_MISSION_TYPE_MISSION);
        len = mavlink_msg_to_send_buffer(buf, &msg);
        emit sendBytes(QByteArray(reinterpret_cast<char*>(buf), len));
    }

    m_missionTotal = totalItems;
    m_lastStatusText = QString("[%1] Uploaded %2 waypoints").arg(m_name).arg(waypoints.size());
    emit missionProgressChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] Uploaded" << waypoints.size() << "waypoints";
}

void DroneVehicle::clearMission()
{
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_mission_clear_all_pack(
        k_gcsSystemId, k_gcsCompId, &msg,
        m_sysId, MAV_COMP_ID_AUTOPILOT1,
        MAV_MISSION_TYPE_MISSION);
    int len = mavlink_msg_to_send_buffer(buf, &msg);
    emit sendBytes(QByteArray(reinterpret_cast<char*>(buf), len));

    m_missionTotal = 0;
    m_missionCurrent = 0;
    m_lastStatusText = QString("[%1] Mission Cleared").arg(m_name);
    emit missionProgressChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] Cleared all mission items";
}

void DroneVehicle::pauseMission()
{
    emit sendBytes(buildCommandLong(MAV_CMD_DO_PAUSE_CONTINUE, 0));
    m_flightMode = "LOITER";
    m_lastStatusText = QString("[%1] Mission Paused (Loiter)").arg(m_name);
    emit flightModeChanged();
    emit statusTextReceived();
}

void DroneVehicle::setFlightMode(const QString &mode)
{
    // Flight mode mapping (ArduCopter custom mode numbers)
    static const QMap<QString, int> modeMap = {
        {"STABILIZE", 0}, {"ACRO", 1}, {"ALT_HOLD", 2}, {"AUTO", 3},
        {"GUIDED", 4}, {"LOITER", 5}, {"RTL", 6}, {"CIRCLE", 7},
        {"LAND", 9}, {"POSHOLD", 16}, {"BRAKE", 17}, {"THROW", 18},
        {"GUIDED_NOGPS", 20}, {"SMARTRTL", 21},
    };

    QString upperMode = mode.toUpper();
    int modeNum = modeMap.value(upperMode, -1);
    if (modeNum < 0) { qWarning() << "Unknown mode:" << mode; return; }

    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_set_mode_pack(
        k_gcsSystemId, k_gcsCompId, &msg,
        m_sysId,
        MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
        static_cast<uint32_t>(modeNum));

    int len = mavlink_msg_to_send_buffer(buf, &msg);
    emit sendBytes(QByteArray(reinterpret_cast<char*>(buf), len));

    m_flightMode = upperMode;
    m_lastStatusText = QString("[%1] Flight Mode: %2").arg(m_name, upperMode);
    emit flightModeChanged();
    emit statusTextReceived();
}

void DroneVehicle::updateSimulatedTelemetry(double lat, double lon, double alt, double relAlt,
                                           double heading, double roll, double pitch, double yaw,
                                           double groundSpeed, double airSpeed, double climbRate,
                                           int batteryPercent, double batteryVoltage,
                                           int gpsSats, double gpsHDOP,
                                           bool armed, const QString &mode, const QString &statusText)
{
    m_lastHeartbeat = QDateTime::currentMSecsSinceEpoch();
    m_heartbeatHz = 20;

    if (!m_connected) {
        m_connected = true;
        emit connectionChanged();
    }
    emit heartbeatReceived();

    if (m_lat != lat || m_lon != lon || m_alt != alt || m_relAlt != relAlt) {
        m_lat = lat; m_lon = lon; m_alt = alt; m_relAlt = relAlt;
        emit positionChanged();
    }

    if (m_heading != heading) {
        m_heading = heading;
        emit headingChanged();
    }

    if (m_roll != roll || m_pitch != pitch || m_yaw != yaw) {
        m_roll = roll; m_pitch = pitch; m_yaw = yaw;
        emit attitudeChanged();
    }

    if (m_groundSpeed != groundSpeed || m_airSpeed != airSpeed || m_climbRate != climbRate) {
        m_groundSpeed = groundSpeed; m_airSpeed = airSpeed; m_climbRate = climbRate;
        emit speedChanged();
    }

    if (m_batteryPercent != batteryPercent || m_batteryVoltage != batteryVoltage) {
        m_batteryPercent = batteryPercent; m_batteryVoltage = batteryVoltage;
        emit batteryChanged();
    }

    if (m_gpsSats != gpsSats || m_gpsHDOP != gpsHDOP) {
        m_gpsSats = gpsSats; m_gpsFixType = 3; m_gpsHDOP = gpsHDOP;
        emit gpsChanged();
    }

    if (m_armed != armed) {
        m_armed = armed;
        emit armedChanged();
    }

    if (m_flightMode != mode) {
        m_flightMode = mode;
        emit flightModeChanged();
    }

    if (!statusText.isEmpty() && m_lastStatusText != statusText) {
        m_lastStatusText = statusText;
        emit statusTextReceived();
    }
}
