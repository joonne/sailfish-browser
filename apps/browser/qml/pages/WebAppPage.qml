
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

import QtQuick 2.2
import QtQuick.Window 2.2 as QuickWindow
import Sailfish.Silica 1.0
import Sailfish.Silica.private 1.0 as Private
import Sailfish.Browser 1.0
import Sailfish.Policy 1.0
import "components" as Browser
import "../shared" as Shared

Page {
    id: browserPage

    readonly property bool active: status == PageStatus.Active

    property alias overlay: overlay
    property alias url: webView.url
    property alias title: webView.title
    property alias webView: webView
    property alias inputRegion: inputRegion

    // Webapp origin for navigation restriction — set once from the initial URL
    property string webAppOrigin: ""

    function _extractOrigin(urlStr) {
        var protocolEnd = urlStr.indexOf("://")
        if (protocolEnd > 0) {
            var rest = urlStr.substring(protocolEnd + 3)
            var pathStart = rest.indexOf("/")
            if (pathStart > 0) {
                return urlStr.substring(0, protocolEnd + 3 + pathStart)
            }
            return urlStr.substring(0, protocolEnd + 3 + rest.length)
        }
        return ""
    }

    cutoutMode: CutoutMode.FullScreen

    function load(url, title) {
        webView.load(url, title)
    }

    function bringToForeground(window) {
        if ((webView.visibility < QuickWindow.Window.Maximized) && window) {
            window.raise()
        }
    }

    property int pageOrientation: pageStack.currentPage._windowOrientation
    onPageOrientationChanged: {
        if (!active) {
            webView.applyContentOrientation(pageOrientation)
        }
    }

    orientationTransitions: orientationFader.orientationTransition

    background: null

    Keys.onPressed: {
        webView.handleKeyPress(event.key)
    }

    Shared.OrientationFader {
        id: orientationFader

        visible: webView.contentItem
        page: browserPage
        fadeTarget: overlay
        color: webView.contentItem ? (webView.resourceController.videoActive &&
                                      webView.contentItem.fullscreen ? "black" : webView.contentItem.backgroundColor)
                                   : "white"

        onApplyContentOrientation: webView.applyContentOrientation(browserPage.orientation)
    }

    Private.VirtualKeyboardObserver {
        id: virtualKeyboardObserver

        active: webView.enabled
        transpose: window._transpose
        orientation: browserPage.orientation

        onWindowChanged: webView.chromeWindow = window

        states: State {
            name: "boundHeightControl"
            when: virtualKeyboardObserver.opened && webView.enabled
            PropertyChanges {
                target: webView.contentItem
                virtualKeyboardHeight: virtualKeyboardObserver.imSize
            }
        }
    }

    Shared.WebView {
        id: webView

        enabled: overlay.animator.allowContentUse
        fullscreenHeight: portrait ? Screen.height : Screen.width
        portrait: browserPage.isPortrait
        maxLiveTabCount: 1
        toolbarHeight: overlay.animator.opened ? overlay.toolBar.rowHeight : 0
        rotationHandler: browserPage
        imOpened: virtualKeyboardObserver.opened
        canShowSelectionMarkers: false

        onForegroundChanged: {
            if (foreground && webView.chromeWindow) {
                webView.chromeWindow.raise()
            }
        }

        onTouched: {
            if (contentFullscreen) {
                fullscreenCloseVisibleTimer.restart()
            } else if (!overlay.animator.opened) {
                // Tap to reveal toolbar in standalone mode
                overlay.animator.showChrome()
                chromeAutoHideTimer.restart()
            } else {
                // Reset auto-hide timer on interaction
                chromeAutoHideTimer.restart()
            }
        }

        onWebContentOrientationChanged: orientationFader.waitForWebContentOrientationChanged = false

        function applyContentOrientation(orientation) {
            orientationFader.waitForWebContentOrientationChanged = (contentItem && contentItem.active)

            switch (orientation) {
            case Orientation.None:
            case Orientation.Portrait:
                updateContentOrientation(Qt.PortraitOrientation)
                break
            case Orientation.Landscape:
                updateContentOrientation(Qt.LandscapeOrientation)
                break
            case Orientation.PortraitInverted:
                updateContentOrientation(Qt.InvertedPortraitOrientation)
                break
            case Orientation.LandscapeInverted:
                updateContentOrientation(Qt.InvertedLandscapeOrientation)
                break
            }
        }
    }

    // Dialog shown when user navigates outside the webapp origin
    Component {
        id: externalNavigationDialog

        Dialog {
            id: dialog
            property string targetUrl

            Column {
                width: parent.width
                spacing: Theme.paddingLarge

                DialogHeader {
                    //% "Open in Browser"
                    acceptText: qsTrId("sailfish_browser-he-open_in_browser")
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    wrapMode: Text.Wrap
                    //% "This link will open in a new browser window"
                    text: qsTrId("sailfish_browser-la-open_in_new_window")
                    color: Theme.highlightColor
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    wrapMode: Text.Wrap
                    text: dialog.targetUrl
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    truncationMode: TruncationMode.Fade
                    maximumLineCount: 3
                }
            }

            onAccepted: {
                // Open in main browser via D-Bus
                Qt.openUrlExternally(dialog.targetUrl)
            }
        }
    }

    IconButton {
        id: fullscreenClose

        opacity: fullscreenCloseVisibleTimer.running || pressed ? 1.0 : 0.0
        Behavior on opacity { FadeAnimation {} }
        visible: opacity > 0
        x: Theme.paddingLarge
        y: Theme.paddingLarge
        icon.source: "image://theme/icon-m-close"
        onClicked: {
            webView.sendAsyncMessage("embedui:exitFullscreen", {})
        }

        Timer {
            id: fullscreenCloseVisibleTimer

            interval: 2000
            running: webView.contentFullscreen
        }
    }

    Connections {
        target: AccessPolicy.browserEnabled && webView && webView.tabModel || null
        ignoreUnknownSignals: true
    }

    InputRegion {
        id: inputRegion

        window: webView.chromeWindow
        orientation: browserPage.orientation
        overlayMask: (webView.enabled && browserPage.active && !webView.touchBlocked)
                     ? Qt.rect(0, overlay.y, browserPage.width, browserPage.height - overlay.y)
                     : Qt.rect(0, 0, browserPage.width, browserPage.height)
        closeButtonMask: fullscreenClose.visible ? Qt.rect(fullscreenClose.x, fullscreenClose.y,
                                                           fullscreenClose.width, fullscreenClose.height)
                                                 : Qt.rect(0, 0, 0, 0)
    }

    Browser.WebAppOverlay {
        id: overlay

        active: true
        webView: webView
        containerPage: browserPage

        animator.onAtBottomChanged: {
            if (!animator.atBottom) {
                webView.clearSelection()
            }
        }

        onActiveChanged: {
            if (active && webView.contentItem) {
                overlay.animator.showChrome()
            }

            if (!active) {
                if (webView.chromeWindow && webView.foreground) {
                    webView.chromeWindow.raise()
                }
            }
        }
    }

    Connections {
        target: WebUtils
        onOpenUrlRequested: {
            if (!AccessPolicy.browserEnabled) {
                bringToForeground(webView.chromeWindow)
                window.activate()
                return
            }

            if (!webView.tabModel.activateTab(url)) {
                webView.clearSelection()
                webView.tabModel.newTab(url, false)
                overlay.dismiss(!Qt.application.active)
            }
            bringToForeground(webView.chromeWindow)
            window.activate()
        }
        onShowChrome: {
            overlay.dismiss(!Qt.application.active)
            bringToForeground(webView.chromeWindow)
            window.activate()
        }
    }

    // Auto-hide toolbar after period of inactivity in standalone mode
    Timer {
        id: chromeAutoHideTimer

        interval: 4000
        onTriggered: {
            if (overlay.animator.opened && !webView.loading) {
                overlay.animator.showFullscreen()
            }
        }
    }

    // Intercept navigation outside the webapp origin
    Connections {
        target: webView
        onUrlChanged: {
            if (!webView.url)
                return

            var currentUrl = webView.url.toString()

            // Capture the origin from the first real URL
            if (browserPage.webAppOrigin === "") {
                browserPage.webAppOrigin = browserPage._extractOrigin(currentUrl)
                return
            }

            var currentOrigin = browserPage._extractOrigin(currentUrl)
            if (currentOrigin !== "" && currentOrigin !== browserPage.webAppOrigin) {
                // Navigate back to the previous (in-origin) page
                webView.goBack()
                // Show dialog offering to open in main browser
                pageStack.push(externalNavigationDialog, { "targetUrl": currentUrl })
            }
        }
    }

    // Start in chromeless standalone mode - toolbar appears on tap
    Component.onCompleted: {
        overlay.animator.showFullscreen()
    }
}
