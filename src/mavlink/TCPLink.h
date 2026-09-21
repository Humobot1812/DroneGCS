#pragma once
#include "AbstractLink.h"
#include <QTcpSocket>
#include <QTimer>

class TCPLink : public AbstractLink
{
    Q_OBJECT
public:
    TCPLink(const QString &host, int port, QObject *parent = nullptr);
    ~TCPLink() override;

    void connect()    override;
    void disconnect() override;
    bool isConnected() const override { return m_socket && m_socket->state() == QAbstractSocket::ConnectedState; }
    QString description() const override {
        return QString("TCP %1:%2").arg(m_host).arg(m_port);
    }

public slots:
    void write(const QByteArray &bytes) override;

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onError(QAbstractSocket::SocketError error);
    void tryReconnect();

private:
    QString     m_host;
    int         m_port;
    QTcpSocket *m_socket = nullptr;
    QTimer     *m_reconnectTimer = nullptr;
};
