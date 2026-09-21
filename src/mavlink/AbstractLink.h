#pragma once
#include <QObject>
#include <QByteArray>

/**
 * AbstractLink — base class for Serial, UDP, TCP transport links.
 * MAVLinkBridge operates on any AbstractLink.
 */
class AbstractLink : public QObject
{
    Q_OBJECT
public:
    explicit AbstractLink(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~AbstractLink() = default;

    virtual void connect() = 0;
    virtual void disconnect() = 0;
    virtual bool isConnected() const = 0;
    virtual QString description() const = 0;

public slots:
    virtual void write(const QByteArray &bytes) = 0;

signals:
    void bytesReceived(const QByteArray &bytes);
    void connected();
    void disconnected();
    void errorOccurred(const QString &error);
};
