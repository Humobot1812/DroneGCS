#include "MAVLinkBridge.h"
#include "AbstractLink.h"
#include <ardupilotmega/mavlink.h>
#include <QDebug>

#include <atomic>

static std::atomic<uint8_t> s_channelCounter{1};

MAVLinkBridge::MAVLinkBridge(AbstractLink *link, QObject *parent)
    : QObject(parent), m_link(link)
{
    // Channels 1..3 for link parser bridges (channel 0 reserved for DroneVehicle)
    m_channel = 1 + (s_channelCounter.fetch_add(1) % 3);

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
        if (mavlink_parse_char(m_channel, byte, &msg, &status)) {
            // Drop broadcast (0) or GCS (>=250) packets right away to prevent dummy drones
            if (msg.sysid > 0 && msg.sysid < 250) {
                uint8_t buf[MAVLINK_MAX_PACKET_LEN];
                int len = mavlink_msg_to_send_buffer(buf, &msg);
                QByteArray pkt(reinterpret_cast<char*>(buf), len);
                emit packetReceived(msg.sysid, pkt);
            }
        }
        ++i;
    }

    // Keep only unprocessed tail (mavlink_parse_char is stateful via m_channel)
    m_buffer.clear();
}
