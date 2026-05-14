/****************************************************************************
**
** Copyright (c) 2014 Jolla Ltd.
** Contact: Raine Makelainen <raine.makelainen@jolla.com>
**
****************************************************************************/

/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

#include <QDir>
#include <QCryptographicHash>
#include <QUrl>
#include <QFile>
#include <QtConcurrent>

#include "desktopbookmarkwriter.h"
#include "browserpaths.h"
#include "faviconmanager.h"
#include "datafetcher.h"

static bool dbw_testMode = false;

DesktopBookmarkWriter::DesktopBookmarkWriter(QObject *parent)
    : QObject(parent)
{
    connect(&m_writer, &QFutureWatcher<QString>::finished,
            this, &DesktopBookmarkWriter::desktopFileWritten);
}

DesktopBookmarkWriter::~DesktopBookmarkWriter()
{
    if (m_writer.isRunning()) {
        m_writer.waitForFinished();
    }
}

void DesktopBookmarkWriter::setTestModeEnabled(bool testMode)
{
    dbw_testMode = testMode;
}

bool DesktopBookmarkWriter::isTestModeEnabled()
{
    return dbw_testMode;
}

void DesktopBookmarkWriter::save(const QString &url, const QString &title, const QString &icon)
{
    QString effectiveIcon = icon;
    if (url.trimmed().isEmpty() || title.trimmed().isEmpty()) {
        emit saved(QString());
        return;
    }

    if (icon.isEmpty()) {
        effectiveIcon = FaviconManager::defaultDesktopBookmarkIcon();
    }

    if (icon.startsWith(QStringLiteral("https://")) || icon.startsWith(QStringLiteral("http://"))) {
        DataFetcher *fetcher = new DataFetcher(this);
        connect(fetcher, &DataFetcher::statusChanged,
                this, [this, url, title, fetcher]() {
            if (fetcher->status() == DataFetcher::Error) {
                m_writer.setFuture(QtConcurrent::run(this, &DesktopBookmarkWriter::write, url, title,
                                                     FaviconManager::defaultDesktopBookmarkIcon()));
            } else if (fetcher->status() == DataFetcher::Ready) {
                m_writer.setFuture(QtConcurrent::run(this, &DesktopBookmarkWriter::write, url, title,
                                                     fetcher->data()));
            }
        });
        fetcher->fetch(icon);
    } else {
        m_writer.setFuture(QtConcurrent::run(this, &DesktopBookmarkWriter::write, url, title, effectiveIcon));
    }
}

void DesktopBookmarkWriter::desktopFileWritten()
{
    QString path = m_writer.result();
    emit saved(path);
}

QString DesktopBookmarkWriter::uniqueDesktopFileName(QString title)
{
    QString filePath;
    if (!isTestModeEnabled()) {
        filePath = BrowserPaths::applicationsLocation();
    } else {
        filePath = BrowserPaths::dataLocation();
    }
    title = title.simplified().replace(QString(" "), QString("-"));

    QDir dir(filePath);
    dir.mkpath(filePath);

    dir.setNameFilters(QStringList() << QString("sailfish-browser-%2*").arg(title));
    QStringList similarlyNamedFiles = dir.entryList();
    int count = similarlyNamedFiles.count();

    QString fileName = QString(desktopFilePattern()).arg(title).arg(count);
    while (similarlyNamedFiles.contains(fileName)) {
        ++count;
        fileName = QString(desktopFilePattern()).arg(title).arg(count);
    }

    return filePath + '/' + fileName;
}

QString DesktopBookmarkWriter::write(const QString &url, const QString &title, const QString &icon)
{
    QString fileName = uniqueDesktopFileName(title);
    QString desktopFileData = QString("[Desktop Entry]\n" \
                                      "Type=Link\n" \
                                      "Name=%1\n" \
                                      "Icon=%2\n" \
                                      "URL=%3\n" \
                                      "Comment=%4\n").arg(title.trimmed(), icon,
                                                          url.trimmed(), title.trimmed());
    QFile desktopFile(fileName);
    if (desktopFile.open(QFile::WriteOnly)) {
        desktopFile.write(desktopFileData.toUtf8());
        desktopFile.flush();
        desktopFile.close();
        return fileName;
    }

    return QString();
}

