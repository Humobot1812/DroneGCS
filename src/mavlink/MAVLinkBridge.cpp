#include "MAVLinkBridge.h"
#include "AbstractLink.h"
#include <ardupilotmega/mavlink.h>
#include <QDebug>

MAVLinkBridge::MAVLinkBridge(AbstractLink *link, QObject *parent)
    : QObject(parent), m_link(link)
{
    QObject::connect(m_link, &AbstractLink::bytesReceived,
                     this, &MAVLinkBridge::onBytesReceived);
}

void MAVLinkBridge::onBytesReceived(const QByteArray &bytes)
{
    // Accumulate bytes; parse individual MAVLink packets
    m_buffer.append(bytes);

    mavlink_message_t msg;
    mavlink_status_t  status;

    int i = 0;
    while (i < m_buffer.size()) {
        uint8_t byte = static_cast<uint8_t>(m_buffer.at(i));
        if (mavlink_parse_char(MAVLINK_COMM_1, byte, &msg, &status)) {
            // Emit the whole raw packet so DroneVehicle can re-parse it
            // (size of message = header + payload + crc + possibly sig)
            uint8_t buf[MAVLINK_MAX_PACKET_LEN];
            int len = mavlink_msg_to_send_buffer(buf, &msg);
            QByteArray pkt(reinterpret_cast<char*>(buf), len);
            emit packetReceived(msg.sysid, pkt);
        }
        ++i;
    }

    // Keep only unprocessed tail (mavlink_parse_char is stateful via MAVLINK_COMM_1)
    m_buffer.clear();
}
