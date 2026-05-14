/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "mprisplayer.h"

#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QCoreApplication>
#include <QDebug>

static const QString MprisServiceName = QStringLiteral("org.mpris.MediaPlayer2.sailfish-browser");
static const QString MprisObjectPath = QStringLiteral("/org/mpris/MediaPlayer2");
static const QString MprisRootInterface = QStringLiteral("org.mpris.MediaPlayer2");
static const QString MprisPlayerInterface = QStringLiteral("org.mpris.MediaPlayer2.Player");
static const QString DbusPropertiesInterface = QStringLiteral("org.freedesktop.DBus.Properties");

// ============================================================================
// MprisRootAdaptor - implements org.mpris.MediaPlayer2
// ============================================================================

class MprisRootAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")

    Q_PROPERTY(bool CanQuit READ canQuit)
    Q_PROPERTY(bool CanRaise READ canRaise)
    Q_PROPERTY(bool HasTrackList READ hasTrackList)
    Q_PROPERTY(QString Identity READ identity)
    Q_PROPERTY(QString DesktopEntry READ desktopEntry)

public:
    explicit MprisRootAdaptor(MprisPlayer *parent)
        : QDBusAbstractAdaptor(parent)
    {
    }

    bool canQuit() const { return false; }
    bool canRaise() const { return true; }
    bool hasTrackList() const { return false; }
    QString identity() const { return QStringLiteral("Sailfish Browser"); }
    QString desktopEntry() const { return QStringLiteral("sailfish-browser"); }

public slots:
    void Raise() {
        // Could raise the browser window via D-Bus
    }
    void Quit() {}
};

// ============================================================================
// MprisPlayerAdaptor - implements org.mpris.MediaPlayer2.Player
// ============================================================================

class MprisPlayerAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")

    Q_PROPERTY(QString PlaybackStatus READ playbackStatus)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(bool CanPlay READ canPlay)
    Q_PROPERTY(bool CanPause READ canPause)
    Q_PROPERTY(bool CanGoNext READ canGoNext)
    Q_PROPERTY(bool CanGoPrevious READ canGoPrevious)
    Q_PROPERTY(bool CanSeek READ canSeek)
    Q_PROPERTY(bool CanControl READ canControl)

public:
    explicit MprisPlayerAdaptor(MprisPlayer *player)
        : QDBusAbstractAdaptor(player)
        , m_player(player)
    {
    }

    QString playbackStatus() const { return m_player->playbackStatus(); }
    QVariantMap metadata() const { return m_player->metadata(); }
    bool canPlay() const { return m_player->canPlay(); }
    bool canPause() const { return m_player->canPause(); }
    bool canGoNext() const { return m_player->canGoNext(); }
    bool canGoPrevious() const { return m_player->canGoPrevious(); }
    bool canSeek() const { return false; }
    bool canControl() const { return true; }

public slots:
    void Play() { m_player->Play(); }
    void Pause() { m_player->Pause(); }
    void PlayPause() { m_player->PlayPause(); }
    void Stop() { m_player->Stop(); }
    void Next() { m_player->Next(); }
    void Previous() { m_player->Previous(); }

private:
    MprisPlayer *m_player;
};

// ============================================================================
// MprisPlayer implementation
// ============================================================================

MprisPlayer::MprisPlayer(QObject *parent)
    : QObject(parent)
    , m_playbackStatus(QStringLiteral("Stopped"))
    , m_canGoNext(false)
    , m_canGoPrevious(false)
    , m_registered(false)
{
    registerService();
}

MprisPlayer::~MprisPlayer()
{
    unregisterService();
}

void MprisPlayer::registerService()
{
    new MprisRootAdaptor(this);
    new MprisPlayerAdaptor(this);

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerObject(MprisObjectPath, this)) {
        qWarning() << "[MPRIS] Failed to register object path";
        return;
    }
    if (!bus.registerService(MprisServiceName)) {
        qWarning() << "[MPRIS] Failed to register service name:" << MprisServiceName;
        return;
    }
    m_registered = true;
    qDebug() << "[MPRIS] Registered:" << MprisServiceName;
}

