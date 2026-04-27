/****************************************************************************
**
** Copyright (c) 2020 Open Mobile Platform LLC.
**
****************************************************************************/

/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QStandardPaths>
#include <QUrl>
#include "browserappinfo.h"

bool BrowserAppInfo::captivePortal()
{
    static bool captivePortalMode = false;
    static bool argsChecked = false;

    if (!argsChecked) {
        if (QCoreApplication::arguments().contains(QLatin1String("-captiveportal")))
            captivePortalMode = true;
        argsChecked = true;
    }

    return captivePortalMode;
}

bool BrowserAppInfo::webApp()
{
    static bool webAppMode = false;
    static bool argsChecked = false;

    if (!argsChecked) {
        webAppMode = QCoreApplication::arguments().contains(QLatin1String("-webapp"));
        argsChecked = true;
    }

    return webAppMode;
}

QString BrowserAppInfo::webAppUrl()
{
    static QString url;
    static bool argsChecked = false;

    if (!argsChecked) {
        const QStringList &arguments = QCoreApplication::arguments();
        int index = arguments.indexOf(QLatin1String("-webapp"));
        if (index >= 0 && index + 1 < arguments.size()) {
            url = arguments.at(index + 1);
        }
        argsChecked = true;
    }

    return url;
}

QString BrowserAppInfo::webAppId()
{
    static QString id;
    static bool computed = false;

    if (!computed) {
        QUrl url(webAppUrl());
        // Derive a stable ID from the URL origin (scheme + host + port)
        QString origin = url.scheme() + QStringLiteral("://") + url.host();
        if (url.port() != -1) {
            origin += QStringLiteral(":") + QString::number(url.port());
        }
        QByteArray hash = QCryptographicHash::hash(origin.toUtf8(), QCryptographicHash::Sha1);
        id = QString::fromLatin1(hash.toHex().left(12));
        computed = true;
    }

    return id;
}

QString BrowserAppInfo::profileName()
{
    const QStringList &arguments = QCoreApplication::arguments();
    int index = arguments.indexOf(QLatin1String("-profile"));
    if (index >= 0 && index + 1 < arguments.size()) {
        return arguments.at(index + 1);
    }

    // Auto-isolate webapp profiles
    if (webApp()) {
        return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
               + QStringLiteral("/webapps/") + webAppId();
    }

    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}
