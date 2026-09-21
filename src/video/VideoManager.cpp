#include "VideoManager.h"
#include <QDebug>

VideoManager::VideoManager(QObject *parent)
    : QObject(parent)
{
    m_sink   = new QVideoSink(this);
    m_player = new QMediaPlayer(this);
    m_player->setVideoSink(m_sink);

    connect(m_player, &QMediaPlayer::playbackStateChanged, this, [this](QMediaPlayer::PlaybackState state) {
        bool nowPlaying = (state == QMediaPlayer::PlayingState);
        if (nowPlaying != m_playing) {
            m_playing = nowPlaying;
            emit playingChanged();
        }
    });
}

VideoManager::~VideoManager()
{
    stop();
}

void VideoManager::setStreamUrl(const QString &url)
{
    if (m_streamUrl == url) return;
    m_streamUrl = url;
    emit streamUrlChanged();
}

void VideoManager::start()
{
    if (m_streamUrl.isEmpty()) return;
    m_player->setSource(QUrl(m_streamUrl));
    m_player->play();
    qDebug() << "VideoManager: playing" << m_streamUrl;
}

void VideoManager::stop()
{
    m_player->stop();
}
