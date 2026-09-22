#include "DroneVehicle.h"

// MAVLink v2 headers
#include <ardupilotmega/mavlink.h>

#include <QTimer>
#include <QDateTime>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QStandardPaths>
#include <cstring>
#include <cmath>

static double calcDistanceM(double lat1, double lon1, double lat2, double lon2)
{
    if ((lat1 == 0.0 && lon1 == 0.0) || (lat2 == 0.0 && lon2 == 0.0)) return 0.0;
    constexpr double R = 6371000.0; // Earth radius in meters
    double phi1 = lat1 * M_PI / 180.0;
    double phi2 = lat2 * M_PI / 180.0;
    double dphi = (lat2 - lat1) * M_PI / 180.0;
    double dlambda = (lon2 - lon1) * M_PI / 180.0;
    double a = sin(dphi / 2.0) * sin(dphi / 2.0) +
               cos(phi1) * cos(phi2) *
               sin(dlambda / 2.0) * sin(dlambda / 2.0);
    double c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
    return R * c;
}

static bool isPointInPolygon(double lat, double lon, const QVariantList &polygon)
{
    int n = polygon.size();
    if (n < 3) return true; // not a closed polygon
    bool inside = false;
    for (int i = 0, j = n - 1; i < n; j = i++) {
        QVariantMap p1 = polygon[i].toMap();
        QVariantMap p2 = polygon[j].toMap();
        double lat1 = p1.value("lat").toDouble();
        double lon1 = p1.value("lon").toDouble();
        double lat2 = p2.value("lat").toDouble();
        double lon2 = p2.value("lon").toDouble();

        bool intersect = ((lat1 > lat) != (lat2 > lat)) &&
            (lon < (lon2 - lon1) * (lat - lat1) / ((lat2 - lat1) + 1e-12) + lon1);
        if (intersect) {
            inside = !inside;
        }
    }
    return inside;
}

DroneVehicle::DroneVehicle(quint8 sysId, QObject *parent)
    : QObject(parent)
    , m_sysId(sysId)
    , m_name(QString("Drone SYS:%1").arg(sysId))
{
    // Heartbeat watchdog: mark disconnected if no packets for 4.5s
    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(4000);
    connect(m_heartbeatTimer, &QTimer::timeout, this, [this]() {
        qint64 now = QDateTime::currentMSecsSinceEpoch();
        if (m_connected && (m_lastPacketTime > 0 && (now - m_lastPacketTime >= 4500))) {
            m_connected = false;
            m_heartbeatHz = 0;
            emit connectionChanged();
        }
    });
    m_heartbeatTimer->start();
    addFlightLog("INFO", QString("Telemetry session initialized for Drone SYS:%1").arg(sysId));
}

void DroneVehicle::setName(const QString &n)  { if (m_name  != n) { m_name  = n; emit nameChanged();  } }
void DroneVehicle::setColor(const QString &c) { if (m_color != c) { m_color = c; emit colorChanged(); } }

