import QtQuick 6
import QtQuick.Controls 6
import QtQuick.Layouts 1
import "../config"

Item {
    id: root
    property var model: []
    property var configObj: null
    property bool useListView: false

    property int columns: (configObj && typeof configObj.columns === "number") ? configObj.columns : 4
    property int rows: (configObj && typeof configObj.rows === "number") ? configObj.rows : 3
    property int tileSize: (configObj && typeof configObj.tileSize === "number") ? configObj.tileSize : 72
    property int spacing: (configObj && typeof configObj.spacing === "number") ? configObj.spacing : 8

    property int effectiveCellWidth: (tileSize + spacing)
    property int effectiveCellHeight: (tileSize + spacing + 20)

    clip: true
    width: effectiveCellWidth * columns
    height: effectiveCellHeight * rows

    Component.onCompleted: Utils.dbg("DBG LOADED TileGrid.qml")

    GridView {
        id: grid
        anchors.leftMargin: 8
        anchors.top: parent.top
        anchors.left: parent.left
        // calculated width and height, strictly according to the settings
        property int cellW: (configObj ? (configObj.tileSize + configObj.spacing) : effectiveCellWidth)
        property int cellH: (configObj ? (configObj.tileSize + configObj.spacing + 20) : effectiveCellHeight)

        width: cellW * (configObj && typeof configObj.columns === "number" ? configObj.columns : columns)
        height: cellH * (configObj && typeof configObj.rows === "number" ? configObj.rows : rows)

        cellWidth: cellW
        cellHeight: cellH
        model: root.model
        flow: GridView.FlowLeftToRight
        snapMode: GridView.NoSnap
        visible: !root.useListView

        delegate: Item {
            width: (configObj ? configObj.tileSize : tileSize)
            height: (configObj ? (configObj.tileSize + 22) : tileSize + 22)

            // Move all visual logic to TileItem, but preserve the dimensions/calculations
            TileItem {
                id: titem
                width: parent.width
                height: parent.height
                indexInModel: index
                appEntry: modelData
                configObj: root.configObj

                // Forward the signal upward; main.qml must subscribe to root.launchRequested
                onActivated: function(app) { root.launchRequested(app, index) }
                onRequestRemove: function() { root.removeRequested(index) }
            }
        }
    }

    ListView {
        id: listViewModel
        anchors.fill: parent
        z: 999
        clip: true
        opacity: root.useListView ? 1.0 : 0.0
        model: root.model
        spacing: -14
        visible: root.useListView

        delegate: Rectangle {
            width: parent.width
            height: 44
            color: "transparent"
            property bool hovered: false

            Rectangle {
                id: hoverBg
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 30
                radius: 6
                color: hovered ? "#2f3b44" : "transparent"
                z: -1
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            property int iconSize: (configObj && typeof configObj.listIconSize === "number") ? Math.max(12, configObj.listIconSize) : 32
            property string iconSource:
            (modelData && modelData.iconFilePath && modelData.iconFilePath.length)
            ? (modelData.iconFilePath.indexOf("file://") === 0 ? modelData.iconFilePath : ("file://" + modelData.iconFilePath))
            : (modelData && modelData.icon && modelData.icon.length
            ? ("image://theme/" + modelData.icon.toString().trim().replace(/\.(png|svg|xpm)$/i,""))
            : "")

            RowLayout {
                anchors.fill: parent
                spacing: -4

                Item { width: 2; Layout.preferredWidth: 2; Layout.minimumWidth: 2 }

                Rectangle {
                    id: iconBox
                    color: "transparent"
                    Layout.preferredWidth: iconSize
                    Layout.preferredHeight: iconSize
                    Layout.minimumWidth: iconSize
                    Layout.minimumHeight: iconSize
                    implicitWidth: iconSize
                    implicitHeight: iconSize
                    Layout.alignment: Qt.AlignVCenter
                }

                Image {
                    id: listIcon
                    width: iconBox.width
                    height: iconBox.height
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                    source: iconSource
                    sourceSize: Qt.size(iconSize, iconSize)
                    visible: root.useListView && iconSource.length > 0
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { width: 16; Layout.preferredWidth: 16; Layout.minimumWidth: 16 }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        text: modelData.name || modelData.exec || "Unnamed"
                        color: "#EEE"
                        font.pixelSize: 16
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: hovered = true
                onExited: hovered = false
                onClicked: {
                    try { root.launchRequested(modelData, index) } catch(e) { Utils.dbg("DBG list launch failed", e) }
                }
            }
        }
    }

    signal launchRequested(var modelData, int index)
    signal removeRequested(int index)
}
