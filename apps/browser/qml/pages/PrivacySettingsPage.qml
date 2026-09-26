/****************************************************************************
**
** Copyright (c) 2014 - 2016 Jolla Ltd.
** Copyright (c) 2020 - 2021 Open Mobile Platform LLC.
** Contact: Raine Makelainen <raine.makelainen@jolla.com>
**
****************************************************************************/

/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

import QtQuick 2.1
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Sailfish.Browser 1.0

Dialog {
    id: page

    property var remorse
    property var previousPage

    canAccept: clearHistory.checked
               || clearCookiesAndSiteData.checked
               || clearSavedPasswords.checked
               || clearCache.checked
               || clearBookmarks.checked
               || clearSitePermissions.checked
    acceptDestination: Qt.resolvedUrl("components/PrivacySettingsConfirmDialog.qml")

    onAcceptPendingChanged: {
        if (!acceptPending) return

        acceptDestinationInstance.historyEnabled = clearHistory.checked
        acceptDestinationInstance.cookieAndSiteDataEnabled = clearCookiesAndSiteData.checked
        acceptDestinationInstance.passwordsEnabled = clearSavedPasswords.checked
        acceptDestinationInstance.cacheEnabled = clearCache.checked
        acceptDestinationInstance.bookmarksEnabled = clearBookmarks.checked
        acceptDestinationInstance.sitePermissionsEnabled = clearSitePermissions.checked
        acceptDestinationInstance.historyPeriod = historyErasingComboBox.currentItem.period
        acceptDestinationInstance.acceptDestination = previousPage
    }

    ConfigurationGroup {
        id: config

        path: "/apps/sailfish-browser/privacy-cleanup"

        property bool clear_history: true
        property int clear_history_period: 0  // combo index
        property bool clear_cookies_and_site_data: true
        property bool clear_passwords: false
        property bool clear_cache: true
        property bool clear_bookmarks: false
        property bool clear_site_permissions: false
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height

        Column {
            id: contentColumn

            width: parent.width

            DialogHeader {
                //: Clear private data page header
                //% "Clear private data"
                title: qsTrId("settings_browser-ph-clear_private_data")

                //% "Clear"
                acceptText: qsTrId("sailfish_browser-he-clear")
            }

            Column {
                width: parent.width
                enabled: !(remorse && remorse.pending)

                TextSwitch {
                    id: clearHistory

                    //% "History"
                    text: qsTrId("settings_browser-la-clear_history")

                    //: Description for clearing history. This will clear history and tabs.
                    //% "Clears history and open tabs"
                    description: qsTrId("settings_browser-la-clear_history_description")

                    checked: config.clear_history
                    automaticCheck: false
                    onClicked: config.clear_history = !config.clear_history
                }

                ComboBox {
                     id: historyErasingComboBox

                     enabled: clearHistory.checked
                     currentIndex: config.clear_history_period

                     onCurrentIndexChanged: {
                         if (config.clear_history_period != currentIndex) {
                             config.clear_history_period = currentIndex
                         }
                     }

                     width: parent.width
                     //% "Clear browser history for"
                     label: qsTrId("settings_browser-la-clear_history_period")

                     menu: ContextMenu {

                         MenuItem {
                             property int period: 1
                             //% "Last 24 hours"
                             text: qsTrId("settings_browser-la-clear_history_day")
                         }

                         MenuItem {
                             property int period: 7
                             //% "Last week"
                             text: qsTrId("settings_browser-la-clear_history_week")
                         }

                         MenuItem {
                             property int period: 28
                             //% "Last 4 weeks"
                             text: qsTrId("settings_browser-la-clear_history_four_weeks")
                         }

                         MenuItem {
                             property int period: 0
                             //% "All time"
                             text: qsTrId("settings_browser-la-clear_history_everything")
                         }
                     }
                 }

                TextSwitch {
                    id: clearCookiesAndSiteData

                    //% "Cookies and site data"
                    text: qsTrId("settings_browser-la-clear_cookies_and_site_data")

                    checked: config.clear_cookies_and_site_data
                    automaticCheck: false
                    onClicked: config.clear_cookies_and_site_data = !config.clear_cookies_and_site_data
                }

                TextSwitch {
                    id: clearSavedPasswords

                    //% "Saved passwords"
                    text: qsTrId("settings_browser-la-clear_passwords")

                    checked: config.clear_passwords
                    automaticCheck: false
                    onClicked: config.clear_passwords = !config.clear_passwords
                }

                TextSwitch {
                    id: clearCache

                    //% "Cache"
                    text: qsTrId("settings_browser-la-clear_cache")

                    checked: config.clear_cache
                    automaticCheck: false
                    onClicked: config.clear_cache = !config.clear_cache
                }

                TextSwitch {
                    id: clearBookmarks

                    //% "Bookmarks"
                    text: qsTrId("settings_browser-la-clear_bookmarks")

                    checked: config.clear_bookmarks
                    automaticCheck: false
                    onClicked: config.clear_bookmarks = !config.clear_bookmarks
                }

                TextSwitch {
                    id: clearSitePermissions

                    //% "Site permissions"
                    text: qsTrId("settings_browser-la-clear_site_permissions")

                    checked: config.clear_site_permissions
                    automaticCheck: false
                    onClicked: config.clear_site_permissions = !config.clear_site_permissions
                }
            }
        }
    }
}
