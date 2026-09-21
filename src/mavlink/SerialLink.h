#pragma once
#include "AbstractLink.h"
#include <QSerialPort>
#include <QTimer>

class SerialLink : public AbstractLink
{
    Q_OBJECT
public:
    SerialLink(const QString &portName, int baudRate, QObject *parent = nullptr);
    ~SerialLink() override;

    void connect()    override;
    void disconnect() override;
    bool isConnected() const override { return m_port && m_port->isOpen(); }
    QString description() const override {
        return QString("Serial %1 @ %2").arg(m_portName).arg(m_baudRate);
    }

public slots:
    void write(const QByteArray &bytes) override;

private slots:
    void onReadyRead();
    void onErrorOccurred(QSerialPort::SerialPortError error);
    void tryReconnect();

private:
    QString      m_portName;
    int          m_baudRate;
    QSerialPort *m_port = nullptr;
    QTimer      *m_reconnectTimer = nullptr;
};
