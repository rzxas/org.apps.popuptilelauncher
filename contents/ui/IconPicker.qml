// IconPicker.qml
import QtQuick 6
import QtQuick.Controls 6
import Qt.labs.platform 1

Item {
    id: root
    property string value: ""    // result: file://... or theme name
    signal accepted(string value)
    signal rejected()

    function open() { iconFileDialog.open() }

    FileDialog {
        id: iconFileDialog
        title: "Choose icon"
        nameFilters: ["Images (*.png *.svg *.xpm)", "All files (*)"]

        onAccepted: {
            // Safely take fileUrl or the first element of fileUrls
            var sel = ""
            if (typeof iconFileDialog.fileUrl !== "undefined" && iconFileDialog.fileUrl) {
                sel = iconFileDialog.fileUrl.toString()
            } else if (iconFileDialog.fileUrls && iconFileDialog.fileUrls.length) {
                sel = iconFileDialog.fileUrls[0].toString()
            } else if (typeof iconFileDialog.file !== "undefined" && iconFileDialog.file) {
                sel = iconFileDialog.file.toString()
            }

            if (!sel) { root.rejected(); return }

            // Normalize the absolute path to file://
            var abs = sel
            if (abs.indexOf("file://") !== 0 && abs.indexOf("/") === 0) abs = "file://" + abs
                root.value = abs
                root.accepted(abs)
        }

        onRejected: { root.rejected() }
    }
}
