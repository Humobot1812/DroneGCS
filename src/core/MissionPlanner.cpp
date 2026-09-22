#include "MissionPlanner.h"
#include <ardupilotmega/mavlink.h>
#include <QDebug>
#include <QVariantMap>
#include <cmath>
#include <algorithm>

MissionPlanner::MissionPlanner(QObject *parent) : QObject(parent) {}

// ─── Polygon intersection helpers ────────────────────────────────────────────

struct Pt { double x, y; };  // x=lon, y=lat

static bool lineIntersect(Pt p1, Pt p2, Pt p3, Pt p4, Pt &out)
{
    double d1x = p2.x - p1.x, d1y = p2.y - p1.y;
    double d2x = p4.x - p3.x, d2y = p4.y - p3.y;
    double denom = d1x * d2y - d1y * d2x;
    if (std::abs(denom) < 1e-12) return false;
    double t = ((p3.x - p1.x) * d2y - (p3.y - p1.y) * d2x) / denom;
    double u = ((p3.x - p1.x) * d1y - (p3.y - p1.y) * d1x) / denom;
    if (t < 0 || t > 1 || u < 0 || u > 1) return false;
    out = {p1.x + t * d1x, p1.y + t * d1y};
    return true;
}

static std::vector<double> sweepIntersections(const std::vector<Pt> &poly,
                                               double sweepLon)
{
    std::vector<double> lats;
    int n = static_cast<int>(poly.size());
    for (int i = 0; i < n; ++i) {
        Pt a = poly[i], b = poly[(i + 1) % n];
        Pt p3{sweepLon, -90}, p4{sweepLon, 90};
        Pt inter;
        if (lineIntersect(a, b, p3, p4, inter))
            lats.push_back(inter.y);
    }
    std::sort(lats.begin(), lats.end());
    return lats;
}

// ─── Zigzag generation ────────────────────────────────────────────────────────

QVariantList MissionPlanner::generateZigzag(const QVariantList &polygon,
                                              double spacingM,
                                              double homeLat,
                                              double homeLon,
                                              double altitudeM)
{
    if (polygon.size() < 3) return {};

    // Build polygon in (lon, lat)
    std::vector<Pt> poly;
    double minLon = 1e9, maxLon = -1e9, minLat = 1e9, maxLat = -1e9;

    for (const auto &pt : polygon) {
        auto m = pt.toMap();
        double lat = m["lat"].toDouble();
        double lon = m["lon"].toDouble();
        poly.push_back({lon, lat});
        minLon = std::min(minLon, lon);
        maxLon = std::max(maxLon, lon);
        minLat = std::min(minLat, lat);
        maxLat = std::max(maxLat, lat);
    }

    double meanLat = (minLat + maxLat) / 2.0;
    double lonStep  = mToLon(spacingM, meanLat);

    // Determine sweep direction (start closer to home)
    bool startFromMin = (std::abs(homeLon - minLon) < std::abs(homeLon - maxLon));
    double cur = startFromMin ? minLon : maxLon;
    double step = startFromMin ? lonStep : -lonStep;

    QVariantList result;
    int seq = 0;
    bool toggle = false;

    while ((startFromMin ? cur <= maxLon : cur >= minLon)) {
        auto lats = sweepIntersections(poly, cur);
        if (lats.size() >= 2) {
            // Take outermost pair
            double latA = lats.front();
            double latB = lats.back();
            if (toggle) std::swap(latA, latB);

            QVariantMap wp1, wp2;
            wp1["lat"] = latA; wp1["lon"] = cur; wp1["alt"] = altitudeM; wp1["seq"] = seq++;
            wp2["lat"] = latB; wp2["lon"] = cur; wp2["alt"] = altitudeM; wp2["seq"] = seq++;
            result.append(wp1);
            result.append(wp2);
            toggle = !toggle;
        }
        cur += step;
    }

    m_waypoints = result;
    qDebug() << "MissionPlanner: generated" << result.size() << "waypoints";
    emit waypointsGenerated(result);
    return result;
}

// ─── Build MAVLink mission packets ───────────────────────────────────────────

QList<QByteArray> MissionPlanner::buildMissionPackets(const QVariantList &waypoints,
                                                        double altM,
                                                        quint8 targetSysId) const
{
    QList<QByteArray> packets;
    constexpr quint8 gcs_sysid = 255, gcs_compid = 190;

    // MISSION_COUNT
    {
        mavlink_message_t msg;
        uint8_t buf[MAVLINK_MAX_PACKET_LEN];
        mavlink_msg_mission_count_pack(gcs_sysid, gcs_compid, &msg,
                                        targetSysId, MAV_COMP_ID_AUTOPILOT1,
                                        static_cast<uint16_t>(waypoints.size()),
                                        MAV_MISSION_TYPE_MISSION,
                                        0 /* opaque_id, optional */);
        int len = mavlink_msg_to_send_buffer(buf, &msg);
        packets.append(QByteArray(reinterpret_cast<char*>(buf), len));
    }

    // MISSION_ITEM_INT for each waypoint
    int seq = 0;
    for (const auto &v : waypoints) {
        auto m = v.toMap();
        double lat = m["lat"].toDouble();
        double lon = m["lon"].toDouble();

        mavlink_message_t msg;
        uint8_t buf[MAVLINK_MAX_PACKET_LEN];
        mavlink_msg_mission_item_int_pack(
            gcs_sysid, gcs_compid, &msg,
            targetSysId, MAV_COMP_ID_AUTOPILOT1,
            static_cast<uint16_t>(seq++),
            MAV_FRAME_GLOBAL_RELATIVE_ALT_INT,
            MAV_CMD_NAV_WAYPOINT,
            0, 1,                         // current, autocontinue
            0, 0, 0,                      // param1-3 (hold time, radius, pass radius)
            std::numeric_limits<float>::quiet_NaN(), // yaw
            static_cast<int32_t>(lat * 1e7),
            static_cast<int32_t>(lon * 1e7),
            static_cast<float>(altM),
            MAV_MISSION_TYPE_MISSION
        );
        int len = mavlink_msg_to_send_buffer(buf, &msg);
        packets.append(QByteArray(reinterpret_cast<char*>(buf), len));
    }

    return packets;
}