void DroneVehicle::disconnect()
{
    m_connected = false;
    addFlightLog("WARN", QString("Telemetry link disconnected for Drone SYS:%1").arg(m_sysId));
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

            m_lastPacketTime = QDateTime::currentMSecsSinceEpoch();

            switch (msg.msgid) {
            case MAVLINK_MSG_ID_HEARTBEAT: {
                mavlink_heartbeat_t hb;
                mavlink_msg_heartbeat_decode(&msg, &hb);

                qint64 now = QDateTime::currentMSecsSinceEpoch();
                if (m_lastHeartbeat > 0) {
                    qint64 diff = now - m_lastHeartbeat;
                    m_heartbeatHz = (diff > 0) ? std::max(1, static_cast<int>(std::round(1000.0 / diff))) : 1;
                } else {
                    m_heartbeatHz = 1;
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

                updateDistancesAndReturnRadius();
                checkGeofenceBreach();
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
                updateDistancesAndReturnRadius();
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
            case MAVLINK_MSG_ID_MISSION_REQUEST_INT: {
                mavlink_mission_request_int_t req;
                mavlink_msg_mission_request_int_decode(&msg, &req);
                handleMissionRequest(req.seq);
                break;
            }
            case MAVLINK_MSG_ID_MISSION_REQUEST: {
                mavlink_mission_request_t req;
                mavlink_msg_mission_request_decode(&msg, &req);
                handleMissionRequest(req.seq);
                break;
            }
            case MAVLINK_MSG_ID_MISSION_ACK: {
                mavlink_mission_ack_t ack;
                mavlink_msg_mission_ack_decode(&msg, &ack);
                if (m_uploadTimeoutTimer) m_uploadTimeoutTimer->stop();

                if (m_missionClearPending) {
                    // This ACK is the response to MISSION_CLEAR_ALL
                    m_missionClearPending = false;
                    if (ack.type == MAV_MISSION_ACCEPTED) {
                        qDebug() << "[Drone" << m_sysId << "] Mission CLEAR ACK accepted";
                        emit missionCleared();
                    } else {
                        qWarning() << "[Drone" << m_sysId << "] Mission CLEAR ACK rejected:" << ack.type;
                        emit missionCleared(); // still announce clear on GCS side
                    }
                } else if (ack.type == MAV_MISSION_ACCEPTED) {
                    m_missionUploadActive = false;
                    m_missionUploadProgress = 100.0;
                    emit missionUploadActiveChanged();
                    emit missionUploadProgressChanged();
                    emit missionProgressChanged();
                    emit missionUploadComplete(true);

                    m_lastStatusText = QString("[%1] Mission Upload Succeeded (%2 waypoints)")
                                           .arg(m_name).arg(m_pendingWaypoints.size());
                    emit statusTextReceived();

                    // Prime seq 1 so vehicle immediately targets first waypoint upon AUTO start
                    mavlink_message_t setCurMsg;
                    uint8_t setBuf[MAVLINK_MAX_PACKET_LEN];
                    mavlink_msg_mission_set_current_pack(
                        k_gcsSystemId, k_gcsCompId, &setCurMsg,
                        m_sysId, MAV_COMP_ID_AUTOPILOT1,
                        1);
                    int setLen = mavlink_msg_to_send_buffer(setBuf, &setCurMsg);
                    emit sendBytes(QByteArray(reinterpret_cast<char*>(setBuf), setLen));

                    qDebug() << "[Drone" << m_sysId << "] Mission ACK ACCEPTED. Primed current seq 1";
                } else {
                    m_missionUploadActive = false;
                    emit missionUploadActiveChanged();
                    emit missionUploadComplete(false);

                    m_lastStatusText = QString("[%1] Mission Upload Failed: ACK %2").arg(m_name).arg(ack.type);
                    emit statusTextReceived();
                    qWarning() << "[Drone" << m_sysId << "] Mission ACK rejected:" << ack.type;
                }
                break;
            }
            case MAVLINK_MSG_ID_MISSION_ITEM_REACHED: {
                mavlink_mission_item_reached_t mir;
                mavlink_msg_mission_item_reached_decode(&msg, &mir);
                m_missionCurrent = mir.seq;
                m_lastStatusText = QString("[%1] Reached Waypoint #%2").arg(m_name).arg(mir.seq);
                emit missionProgressChanged();
                emit statusTextReceived();
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
                updateDistancesAndReturnRadius();
                checkGeofenceBreach();
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

void DroneVehicle::sendMavlinkParam(const char *paramId, float value)
{
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    char idBuf[17] = {0};
    strncpy(idBuf, paramId, 16);

    mavlink_msg_param_set_pack(
        k_gcsSystemId, k_gcsCompId, &msg,
        m_sysId, MAV_COMP_ID_AUTOPILOT1,
        idBuf, value, MAV_PARAM_TYPE_REAL32);

    int len = mavlink_msg_to_send_buffer(buf, &msg);
    emit sendBytes(QByteArray(reinterpret_cast<char*>(buf), len));
}

void DroneVehicle::arm()
{
    emit sendBytes(buildCommandLong(MAV_CMD_COMPONENT_ARM_DISARM, 1.0f));
    m_armed = true;
    m_lastStatusText = QString("[%1] ARMED — Motors active").arg(m_name);
    addFlightLog("CRITICAL", "Armed vehicle motors — Propulsion active");
    emit armedChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] ARM command sent";
}

void DroneVehicle::disarm()
{
    emit sendBytes(buildCommandLong(MAV_CMD_COMPONENT_ARM_DISARM, 0.0f));
    m_armed = false;
    m_lastStatusText = QString("[%1] DISARMED — Motors stopped").arg(m_name);
    addFlightLog("WARN", "Disarmed vehicle motors — Propulsion stopped");
    emit armedChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] DISARM command sent";
}

void DroneVehicle::takeoff(double altitudeM)
{
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
    addFlightLog("NAV", QString("Takeoff command executed to target altitude %1 m AGL").arg(altitudeM, 0, 'f', 1));
    emit flightModeChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] GUIDED + ARM + TAKEOFF sent to" << altitudeM << "m";
}

void DroneVehicle::returnToLaunch()
{
    emit sendBytes(buildCommandLong(MAV_CMD_NAV_RETURN_TO_LAUNCH));
    m_flightMode = "RTL";
    m_lastStatusText = QString("[%1] RETURNING TO LAUNCH (RTL)").arg(m_name);
    addFlightLog("NAV", "Return to Launch (RTL) mode commanded — Aircraft returning to Home");
    emit flightModeChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] RTL command sent";
}

void DroneVehicle::land()
{
    emit sendBytes(buildCommandLong(MAV_CMD_NAV_LAND));
    m_flightMode = "LAND";
    m_lastStatusText = QString("[%1] LANDING initiated").arg(m_name);
    addFlightLog("NAV", "Vertical descent landing commanded");
    emit flightModeChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] LAND command sent";
}

