/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

import QtQuick 2.2
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    readonly property var _metadata: MprisPlayer ? MprisPlayer.Metadata : ({})
    readonly property string _title: _metadata["xesam:title"] || ""
    readonly property string _artist: {
        var a = _metadata["xesam:artist"]
        return (a && a.length > 0) ? a[0] : ""
    }
    readonly property string _artUrl: _metadata["mpris:artUrl"] || ""
    readonly property bool _hasMedia: _title.length > 0 || _artUrl.length > 0

    Image {
        anchors.fill: parent
        source: cover._artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
        opacity: 0.5
    }

    Column {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Theme.paddingLarge
        }
        spacing: Theme.paddingSmall
        visible: cover._hasMedia

        Label {
            width: parent.width
            text: cover._title
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            color: Theme.primaryColor
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            text: cover._artist
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
            wrapMode: Text.Wrap
            maximumLineCount: 1
            elide: Text.ElideRight
            visible: cover._artist.length > 0
        }
    }

    CoverPlaceholder {
        visible: !cover._hasMedia
        //% "Web App"
        text: qsTrId("sailfish_browser-la-web_app")
        icon.source: "image://theme/icon-launcher-browser"
    }

    CoverActionList {
        enabled: cover._hasMedia

        CoverAction {
            iconSource: MprisPlayer && MprisPlayer.PlaybackStatus === "Playing"
                        ? "image://theme/icon-cover-pause"
                        : "image://theme/icon-cover-play"
            onTriggered: {
                if (MprisPlayer) {
                    MprisPlayer.PlayPause()
                }
            }
        }

        CoverAction {
            iconSource: "image://theme/icon-cover-next-song"
            onTriggered: {
                if (MprisPlayer && MprisPlayer.CanGoNext) {
                    MprisPlayer.Next()
                }
            }
        }
    }
}
