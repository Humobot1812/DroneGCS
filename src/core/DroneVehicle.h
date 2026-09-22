#pragma once
#include <QObject>
#include <QString>
#include <QTimer>
#include <QGeoCoordinate>
#include <QList>
#include <QVariantList>
#include <QVariantMap>
#include <QMap>

/**
 * DroneVehicle — represents one physical or simulated drone.
 * All properties are Q_PROPERTY so QML binds to them automatically.
 */
class DroneVehicle : public QObject
{
    Q_OBJECT

    // Identity
    Q_PROPERTY(int sysId           READ sysId              CONSTANT)
    Q_PROPERTY(QString name        READ name       WRITE setName   NOTIFY nameChanged)
    Q_PROPERTY(QString color       READ color      WRITE setColor  NOTIFY colorChanged)

    // Connection
    Q_PROPERTY(bool isConnected    READ isConnected    NOTIFY connectionChanged)
    Q_PROPERTY(int  heartbeatHz    READ heartbeatHz    NOTIFY heartbeatReceived)

    // Arm / flight state
    Q_PROPERTY(bool isArmed        READ isArmed        NOTIFY armedChanged)
    Q_PROPERTY(QString flightMode  READ flightMode     NOTIFY flightModeChanged)
    Q_PROPERTY(int  mav_type       READ mavType        NOTIFY mavTypeChanged)

    // Autopilot & vehicle identification (populated from heartbeat)
    Q_PROPERTY(QString autopilotType READ autopilotType NOTIFY autopilotTypeChanged)
    Q_PROPERTY(QString vehicleType   READ vehicleType   NOTIFY vehicleTypeChanged)

    // Position
    Q_PROPERTY(double latitude     READ latitude       NOTIFY positionChanged)
    Q_PROPERTY(double longitude    READ longitude      NOTIFY positionChanged)
    Q_PROPERTY(double altitude     READ altitude       NOTIFY positionChanged)
    Q_PROPERTY(double relAltitude  READ relAltitude    NOTIFY positionChanged)
    Q_PROPERTY(double headingDeg   READ headingDeg     NOTIFY headingChanged)

    // Attitude
    Q_PROPERTY(double roll         READ roll           NOTIFY attitudeChanged)
    Q_PROPERTY(double pitch        READ pitch          NOTIFY attitudeChanged)
    Q_PROPERTY(double yaw          READ yaw            NOTIFY attitudeChanged)

    // Speed
    Q_PROPERTY(double groundSpeed  READ groundSpeed    NOTIFY speedChanged)
    Q_PROPERTY(double airSpeed     READ airSpeed       NOTIFY speedChanged)
    Q_PROPERTY(double climbRate    READ climbRate      NOTIFY speedChanged)

    // Battery
    Q_PROPERTY(int   batteryPercent READ batteryPercent NOTIFY batteryChanged)
    Q_PROPERTY(double batteryVoltage READ batteryVoltage NOTIFY batteryChanged)

    // GPS
    Q_PROPERTY(int   gpsSats        READ gpsSats        NOTIFY gpsChanged)
    Q_PROPERTY(int   gpsFixType     READ gpsFixType     NOTIFY gpsChanged)
    Q_PROPERTY(double gpsHDOP       READ gpsHDOP        NOTIFY gpsChanged)

    // Mission
    Q_PROPERTY(int   missionCurrent  READ missionCurrent  NOTIFY missionProgressChanged)
    Q_PROPERTY(int   missionTotal    READ missionTotal    NOTIFY missionProgressChanged)
    Q_PROPERTY(bool  missionUploadActive READ missionUploadActive NOTIFY missionUploadActiveChanged)
    Q_PROPERTY(double missionUploadProgress READ missionUploadProgress NOTIFY missionUploadProgressChanged)

    // Status text
    Q_PROPERTY(QString lastStatusText READ lastStatusText NOTIFY statusTextReceived)

    // Home position
    Q_PROPERTY(double homeLat READ homeLat NOTIFY homePositionChanged)
    Q_PROPERTY(double homeLon READ homeLon NOTIFY homePositionChanged)
    Q_PROPERTY(double homeAlt READ homeAlt NOTIFY homePositionChanged)
    Q_PROPERTY(double distanceToHome READ distanceToHome NOTIFY distanceToHomeChanged)
    Q_PROPERTY(double safeReturnRadius READ safeReturnRadius NOTIFY safeReturnRadiusChanged)

