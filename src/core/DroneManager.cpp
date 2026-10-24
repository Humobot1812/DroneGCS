#include "DroneManager.h"
#include "DroneVehicle.h"
#include "../mavlink/AbstractLink.h"
#include "../mavlink/SerialLink.h"
#include "../mavlink/UDPLink.h"
#include "../mavlink/TCPLink.h"
#include "../mavlink/MAVLinkBridge.h"

#include <QSerialPortInfo>
#include <QDebug>
#include <ardupilotmega/mavlink.h>

static bool isAutopilotVehicleType(uint8_t type)
{
    switch (type) {
    case MAV_TYPE_GENERIC:
    case MAV_TYPE_FIXED_WING:
    case MAV_TYPE_QUADROTOR:
    case MAV_TYPE_COAXIAL:
    case MAV_TYPE_HELICOPTER:
    case MAV_TYPE_HEXAROTOR:
    case MAV_TYPE_OCTOROTOR:
    case MAV_TYPE_TRICOPTER:
    case MAV_TYPE_FLAPPING_WING:
    case MAV_TYPE_KITE:
    case MAV_TYPE_GROUND_ROVER:
    case MAV_TYPE_SURFACE_BOAT:
    case MAV_TYPE_SUBMARINE:
    case MAV_TYPE_VTOL_TAILSITTER_DUOROTOR:
    case MAV_TYPE_VTOL_TAILSITTER_QUADROTOR:
    case MAV_TYPE_VTOL_TILTROTOR:
    case MAV_TYPE_VTOL_FIXEDROTOR:
    case MAV_TYPE_VTOL_TAILSITTER:
    case MAV_TYPE_VTOL_TILTWING:
    case MAV_TYPE_VTOL_RESERVED5:
    case MAV_TYPE_DODECAROTOR:
    case MAV_TYPE_AIRSHIP:
    case MAV_TYPE_FREE_BALLOON:
    case MAV_TYPE_ROCKET:
    case MAV_TYPE_PARAFOIL:
        return true;
    default:
        return false;
    }
}

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
    // Deduplicate: avoid re-opening identical serial port
    for (auto *l : m_links) {
        if (auto *s = qobject_cast<SerialLink*>(l)) {
            if (s->portName() == port) {
                qDebug() << "DroneManager: Serial port" << port << "already open";
                return;
            }
        }
    }

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
    // Deduplicate: avoid binding to identical UDP port multiple times
    for (auto *l : m_links) {
        if (auto *u = qobject_cast<UDPLink*>(l)) {
            if (u->port() == port) {
                qDebug() << "DroneManager: UDP port" << port << "already listening";
                return;
            }
        }
    }

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
    // Deduplicate: avoid duplicate TCP connections
    for (auto *l : m_links) {
        if (auto *t = qobject_cast<TCPLink*>(l)) {
            if (t->host() == host && t->port() == port) {
                qDebug() << "DroneManager: TCP" << host << ":" << port << "already active";
                return;
            }
        }
    }

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

void DroneManager::removeDisconnectedDrones()
{
    for (int i = m_drones.count() - 1; i >= 0; --i) {
        DroneVehicle *d = m_drones.at(i);
        if (d && !d->isConnected()) {
            qDebug() << "DroneManager: removing dummy/disconnected drone:" << d->name();
            removeConnection(i);
        }
    }
}