void DroneVehicle::emergencyKill()
{
    // Parameter 2 = 21196 force kills motor output in ArduPilot
    emit sendBytes(buildCommandLong(MAV_CMD_COMPONENT_ARM_DISARM, 0.0f, 21196.0f));
    m_armed = false;
    m_lastStatusText = QString("⚠️ [%1] EMERGENCY KILL EXECUTED").arg(m_name);
    addFlightLog("CRITICAL", "EMERGENCY MOTOR KILL COMMAND EXECUTED — Motors forced off");
    emit armedChanged();
    emit statusTextReceived();
    qWarning() << "[Drone" << m_sysId << "] EMERGENCY KILL EXECUTED";
}

void DroneVehicle::gotoLocation(double lat, double lon, double alt)
{
    emit sendBytes(buildCommandLong(MAV_CMD_DO_REPOSITION, -1, 1, 0, 0,
                                     static_cast<float>(lat),
                                     static_cast<float>(lon),
                                     static_cast<float>(alt)));
    m_flightMode = "GUIDED";
    m_lastStatusText = QString("[%1] Guided Fly-To: %2, %3 (%4m)")
                           .arg(m_name).arg(lat, 0, 'f', 5).arg(lon, 0, 'f', 5).arg(alt, 0, 'f', 1);
    addFlightLog("NAV", QString("Reposition to Lat %1, Lon %2, Alt %3m").arg(lat, 0, 'f', 5).arg(lon, 0, 'f', 5).arg(alt, 0, 'f', 1));
    emit flightModeChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] Goto Location:" << lat << lon << alt;
}

void DroneVehicle::startMission()
{
    // Prime seq 1
    mavlink_message_t setCurMsg;
    uint8_t setBuf[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_mission_set_current_pack(
        k_gcsSystemId, k_gcsCompId, &setCurMsg,
        m_sysId, MAV_COMP_ID_AUTOPILOT1,
        1);
    int setLen = mavlink_msg_to_send_buffer(setBuf, &setCurMsg);
    emit sendBytes(QByteArray(reinterpret_cast<char*>(setBuf), setLen));

    // Switch to AUTO mode
    setFlightMode("AUTO");

    // Command mission start
    emit sendBytes(buildCommandLong(MAV_CMD_MISSION_START, 1, m_missionTotal > 0 ? m_missionTotal : 100));

    m_flightMode = "AUTO";
    m_lastStatusText = QString("[%1] AUTO Mission Started").arg(m_name);
    addFlightLog("NAV", "Autonomous waypoint mission execution started (AUTO mode active)");
    emit flightModeChanged();
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] AUTO Mission Started";
}

void DroneVehicle::pauseMission()
{
    emit sendBytes(buildCommandLong(MAV_CMD_DO_PAUSE_CONTINUE, 0));
    m_flightMode = "LOITER";
    m_lastStatusText = QString("[%1] Mission Paused (Loiter)").arg(m_name);
    addFlightLog("NAV", "Mission paused — Aircraft entered LOITER position hold");
    emit flightModeChanged();
    emit statusTextReceived();
}

