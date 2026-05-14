
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
        webAppMode: true

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

    // Start in chromeless standalone mode - toolbar appears on tap
    Component.onCompleted: {
        overlay.animator.showFullscreen()
    }
}
