#pragma once
#include <QObject>
#include <QMediaPlayer>
#include <QVideoSink>
#include <QString>

class VideoManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isPlaying    READ isPlaying    NOTIFY playingChanged)
    Q_PROPERTY(QString streamUrl READ streamUrl    WRITE setStreamUrl NOTIFY streamUrlChanged)

public:
    explicit VideoManager(QObject *parent = nullptr);
    ~VideoManager() override;

    bool    isPlaying()  const { return m_playing; }
    QString streamUrl()  const { return m_streamUrl; }
    void    setStreamUrl(const QString &url);

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();

    QVideoSink* videoSink() const { return m_sink; }

signals:
    void playingChanged();
    void streamUrlChanged();

private:
    QMediaPlayer *m_player   = nullptr;
    QVideoSink   *m_sink     = nullptr;
    QString       m_streamUrl;
    bool          m_playing  = false;
};