    // Geofencing
    Q_PROPERTY(bool geofenceEnabled READ geofenceEnabled WRITE setGeofenceEnabled NOTIFY geofenceChanged)
    Q_PROPERTY(bool circularFenceEnabled READ circularFenceEnabled WRITE setCircularFenceEnabled NOTIFY circularFenceEnabledChanged)
    Q_PROPERTY(int geofenceAction READ geofenceAction WRITE setGeofenceAction NOTIFY geofenceChanged)
    Q_PROPERTY(double geofenceRadius READ geofenceRadius WRITE setGeofenceRadius NOTIFY geofenceChanged)
    Q_PROPERTY(double geofenceMinAlt READ geofenceMinAlt WRITE setGeofenceMinAlt NOTIFY geofenceChanged)
    Q_PROPERTY(double geofenceMaxAlt READ geofenceMaxAlt WRITE setGeofenceMaxAlt NOTIFY geofenceChanged)
    Q_PROPERTY(bool geofenceBreached READ geofenceBreached NOTIFY geofenceBreachedChanged)
    Q_PROPERTY(QString geofenceBreachReason READ geofenceBreachReason NOTIFY geofenceBreachedChanged)
    Q_PROPERTY(QVariantList geofencePolygon READ geofencePolygon WRITE setGeofencePolygon NOTIFY geofencePolygonChanged)

    // Flight Logging & Telemetry Recorder
    Q_PROPERTY(QVariantList flightLogs READ flightLogs NOTIFY flightLogsChanged)
    Q_PROPERTY(int flightLogCount READ flightLogCount NOTIFY flightLogsChanged)

public:
    explicit DroneVehicle(quint8 sysId, QObject *parent = nullptr);

    // Getters
    int       sysId()           const { return m_sysId; }
    QString   name()            const { return m_name; }
    QString   color()           const { return m_color; }
    bool      isConnected()     const { return m_connected; }
    int       heartbeatHz()     const { return m_heartbeatHz; }
    bool      isArmed()         const { return m_armed; }
    QString   flightMode()      const { return m_flightMode; }
    int       mavType()         const { return m_mavType; }
    QString   autopilotType()   const { return m_autopilotType; }
    QString   vehicleType()     const { return m_vehicleType; }
    double    latitude()        const { return m_lat; }
    double    longitude()       const { return m_lon; }
    double    altitude()        const { return m_alt; }
    double    relAltitude()     const { return m_relAlt; }
    double    headingDeg()      const { return m_heading; }
    double    roll()            const { return m_roll; }
    double    pitch()           const { return m_pitch; }
    double    yaw()             const { return m_yaw; }
    double    groundSpeed()     const { return m_groundSpeed; }
    double    airSpeed()        const { return m_airSpeed; }
    double    climbRate()       const { return m_climbRate; }
    int       batteryPercent()  const { return m_batteryPercent; }
    double    batteryVoltage()  const { return m_batteryVoltage; }
    int       gpsSats()         const { return m_gpsSats; }
    int       gpsFixType()      const { return m_gpsFixType; }
    double    gpsHDOP()         const { return m_gpsHDOP; }
    int       missionCurrent()  const { return m_missionCurrent; }
    int       missionTotal()    const { return m_missionTotal; }
    bool      missionUploadActive() const { return m_missionUploadActive; }
    double    missionUploadProgress() const { return m_missionUploadProgress; }
    QString   lastStatusText()  const { return m_lastStatusText; }
    double    homeLat()         const { return m_homeLat; }
    double    homeLon()         const { return m_homeLon; }
    double    homeAlt()         const { return m_homeAlt; }
    double    distanceToHome()  const { return m_distanceToHome; }
    double    safeReturnRadius() const { return m_safeReturnRadius; }

