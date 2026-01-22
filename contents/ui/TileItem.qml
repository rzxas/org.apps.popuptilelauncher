import QtQuick 6
import QtQuick.Controls 6
import "../config"

Item {
    id: root
    property var appEntry: ({ name: "", exec: "", icon: "" })
    property int indexInModel: -1
    property var configObj: null

    signal activated(var app)
    signal requestRemove()

    // default dimensions, can be overridden from the outside
    property int tileSizeLocal: (configObj && typeof configObj.tileSize === "number") ? configObj.tileSize : 52
    width: tileSizeLocal
    height: tileSizeLocal + 22

    // computed properties (taken from your inline delegate)
    property int iconSize: Math.max(16, Math.floor(tileSizeLocal * 0.6))
    property int hoverLift: 3
    property int hoverPaddingVertical: 8
    property int hoverTopBase: Math.max(4, Math.floor((height - iconSize) * 0.12))
    property int hoverTopMargin: Math.max(0, hoverTopBase - hoverLift)
    property int hoverHeightComputed: Math.max(iconSize + hoverPaddingVertical, Math.floor(iconSize * 1.15))

    property int computedFontSize: Math.max(12, Math.floor(tileSizeLocal * 0.12))
    property int maxLines: 2
    property int maxCharsPerLine: Math.max(9, Math.floor((width - 12) / Math.max(8, computedFontSize)))

    property string labelSource: (appEntry && appEntry.name) ? appEntry.name : ((appEntry && appEntry.exec) ? appEntry.exec : "Unnamed")
    property string labelText: (function() {
        try {
            var s = labelSource ? labelSource.toString().trim() : "Unnamed"
            if (!s) return "Unnamed"
                var words = s.split(/\s+/)
                var lines = []
                var cur = ""
                for (var i = 0; i < words.length; i++) {
                    var w = words[i]
                    if (w.length > maxCharsPerLine) {
                        if (cur) { lines.push(cur); cur = "" ; if (lines.length >= maxLines) break }
                        var cut = w.substring(0, Math.max(1, maxCharsPerLine - 1)) + "…"
                        lines.push(cut)
                        if (lines.length >= maxLines) break
                    } else {
                        var candidate = cur ? (cur + " " + w) : w
                        if (candidate.length <= maxCharsPerLine) cur = candidate
                            else { if (cur) lines.push(cur); cur = w; if (lines.length >= maxLines) break }
                    }
                }
                if (lines.length < maxLines && cur) lines.push(cur)
                    var out = []
                    for (var j = 0; j < Math.min(lines.length, maxLines); j++) {
                        var L = lines[j]
                        if (L.length > maxCharsPerLine) L = L.substring(0, Math.max(1, maxCharsPerLine - 1)) + "…"
                            out.push(L)
                    }
                    return out.join("\n")
        } catch(e) { return labelSource }
    })()

    // highlight background
    Rectangle {
        id: hoverBg
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: hoverTopMargin
        width: parent.width
        height: hoverHeightComputed
        radius: 8
        color: "transparent"
        z: -1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on height { NumberAnimation { duration: 120 } }
        Behavior on anchors.topMargin { NumberAnimation { duration: 120 } }
    }

    // tile content
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.max(6, Math.floor((height - iconSize) * 0.12))
        spacing: 4
        width: parent.width

        Image {
            id: ico
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width * 0.7, iconSize)
            height: width
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true

            property string fileSrc: (appEntry && appEntry.iconFilePath) ? appEntry.iconFilePath : ""
            property string themeName: (appEntry && appEntry.icon) ? appEntry.icon.toString().trim() : ""

            source: (fileSrc && fileSrc.length) ? fileSrc
            : (themeName && themeName.length ? ("image://theme/" + themeName.replace(/\.(png|svg|xpm)$/i,"")) : "")

            visible: source !== "" && source !== "null"

            onStatusChanged: {
                if (status === Image.Error) {
                    // If we tried theme and it didn't work, try fileSrc (just in case)
                    var srcStr = (typeof source === "string") ? source : ""
                    if (srcStr.indexOf("image://theme/") === 0 && fileSrc && fileSrc.length && srcStr !== fileSrc) {
                        source = fileSrc
                        return
                    }
                    // Otherwise, leave it empty (the background/placeholder is drawn below)
                }
            }
        }

        Rectangle {
            visible: !ico.visible
            width: Math.min(parent.width * 0.7, iconSize)
            height: ico.width
            color: "#333"
            radius: 6
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            id: tileLabel
            width: parent.width - 12
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#EEE"
            font.pixelSize: computedFontSize
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            maximumLineCount: maxLines
            elide: Text.ElideNone
            text: labelText
            z: 1
        }
    }

    // MouseArea - the only source of launching and deleting
    MouseArea {
        width: parent.width
        height: parent.height
        hoverEnabled: true
        onEntered: hoverBg.color = Qt.rgba(0.18, 0.23, 0.27, 0.9)
        onExited: hoverBg.color = "transparent"
        onClicked: function(event) {
            if (event.button === Qt.LeftButton) {
                try { root.activated(appEntry) } catch(e) { Utils.dbg("DBG TileItem: emit failed", e) }
            } else if (event.button === Qt.RightButton) {
                try { if (configObj && typeof configObj.removeApp === "function") configObj.removeApp(indexInModel) } catch(e) { Utils.dbg("DBG TileItem: remove failed", e) }
            }
        }
    }

    Component.onCompleted: Utils.dbg("DBG LOADED TileItem.qml")
}