void DroneVehicle::clearMission()
{
    m_missionClearPending = true;  // flag so MISSION_ACK routes to missionCleared

    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_mission_clear_all_pack(
        k_gcsSystemId, k_gcsCompId, &msg,
        m_sysId, MAV_COMP_ID_AUTOPILOT1,
        MAV_MISSION_TYPE_MISSION);
    int len = mavlink_msg_to_send_buffer(buf, &msg);
    emit sendBytes(QByteArray(reinterpret_cast<char*>(buf), len));

    m_pendingWaypoints.clear();
    m_missionTotal = 0;
    m_missionCurrent = 0;
    m_missionUploadActive = false;
    m_missionUploadProgress = 0.0;

    m_lastStatusText = QString("[%1] Mission Cleared").arg(m_name);
    addFlightLog("NAV", "Operator cleared all mission waypoints");
    emit missionProgressChanged();
    emit missionUploadActiveChanged();
    emit missionUploadProgressChanged();
    emit statusTextReceived();

    // If not connected, there will be no ACK — fire the signal immediately
    if (!m_connected) {
        m_missionClearPending = false;
        emit missionCleared();
    }

    qDebug() << "[Drone" << m_sysId << "] Cleared all mission items";
}

void DroneVehicle::sendMissionCount(int count)
{
    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];
    mavlink_msg_mission_count_pack(
        k_gcsSystemId, k_gcsCompId, &msg,
        m_sysId, MAV_COMP_ID_AUTOPILOT1,
        static_cast<uint16_t>(count),
        MAV_MISSION_TYPE_MISSION,
        0 /* opaque_id */);
    int len = mavlink_msg_to_send_buffer(buf, &msg);
    emit sendBytes(QByteArray(reinterpret_cast<char*>(buf), len));
}

void DroneVehicle::uploadWaypoints(const QVariantList &waypoints)
{
    if (waypoints.isEmpty()) return;

    m_pendingWaypoints = waypoints;
    m_missionUploadActive = true;
    m_missionUploadProgress = 0.0;
    emit missionUploadActiveChanged();
    emit missionUploadProgressChanged();

    int totalItems = waypoints.size() + 1; // seq 0 is home
    m_missionTotal = totalItems;
    m_uploadRetryCount = 0;

    sendMissionCount(totalItems);

    if (!m_uploadTimeoutTimer) {
        m_uploadTimeoutTimer = new QTimer(this);
        m_uploadTimeoutTimer->setInterval(1500);
        connect(m_uploadTimeoutTimer, &QTimer::timeout, this, [this]() {
            if (m_missionUploadActive) {
                if (m_uploadRetryCount < 3) {
                    m_uploadRetryCount++;
                    qDebug() << "[Drone" << m_sysId << "] Retrying MISSION_COUNT attempt" << m_uploadRetryCount;
                    sendMissionCount(m_pendingWaypoints.size() + 1);
                } else {
                    qWarning() << "[Drone" << m_sysId << "] Mission upload timeout - no request from vehicle";
                    m_missionUploadActive = false;
                    m_uploadTimeoutTimer->stop();
                    emit missionUploadActiveChanged();
                    emit missionUploadComplete(false);
                }
            } else {
                m_uploadTimeoutTimer->stop();
            }
        });
    }
    m_uploadTimeoutTimer->start();
}

void DroneVehicle::handleMissionRequest(int seq)
{
    if (m_uploadTimeoutTimer) m_uploadTimeoutTimer->start(); // reset timeout
    int total = m_pendingWaypoints.size() + 1;
    if (seq < 0 || seq >= total) return;

    mavlink_message_t msg;
    uint8_t buf[MAVLINK_MAX_PACKET_LEN];

    if (seq == 0) {
        // HOME waypoint
        double hLat = (m_homeLat != 0.0) ? m_homeLat : m_lat;
        double hLon = (m_homeLon != 0.0) ? m_homeLon : m_lon;
        double hAlt = (m_relAlt > 5.0) ? m_relAlt : 15.0;

        mavlink_msg_mission_item_int_pack(
            k_gcsSystemId, k_gcsCompId, &msg,
            m_sysId, MAV_COMP_ID_AUTOPILOT1,
            0, MAV_FRAME_GLOBAL_RELATIVE_ALT_INT,
            MAV_CMD_NAV_WAYPOINT,
            1, 1, // current=1, autocontinue=1
            0, 0, 0, 0,
            static_cast<int32_t>(hLat * 1e7),
            static_cast<int32_t>(hLon * 1e7),
            static_cast<float>(hAlt),
            MAV_MISSION_TYPE_MISSION);
    } else {
        // User waypoint (seq - 1 in pending list)
        QVariantMap wp = m_pendingWaypoints.at(seq - 1).toMap();
        double lat = wp.value("lat", 0.0).toDouble();
        double lon = wp.value("lon", 0.0).toDouble();
        double alt = wp.value("alt", 20.0).toDouble();
        float delay = wp.value("delay", 0.0).toFloat();

        mavlink_msg_mission_item_int_pack(
            k_gcsSystemId, k_gcsCompId, &msg,
            m_sysId, MAV_COMP_ID_AUTOPILOT1,
            static_cast<uint16_t>(seq),
            MAV_FRAME_GLOBAL_RELATIVE_ALT_INT,
            MAV_CMD_NAV_WAYPOINT,
            0, 1, // current=0, autocontinue=1
            delay, 0, 0, 0,
            static_cast<int32_t>(lat * 1e7),
            static_cast<int32_t>(lon * 1e7),
            static_cast<float>(alt),
            MAV_MISSION_TYPE_MISSION);
    }

    int len = mavlink_msg_to_send_buffer(buf, &msg);
    emit sendBytes(QByteArray(reinterpret_cast<char*>(buf), len));

    m_missionUploadProgress = (static_cast<double>(seq + 1) / static_cast<double>(total)) * 100.0;
    emit missionUploadProgressChanged();
}

