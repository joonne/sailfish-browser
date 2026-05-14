/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef MPRISPLAYER_H
#define MPRISPLAYER_H

#include <QObject>
#include <QVariantMap>
#include <QDBusObjectPath>

class MprisPlayer : public QObject
{
    Q_OBJECT

    // org.mpris.MediaPlayer2.Player properties
    Q_PROPERTY(QString PlaybackStatus READ playbackStatus NOTIFY playbackStatusChanged)
    Q_PROPERTY(QVariantMap Metadata READ metadata NOTIFY metadataChanged)
    Q_PROPERTY(bool CanPlay READ canPlay CONSTANT)
    Q_PROPERTY(bool CanPause READ canPause CONSTANT)
    Q_PROPERTY(bool CanGoNext READ canGoNext NOTIFY canGoNextChanged)
    Q_PROPERTY(bool CanGoPrevious READ canGoPrevious NOTIFY canGoPreviousChanged)

public:
    explicit MprisPlayer(QObject *parent = nullptr);
    ~MprisPlayer();

    QString playbackStatus() const;
    QVariantMap metadata() const;
    bool canPlay() const { return true; }
    bool canPause() const { return true; }
    bool canGoNext() const { return m_canGoNext; }
    bool canGoPrevious() const { return m_canGoPrevious; }

    // Called from QML/ResourceController when media state changes
    Q_INVOKABLE void setPlaybackState(const QString &state);
    Q_INVOKABLE void setMetadata(const QString &title, const QString &artist, const QString &artUrl);
    Q_INVOKABLE void setCanGoNext(bool canNext);
    Q_INVOKABLE void setCanGoPrevious(bool canPrev);

public slots:
    // MPRIS methods called from D-Bus
    void Play();
    void Pause();
    void PlayPause();
    void Stop();
    void Next();
    void Previous();

signals:
    void playbackStatusChanged();
    void metadataChanged();
    void canGoNextChanged();
    void canGoPreviousChanged();

    // Signals to forward D-Bus commands to Gecko
    void playRequested();
    void pauseRequested();
    void playPauseRequested();
    void stopRequested();
    void nextRequested();
    void previousRequested();

private:
    void registerService();
    void unregisterService();
    void emitPropertiesChanged(const QString &interface, const QVariantMap &changedProperties);

    QString m_playbackStatus;
    QVariantMap m_metadata;
    bool m_canGoNext;
    bool m_canGoPrevious;
    bool m_registered;
};

#endif // MPRISPLAYER_H
