/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: menuDialog

    property string action

    canAccept: action !== ""

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            DialogHeader {
                //% "Web App"
                title: qsTrId("sailfish_browser-he-webapp_menu")
                //% "Cancel"
                cancelText: qsTrId("sailfish_browser-me-webapp_cancel")
                acceptText: ""
            }

            BackgroundItem {
                width: parent.width
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    //% "Open in Browser"
                    text: qsTrId("sailfish_browser-me-webapp_open_in_browser")
                }
                onClicked: {
                    menuDialog.action = "browser"
                    menuDialog.accept()
                }
            }

            BackgroundItem {
                width: parent.width
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    //% "Close"
                    text: qsTrId("sailfish_browser-me-webapp_close")
                }
                onClicked: {
                    menuDialog.action = "close"
                    menuDialog.accept()
                }
            }
        }
    }
}