// ─── Geofencing & Safety ──────────────────────────────────────────────────────

void DroneVehicle::setGeofenceEnabled(bool enabled)
{
    if (m_geofenceEnabled != enabled) {
        m_geofenceEnabled = enabled;
        emit geofenceChanged();
        sendMavlinkParam("FENCE_ENABLE", enabled ? 1.0f : 0.0f);
        checkGeofenceBreach();
    }
}

void DroneVehicle::setCircularFenceEnabled(bool enabled)
{
    if (m_circularFenceEnabled != enabled) {
        m_circularFenceEnabled = enabled;
        emit circularFenceEnabledChanged();
        checkGeofenceBreach();
    }
}

void DroneVehicle::setGeofenceAction(int action)
{
    if (m_geofenceAction != action) {
        m_geofenceAction = action;
        emit geofenceChanged();
        sendMavlinkParam("FENCE_ACTION", static_cast<float>(action));
    }
}

void DroneVehicle::setGeofenceRadius(double radius)
{
    if (m_geofenceRadius != radius) {
        m_geofenceRadius = radius;
        emit geofenceChanged();
        sendMavlinkParam("FENCE_RADIUS", static_cast<float>(radius));
        checkGeofenceBreach();
    }
}

void DroneVehicle::setGeofenceMinAlt(double minAlt)
{
    if (m_geofenceMinAlt != minAlt) {
        m_geofenceMinAlt = minAlt;
        emit geofenceChanged();
        if (minAlt > 0) sendMavlinkParam("FENCE_ALT_MIN", static_cast<float>(minAlt));
        checkGeofenceBreach();
    }
}

void DroneVehicle::setGeofenceMaxAlt(double maxAlt)
{
    if (m_geofenceMaxAlt != maxAlt) {
        m_geofenceMaxAlt = maxAlt;
        emit geofenceChanged();
        sendMavlinkParam("FENCE_ALT_MAX", static_cast<float>(maxAlt));
        checkGeofenceBreach();
    }
}

void DroneVehicle::setGeofencePolygon(const QVariantList &polygon)
{
    m_geofencePolygon = polygon;
    emit geofencePolygonChanged();
    checkGeofenceBreach();
}

void DroneVehicle::uploadGeofence(const QVariantList &polygon, double maxAlt, double minAlt, double radius, int action)
{
    m_geofenceEnabled = true;
    m_circularFenceEnabled = (radius > 0);
    m_geofencePolygon = polygon;
    m_geofenceMaxAlt = maxAlt;
    m_geofenceMinAlt = minAlt;
    m_geofenceRadius = radius;
    m_geofenceAction = action;

    emit geofenceChanged();
    emit circularFenceEnabledChanged();
    emit geofencePolygonChanged();

    sendMavlinkParam("FENCE_ENABLE", 1.0f);
    sendMavlinkParam("FENCE_ACTION", static_cast<float>(action));
    sendMavlinkParam("FENCE_RADIUS", static_cast<float>(radius));
    sendMavlinkParam("FENCE_ALT_MAX", static_cast<float>(maxAlt));
    if (minAlt > 0) sendMavlinkParam("FENCE_ALT_MIN", static_cast<float>(minAlt));

    m_lastStatusText = QString("[%1] Geofence Armed & Synced").arg(m_name);
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] Geofence synced: maxAlt=" << maxAlt << "radius=" << radius;
    checkGeofenceBreach();
}

void DroneVehicle::uploadGeofence(bool enabled, double radius, double minAlt, double maxAlt, int action, const QVariantList &polygon)
{
    uploadGeofence(polygon, maxAlt, minAlt, radius, action);
    setGeofenceEnabled(enabled);
}