void DroneManager::routePacket(quint8 sysId, const QByteArray &rawPacket)
{
    // Drop invalid broadcast (0) or GCS range (>= 250)
    if (sysId == 0 || sysId >= 250) return;

    // 1. If drone already exists, route packet directly
    DroneVehicle *existingDrone = droneById(sysId);
    if (existingDrone) {
        existingDrone->processPacket(rawPacket);
        return;
    }

    // 2. Drone does NOT exist yet.
    // Strictly verify that this packet is a valid HEARTBEAT from an actual vehicle autopilot
    // before instantiating any DroneVehicle instance.
    mavlink_message_t msg;
    mavlink_status_t status;
    bool foundValidVehicleHeartbeat = false;

    for (int i = 0; i < rawPacket.size(); ++i) {
        uint8_t byte = static_cast<uint8_t>(rawPacket.at(i));
        if (mavlink_parse_char(MAVLINK_COMM_0, byte, &msg, &status)) {
            if (msg.sysid == sysId && msg.msgid == MAVLINK_MSG_ID_HEARTBEAT) {
                mavlink_heartbeat_t hb;
                mavlink_msg_heartbeat_decode(&msg, &hb);

                // Autopilot check: must NOT be invalid (non-autopilot components report MAV_AUTOPILOT_INVALID)
                if (hb.autopilot == MAV_AUTOPILOT_INVALID) {
                    qDebug() << "DroneManager: rejecting heartbeat with MAV_AUTOPILOT_INVALID from sysId" << sysId;
                    return;
                }

                // Vehicle type check: must be a real vehicle (not GCS, companion, gimbal, tracker, etc.)
                if (!isAutopilotVehicleType(hb.type)) {
                    qDebug() << "DroneManager: rejecting heartbeat from non-vehicle MAV_TYPE" << hb.type << "from sysId" << sysId;
                    return;
                }

                foundValidVehicleHeartbeat = true;
                break;
            }
        }
    }

    if (!foundValidVehicleHeartbeat) {
        // Not a verified vehicle heartbeat; ignore packet so no dummy drone is created.
        return;
    }

    // Clean up any previous dummy/disconnected drones before adding the newly verified vehicle
    removeDisconnectedDrones();

    // Now instantiate the actual verified drone
    DroneVehicle *drone = getOrCreateDrone(sysId);
    if (drone) {
        drone->processPacket(rawPacket);
    }
}

DroneVehicle* DroneManager::getOrCreateDrone(quint8 sysId)
{
    if (sysId == 0 || sysId >= 250) {
        qWarning() << "DroneManager::getOrCreateDrone rejected invalid sysId=" << sysId;
        return nullptr;
    }

    for (auto *d : m_drones)
        if (d->sysId() == sysId) return d;

    // New verified drone discovered
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
    QStringList fcPorts;   // ttyACM* and ttyUSB* first — most likely flight controllers
    QStringList otherPorts;

    for (const auto &info : QSerialPortInfo::availablePorts()) {
        const QString name = info.portName();  // e.g. "ttyACM0", "ttyUSB0", "ttyS4"
        if (name.startsWith("ttyACM") || name.startsWith("ttyUSB"))
            fcPorts << name;
        else
            otherPorts << name;
    }

    fcPorts.sort();
    otherPorts.sort();
    return fcPorts + otherPorts;  // FC ports on top
}

void DroneManager::autoConnect()
{
    // ── 1. SERIAL: scan for flight controller USB ports ───────────────────────
    static const QStringList k_fcPrefixes = { "ttyACM", "ttyUSB" };
    static const int k_serialBaud = 57600;

    bool serialFound = false;
    for (const auto &info : QSerialPortInfo::availablePorts()) {
        const QString name = info.portName();
        for (const auto &prefix : k_fcPrefixes) {
            if (name.startsWith(prefix)) {
                qDebug() << "DroneManager::autoConnect Serial:" << name << "@" << k_serialBaud;
                addSerialConnection(name, k_serialBaud);
                emit autoConnectStatus(true, "Serial",
                    QString("%1 @ %2 baud").arg(name).arg(k_serialBaud));
                serialFound = true;
                break;
            }
        }
        if (serialFound) break;
    }
    if (!serialFound)
        emit autoConnectStatus(false, "Serial", "No ttyACM/ttyUSB device found");

    // ── 2. UDP: open listener on all common MAVLink ports ────────────────────
    // Standard MAVLink UDP ports used by Mission Planner, QGC, ArduPilot, PX4
    static const QList<int> k_udpPorts = { 14550, 14551, 14552, 18570 };

    for (int port : k_udpPorts) {
        qDebug() << "DroneManager::autoConnect UDP: listening on" << port;
        addUDPConnection("", port);
        emit autoConnectStatus(true,
            QString("UDP:%1").arg(port),
            QString("Listening on :%1").arg(port));
    }

    // ── 3. TCP: attempt connection to all common SITL / autopilot ports ───────
    // ArduPilot SITL: 5760/5761/5762, some GCS setups use 14550
    static const QList<int> k_tcpPorts = { 5760, 5761, 5762, 14550 };

    for (int port : k_tcpPorts) {
        qDebug() << "DroneManager::autoConnect TCP: 127.0.0.1:" << port;
        addTCPConnection("127.0.0.1", port);
        emit autoConnectStatus(true,
            QString("TCP:%1").arg(port),
            QString("127.0.0.1:%1").arg(port));
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
