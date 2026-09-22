#pragma once
#include <QObject>
#include <QSettings>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString mapTileUrl  READ mapTileUrl  WRITE setMapTileUrl  NOTIFY mapTileUrlChanged)
    Q_PROPERTY(int     udpPort     READ udpPort     WRITE setUdpPort     NOTIFY udpPortChanged)
    Q_PROPERTY(double  defaultAlt  READ defaultAlt  WRITE setDefaultAlt  NOTIFY defaultAltChanged)
    Q_PROPERTY(double  rtlAlt      READ rtlAlt      WRITE setRtlAlt      NOTIFY rtlAltChanged)
    Q_PROPERTY(double  sweepSpacing READ sweepSpacing WRITE setSweepSpacing NOTIFY sweepSpacingChanged)
    Q_PROPERTY(QString pythonPath  READ pythonPath  WRITE setPythonPath  NOTIFY pythonPathChanged)
    Q_PROPERTY(bool    autoDetectAutopilot READ autoDetectAutopilot WRITE setAutoDetectAutopilot NOTIFY autoDetectAutopilotChanged)
    Q_PROPERTY(bool    voiceEnabled READ voiceEnabled WRITE setVoiceEnabled NOTIFY voiceEnabledChanged)
    Q_PROPERTY(QString maleVoiceProfile READ maleVoiceProfile WRITE setMaleVoiceProfile NOTIFY maleVoiceProfileChanged)
    Q_PROPERTY(double  geofenceDefaultRadius READ geofenceDefaultRadius WRITE setGeofenceDefaultRadius NOTIFY geofenceDefaultRadiusChanged)
    Q_PROPERTY(double  geofenceDefaultMaxAlt READ geofenceDefaultMaxAlt WRITE setGeofenceDefaultMaxAlt NOTIFY geofenceDefaultMaxAltChanged)
    Q_PROPERTY(int     geofenceDefaultAction READ geofenceDefaultAction WRITE setGeofenceDefaultAction NOTIFY geofenceDefaultActionChanged)

    Q_PROPERTY(QString geminiApiKey READ geminiApiKey WRITE setGeminiApiKey NOTIFY geminiApiKeyChanged)
    Q_PROPERTY(bool    hasGeminiKey READ hasGeminiKey NOTIFY geminiApiKeyChanged)
    Q_PROPERTY(QString geminiModel READ geminiModel WRITE setGeminiModel NOTIFY geminiModelChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QString mapTileUrl()   const;
    int     udpPort()      const;
    double  defaultAlt()   const;
    double  rtlAlt()       const;
    double  sweepSpacing() const;
    QString pythonPath()   const;
    bool    autoDetectAutopilot() const;
    bool    voiceEnabled() const;
    QString maleVoiceProfile() const;
    double  geofenceDefaultRadius() const;
    double  geofenceDefaultMaxAlt() const;
    int     geofenceDefaultAction() const;
    QString geminiApiKey() const;
    bool    hasGeminiKey() const;
    QString geminiModel() const;

    void setMapTileUrl(const QString &v);
    void setUdpPort(int v);
    void setDefaultAlt(double v);
    void setRtlAlt(double v);
    void setSweepSpacing(double v);
    void setPythonPath(const QString &v);
    void setAutoDetectAutopilot(bool v);
    void setVoiceEnabled(bool v);
    void setMaleVoiceProfile(const QString &v);
    void setGeofenceDefaultRadius(double v);
    void setGeofenceDefaultMaxAlt(double v);
    void setGeofenceDefaultAction(int v);
    void setGeminiApiKey(const QString &v);
    void setGeminiModel(const QString &v);

    Q_INVOKABLE void save();
    Q_INVOKABLE void reset();

signals:
    void mapTileUrlChanged();
    void udpPortChanged();
    void defaultAltChanged();
    void rtlAltChanged();
    void sweepSpacingChanged();
    void pythonPathChanged();
    void autoDetectAutopilotChanged();
    void voiceEnabledChanged();
    void maleVoiceProfileChanged();
    void geofenceDefaultRadiusChanged();
    void geofenceDefaultMaxAltChanged();
    void geofenceDefaultActionChanged();
    void geminiApiKeyChanged();
    void geminiModelChanged();

private:
    QSettings m_settings;
};
