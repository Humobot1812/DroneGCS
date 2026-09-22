#pragma once
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QDateTime>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>

class DroneManager;
class DroneVehicle;
class AudioAnnunciator;
class AppSettings;

/**
 * AiAssistant — Tactical AI Autonomous Flight Copilot for DRONE_GCS.
 * Powered by Google Gemini AI API with complete live UAV context awareness
 * and autonomous control permissions across the entire GCS.
 * 
 * Features seamless zero-latency local fallback if offline or unconfigured.
 * Voice recording input removed as per operator specification (text input + spoken audio output).
 */
class AiAssistant : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isProcessing READ isProcessing NOTIFY isProcessingChanged)
    Q_PROPERTY(bool isGeminiActive READ isGeminiActive NOTIFY geminiStatusChanged)
    Q_PROPERTY(bool hasGeminiKey READ hasGeminiKey NOTIFY geminiStatusChanged)
    Q_PROPERTY(QString lastSpokenResponse READ lastSpokenResponse NOTIFY lastSpokenResponseChanged)
    Q_PROPERTY(QVariantList conversationHistory READ conversationHistory NOTIFY conversationHistoryChanged)
    Q_PROPERTY(int messageCount READ messageCount NOTIFY conversationHistoryChanged)
    Q_PROPERTY(bool isListening READ isListening CONSTANT)

    // Reasoning & Thinking pulse properties
    Q_PROPERTY(QString thinkingPhase READ thinkingPhase NOTIFY thinkingPhaseChanged)
    Q_PROPERTY(int thinkingElapsedMs READ thinkingElapsedMs NOTIFY thinkingElapsedMsChanged)

    // Safety Interlock Countdown properties
    Q_PROPERTY(bool hasPendingHazardAction READ hasPendingHazardAction NOTIFY pendingHazardActionChanged)
    Q_PROPERTY(QString pendingHazardAction READ pendingHazardAction NOTIFY pendingHazardActionChanged)
    Q_PROPERTY(QString pendingHazardParam READ pendingHazardParam NOTIFY pendingHazardActionChanged)
    Q_PROPERTY(int pendingHazardRemainingMs READ pendingHazardRemainingMs NOTIFY pendingHazardActionChanged)
    Q_PROPERTY(double pendingHazardProgress READ pendingHazardProgress NOTIFY pendingHazardActionChanged)

public:
    explicit AiAssistant(DroneManager *droneManager, AudioAnnunciator *audioAnnunciator, AppSettings *appSettings = nullptr, QObject *parent = nullptr);

    bool isProcessing() const { return m_isProcessing; }
    bool isGeminiActive() const;
    bool hasGeminiKey() const;
    bool isListening() const { return false; } // Voice input disabled per operator instruction
    QString lastSpokenResponse() const { return m_lastSpokenResponse; }
    QVariantList conversationHistory() const { return m_conversationHistory; }
    int messageCount() const { return m_conversationHistory.size(); }

    QString thinkingPhase() const { return m_thinkingPhase; }
    int thinkingElapsedMs() const { return m_thinkingElapsedMs; }

    bool hasPendingHazardAction() const { return m_hasPendingHazardAction; }
    QString pendingHazardAction() const { return m_pendingHazardAction; }
    QString pendingHazardParam() const { return m_pendingHazardParam; }
    int pendingHazardRemainingMs() const { return m_pendingHazardRemainingMs; }
    double pendingHazardProgress() const { return m_pendingHazardRemainingMs / 3000.0; }

    // QML-invokable methods
    Q_INVOKABLE void processCommand(const QString &input);
    Q_INVOKABLE void clearHistory();
    Q_INVOKABLE void executeQuickAction(const QString &action);
    Q_INVOKABLE void setGeminiApiKey(const QString &key);
    Q_INVOKABLE QString getGeminiApiKey() const;

    // Safety Abort Interlocks
    Q_INVOKABLE void abortHazardAction();
    Q_INVOKABLE void confirmHazardActionNow();

signals:
    void isProcessingChanged();
    void geminiStatusChanged();
    void lastSpokenResponseChanged();
    void conversationHistoryChanged();
    void commandExecuted(const QString &action, bool success, const QString &details);
    void thinkingPhaseChanged();
    void thinkingElapsedMsChanged();
    void pendingHazardActionChanged();

    // GCS Application control signals invoked by AI
    void requestPageNavigation(int pageIndex);
    void requestTogglePip();
    void requestOpenFlightLogs();
    void requestOpenSettings();
    void requestRunPreflight();

private slots:
    void onGeminiReplyFinished(QNetworkReply *reply, const QString &originalInput);
    void onHazardTimerTick();
    void onThinkingTimerTick();

private:
    DroneVehicle* activeDrone() const;
    void addMessage(const QString &role, const QString &text, const QString &actionTag = QString(), bool success = true);
    void respondAndSpeak(const QString &replyText, const QString &actionTag = QString(), bool success = true);

    // AI Engine Implementations
    void sendGeminiRequest(const QString &input);
    void sendGeminiViaCurl(const QString &input, const QString &apiKey, const QString &model, const QByteArray &postData);
    void processGeminiJsonResponse(const QByteArray &responseData, const QString &originalInput);
    void executeLocalAutonomousCommand(const QString &input);
    void executeAction(const QString &action, const QString &param);
    void scheduleHazardousAction(const QString &action, const QString &param);
    void executePhysicalAction(const QString &action, const QString &param);
    QString buildFullUavTelemetryContext() const;

    DroneManager *m_droneManager = nullptr;
    AudioAnnunciator *m_audioAnnunciator = nullptr;
    AppSettings *m_appSettings = nullptr;
    QNetworkAccessManager *m_netManager = nullptr;

    bool m_isProcessing = false;
    QString m_lastSpokenResponse;
    QVariantList m_conversationHistory;

    // Thinking & Reasoning state
    QTimer *m_thinkingTimer = nullptr;
    QString m_thinkingPhase;
    int m_thinkingElapsedMs = 0;

    // Hazardous safety countdown state
    QTimer *m_hazardCountdownTimer = nullptr;
    bool m_hasPendingHazardAction = false;
    QString m_pendingHazardAction;
    QString m_pendingHazardParam;
    int m_pendingHazardRemainingMs = 3000;
};
