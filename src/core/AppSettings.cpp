#include "AppSettings.h"

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
    , m_settings("DRONE_GCS", "GCS")
{}

QString AppSettings::mapTileUrl()   const { return m_settings.value("map/tileUrl", "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png").toString(); }
int     AppSettings::udpPort()      const { return m_settings.value("link/udpPort", 14550).toInt(); }
double  AppSettings::defaultAlt()   const { return m_settings.value("mission/defaultAlt", 15.0).toDouble(); }
double  AppSettings::sweepSpacing() const { return m_settings.value("mission/sweepSpacing", 25.0).toDouble(); }
QString AppSettings::pythonPath()   const { return m_settings.value("python/path", "python3").toString(); }

void AppSettings::setMapTileUrl(const QString &v)  { m_settings.setValue("map/tileUrl", v);           emit mapTileUrlChanged(); }
void AppSettings::setUdpPort(int v)                { m_settings.setValue("link/udpPort", v);           emit udpPortChanged(); }
void AppSettings::setDefaultAlt(double v)          { m_settings.setValue("mission/defaultAlt", v);     emit defaultAltChanged(); }
void AppSettings::setSweepSpacing(double v)        { m_settings.setValue("mission/sweepSpacing", v);   emit sweepSpacingChanged(); }
void AppSettings::setPythonPath(const QString &v)  { m_settings.setValue("python/path", v);            emit pythonPathChanged(); }

void AppSettings::save()  { m_settings.sync(); }
void AppSettings::reset()
{
    m_settings.clear();
    emit mapTileUrlChanged();
    emit udpPortChanged();
    emit defaultAltChanged();
    emit sweepSpacingChanged();
    emit pythonPathChanged();
}