void MprisPlayer::unregisterService()
{
    if (m_registered) {
        QDBusConnection bus = QDBusConnection::sessionBus();
        bus.unregisterService(MprisServiceName);
        bus.unregisterObject(MprisObjectPath);
        m_registered = false;
    }
}

QString MprisPlayer::playbackStatus() const
{
    return m_playbackStatus;
}

QVariantMap MprisPlayer::metadata() const
{
    return m_metadata;
}

void MprisPlayer::setPlaybackState(const QString &state)
{
    QString mprisState;
    if (state == QStringLiteral("play") || state == QStringLiteral("Playing")) {
        mprisState = QStringLiteral("Playing");
    } else if (state == QStringLiteral("pause") || state == QStringLiteral("Paused")) {
        mprisState = QStringLiteral("Paused");
    } else {
        mprisState = QStringLiteral("Stopped");
    }

    if (m_playbackStatus != mprisState) {
        m_playbackStatus = mprisState;
        emit playbackStatusChanged();
        emitPropertiesChanged(MprisPlayerInterface, {
            {QStringLiteral("PlaybackStatus"), m_playbackStatus}
        });
    }
}

void MprisPlayer::setMetadata(const QString &title, const QString &artist, const QString &artUrl)
{
    QVariantMap newMetadata;
    if (!title.isEmpty()) {
        newMetadata[QStringLiteral("xesam:title")] = title;
    }
    if (!artist.isEmpty()) {
        newMetadata[QStringLiteral("xesam:artist")] = QStringList{artist};
    }
    if (!artUrl.isEmpty()) {
        newMetadata[QStringLiteral("mpris:artUrl")] = artUrl;
    }
    // MPRIS requires a track ID
    newMetadata[QStringLiteral("mpris:trackid")] =
        QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/sailfishos/browser/track/1")));

    if (m_metadata != newMetadata) {
        m_metadata = newMetadata;
        emit metadataChanged();
        emitPropertiesChanged(MprisPlayerInterface, {
            {QStringLiteral("Metadata"), m_metadata}
        });
    }
}

void MprisPlayer::setCanGoNext(bool canNext)
{
    if (m_canGoNext != canNext) {
        m_canGoNext = canNext;
        emit canGoNextChanged();
        emitPropertiesChanged(MprisPlayerInterface, {
            {QStringLiteral("CanGoNext"), m_canGoNext}
        });
    }
}

void MprisPlayer::setCanGoPrevious(bool canPrev)
{
    if (m_canGoPrevious != canPrev) {
        m_canGoPrevious = canPrev;
        emit canGoPreviousChanged();
        emitPropertiesChanged(MprisPlayerInterface, {
            {QStringLiteral("CanGoPrevious"), m_canGoPrevious}
        });
    }
}

void MprisPlayer::Play()
{
    emit playRequested();
}

void MprisPlayer::Pause()
{
    emit pauseRequested();
}

void MprisPlayer::PlayPause()
{
    emit playPauseRequested();
}

void MprisPlayer::Stop()
{
    emit stopRequested();
}

void MprisPlayer::Next()
{
    emit nextRequested();
}

void MprisPlayer::Previous()
{
    emit previousRequested();
}

void MprisPlayer::emitPropertiesChanged(const QString &interface, const QVariantMap &changedProperties)
{
    if (!m_registered)
        return;

    QDBusMessage signal = QDBusMessage::createSignal(
        MprisObjectPath, DbusPropertiesInterface, QStringLiteral("PropertiesChanged"));
    signal << interface << changedProperties << QStringList();
    QDBusConnection::sessionBus().send(signal);
}

#include "mprisplayer.moc"
