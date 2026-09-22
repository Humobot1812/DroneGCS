#pragma once
#include <QObject>
#include <QList>
#include <QAbstractListModel>
#include "DroneVehicle.h"

class MAVLinkBridge;
class AbstractLink;

/**
 * DroneManager — owns and manages a collection of DroneVehicle instances.
 * Exposed to QML as the root context property "droneManager".
 */
class DroneManager : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int droneCount READ droneCount NOTIFY droneCountChanged)
    Q_PROPERTY(int activeDroneIndex READ activeDroneIndex WRITE setActiveDroneIndex NOTIFY activeDroneIndexChanged)
    Q_PROPERTY(DroneVehicle* activeDrone READ activeDrone NOTIFY activeDroneChanged)
    Q_PROPERTY(bool isSimulating READ isSimulating CONSTANT)

public:
    enum DroneRoles {
        DroneIdRole = Qt::UserRole + 1,
        DroneNameRole,
        DroneObjectRole,
        ConnectedRole,
        ArmedRole,
        FlightModeRole,
        ColorRole
    };

    explicit DroneManager(QObject *parent = nullptr);
    ~DroneManager() override;

    // QAbstractListModel interface
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int droneCount() const { return m_drones.count(); }
    int activeDroneIndex() const { return m_activeDroneIndex; }
    DroneVehicle* activeDrone() const;
    DroneVehicle* droneById(int sysId) const;
    bool isSimulating() const { return false; }

    // Connection colors per drone slot
    static const QStringList k_droneColors;

public slots:
    // Called from QML connection dialog
    Q_INVOKABLE void addSerialConnection(const QString &port, int baudRate);
    Q_INVOKABLE void addUDPConnection(const QString &host, int port);
    Q_INVOKABLE void addTCPConnection(const QString &host, int port);
    Q_INVOKABLE void removeConnection(int index);
    Q_INVOKABLE void setActiveDroneIndex(int index);
    Q_INVOKABLE QStringList availableSerialPorts() const;
    Q_INVOKABLE void autoConnect();   // Scan & connect to first known FC port
    Q_INVOKABLE DroneVehicle* droneAt(int index) const;
    DroneVehicle* getOrCreateDrone(quint8 sysId);

    // Swarm Master Commands
    Q_INVOKABLE void armAll();
    Q_INVOKABLE void disarmAll();
    Q_INVOKABLE void returnAllToLaunch();
    Q_INVOKABLE void takeoffAll(double altitudeM = 15.0);
    Q_INVOKABLE void landAll();

    // Route a raw MAVLink packet to the correct DroneVehicle by sysId
    void routePacket(quint8 sysId, const QByteArray &rawPacket);

signals:
    void droneCountChanged();
    void activeDroneIndexChanged();
    void activeDroneChanged();
    void droneAdded(DroneVehicle *drone);
    void droneRemoved(int index);
    void autoConnectStatus(bool success, const QString &transport, const QString &message);  // per-transport result

private:
    QList<DroneVehicle*>  m_drones;
    QList<AbstractLink*>  m_links;    // all registered transport links
    int m_activeDroneIndex = -1;
};
