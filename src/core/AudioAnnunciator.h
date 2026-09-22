#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QQueue>
#include <QProcess>
#include <QDateTime>
#include <QMap>

/**
 * AudioAnnunciator — Spoken voice annunciator subsystem for DRONE_GCS.
 * Uses a non-blocking queue over system speech synthesis tools (spd-say, espeak).
 */
class AudioAnnunciator : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString maleVoiceProfile READ maleVoiceProfile WRITE setMaleVoiceProfile NOTIFY maleVoiceProfileChanged)
    Q_PROPERTY(QString lastSpoken READ lastSpoken NOTIFY lastSpokenChanged)

public:
    explicit AudioAnnunciator(QObject *parent = nullptr);
    ~AudioAnnunciator() override;

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled);

    QString maleVoiceProfile() const { return m_maleVoiceProfile; }
    void setMaleVoiceProfile(const QString &profile);

    QString lastSpoken() const { return m_lastSpoken; }

    // QML-invokable speech commands
    Q_INVOKABLE void say(const QString &text, bool highPriority = false);
    Q_INVOKABLE void testVoice();
    Q_INVOKABLE void testVoiceProfile(const QString &profile);
    Q_INVOKABLE QStringList availableVoiceProfiles() const;

    // Standardized GCS flight announcements
    void onDroneConnected(bool connected, const QString &droneName = QString());
    void onArmedChanged(bool armed, const QString &droneName = QString());
    void onFlightModeChanged(const QString &mode, const QString &droneName = QString());
    void onTakeoff();
    void onLanding();
    void onBatteryWarning(int percent);
    void onGeofenceBreach();
    void onGpsLost(const QString &droneName = QString());
    void onMissionUploaded(int count);
    void onMissionCleared();

signals:
    void enabledChanged();
    void maleVoiceProfileChanged();
    void lastSpokenChanged();

private slots:
    void processQueue();
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);

private:
    void dispatchSpeech(const QString &text);
    QString findSpeechEngine() const;

    bool m_enabled = true;
    QString m_maleVoiceProfile = "male1";
    QString m_lastSpoken;
    QQueue<QString> m_queue;
    QProcess *m_process = nullptr;
    QString m_enginePath;
    QString m_engineType;

    qint64 m_lastBreachAlertTime = 0;
    QMap<int, qint64> m_lastBatteryAlertTimes;
    qint64 m_lastModeAlertTime = 0;
    QString m_lastAnnouncedMode;
};
