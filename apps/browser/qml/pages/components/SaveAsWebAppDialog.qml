import QtQuick 2.0
import Sailfish.Silica 1.0

BookmarkEditDialog {
    property string icon
    property Component desktopBookmarkWriter
    property QtObject bookmarkWriterParent

    //% "Save as Web App"
    description: qsTrId("sailfish_browser-he-save_as_web_app")
    onAccepted: {
        if (desktopBookmarkWriter) {
            var bookmarkWriter = desktopBookmarkWriter.createObject(bookmarkWriterParent)
            bookmarkWriter.saveAsWebApp(editedUrl, editedTitle, icon)
        } else {
            console.log("Cannot save web app without bookmark writer!!")
        }
    }
}