    bool      geofenceEnabled() const { return m_geofenceEnabled; }
    bool      circularFenceEnabled() const { return m_circularFenceEnabled; }
    int       geofenceAction()  const { return m_geofenceAction; }
    double    geofenceRadius()  const { return m_geofenceRadius; }
    double    geofenceMinAlt()  const { return m_geofenceMinAlt; }
    double    geofenceMaxAlt()  const { return m_geofenceMaxAlt; }
    bool      geofenceBreached() const { return m_geofenceBreached; }
    QString   geofenceBreachReason() const { return m_geofenceBreachReason; }
    QVariantList geofencePolygon() const { return m_geofencePolygon; }

    void setName(const QString &n);
    void setColor(const QString &c);
    void setAutopilotType(const QString &ap) { if (m_autopilotType != ap) { m_autopilotType = ap; emit autopilotTypeChanged(); } }
    void setVehicleType(const QString &vt)   { if (m_vehicleType != vt) { m_vehicleType = vt; emit vehicleTypeChanged(); } }
    void disconnect();

    // Called by DroneManager when a packet arrives for this sysId
    void processPacket(const QByteArray &rawPacket);

    // QML invokable commands
    Q_INVOKABLE void arm();
    Q_INVOKABLE void disarm();
    Q_INVOKABLE void setFlightMode(const QString &mode);
    Q_INVOKABLE void takeoff(double altitudeM);
    Q_INVOKABLE void returnToLaunch();
    Q_INVOKABLE void land();
    Q_INVOKABLE void startMission();
    Q_INVOKABLE void pauseMission();
    Q_INVOKABLE void emergencyKill();
    Q_INVOKABLE void gotoLocation(double lat, double lon, double alt);
    Q_INVOKABLE void uploadWaypoints(const QVariantList &waypoints);
    Q_INVOKABLE void clearMission();

    // Pre-flight automated checklist
    Q_INVOKABLE QVariantMap runPreflightCheck();

    // Flight Logging & Export
    QVariantList flightLogs() const;
    int flightLogCount() const;
    Q_INVOKABLE void addFlightLog(const QString &level, const QString &message);
    Q_INVOKABLE QString exportFlightLogsToCsv(const QString &targetDir = QString());
    Q_INVOKABLE void clearFlightLogs();

    // Geofencing invokables
    Q_INVOKABLE void setGeofenceEnabled(bool enabled);
    Q_INVOKABLE void setCircularFenceEnabled(bool enabled);
    Q_INVOKABLE void setGeofenceAction(int action);
    Q_INVOKABLE void setGeofenceRadius(double radius);
    Q_INVOKABLE void setGeofenceMinAlt(double minAlt);
    Q_INVOKABLE void setGeofenceMaxAlt(double maxAlt);
    Q_INVOKABLE void setGeofencePolygon(const QVariantList &polygon);
    Q_INVOKABLE void uploadGeofence(const QVariantList &polygon, double maxAlt, double minAlt, double radius, int action);
    Q_INVOKABLE void uploadGeofence(bool enabled, double radius, double minAlt, double maxAlt, int action, const QVariantList &polygon);
    Q_INVOKABLE void clearGeofence();

    // Simulation / Mock telemetry update
    void updateSimulatedTelemetry(double lat, double lon, double alt, double relAlt,
                                  double heading, double roll, double pitch, double yaw,
                                  double groundSpeed, double airSpeed, double climbRate,
                                  int batteryPercent, double batteryVoltage,
                                  int gpsSats, double gpsHDOP,
                                  bool armed, const QString &mode, const QString &statusText);

signals:
    void nameChanged();
    void colorChanged();
    void connectionChanged();
    void heartbeatReceived();
    void armedChanged();
    void flightModeChanged();
    void mavTypeChanged();
    void autopilotTypeChanged();
    void vehicleTypeChanged();
    void positionChanged();
    void headingChanged();
    void attitudeChanged();
    void speedChanged();
    void batteryChanged();
    void gpsChanged();
    void missionProgressChanged();
    void missionUploadActiveChanged();
    void missionUploadProgressChanged();
    void missionUploadComplete(bool success);
    void missionCleared();
    void statusTextReceived();
    void homePositionChanged();
    void distanceToHomeChanged();
    void safeReturnRadiusChanged();
    void geofenceChanged();
    void circularFenceEnabledChanged();
    void geofenceBreachedChanged();
    void geofenceBreachChanged();
    void geofencePolygonChanged();
    void flightLogsChanged();

