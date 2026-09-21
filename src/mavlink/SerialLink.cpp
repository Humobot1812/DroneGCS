#include "SerialLink.h"
#include <QDebug>

SerialLink::SerialLink(const QString &portName, int baudRate, QObject *parent)
    : AbstractLink(parent)
    , m_portName(portName)
    , m_baudRate(baudRate)
{
    m_reconnectTimer = new QTimer(this);
    m_reconnectTimer->setInterval(3000);
    m_reconnectTimer->setSingleShot(false);
    QObject::connect(m_reconnectTimer, &QTimer::timeout, this, &SerialLink::tryReconnect);
}

SerialLink::~SerialLink()
{
    disconnect();
}

void SerialLink::connect()
{
    if (m_port) { m_port->close(); m_port->deleteLater(); }

    m_port = new QSerialPort(m_portName, this);
    m_port->setBaudRate(m_baudRate);
    m_port->setDataBits(QSerialPort::Data8);
    m_port->setParity(QSerialPort::NoParity);
    m_port->setStopBits(QSerialPort::OneStop);
    m_port->setFlowControl(QSerialPort::NoFlowControl);

    QObject::connect(m_port, &QSerialPort::readyRead,
                     this, &SerialLink::onReadyRead);
    QObject::connect(m_port, &QSerialPort::errorOccurred,
                     this, &SerialLink::onErrorOccurred);

    if (m_port->open(QIODevice::ReadWrite)) {
        qDebug() << "SerialLink: opened" << m_portName;
        m_reconnectTimer->stop();
        emit connected();
    } else {
        qWarning() << "SerialLink: failed to open" << m_portName << m_port->errorString();
        m_reconnectTimer->start();
    }
}

void SerialLink::disconnect()
{
    m_reconnectTimer->stop();
    if (m_port && m_port->isOpen()) {
        m_port->close();
        emit disconnected();
    }
}

void SerialLink::write(const QByteArray &bytes)
{
    if (m_port && m_port->isOpen())
        m_port->write(bytes);
}

void SerialLink::onReadyRead()
{
    if (m_port)
        emit bytesReceived(m_port->readAll());
}

void SerialLink::onErrorOccurred(QSerialPort::SerialPortError error)
{
    if (error == QSerialPort::NoError) return;
    qWarning() << "SerialLink error:" << m_port->errorString();
    emit errorOccurred(m_port->errorString());
    m_reconnectTimer->start();
}

void SerialLink::tryReconnect()
{
    qDebug() << "SerialLink: reconnecting" << m_portName;
    connect();
}
