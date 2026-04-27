/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Browser 1.0
import "." as Browser
import "../../shared" as Shared

Column {
    id: toolBarRow

    property string url
    readonly property real rowHeight: height
    readonly property int maxRowCount: 1

    readonly property int horizontalOffset: largeScreen ? Theme.paddingLarge : Theme.paddingSmall
    readonly property int buttonPadding: largeScreen
                                         || orientation === Orientation.Landscape
                                         || orientation === Orientation.LandscapeInverted
                                         ? Theme.paddingMedium : Theme.paddingSmall
    readonly property int iconWidth: largeScreen ? (Theme.iconSizeLarge + 3 * buttonPadding)
                                                 : (Theme.iconSizeMedium + 2 * buttonPadding)
    readonly property int smallIconWidth: largeScreen ? (Theme.iconSizeMedium + 3 * buttonPadding)
                                                      : (Theme.iconSizeSmall + 2 * buttonPadding)

    property int scaledPortraitHeight: Screen.height -
                                       Math.floor((Screen.height - Settings.toolbarLarge * Theme.pixelRatio) /
                                                  WebUtils.cssPixelRatio) * WebUtils.cssPixelRatio
    property int scaledLandscapeHeight: Screen.width -
                                        Math.floor((Screen.width - Settings.toolbarSmall * Theme.pixelRatio) /
                                                   WebUtils.cssPixelRatio) * WebUtils.cssPixelRatio

    signal showChrome
    signal closeRequested
    signal openInBrowser

    width: parent.width

    Row {
        id: toolsRow

        width: parent.width
        height: browserPage.isPortrait ? scaledPortraitHeight : scaledLandscapeHeight

        Shared.ExpandingButton {
            id: backIcon

            height: parent.height
            expandedWidth: toolBarRow.iconWidth
            icon.source: "image://theme/icon-m-back"
            active: webView.canGoBack
            onTapped: webView.goBack()
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: toolBarRow.width - (menuButton.width + backIcon.width + reloadButton.width) + Theme.paddingMedium
            color: Theme.highlightColor

            text: {
                if (url) {
                    return WebUtils.displayableUrl(url)
                } else {
                    //% "Loading"
                    return qsTrId("sailfish_browser-la-webapp_loading")
                }
            }

            truncationMode: TruncationMode.Fade
        }

        Shared.ExpandingButton {
            id: reloadButton

            height: parent.height
            expandedWidth: toolBarRow.iconWidth
            icon.source: webView.loading ? "image://theme/icon-m-reset" : "image://theme/icon-m-refresh"
            active: webView.contentItem
            onTapped: {
                if (webView.loading) {
                    webView.stop()
                } else {
                    webView.reload()
                }
                toolBarRow.showChrome()
            }
        }

        Shared.ExpandingButton {
            id: menuButton

            height: parent.height
            expandedWidth: toolBarRow.iconWidth
            icon.source: "image://theme/icon-m-levels"
            onTapped: webAppMenu.open(menuButton)
        }
    }

    ContextMenu {
        id: webAppMenu

        MenuItem {
            //% "Open in Browser"
            text: qsTrId("sailfish_browser-me-webapp_open_in_browser")
            onClicked: toolBarRow.openInBrowser()
        }

        MenuItem {
            //% "Close"
            text: qsTrId("sailfish_browser-me-webapp_close")
            onClicked: toolBarRow.closeRequested()
        }
    }
}