    // Raw bytes to send (connected to link by AbstractLink::write)
    void sendBytes(const QByteArray &bytes);

private:
    void parseHeartbeat(const uint8_t *payload, int len);
    void parseGlobalPosition(const uint8_t *payload, int len);
    void parseAttitude(const uint8_t *payload, int len);
    void parseVfrHud(const uint8_t *payload, int len);
    void parseSysStatus(const uint8_t *payload, int len);
    void parseGpsRaw(const uint8_t *payload, int len);
    void parseMissionCurrent(const uint8_t *payload, int len);
    void parseStatusText(const uint8_t *payload, int len);
    void parseHomePosition(const uint8_t *payload, int len);

    // MAVLink Mission Protocol helpers
    void sendMissionCount(int count);
    void handleMissionRequest(int seq);
    void checkGeofenceBreach();
    void updateDistancesAndReturnRadius();
    void sendMavlinkParam(const char *paramId, float value);

    QByteArray buildCommandLong(uint16_t cmd, float p1=0, float p2=0,
                                float p3=0, float p4=0, float p5=0,
                                float p6=0, float p7=0) const;

    quint8  m_sysId       = 0;
    QString m_name;
    QString m_color;
    bool    m_connected   = false;
    int     m_heartbeatHz = 0;
    bool    m_armed       = false;
    QString m_flightMode;
    int     m_mavType     = 0;
    QString m_autopilotType;   // "ArduPilot", "PX4", "Generic", ...
    QString m_vehicleType;     // "Quadrotor", "Hexarotor", "Fixed Wing", "Rover", ...

    double  m_lat = 0, m_lon = 0, m_alt = 0, m_relAlt = 0;
    double  m_heading = 0;
    double  m_roll = 0, m_pitch = 0, m_yaw = 0;
    double  m_groundSpeed = 0, m_airSpeed = 0, m_climbRate = 0;

    int    m_batteryPercent = -1;
    double m_batteryVoltage = 0.0;

    int    m_gpsSats    = 0;
    int    m_gpsFixType = 0;
    double m_gpsHDOP    = 99.0;

    int m_missionCurrent = 0;
    int m_missionTotal   = 0;
    bool m_missionUploadActive = false;
    double m_missionUploadProgress = 0.0;
    bool m_missionClearPending = false;  // set while awaiting MISSION_ACK from MISSION_CLEAR_ALL
    QVariantList m_pendingWaypoints;
    QTimer *m_uploadTimeoutTimer = nullptr;
    int m_uploadRetryCount = 0;

    QString m_lastStatusText;

    double  m_homeLat = 0, m_homeLon = 0, m_homeAlt = 0;
    double  m_distanceToHome = 0.0;
    double  m_safeReturnRadius = 0.0;

    // Geofencing state
    bool    m_geofenceEnabled = false;
    bool    m_circularFenceEnabled = false;
    int     m_geofenceAction = 1; // 0=Warn, 1=RTL, 2=Land, 3=Loiter
    double  m_geofenceRadius = 300.0;
    double  m_geofenceMinAlt = 2.0;
    double  m_geofenceMaxAlt = 120.0;
    bool    m_geofenceBreached = false;
    QString m_geofenceBreachReason;
    QVariantList m_geofencePolygon;

    // heartbeat timing
    QTimer *m_heartbeatTimer = nullptr;
    qint64  m_lastHeartbeat  = 0;
    qint64  m_lastPacketTime = 0;

    // Flight Log Records
    struct FlightLogRecord {
        QString timestamp;
        qint64 epochMs = 0;
        QString level;
        QString message;
        double lat = 0.0;
        double lon = 0.0;
        double alt = 0.0;
        double speed = 0.0;
        double heading = 0.0;
        int battery = 0;
        double voltage = 0.0;
        int sats = 0;
        double hdop = 0.0;
        QString flightMode;
        bool armed = false;
    };
    QVector<FlightLogRecord> m_flightLogs;
    qint64 m_lastPeriodicLogTime = 0;

    static constexpr quint8 k_gcsSystemId = 255;
    static constexpr quint8 k_gcsCompId   = 190;
};
