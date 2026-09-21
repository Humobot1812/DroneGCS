#include "TCPLink.h"
#include <QDebug>

TCPLink::TCPLink(const QString &host, int port, QObject *parent)
    : AbstractLink(parent), m_host(host), m_port(port)
{
    m_reconnectTimer = new QTimer(this);
    m_reconnectTimer->setInterval(3000);
    m_reconnectTimer->setSingleShot(false);
    QObject::connect(m_reconnectTimer, &QTimer::timeout, this, &TCPLink::tryReconnect);
}

TCPLink::~TCPLink() { disconnect(); }

void TCPLink::connect()
{
    if (m_socket) { m_socket->abort(); m_socket->deleteLater(); }

    m_socket = new QTcpSocket(this);
    QObject::connect(m_socket, &QTcpSocket::connected,    this, &TCPLink::onConnected);
    QObject::connect(m_socket, &QTcpSocket::disconnected, this, &TCPLink::onDisconnected);
    QObject::connect(m_socket, &QTcpSocket::readyRead,    this, &TCPLink::onReadyRead);
    QObject::connect(m_socket, &QAbstractSocket::errorOccurred, this, &TCPLink::onError);

    m_socket->connectToHost(m_host, static_cast<quint16>(m_port));
    qDebug() << "TCPLink: connecting to" << m_host << ":" << m_port;
}

void TCPLink::disconnect()
{
    m_reconnectTimer->stop();
    if (m_socket) { m_socket->disconnectFromHost(); }
}

void TCPLink::write(const QByteArray &bytes)
{
    if (m_socket && m_socket->state() == QAbstractSocket::ConnectedState)
        m_socket->write(bytes);
}

void TCPLink::onConnected()
{
    m_reconnectTimer->stop();
    qDebug() << "TCPLink: connected to" << m_host << ":" << m_port;
    emit connected();
}

void TCPLink::onDisconnected()
{
    qDebug() << "TCPLink: disconnected, retrying...";
    m_reconnectTimer->start();
    emit disconnected();
}

void TCPLink::onReadyRead()
{
    if (m_socket)
        emit bytesReceived(m_socket->readAll());
}

void TCPLink::onError(QAbstractSocket::SocketError)
{
    qWarning() << "TCPLink error:" << m_socket->errorString();
    emit errorOccurred(m_socket->errorString());
    m_reconnectTimer->start();
}

void TCPLink::tryReconnect()
{
    qDebug() << "TCPLink: reconnecting...";
    connect();
}
