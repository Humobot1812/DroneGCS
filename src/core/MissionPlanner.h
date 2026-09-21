#pragma once
#include <QObject>
#include <QVariantList>

struct Waypoint {
    double lat, lon, altM;
    int    seq;
};

/**
 * MissionPlanner — generates survey waypoints and uploads them via MAVLink.
 * Also handles downloading the current mission from a vehicle.
 */
class MissionPlanner : public QObject
{
    Q_OBJECT
public:
    explicit MissionPlanner(QObject *parent = nullptr);

    /**
     * Generate zigzag survey waypoints inside a polygon.
     * @param polygon  List of [lat, lon] pairs
     * @param spacingM Sweep line spacing in meters
     * @param homeLat  Home latitude (to choose nearest start sweep)
     * @param homeLon  Home longitude
     * @return List of QVariantMaps {"lat", "lon", "seq"}
     */
    Q_INVOKABLE QVariantList generateZigzag(const QVariantList &polygon,
                                             double spacingM,
                                             double homeLat,
                                             double homeLon);

    /**
     * Build MAVLink MISSION_ITEM_INT packets for a waypoint list.
     * Returns raw bytes to send to the drone.
     */
    QList<QByteArray> buildMissionPackets(const QVariantList &waypoints,
                                           double altM,
                                           quint8 targetSysId) const;

    Q_INVOKABLE int waypointCount() const { return m_waypoints.size(); }
    Q_INVOKABLE QVariantList waypoints() const { return m_waypoints; }

signals:
    void waypointsGenerated(const QVariantList &waypoints);

private:
    // Geo helpers
    static double degToRad(double d) { return d * M_PI / 180.0; }
    static double mToLat(double meters) { return meters / 111139.0; }
    static double mToLon(double meters, double lat) {
        return meters / (111139.0 * std::cos(degToRad(lat)));
    }

    QVariantList m_waypoints;
};
