#pragma once
#include <QObject>

class AbstractLink;

/**
 * MAVLinkBridge — sits on top of an AbstractLink and parses raw bytes
 * into MAVLink v2 packets, routing them by sysId.
 */
class MAVLinkBridge : public QObject
{
    Q_OBJECT
public:
    explicit MAVLinkBridge(AbstractLink *link, QObject *parent = nullptr);

signals:
    void packetReceived(quint8 sysId, const QByteArray &rawPacket);

private slots:
    void onBytesReceived(const QByteArray &bytes);

private:
    AbstractLink *m_link = nullptr;
    QByteArray    m_buffer;
};
