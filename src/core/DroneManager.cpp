#include "DroneManager.h"
#include "DroneVehicle.h"
#include "../mavlink/AbstractLink.h"
#include "../mavlink/SerialLink.h"
#include "../mavlink/UDPLink.h"
#include "../mavlink/TCPLink.h"
#include "../mavlink/MAVLinkBridge.h"

#include <QSerialPortInfo>
#include <QDebug>

const QStringList DroneManager::k_droneColors = {
    "#00d4ff",  // cyan
    "#ffa500",  // amber
    "#3fb950",  // green
    "#ff6b6b",  // coral red
    "#c084fc",  // purple
    "#34d399",  // emerald
    "#f59e0b",  // yellow
    "#60a5fa",  // blue
};

DroneManager::DroneManager(QObject *parent)
    : QAbstractListModel(parent)
{
}

DroneManager::~DroneManager()
{
    qDeleteAll(m_drones);
}

// ─── QAbstractListModel ───────────────────────────────────────────────────────

int DroneManager::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_drones.count();
}

QVariant DroneManager::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_drones.count())
        return QVariant();

    DroneVehicle *drone = m_drones.at(index.row());
    switch (role) {
    case DroneIdRole:   return drone->sysId();
    case DroneNameRole: return drone->name();
    case DroneObjectRole: return QVariant::fromValue(drone);
    case ConnectedRole: return drone->isConnected();
    case ArmedRole:     return drone->isArmed();
    case FlightModeRole: return drone->flightMode();
    case ColorRole:     return k_droneColors.value(index.row() % k_droneColors.size());
    }
    return QVariant();
}

QHash<int, QByteArray> DroneManager::roleNames() const
{
    return {
        {DroneIdRole,    "droneId"},
        {DroneNameRole,  "droneName"},
        {DroneObjectRole,"droneObject"},
        {ConnectedRole,  "connected"},
        {ArmedRole,      "armed"},
        {FlightModeRole, "flightMode"},
        {ColorRole,      "color"},
    };
}

// ─── Connections ──────────────────────────────────────────────────────────────

void DroneManager::addSerialConnection(const QString &port, int baudRate)
{
    qDebug() << "DroneManager: adding serial" << port << "@" << baudRate;
    auto *link = new SerialLink(port, baudRate, this);
    auto *bridge = new MAVLinkBridge(link, this);

    m_links.append(link);  // register so DroneVehicle::sendBytes can reach it

    connect(bridge, &MAVLinkBridge::packetReceived,
            this, [this](quint8 sysId, const QByteArray &pkt) {
        routePacket(sysId, pkt);
    });

    // Wire any already-created drones to this new link
    for (auto *d : m_drones)
        connect(d, &DroneVehicle::sendBytes, link, &AbstractLink::write, Qt::QueuedConnection);

    link->connect();
}

void DroneManager::addUDPConnection(const QString &host, int port)
{
    qDebug() << "DroneManager: adding UDP" << host << ":" << port;
    auto *link = new UDPLink(host, port, this);
    auto *bridge = new MAVLinkBridge(link, this);

    m_links.append(link);  // register so DroneVehicle::sendBytes can reach it

    connect(bridge, &MAVLinkBridge::packetReceived,
            this, [this](quint8 sysId, const QByteArray &pkt) {
        routePacket(sysId, pkt);
    });

    // Wire any already-created drones to this new link
    for (auto *d : m_drones)
        connect(d, &DroneVehicle::sendBytes, link, &AbstractLink::write, Qt::QueuedConnection);

    link->connect();
}

void DroneManager::addTCPConnection(const QString &host, int port)
{
    qDebug() << "DroneManager: adding TCP" << host << ":" << port;
    auto *link = new TCPLink(host, port, this);
    auto *bridge = new MAVLinkBridge(link, this);

    m_links.append(link);  // register so DroneVehicle::sendBytes can reach it

    connect(bridge, &MAVLinkBridge::packetReceived,
            this, [this](quint8 sysId, const QByteArray &pkt) {
        routePacket(sysId, pkt);
    });

    // Wire any already-created drones to this new link
    for (auto *d : m_drones)
        connect(d, &DroneVehicle::sendBytes, link, &AbstractLink::write, Qt::QueuedConnection);

    link->connect();
}

void DroneManager::removeConnection(int index)
{
    if (index < 0 || index >= m_drones.count()) return;

    beginRemoveRows(QModelIndex(), index, index);
    DroneVehicle *drone = m_drones.takeAt(index);
    drone->disconnect();
    drone->deleteLater();
    endRemoveRows();

    if (m_activeDroneIndex >= m_drones.count())
        setActiveDroneIndex(m_drones.count() - 1);

    emit droneCountChanged();
    emit droneRemoved(index);
}

