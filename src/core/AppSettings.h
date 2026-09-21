#pragma once
#include <QObject>
#include <QSettings>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString mapTileUrl  READ mapTileUrl  WRITE setMapTileUrl  NOTIFY mapTileUrlChanged)
    Q_PROPERTY(int     udpPort     READ udpPort     WRITE setUdpPort     NOTIFY udpPortChanged)
    Q_PROPERTY(double  defaultAlt  READ defaultAlt  WRITE setDefaultAlt  NOTIFY defaultAltChanged)
    Q_PROPERTY(double  sweepSpacing READ sweepSpacing WRITE setSweepSpacing NOTIFY sweepSpacingChanged)
    Q_PROPERTY(QString pythonPath  READ pythonPath  WRITE setPythonPath  NOTIFY pythonPathChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QString mapTileUrl()   const;
    int     udpPort()      const;
    double  defaultAlt()   const;
    double  sweepSpacing() const;
    QString pythonPath()   const;

    void setMapTileUrl(const QString &v);
    void setUdpPort(int v);
    void setDefaultAlt(double v);
    void setSweepSpacing(double v);
    void setPythonPath(const QString &v);

    Q_INVOKABLE void save();
    Q_INVOKABLE void reset();

signals:
    void mapTileUrlChanged();
    void udpPortChanged();
    void defaultAltChanged();
    void sweepSpacingChanged();
    void pythonPathChanged();

private:
    QSettings m_settings;
};
