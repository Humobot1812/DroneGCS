#pragma once
#include "AbstractLink.h"
#include <QUdpSocket>
#include <QHostAddress>

class UDPLink : public AbstractLink
{
    Q_OBJECT
public:
    UDPLink(const QString &host, int port, QObject *parent = nullptr);
    ~UDPLink() override;

    void connect()    override;
    void disconnect() override;
    bool isConnected() const override { return m_socket && m_socket->state() != QAbstractSocket::UnconnectedState; }
    QString description() const override {
        return QString("UDP %1:%2").arg(m_host).arg(m_port);
    }

public slots:
    void write(const QByteArray &bytes) override;

private slots:
    void onReadyRead();

private:
    QString     m_host;
    int         m_port;
    QUdpSocket *m_socket = nullptr;
    QHostAddress m_targetAddr;
    quint16      m_targetPort = 0;
    bool         m_targetKnown = false;
};
