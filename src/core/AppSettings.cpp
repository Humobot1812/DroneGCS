#include "AppSettings.h"

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
    , m_settings("DRONE_GCS", "GCS")
{}

QString AppSettings::mapTileUrl()   const { return m_settings.value("map/tileUrl", "https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}").toString(); }
int     AppSettings::udpPort()      const { return m_settings.value("link/udpPort", 14550).toInt(); }
double  AppSettings::defaultAlt()   const { return m_settings.value("mission/defaultAlt", 15.0).toDouble(); }
double  AppSettings::rtlAlt()       const { return m_settings.value("mission/rtlAlt", 25.0).toDouble(); }
double  AppSettings::sweepSpacing() const { return m_settings.value("mission/sweepSpacing", 25.0).toDouble(); }
QString AppSettings::pythonPath()   const { return m_settings.value("python/path", "python3").toString(); }
bool    AppSettings::autoDetectAutopilot() const { return m_settings.value("autopilot/autoDetect", true).toBool(); }
bool    AppSettings::voiceEnabled() const { return m_settings.value("voice/enabled", true).toBool(); }
QString AppSettings::maleVoiceProfile() const { return m_settings.value("voice/maleProfile", "male1").toString(); }
double  AppSettings::geofenceDefaultRadius() const { return m_settings.value("geofence/radius", 300.0).toDouble(); }
double  AppSettings::geofenceDefaultMaxAlt() const { return m_settings.value("geofence/maxAlt", 120.0).toDouble(); }
int     AppSettings::geofenceDefaultAction() const { return m_settings.value("geofence/action", 1).toInt(); }
QString AppSettings::geminiApiKey() const {
    QString key = m_settings.value("ai/geminiApiKey", "").toString().trimmed();
    if (key.isEmpty()) {
        key = QString::fromLocal8Bit(qgetenv("GEMINI_API_KEY")).trimmed();
    }
    return key;
}
bool    AppSettings::hasGeminiKey() const { return !geminiApiKey().isEmpty(); }
QString AppSettings::geminiModel() const {
    QString m = m_settings.value("ai/geminiModel", "gemini-3.6-flash").toString().trimmed();
    if (m.isEmpty() || m.contains("2.0") || m.contains("1.5") || m.contains("2.5")) {
        return "gemini-3.6-flash";
    }
    return m;
}

void AppSettings::setMapTileUrl(const QString &v)  { m_settings.setValue("map/tileUrl", v);           emit mapTileUrlChanged(); }
void AppSettings::setUdpPort(int v)                { m_settings.setValue("link/udpPort", v);           emit udpPortChanged(); }
void AppSettings::setDefaultAlt(double v)          { m_settings.setValue("mission/defaultAlt", v);     emit defaultAltChanged(); }
void AppSettings::setRtlAlt(double v)              { m_settings.setValue("mission/rtlAlt", v);         emit rtlAltChanged(); }
void AppSettings::setSweepSpacing(double v)        { m_settings.setValue("mission/sweepSpacing", v);   emit sweepSpacingChanged(); }
void AppSettings::setPythonPath(const QString &v)  { m_settings.setValue("python/path", v);            emit pythonPathChanged(); }
void AppSettings::setAutoDetectAutopilot(bool v)   { m_settings.setValue("autopilot/autoDetect", v);   emit autoDetectAutopilotChanged(); }
void AppSettings::setVoiceEnabled(bool v)          { m_settings.setValue("voice/enabled", v);          emit voiceEnabledChanged(); }
void AppSettings::setMaleVoiceProfile(const QString &v) { m_settings.setValue("voice/maleProfile", v); emit maleVoiceProfileChanged(); }
void AppSettings::setGeofenceDefaultRadius(double v) { m_settings.setValue("geofence/radius", v);      emit geofenceDefaultRadiusChanged(); }
void AppSettings::setGeofenceDefaultMaxAlt(double v) { m_settings.setValue("geofence/maxAlt", v);      emit geofenceDefaultMaxAltChanged(); }
void AppSettings::setGeofenceDefaultAction(int v)  { m_settings.setValue("geofence/action", v);      emit geofenceDefaultActionChanged(); }
void AppSettings::setGeminiApiKey(const QString &v) {
    if (m_settings.value("ai/geminiApiKey").toString() != v.trimmed()) {
        m_settings.setValue("ai/geminiApiKey", v.trimmed());
        emit geminiApiKeyChanged();
    }
}
void AppSettings::setGeminiModel(const QString &v) {
    if (m_settings.value("ai/geminiModel").toString() != v.trimmed()) {
        m_settings.setValue("ai/geminiModel", v.trimmed());
        emit geminiModelChanged();
    }
}

void AppSettings::save()  { m_settings.sync(); }

void AppSettings::reset()
{
    m_settings.clear();
    emit mapTileUrlChanged();
    emit udpPortChanged();
    emit defaultAltChanged();
    emit rtlAltChanged();
    emit sweepSpacingChanged();
    emit pythonPathChanged();
    emit autoDetectAutopilotChanged();
    emit voiceEnabledChanged();
    emit maleVoiceProfileChanged();
    emit geofenceDefaultRadiusChanged();
    emit geofenceDefaultMaxAltChanged();
    emit geofenceDefaultActionChanged();
    emit geminiApiKeyChanged();
    emit geminiModelChanged();
}