void DroneVehicle::clearGeofence()
{
    m_geofenceEnabled = false;
    m_circularFenceEnabled = false;
    m_geofencePolygon.clear();
    m_geofenceBreached = false;
    m_geofenceBreachReason.clear();

    emit geofenceChanged();
    emit circularFenceEnabledChanged();
    emit geofencePolygonChanged();
    emit geofenceBreachedChanged();
    emit geofenceBreachChanged();

    sendMavlinkParam("FENCE_ENABLE", 0.0f);

    m_lastStatusText = QString("[%1] Geofence Disarmed & Cleared").arg(m_name);
    emit statusTextReceived();
    qDebug() << "[Drone" << m_sysId << "] Geofence cleared";
}

void DroneVehicle::checkGeofenceBreach()
{
    if (!m_geofenceEnabled) {
        if (m_geofenceBreached) {
            m_geofenceBreached = false;
            m_geofenceBreachReason.clear();
            emit geofenceBreachedChanged();
            emit geofenceBreachChanged();
        }
        return;
    }

    bool breached = false;
    QString reason;

    // 1. Max horizontal radius check (only if circular fence is enabled)
    if (m_circularFenceEnabled && m_geofenceRadius > 0 && m_homeLat != 0.0 && m_homeLon != 0.0 && m_lat != 0.0 && m_lon != 0.0) {
        double dist = calcDistanceM(m_lat, m_lon, m_homeLat, m_homeLon);
        if (dist > m_geofenceRadius) {
            breached = true;
            reason = QString("Radius breached (%1m > %2m)").arg(int(dist)).arg(int(m_geofenceRadius));
        }
    }

    // 2. Altitude Ceiling check
    if (!breached && m_geofenceMaxAlt > 0 && m_relAlt > m_geofenceMaxAlt) {
        breached = true;
        reason = QString("Ceiling breached (%1m > %2m)").arg(int(m_relAlt)).arg(int(m_geofenceMaxAlt));
    }

    // 3. Altitude Floor check (only if armed and airborne)
    if (!breached && m_armed && m_geofenceMinAlt > 0 && m_relAlt > 0.5 && m_relAlt < m_geofenceMinAlt) {
        breached = true;
        reason = QString("Floor breached (%1m < %2m)").arg(int(m_relAlt)).arg(int(m_geofenceMinAlt));
    }

    // 4. Polygon check
    if (!breached && m_geofencePolygon.size() >= 3) {
        bool inside = isPointInPolygon(m_lat, m_lon, m_geofencePolygon);
        if (!inside) {
            breached = true;
            reason = "Perimeter fence boundary breached";
        }
    }

    if (breached != m_geofenceBreached || reason != m_geofenceBreachReason) {
        m_geofenceBreached = breached;
        m_geofenceBreachReason = reason;
        emit geofenceBreachedChanged();
        emit geofenceBreachChanged();

        if (breached) {
            qWarning() << "[Drone" << m_sysId << "] GEOFENCE BREACH DETECTED:" << reason;
            m_lastStatusText = QString("🚨 GEOFENCE BREACH: %1").arg(reason);
            emit statusTextReceived();

            // Execute breach action
            // 0: Warning only
            // 1: RTL
            // 2: Land
            // 3: Loiter
            if (m_geofenceAction == 1) {
                returnToLaunch();
            } else if (m_geofenceAction == 2) {
                land();
            } else if (m_geofenceAction == 3) {
                pauseMission();
            }
        }
    }
}

void DroneVehicle::updateDistancesAndReturnRadius()
{
    // 1. Distance to Home
    if (m_homeLat != 0.0 && m_homeLon != 0.0 && m_lat != 0.0 && m_lon != 0.0) {
        double d = calcDistanceM(m_lat, m_lon, m_homeLat, m_homeLon);
        if (std::abs(d - m_distanceToHome) > 0.5) {
            m_distanceToHome = d;
            emit distanceToHomeChanged();
        }
    }

    // 2. Safe Return Radius
    // If battery <= 20%, return radius is 0
    // Between 20% and 100%, usable fraction maps to max 3000m safe radius
    double newSafeRadius = 0.0;
    if (m_batteryPercent > 20) {
        double usableFrac = (m_batteryPercent - 20.0) / 80.0;
        newSafeRadius = usableFrac * 3000.0;
    } else if (m_batteryPercent == -1 && m_batteryVoltage > 11.5) {
        newSafeRadius = 1500.0;
    }

    if (std::abs(newSafeRadius - m_safeReturnRadius) > 5.0) {
        m_safeReturnRadius = newSafeRadius;
        emit safeReturnRadiusChanged();
    }
}

