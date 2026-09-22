#include "AudioAnnunciator.h"
#include <QStandardPaths>
#include <QFileInfo>
#include <QSettings>
#include <QDebug>

AudioAnnunciator::AudioAnnunciator(QObject *parent)
    : QObject(parent)
{
    // Load enabled setting and voice profile
    QSettings settings("DRONE_GCS", "GCS");
    m_enabled = settings.value("voice/enabled", true).toBool();
    m_maleVoiceProfile = settings.value("voice/maleProfile", "male1").toString();

    m_enginePath = findSpeechEngine();

    m_process = new QProcess(this);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &AudioAnnunciator::onProcessFinished);
}

AudioAnnunciator::~AudioAnnunciator()
{
    if (m_process && m_process->state() != QProcess::NotRunning) {
        m_process->kill();
        m_process->waitForFinished(500);
    }
}

QString AudioAnnunciator::findSpeechEngine() const
{
    // Check spd-say first (high-quality dispatcher)
    QString spd = QStandardPaths::findExecutable("spd-say");
    if (!spd.isEmpty()) return spd;

    // Check espeak-ng
    QString espeakNg = QStandardPaths::findExecutable("espeak-ng");
    if (!espeakNg.isEmpty()) return espeakNg;

    // Check espeak
    QString espeak = QStandardPaths::findExecutable("espeak");
    if (!espeak.isEmpty()) return espeak;

    return QString();
}

void AudioAnnunciator::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        QSettings settings("DRONE_GCS", "GCS");
        settings.setValue("voice/enabled", m_enabled);
        emit enabledChanged();
        if (!m_enabled && m_process && m_process->state() != QProcess::NotRunning) {
            m_process->kill();
            m_queue.clear();
        }
    }
}

void AudioAnnunciator::setMaleVoiceProfile(const QString &profile)
{
    if (m_maleVoiceProfile != profile) {
        m_maleVoiceProfile = profile;
        QSettings settings("DRONE_GCS", "GCS");
        settings.setValue("voice/maleProfile", m_maleVoiceProfile);
        emit maleVoiceProfileChanged();
    }
}

QStringList AudioAnnunciator::availableVoiceProfiles() const
{
    return QStringList{ "male1", "male2", "male3", "military" };
}

void AudioAnnunciator::say(const QString &text, bool highPriority)
{
    if (!m_enabled || text.trimmed().isEmpty()) return;

    if (highPriority) {
        m_queue.clear(); // Preempt and clear any non-critical speech backlog immediately
        m_queue.prepend(text);
        if (m_process->state() != QProcess::NotRunning) {
            m_process->kill();
        }
    } else {
        // Discard excessive backlog to prevent lagged audio
        if (m_queue.size() > 5) {
            m_queue.removeFirst();
        }
        m_queue.enqueue(text);
    }

    if (m_process->state() == QProcess::NotRunning) {
        processQueue();
    }
}

void AudioAnnunciator::processQueue()
{
    if (m_queue.isEmpty() || !m_enabled) return;

    QString nextText = m_queue.dequeue();
    dispatchSpeech(nextText);
}

void AudioAnnunciator::dispatchSpeech(const QString &text)
{
    if (m_enginePath.isEmpty()) {
        m_enginePath = findSpeechEngine();
    }

    m_lastSpoken = text;
    emit lastSpokenChanged();
    qDebug() << "[AudioAnnunciator]" << text;

    if (m_enginePath.isEmpty()) {
        processQueue();
        return;
    }

    QStringList args;
    if (m_enginePath.contains("spd-say")) {
        args << "-t";
        if (m_maleVoiceProfile == "male2") {
            args << "male2" << "-p" << "-25" << "-r" << "-5";
        } else if (m_maleVoiceProfile == "male3") {
            args << "male3" << "-p" << "-15" << "-r" << "5";
        } else if (m_maleVoiceProfile == "military") {
            args << "male1" << "-p" << "-40" << "-r" << "-10";
        } else { // "male1" default
            args << "male1" << "-p" << "-10" << "-r" << "0";
        }
        args << text;
    } else {
        if (m_maleVoiceProfile == "male2") {
            args << "-v" << "en-us+m3" << "-p" << "30" << "-s" << "145";
        } else if (m_maleVoiceProfile == "male3") {
            args << "-v" << "en-gb+m3" << "-p" << "42" << "-s" << "165";
        } else if (m_maleVoiceProfile == "military") {
            args << "-v" << "en-us+klatt" << "-p" << "35" << "-s" << "150";
        } else { // male1
            args << "-v" << "en-us+m1" << "-p" << "40" << "-s" << "155";
        }
        args << "-a" << "100" << text;
    }

    m_process->start(m_enginePath, args);
}

