#pragma once
#include <QObject>
#include <QVariantList>
#include <deque>

/**
 * TelemetryStore — rolling history buffers for telemetry graphing.
 * Exposed to QML for sparkline charts.
 */
class TelemetryStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList altitudeHistory READ altitudeHistory NOTIFY historyChanged)
    Q_PROPERTY(QVariantList speedHistory    READ speedHistory    NOTIFY historyChanged)
    Q_PROPERTY(QVariantList batteryHistory  READ batteryHistory  NOTIFY historyChanged)
    Q_PROPERTY(int maxPoints READ maxPoints CONSTANT)

public:
    static constexpr int MAX_POINTS = 300;   // ~5min @ 1Hz

    explicit TelemetryStore(QObject *parent = nullptr);

    void appendAltitude(double v) { append(m_alt, v); }
    void appendSpeed(double v)    { append(m_spd, v); }
    void appendBattery(int v)     { append(m_bat, v); }

    QVariantList altitudeHistory() const { return toVariantList(m_alt); }
    QVariantList speedHistory()    const { return toVariantList(m_spd); }
    QVariantList batteryHistory()  const { return toVariantList(m_bat); }
    int          maxPoints()       const { return MAX_POINTS; }

    Q_INVOKABLE void clear();

signals:
    void historyChanged();

private:
    void append(std::deque<double> &buf, double v) {
        buf.push_back(v);
        if (static_cast<int>(buf.size()) > MAX_POINTS) buf.pop_front();
        emit historyChanged();
    }

    QVariantList toVariantList(const std::deque<double> &buf) const {
        QVariantList l;
        l.reserve(static_cast<int>(buf.size()));
        for (double v : buf) l.append(v);
        return l;
    }

    std::deque<double> m_alt, m_spd, m_bat;
};