QVariantMap DroneVehicle::runPreflightCheck()
{
    QVariantMap res;

    // 1. Telemetry Link
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    bool hasRecentPackets = (m_lastPacketTime > 0 && (now - m_lastPacketTime < 4500));
    bool linkOk = m_connected && (m_heartbeatHz > 0 || hasRecentPackets);
    int displayHz = std::max(1, m_heartbeatHz);
    res["link"] = linkOk;
    res["link_msg"] = linkOk ? QString("Link Active (%1 Hz)").arg(displayHz) : "No Telemetry Heartbeat";

    // 2. IMU / Attitude
    bool imuOk = m_connected && !std::isnan(m_roll) && !std::isnan(m_pitch) &&
                 (std::abs(m_roll) < 45.0) && (std::abs(m_pitch) < 45.0);
    res["imu"] = imuOk;
    res["imu_msg"] = imuOk ? QString("Nominal Level (Roll:%1° Pitch:%2°)")
                              .arg(m_roll, 0, 'f', 1).arg(m_pitch, 0, 'f', 1)
                           : (m_connected ? "Sensor Tilt/Attitude Error (>45°)" : "Sensors Offline");

    // 3. Compass / Magnetometer
    bool compassOk = m_connected && !std::isnan(m_heading) && (m_heading >= 0.0 && m_heading <= 360.0);
    res["compass"] = compassOk;
    res["compass_msg"] = compassOk ? QString("Heading Valid (%1°)").arg(m_heading, 0, 'f', 1)
                                   : "Uncalibrated / Compass Err";

    // 4. Barometer / Altitude
    bool baroOk = m_connected && !std::isnan(m_alt);
    res["baro"] = baroOk;
    res["baro_msg"] = baroOk ? QString("Altitude %1 m AGL").arg(m_relAlt, 0, 'f', 1)
                             : "Baro Sensor Failure";

    // 5. GPS Navigation
    bool gpsOk = m_connected && (m_gpsFixType >= 3) && (m_gpsSats >= 6) && (m_gpsHDOP <= 2.5);
    res["gps"] = gpsOk;
    res["gps_msg"] = gpsOk ? QString("3D Fix (%1 Sats, HDOP %2)").arg(m_gpsSats).arg(m_gpsHDOP, 0, 'f', 2)
                           : QString("Degraded (%1 Sats, Fix:%2, HDOP %3)")
                              .arg(m_gpsSats).arg(m_gpsFixType).arg(m_gpsHDOP, 0, 'f', 1);

    // 6. Battery Health
    bool batOk = m_connected && (m_batteryPercent >= 25 || (m_batteryVoltage > 11.1 && m_batteryPercent == -1));
    res["battery"] = batOk;
    res["battery_msg"] = batOk ? QString("%1% (%2 V)").arg(m_batteryPercent).arg(m_batteryVoltage, 0, 'f', 1)
                               : (m_batteryPercent >= 0 ? QString("Low Battery (%1%)").arg(m_batteryPercent)
                                                        : "No Battery Telemetry");

    bool allPassed = linkOk && imuOk && compassOk && baroOk && gpsOk && batOk;
    res["all_passed"] = allPassed;

    return res;
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
    addFlightLog("MODE", QString("Flight mode set to %1").arg(upperMode));
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
        addFlightLog(m_armed ? "CRITICAL" : "WARN", m_armed ? "Propulsion systems ARMED" : "Propulsion systems DISARMED");
        emit armedChanged();
    }

    if (m_flightMode != mode) {
        m_flightMode = mode;
        addFlightLog("MODE", QString("Flight mode set to %1").arg(mode));
        emit flightModeChanged();
    }

    if (!statusText.isEmpty() && m_lastStatusText != statusText) {
        m_lastStatusText = statusText;
        addFlightLog("STATUS", statusText);
        emit statusTextReceived();
    }

    qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - m_lastPeriodicLogTime >= 3000 || m_flightLogs.size() < 4) {
        m_lastPeriodicLogTime = now;
        addFlightLog("TELEMETRY", QString("Alt: %1m AGL | Spd: %2m/s | Bat: %3% (%4V) | Sats: %5 (HDOP %6)")
                                      .arg(m_relAlt, 0, 'f', 1)
                                      .arg(m_groundSpeed, 0, 'f', 1)
                                      .arg(m_batteryPercent)
                                      .arg(m_batteryVoltage, 0, 'f', 1)
                                      .arg(m_gpsSats)
                                      .arg(m_gpsHDOP, 0, 'f', 2));
    }

    updateDistancesAndReturnRadius();
    checkGeofenceBreach();
}