void AudioAnnunciator::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    Q_UNUSED(exitCode);
    Q_UNUSED(exitStatus);
    processQueue();
}

void AudioAnnunciator::testVoice()
{
    say("Audio voice annunciator online. All telemetry systems active.", true);
}

void AudioAnnunciator::testVoiceProfile(const QString &profile)
{
    QString old = m_maleVoiceProfile;
    m_maleVoiceProfile = profile;
    QString sampleText;
    if (profile == "male1") {
        sampleText = "Tactical Commander online. Telemetry link verified.";
    } else if (profile == "male2") {
        sampleText = "Deep Cockpit Annunciator online. Warning systems armed.";
    } else if (profile == "male3") {
        sampleText = "Aviation Radio Pilot online. Ready for departure.";
    } else if (profile == "military") {
        sampleText = "Tactical Defense System online. All units standby.";
    } else {
        sampleText = "Audio voice annunciator online.";
    }
    say(sampleText, true);
    m_maleVoiceProfile = old;
}

void AudioAnnunciator::onDroneConnected(bool connected, const QString &droneName)
{
    QString name = droneName.isEmpty() ? "Drone" : droneName;
    if (connected) {
        say(QString("%1 connected").arg(name), true);
    } else {
        say(QString("%1 disconnected").arg(name), true);
    }
}

void AudioAnnunciator::onArmedChanged(bool armed, const QString &droneName)
{
    Q_UNUSED(droneName);
    if (armed) {
        say("Drone armed. Stand clear.", true);
    } else {
        say("Drone disarmed.", true);
    }
}

void AudioAnnunciator::onFlightModeChanged(const QString &mode, const QString &droneName)
{
    Q_UNUSED(droneName);
    QString clean = mode.trimmed().toUpper();
    if (clean.isEmpty() || clean == m_lastAnnouncedMode) return;

    qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - m_lastModeAlertTime < 1000) return;
    m_lastModeAlertTime = now;
    m_lastAnnouncedMode = clean;

    if (clean == "GUIDED") {
        say("Guided mode active");
    } else if (clean == "AUTO") {
        say("Auto mode active");
    } else if (clean == "RTL") {
        say("Return to launch mode active");
    } else if (clean == "LOITER") {
        say("Loiter mode active");
    } else if (clean == "LAND") {
        say("Landing mode active");
    } else if (clean == "STABILIZE") {
        say("Stabilize mode active");
    } else if (clean == "POSHOLD") {
        say("Position hold active");
    } else if (clean == "ALT_HOLD") {
        say("Altitude hold active");
    } else {
        say(QString("%1 mode active").arg(clean.toLower()));
    }
}

void AudioAnnunciator::onTakeoff()
{
    say("Takeoff initiated", true);
}

void AudioAnnunciator::onLanding()
{
    say("Landing initiated", true);
}

void AudioAnnunciator::onBatteryWarning(int percent)
{
    if (percent <= 25 && percent > 0) {
        int bracket = (percent <= 10) ? 10 : (percent <= 15 ? 15 : (percent <= 20 ? 20 : 25));
        qint64 now = QDateTime::currentMSecsSinceEpoch();
        qint64 lastTime = m_lastBatteryAlertTimes.value(bracket, 0);
        if (now - lastTime > 30000) {
            m_lastBatteryAlertTimes[bracket] = now;
            say(QString("Warning! Low battery: %1 percent remaining").arg(percent), true);
        }
    }
}

void AudioAnnunciator::onGeofenceBreach()
{
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - m_lastBreachAlertTime > 8000) {
        m_lastBreachAlertTime = now;
        say("Warning! Geofence breach detected!", true);
    }
}

void AudioAnnunciator::onGpsLost(const QString &droneName)
{
    Q_UNUSED(droneName);
    say("Warning! GPS fix lost. Entering manual stabilization fallback.", true);
}

void AudioAnnunciator::onMissionUploaded(int count)
{
    Q_UNUSED(count)
    say("Mission uploaded. Ready for auto mode.", true);
}

void AudioAnnunciator::onMissionCleared()
{
    say("Mission cleared. No active mission on board.", true);
}
