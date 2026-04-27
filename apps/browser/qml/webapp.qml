
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

import QtQuick 2.2
import "pages"
import "shared"

BrowserWindow {
    id: window

    cover: null

    //% "Web App"
    activityDisabledByMdm: qsTrId("sailfish_browser-la-web_app")
    initialPage: Component {
        WebAppPage {
            id: webAppPage

            Component.onCompleted: {
                window.webView = webView
                window.rootPage = webAppPage
            }

            Component.onDestruction: {
                window.webView = null
            }
        }
    }
}