void DroneVehicle::addFlightLog(const QString &level, const QString &message)
{
    FlightLogRecord rec;
    rec.timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
    rec.epochMs = QDateTime::currentMSecsSinceEpoch();
    rec.level = level;
    rec.message = message;
    rec.lat = m_lat;
    rec.lon = m_lon;
    rec.alt = m_relAlt;
    rec.speed = m_groundSpeed;
    rec.heading = m_heading;
    rec.battery = m_batteryPercent;
    rec.voltage = m_batteryVoltage;
    rec.sats = m_gpsSats;
    rec.hdop = m_gpsHDOP;
    rec.flightMode = m_flightMode;
    rec.armed = m_armed;

    m_flightLogs.append(rec);
    if (m_flightLogs.size() > 3000) {
        m_flightLogs.removeFirst();
    }
    emit flightLogsChanged();
}

int DroneVehicle::flightLogCount() const
{
    return m_flightLogs.size();
}

QVariantList DroneVehicle::flightLogs() const
{
    QVariantList list;
    list.reserve(m_flightLogs.size());
    for (int i = m_flightLogs.size() - 1; i >= 0; --i) {
        const auto &rec = m_flightLogs.at(i);
        QVariantMap map;
        map["timestamp"] = rec.timestamp;
        map["timeShort"] = rec.timestamp.mid(11, 12); // "HH:mm:ss.zzz"
        map["epochMs"] = rec.epochMs;
        map["level"] = rec.level;
        map["message"] = rec.message;
        map["lat"] = rec.lat;
        map["lon"] = rec.lon;
        map["alt"] = rec.alt;
        map["speed"] = rec.speed;
        map["heading"] = rec.heading;
        map["battery"] = rec.battery;
        map["voltage"] = rec.voltage;
        map["sats"] = rec.sats;
        map["hdop"] = rec.hdop;
        map["flightMode"] = rec.flightMode;
        map["armed"] = rec.armed;
        list.append(map);
    }
    return list;
}

void DroneVehicle::clearFlightLogs()
{
    m_flightLogs.clear();
    addFlightLog("INFO", "Flight logs cleared by operator");
    emit flightLogsChanged();
}

QString DroneVehicle::exportFlightLogsToCsv(const QString &targetDir)
{
    QString dirPath = targetDir;
    if (dirPath.isEmpty()) {
        dirPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + "/DRONE_GCS_FlightLogs";
    }
    QDir dir(dirPath);
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    QString fileName = QString("flight_log_SYS%1_%2.csv")
                           .arg(m_sysId)
                           .arg(QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss"));
    QString fullPath = dir.filePath(fileName);

    QFile file(fullPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "[DroneVehicle] Failed to write flight log CSV to" << fullPath;
        return QString();
    }

    QTextStream out(&file);
    out << "Timestamp,EpochMs,SysId,DroneName,Level,Message,Latitude,Longitude,Altitude_AGL_m,GroundSpeed_ms,Heading_deg,Battery_pct,Voltage_v,GPS_Sats,GPS_HDOP,FlightMode,Armed\n";

    for (const auto &rec : m_flightLogs) {
        QString escapedMsg = rec.message;
        escapedMsg.replace("\"", "\"\"");
        out << "\"" << rec.timestamp << "\","
            << rec.epochMs << ","
            << m_sysId << ","
            << "\"" << m_name << "\","
            << "\"" << rec.level << "\","
            << "\"" << escapedMsg << "\","
            << QString::number(rec.lat, 'f', 7) << ","
            << QString::number(rec.lon, 'f', 7) << ","
            << QString::number(rec.alt, 'f', 2) << ","
            << QString::number(rec.speed, 'f', 2) << ","
            << QString::number(rec.heading, 'f', 1) << ","
            << rec.battery << ","
            << QString::number(rec.voltage, 'f', 2) << ","
            << rec.sats << ","
            << QString::number(rec.hdop, 'f', 2) << ","
            << "\"" << rec.flightMode << "\","
            << (rec.armed ? "TRUE" : "FALSE") << "\n";
    }

    file.close();
    qDebug() << "[DroneVehicle] Exported" << m_flightLogs.size() << "flight log rows to" << fullPath;
    addFlightLog("INFO", QString("Exported %1 log entries to %2").arg(m_flightLogs.size()).arg(fileName));
    return fullPath;
}