void DroneManager::routePacket(quint8 sysId, const QByteArray &rawPacket)
{
    DroneVehicle *drone = getOrCreateDrone(sysId);
    drone->processPacket(rawPacket);
}

DroneVehicle* DroneManager::getOrCreateDrone(quint8 sysId)
{
    for (auto *d : m_drones)
        if (d->sysId() == sysId) return d;

    // New drone discovered
    int idx = m_drones.count();
    beginInsertRows(QModelIndex(), idx, idx);

    auto *drone = new DroneVehicle(sysId, this);
    drone->setColor(k_droneColors.value(idx % k_droneColors.size()));
    drone->setName(QString("Drone %1 (SYS:%2)").arg(idx + 1).arg(sysId));

    // Wire drone's outgoing commands to ALL registered links
    for (auto *link : m_links)
        connect(drone, &DroneVehicle::sendBytes, link, &AbstractLink::write, Qt::QueuedConnection);

    m_drones.append(drone);
    endInsertRows();

    // ── Relay drone property changes → model dataChanged ─────────────────────
    // This is what makes the ListView tab update live (connected/armed/mode)
    auto notifyRow = [this, drone]() {
        int row = m_drones.indexOf(drone);
        if (row >= 0) {
            QModelIndex mi = index(row);
            emit dataChanged(mi, mi, {ConnectedRole, ArmedRole, FlightModeRole, DroneNameRole});
        }
    };
    connect(drone, &DroneVehicle::connectionChanged,    this, notifyRow);
    connect(drone, &DroneVehicle::armedChanged,         this, notifyRow);
    connect(drone, &DroneVehicle::flightModeChanged,    this, notifyRow);
    connect(drone, &DroneVehicle::nameChanged,          this, notifyRow);
    // ─────────────────────────────────────────────────────────────────────────

    if (m_activeDroneIndex < 0) {
        m_activeDroneIndex = 0;
        emit activeDroneIndexChanged();
        emit activeDroneChanged();
    }

    emit droneCountChanged();
    emit droneAdded(drone);

    qDebug() << "DroneManager: new drone sysId=" << sysId << "color=" << drone->color();
    return drone;
}

// ─── Accessors ────────────────────────────────────────────────────────────────

DroneVehicle* DroneManager::activeDrone() const
{
    if (m_activeDroneIndex < 0 || m_activeDroneIndex >= m_drones.count())
        return nullptr;
    return m_drones.at(m_activeDroneIndex);
}

DroneVehicle* DroneManager::droneById(int sysId) const
{
    for (auto *d : m_drones)
        if (d->sysId() == sysId) return d;
    return nullptr;
}

DroneVehicle* DroneManager::droneAt(int index) const
{
    if (index < 0 || index >= m_drones.count()) return nullptr;
    return m_drones.at(index);
}

void DroneManager::setActiveDroneIndex(int index)
{
    if (index == m_activeDroneIndex) return;
    m_activeDroneIndex = index;
    emit activeDroneIndexChanged();
    emit activeDroneChanged();
}

QStringList DroneManager::availableSerialPorts() const
{
    QStringList ports;
    for (const auto &info : QSerialPortInfo::availablePorts())
        ports << info.portName();
    return ports;
}