QString DesktopBookmarkWriter::desktopFilePattern()
{
    return QStringLiteral("sailfish-browser-%2-%3.desktop");
}

void DesktopBookmarkWriter::saveAsWebApp(const QString &url, const QString &title, const QString &icon)
{
    QString effectiveIcon = icon;
    if (url.trimmed().isEmpty() || title.trimmed().isEmpty()) {
        emit saved(QString());
        return;
    }

    if (icon.isEmpty()) {
        effectiveIcon = FaviconManager::defaultDesktopBookmarkIcon();
    }

    if (icon.startsWith(QStringLiteral("https://")) || icon.startsWith(QStringLiteral("http://"))) {
        DataFetcher *fetcher = new DataFetcher(this);
        connect(fetcher, &DataFetcher::statusChanged,
                this, [this, url, title, fetcher]() {
            if (fetcher->status() == DataFetcher::Error) {
                m_writer.setFuture(QtConcurrent::run(this, &DesktopBookmarkWriter::writeWebApp, url, title,
                                                     FaviconManager::defaultDesktopBookmarkIcon()));
            } else if (fetcher->status() == DataFetcher::Ready) {
                m_writer.setFuture(QtConcurrent::run(this, &DesktopBookmarkWriter::writeWebApp, url, title,
                                                     fetcher->data()));
            }
        });
        fetcher->fetch(icon);
    } else {
        m_writer.setFuture(QtConcurrent::run(this, &DesktopBookmarkWriter::writeWebApp, url, title, effectiveIcon));
    }
}

QString DesktopBookmarkWriter::writeWebApp(const QString &url, const QString &title, const QString &icon)
{
    // Derive a stable webapp ID from the URL origin
    QUrl parsedUrl(url);
    QString origin = parsedUrl.scheme() + QStringLiteral("://") + parsedUrl.host();
    if (parsedUrl.port() != -1) {
        origin += QStringLiteral(":") + QString::number(parsedUrl.port());
    }
    QByteArray hash = QCryptographicHash::hash(origin.toUtf8(), QCryptographicHash::Sha1);
    QString webAppId = QString::fromLatin1(hash.toHex().left(12));
    QString serviceName = QStringLiteral("org.sailfishos.browser.webapp.w") + webAppId;

    QString fileName = uniqueDesktopFileName(title);
    QString desktopFileData = QString("[Desktop Entry]\n"
                                      "Type=Application\n"
                                      "Name=%1\n"
                                      "Icon=%2\n"
                                      "Exec=/usr/bin/sailfish-browser -webapp %3\n"
                                      "Comment=%4\n").arg(title.trimmed(), icon,
                                                          url.trimmed(), title.trimmed());
    desktopFileData += QString("X-Maemo-Service=%1\n"
                               "X-Maemo-Object-Path=/ui\n"
                               "X-Maemo-Method=%1.openUrl\n").arg(serviceName);
    desktopFileData += QStringLiteral("X-Nemo-Application-Type=no-invoker\n"
                                       "\n"
                                       "[X-Sailjail]\n"
                                       "Permissions=WebView;Audio;Internet\n"
                                       "OrganizationName=org.sailfishos\n");
    desktopFileData += QString("ApplicationName=webapp-%1\n").arg(webAppId);

    QFile desktopFile(fileName);
    if (desktopFile.open(QFile::WriteOnly)) {
        desktopFile.write(desktopFileData.toUtf8());
        desktopFile.flush();
        desktopFile.close();

        // Create D-Bus service file for lipstick auto-activation
        QString dbusServiceDir = QDir::homePath() + QStringLiteral("/.local/share/dbus-1/services");
        QDir().mkpath(dbusServiceDir);
        QString dbusServiceFile = dbusServiceDir + QStringLiteral("/") + serviceName + QStringLiteral(".service");
        QString dbusServiceData = QString("[D-BUS Service]\n"
                                          "Name=%1\n"
                                          "Exec=/usr/bin/sailfish-browser -webapp %2\n").arg(serviceName, url.trimmed());
        QFile dbusFile(dbusServiceFile);
        if (dbusFile.open(QFile::WriteOnly)) {
            dbusFile.write(dbusServiceData.toUtf8());
            dbusFile.flush();
            dbusFile.close();
        }

        return fileName;
    }

    return QString();
}
