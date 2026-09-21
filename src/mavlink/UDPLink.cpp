#include "UDPLink.h"
#include <QDebug>

UDPLink::UDPLink(const QString &host, int port, QObject *parent)
    : AbstractLink(parent), m_host(host), m_port(port)
{
}

UDPLink::~UDPLink() { disconnect(); }

void UDPLink::connect()
{
    if (m_socket) { m_socket->close(); m_socket->deleteLater(); }

    m_socket = new QUdpSocket(this);
    QObject::connect(m_socket, &QUdpSocket::readyRead, this, &UDPLink::onReadyRead);

    // Bind to listen port (14550 typical)
    if (m_socket->bind(QHostAddress::AnyIPv4, static_cast<quint16>(m_port),
                        QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint)) {
        qDebug() << "UDPLink: bound to port" << m_port;
        emit connected();
    } else {
        qWarning() << "UDPLink: bind failed:" << m_socket->errorString();
        emit errorOccurred(m_socket->errorString());
    }
}

void UDPLink::disconnect()
{
    if (m_socket) {
        m_socket->close();
        emit disconnected();
    }
}

void UDPLink::write(const QByteArray &bytes)
{
    if (!m_socket || !m_targetKnown) return;
    m_socket->writeDatagram(bytes, m_targetAddr, m_targetPort);
}

void UDPLink::onReadyRead()
{
    while (m_socket && m_socket->hasPendingDatagrams()) {
        QByteArray data;
        data.resize(static_cast<int>(m_socket->pendingDatagramSize()));
        QHostAddress sender;
        quint16 senderPort;
        m_socket->readDatagram(data.data(), data.size(), &sender, &senderPort);

        // Remember the sender to send replies back
        if (!m_targetKnown) {
            m_targetAddr  = sender;
            m_targetPort  = senderPort;
            m_targetKnown = true;
            qDebug() << "UDPLink: target set to" << sender.toString() << ":" << senderPort;
        }
        emit bytesReceived(data);
    }
}