void DroneManager::startSimulation(int droneCount)
{
    if (m_simTimer && m_simTimer->isActive()) return;

    for (int i = 1; i <= droneCount; ++i) {
        DroneVehicle *d = getOrCreateDrone(static_cast<quint8>(i));
        if (i == 1) {
            d->setName("Alpha-1 (Quadcopter)");
            d->setVehicleType("Quadrotor");
            d->setAutopilotType("ArduPilot");
        } else if (i == 2) {
            d->setName("Beta-2 (Quadcopter)");
            d->setVehicleType("Quadrotor");
            d->setAutopilotType("PX4");
        } else {
            d->setName(QString("Drone-%1").arg(i));
            d->setVehicleType("Quadrotor");
            d->setAutopilotType("ArduPilot");
        }
    }

    if (!m_simTimer) {
        m_simTimer = new QTimer(this);
        m_simTimer->setInterval(40); // 25 Hz smooth telemetry
        connect(m_simTimer, &QTimer::timeout, this, [this]() {
            m_simTime += 0.04;
            double t = m_simTime;

            const double centerLat = 28.613939;
            const double centerLon = 77.209021;
            const double degPerMeter = 1.0 / 111320.0;

            for (int i = 0; i < m_drones.count(); ++i) {
                DroneVehicle *d = m_drones.at(i);
                if (!d) continue;

                if (i == 0) {
                    double omega = 0.15;
                    double radius = 150.0;
                    double angle = omega * t;
                    double dLat = radius * std::cos(angle) * degPerMeter;
                    double dLon = radius * std::sin(angle) * degPerMeter / std::cos(centerLat * M_PI / 180.0);
                    double lat = centerLat + dLat;
                    double lon = centerLon + dLon;

                    double headingRad = std::atan2(std::cos(angle), -std::sin(angle));
                    double headingDeg = std::fmod(headingRad * 180.0 / M_PI + 360.0, 360.0);

                    double roll = 14.0 * std::sin(t * 0.5);
                    double pitch = -3.0 + 1.5 * std::cos(t * 0.8);
                    double yaw = headingDeg;

                    double alt = 25.0 + 3.0 * std::sin(t * 0.2);
                    double relAlt = alt;
                    double speed = 12.4 + 0.8 * std::sin(t * 0.3);
                    double climbRate = 0.6 * std::cos(t * 0.2);

                    int bat = std::max(20, 95 - static_cast<int>(t / 20.0));
                    double batVolt = 21.8 + (bat / 100.0) * 3.4;

                    QString status = (static_cast<int>(t) % 15 == 0) ? "EKF3 IMU0 is using GPS" :
                                     (static_cast<int>(t) % 25 == 0) ? "Waypoint 3 reached" : "";

                    QString currentMode = d->flightMode().isEmpty() ? "GUIDED" : d->flightMode();
                    d->updateSimulatedTelemetry(lat, lon, alt, relAlt, headingDeg,
                                                roll, pitch, yaw, speed, speed, climbRate,
                                                bat, batVolt, 14, 0.9, d->isArmed(), currentMode, status);
                } else if (i == 1) {
                    double omega = 0.11;
                    double radius = 220.0;
                    double angle = omega * t;
                    double dLat = radius * std::sin(angle) * degPerMeter;
                    double dLon = (radius * 1.4) * std::sin(angle * 2.0) * 0.5 * degPerMeter / std::cos(centerLat * M_PI / 180.0);
                    double lat = (centerLat + 0.002) + dLat;
                    double lon = (centerLon + 0.002) + dLon;

                    double vx = radius * omega * std::cos(angle);
                    double vy = (radius * 1.4) * omega * std::cos(angle * 2.0);
                    double headingRad = std::atan2(vy, vx);
                    double headingDeg = std::fmod(headingRad * 180.0 / M_PI + 360.0, 360.0);

                    double roll = -18.0 * std::cos(angle * 2.0);
                    double pitch = -4.0 + 2.0 * std::sin(t * 0.6);
                    double yaw = headingDeg;

                    double alt = 45.0 + 5.0 * std::sin(t * 0.15);
                    double relAlt = alt;
                    double speed = 15.2 + 1.2 * std::sin(t * 0.4);
                    double climbRate = 0.75 * std::cos(t * 0.15);

                    int bat = std::max(15, 88 - static_cast<int>(t / 25.0));
                    double batVolt = 15.2 + (bat / 100.0) * 1.6;

                    QString status = (static_cast<int>(t) % 18 == 0) ? "Auto mission in progress" : "";

                    QString currentMode = d->flightMode().isEmpty() ? "AUTO" : d->flightMode();
                    d->updateSimulatedTelemetry(lat, lon, alt, relAlt, headingDeg,
                                                roll, pitch, yaw, speed, speed, climbRate,
                                                bat, batVolt, 16, 0.8, d->isArmed(), currentMode, status);
                }
            }
        });
    }

    m_simTimer->start();
    emit simulationStateChanged();
    qDebug() << "DroneManager: simulation started with" << droneCount << "drones";
}

void DroneManager::stopSimulation()
{
    if (m_simTimer) {
        m_simTimer->stop();
        emit simulationStateChanged();
        qDebug() << "DroneManager: simulation stopped";
    }
}

void DroneManager::armAll()
{
    for (auto *d : m_drones) {
        if (d) d->arm();
    }
    qDebug() << "DroneManager: Swarm ARM ALL sent to" << m_drones.count() << "drones";
}

void DroneManager::disarmAll()
{
    for (auto *d : m_drones) {
        if (d) d->disarm();
    }
    qDebug() << "DroneManager: Swarm DISARM ALL sent to" << m_drones.count() << "drones";
}

void DroneManager::returnAllToLaunch()
{
    for (auto *d : m_drones) {
        if (d) d->returnToLaunch();
    }
    qDebug() << "DroneManager: Swarm RTL ALL sent to" << m_drones.count() << "drones";
}

void DroneManager::takeoffAll(double altitudeM)
{
    for (auto *d : m_drones) {
        if (d) d->takeoff(altitudeM);
    }
    qDebug() << "DroneManager: Swarm TAKEOFF ALL sent to" << m_drones.count() << "drones (alt:" << altitudeM << ")";
}

void DroneManager::landAll()
{
    for (auto *d : m_drones) {
        if (d) d->land();
    }
    qDebug() << "DroneManager: Swarm LAND ALL sent to" << m_drones.count() << "drones";
}
