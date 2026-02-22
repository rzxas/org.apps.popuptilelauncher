import QtQuick 6
import QtQuick.Controls 6
import QtQuick.Layouts 1
import QtQuick.Window 2
import "../config"
import org.kde.kirigami 2 as Kirigami

Window {
    id: editDialogWindow
    title: "Edit Applications"
    width: 560
    height: 420
    visible: false
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    modality: Qt.NonModal
    color: Kirigami.Theme.backgroundColor
    property var configObj: null
    property bool _appsModelConnected: false

    // Drag state
    property int draggingIndex: -1
    property real dragMouseY: 0
    property int delegateHeight: 48
    property bool dragInProgress: false

    signal requestReloadPopup()

    function updateModels() {
        try {
            editList.model = (editDialogWindow.configObj && editDialogWindow.configObj.appsModel) ? editDialogWindow.configObj.appsModel : []
        } catch(e) { Utils.dbg("DBG EditDialog.updateModels failed", e) }
    }

    function move(fromIndex, toIndex) {
        try {
            if (!editDialogWindow.configObj || !editDialogWindow.configObj.appsModel) return
            var m = editDialogWindow.configObj.appsModel
            if (fromIndex < 0 || fromIndex >= m.length) return
            if (toIndex < 0) toIndex = 0
            if (toIndex >= m.length) toIndex = m.length - 1
            if (fromIndex === toIndex) return
            var item = m.splice(fromIndex, 1)[0]
            m.splice(toIndex, 0, item)
            try {
                if (typeof editDialogWindow.configObj.persistAndNotify === "function") {
                    editDialogWindow.configObj.persistAndNotify()
                } else {
                    if (typeof editDialogWindow.configObj.save === "function") editDialogWindow.configObj.save()
                    try { editDialogWindow.configObj.appsModelUpdated() } catch(e) {}
                }
            } catch(e) { Utils.dbg("EditDialog.move: persist failed", e) }
            try { editList.model = editDialogWindow.configObj.appsModel } catch(e) {}
        } catch(e) { Utils.dbg("EditDialog.move failed", e) }
    }

    function open() {
        try {
            editDialogWindow.visible = true
            try {
                if (screen) {
                    editDialogWindow.x = Math.max(0, Math.floor((screen.width - editDialogWindow.width)/2))
                    editDialogWindow.y = Math.max(0, Math.floor((screen.height - editDialogWindow.height)/2))
                }
            } catch(e) {}
            try { editDialogWindow.requestActivate && editDialogWindow.requestActivate() } catch(e) {}
            try { Qt.callLater(function(){ try { editDialogWindow.requestActivate && editDialogWindow.requestActivate() } catch(e) {} }) } catch(e) {}
        } catch(e) { Utils.dbg("EditDialog.open failed", e) }
    }

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
        radius: 8

        border.color: (Kirigami && Kirigami.Theme && Kirigami.Theme.borderColor)
        ? Kirigami.Theme.borderColor
        : (luminance(Kirigami.Theme.backgroundColor) > 0.5 ? Qt.rgba(0,0,0,0.12) : Qt.rgba(1,1,1,0.06))
        border.width: 1.5

        function luminance(c) {
            return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Label { text: editDialogWindow.title; font.pixelSize: 16; Layout.alignment: Qt.AlignLeft }
                Item { Layout.fillWidth: true }
                Button { text: "Close"; onClicked: editDialogWindow.visible = false }
            }

            ListView {
                id: editList
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                clip: true
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                model: (editDialogWindow.configObj && editDialogWindow.configObj.appsModel) ? editDialogWindow.configObj.appsModel : []
                spacing: 6
                highlightMoveDuration: 120

                delegate: Item {
                    id: rowItem
                    width: parent.width
                    height: editDialogWindow.delegateHeight

                    Rectangle {
                        id: bg
                        anchors.fill: parent
                        property color bgColor: (editDialogWindow.draggingIndex === index)
                        ? Qt.rgba(0.23,0.23,0.23,1) // overlay drag
                        : (typeof Kirigami !== "undefined" && Kirigami.Theme && Kirigami.Theme.backgroundColor
                        ? Kirigami.Theme.backgroundColor
                        : Qt.application.palette.window)
                        color: bgColor
                        radius: 6

                        function luminance(c) { return 0.2126*c.r + 0.7152*c.g + 0.0722*c.b }

                        border.color: (typeof Kirigami !== "undefined" && Kirigami.Theme && Kirigami.Theme.borderColor)
                        ? Kirigami.Theme.borderColor
                        : (luminance(bgColor) > 0.5 ? Qt.rgba(0,0,0,0.12) : Qt.rgba(1,1,1,0.06))
                        border.width: 1

                        opacity: (editDialogWindow.draggingIndex === index) ? 0.85 : 1.0
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        RowLayout {
                            spacing: 8
                            // List icon — wrapped in a Rectangle so it can be rounded and cropped
                            Rectangle {
                                width: 28; height: 28
                                radius: 6
                                color: "transparent"
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    // Source: absolute path or theme name
                                    source: (modelData && modelData.iconFilePath && modelData.iconFilePath.length)
                                    ? modelData.iconFilePath
                                    : (modelData && modelData.icon && modelData.icon.length
                                    ? ("image://theme/" + modelData.icon.toString().trim().replace(/\.(png|svg|xpm)$/i,""))
                                    : "")
                                    visible: source !== "" && source !== "null"
                                }
                            }

                            Label {
                                id: nameLabel
                                text: (modelData.name || modelData.exec || "Unnamed") + (modelData.runInTerminal ? "  [T]" : "")
                                elide: Text.ElideRight
                                Layout.preferredWidth: 200
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            id: editBtn
                            text: "Edit"
                            onClicked: { try { editFormWindow.openForIndex(index) } catch(e) { Utils.dbg("Edit open failed", e) } }
                        }

                        Button {
                            id: removeBtn
                            text: "Remove"
                            onClicked: {
                                try {
                                    if (editDialogWindow.configObj && typeof editDialogWindow.configObj.removeApp === "function" && editDialogWindow.configObj.appsModel && typeof editDialogWindow.configObj.appsModel.length === "number") {
                                        if (index >= 0 && index < editDialogWindow.configObj.appsModel.length) {
                                            editDialogWindow.configObj.removeApp(index)
                                        } else {
                                            Utils.dbg("DBG EditDialog: remove clicked but index out of range", index)
                                        }
                                    } else {
                                        Utils.dbg("DBG EditDialog: remove clicked but removeApp not available")
                                    }
                                } catch(e) { Utils.dbg("DBG EditDialog: remove clicked failed", e) }
                            }
                        }
                    }

                    // LEFT-SIDE MouseArea: doesn't cover the right buttons so Edit/Remove remain clickable
                    MouseArea {
                        id: dragArea
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(120, parent.width - 180) // Adjust 180 to match the button width
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton

                        property real startX: 0
                        property real startY: 0
                        property real extraPixelPerStep: 3
                        property bool pressedInside: false
                        property bool draggingStarted: false
                        property int startIndex: -1
                        property int moveThreshold: 10      // Can be increased for a touchpad
                        property int longPressMs: 220

                        Timer {
                            id: longPressTimer
                            interval: dragArea.longPressMs
                            repeat: false
                            onTriggered: {
                                if (dragArea.pressedInside && !dragArea.draggingStarted) {
                                    dragArea.draggingStarted = true
                                    editDialogWindow.draggingIndex = dragArea.startIndex
                                    editDialogWindow.dragInProgress = true
                                    rowItem.opacity = 0.25
                                    // Show preview
                                    dragPreviewText.text = modelData.name || modelData.exec || "Unnamed"
                                    dragPreview.visible = true
                                }
                            }
                        }

                        // onPressed: {
                        onPressed: function(mouse) {
                            dragArea.startX = mouse.x
                            dragArea.startY = mouse.y
                            dragArea.pressedInside = true
                            dragArea.draggingStarted = false
                            dragArea.startIndex = index
                            longPressTimer.start()
                        }

                        // --- onPositionChanged ---
                        onPositionChanged: function(mouse) {
                            if (!dragArea.pressedInside) return;

                            var dx = Math.abs(mouse.x - dragArea.startX);
                            var dy = Math.abs(mouse.y - dragArea.startY);

                            if (!dragArea.draggingStarted && (dx >= dragArea.moveThreshold || dy >= dragArea.moveThreshold)) {
                                longPressTimer.stop();
                                dragArea.draggingStarted = true;
                                editDialogWindow.draggingIndex = dragArea.startIndex;
                                editDialogWindow.dragInProgress = true;
                                rowItem.opacity = 0.25;
                                dragPreviewText.text = modelData.name || modelData.exec || "Unnamed";
                                dragPreview.visible = true;
                            }

                            if (dragArea.draggingStarted) {
                                var p = editList.mapFromItem(dragArea, mouse.x, mouse.y);
                                var posInList = p.y + editList.contentY;

                                var delegateH = editDialogWindow.delegateHeight;
                                var len = (editDialogWindow.configObj && editDialogWindow.configObj.appsModel) ? editDialogWindow.configObj.appsModel.length : 0;
                                var dragIdx = editDialogWindow.draggingIndex;

                                // Calculate the slot and target (before/after) based on the cell's center
                                var slot = Math.floor(posInList / delegateH);
                                if (slot < 0) slot = 0;
                                if (slot > len - 1) slot = len - 1;
                                var within = posInList - slot * delegateH;
                                var target = (within >= (delegateH / 2)) ? (slot + 1) : slot;

                                // clamp target 0..len
                                if (target < 0) target = 0;
                                if (target > len) target = len;

                                // Basic visual border (without pixel correction)
                                var baseVisualTarget = target;
                                if (typeof dragIdx === "number" && dragIdx >= 0 && dragIdx < len && dragIdx < target) {
                                    baseVisualTarget = target - 1;
                                }
                                if (baseVisualTarget < 0) baseVisualTarget = 0;
                                if (baseVisualTarget > len) baseVisualTarget = len;

                                var baseY = editList.y + baseVisualTarget * delegateH - editList.contentY - (insertionIndicator.height / 2);

                                // Additional pixel correction: +1px for each index difference when moving down and -1px when moving up
                                var pixelDelta = 0;
                                if (typeof dragIdx === "number" && dragIdx >= 0) {
                                    if (target > dragIdx) {
                                        // When moving down: -1 in baseVisualTarget has already been compensated for, so additional steps = target - dragIdx - 1
                                        var stepsDown = target - dragIdx - 1;
                                        if (stepsDown < 0) stepsDown = 0;
                                        pixelDelta = stepsDown * dragArea.extraPixelPerStep;
                                    } else if (target < dragIdx) {
                                        // When moving up: We need to subtract one less position, so we use (target - dragIdx + 1) as the negative number of steps
                                        var stepsUp = (target - dragIdx + 4); // Negative or 0
                                        pixelDelta = stepsUp * dragArea.extraPixelPerStep; // Will give a negative Offset
                                    } else {
                                        pixelDelta = 0;
                                    }
                                }
                                insertionIndicator.visible = true;
                                insertionIndicator.y = Math.round(baseY + pixelDelta);

                                // Preview under the cursor (can be left as is)
                                dragPreview.y = editList.y + posInList - (delegateH / 2) - editList.contentY;
                            }
                        }

                        // --- onReleased ---
                        onReleased: function(mouse) {
                            longPressTimer.stop();
                            dragArea.pressedInside = false;

                            if (!dragArea.draggingStarted) {
                                return;
                            }

                            var p = editList.mapFromItem(dragArea, mouse.x, mouse.y);
                            var posInList = p.y + editList.contentY;

                            var delegateH = editDialogWindow.delegateHeight;
                            var len = (editDialogWindow.configObj && editDialogWindow.configObj.appsModel) ? editDialogWindow.configObj.appsModel.length : 0;
                            var slot = Math.floor(posInList / delegateH);
                            if (slot < 0) slot = 0;
                            if (slot > len - 1) slot = len - 1;
                            var within = posInList - slot * delegateH;
                            var target = (within >= (delegateH / 2)) ? (slot + 1) : slot;

                            var from = dragArea.startIndex;

                            // Hide visual elements
                            dragPreview.visible = false;
                            insertionIndicator.visible = false;
                            rowItem.opacity = 1.0;
                            editDialogWindow.draggingIndex = -1;
                            editDialogWindow.dragInProgress = false;
                            dragArea.draggingStarted = false;

                            if (typeof from === "number" && from >= 0 && target >= 0 && from !== target) {
                                var adjustedTarget = target;
                                if (from < target) adjustedTarget = target - 1;
                                if (adjustedTarget < 0) adjustedTarget = 0;
                                if (adjustedTarget > len - 1) adjustedTarget = len - 1;

                                editDialogWindow.move(from, adjustedTarget);
                            }
                        }

                        onCanceled: {
                            longPressTimer.stop()
                            dragArea.pressedInside = false
                            dragArea.draggingStarted = false
                            dragPreview.visible = false
                            insertionIndicator.visible = false
                            rowItem.opacity = 1.0
                            editDialogWindow.draggingIndex = -1
                            editDialogWindow.dragInProgress = false
                        }
                    } // MouseArea
                } // delegate

                // Drag preview and insertion indicator — one instance inside the ListView
                Rectangle {
                    id: dragPreview
                    visible: false
                    width: editList.width - 20
                    height: editDialogWindow.delegateHeight - 8
                    color: "#444"
                    radius: 6
                    opacity: 0.95
                    z: 999
                    anchors.left: editList.left
                    anchors.leftMargin: 10
                    y: editList.y
                    Text {
                        id: dragPreviewText
                        anchors.centerIn: parent
                        text: ""
                        color: "#FFF"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                    }
                }

                Rectangle {
                    id: insertionIndicator
                    visible: false
                    width: editList.width - 20
                    height: 4
                    color: "#66c2ff"
                    radius: 2
                    z: 998
                    anchors.left: editList.left
                    anchors.leftMargin: 10
                    y: editList.y
                }
            } // ListView

            RowLayout { Layout.alignment: Qt.AlignRight
                spacing: 8
                Button { text: "Done"; onClicked: editDialogWindow.visible = false }
            }
        }
    }

    Window {
        id: editFormWindow
        title: "Edit entry"
        width: 420
        height: 210
        visible: false
        flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        modality: Qt.WindowModal
        color: Kirigami.Theme.backgroundColor
        property int editingIndex: -1
        property var editModel: null
        property string previewIconSource: ""

        Rectangle {
            anchors.fill: parent
            color: Kirigami.Theme.backgroundColor
            radius: 8

            border.color: (Kirigami && Kirigami.Theme && Kirigami.Theme.borderColor)
            ? Kirigami.Theme.borderColor
            : (luminance(Kirigami.Theme.backgroundColor) > 0.6 ? Qt.rgba(0,0,0,0.12) : Qt.rgba(1,1,1,0.06))
            border.width: 1.5

            function luminance(c) {
                return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
            }
        }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 8
            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                ColumnLayout {
                    id: leftFields
                    Layout.preferredWidth: 320
                    spacing: 8

                    TextField { id: inName; placeholderText: "Name"; Layout.fillWidth: true }
                    TextField { id: inExec; placeholderText: "Exec command"; Layout.fillWidth: true }
                    TextField { id: inIcon; placeholderText: "Icon name or path"; Layout.fillWidth: true }
                }

                Rectangle {
                    id: bigIconButtonFrame
                    Layout.fillHeight: true
                    Layout.preferredWidth: 120
                    radius: 8
                    color: "transparent"
                    border.color: "#444"
                    border.width: 1
                    clip: true

                    ToolButton {
                        id: bigIconBtn
                        anchors.fill: parent
                        padding: 0
                        // Remove possible automatic indents
                        contentItem: Item {
                            anchors.fill: parent
                            // Background/effects can be added here if needed
                            Image {
                                id: bigIconPreview
                                width: 48; height: 48
                                anchors.centerIn: parent
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                source: (editFormWindow && editFormWindow.previewIconSource && editFormWindow.previewIconSource.length)
                                ? editFormWindow.previewIconSource
                                : "" //"image://theme/image-missing"
                                visible: source !== "" && source !== "null"
                            }

                            // Label under the icon (optional). If not needed, delete the block.
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: "Choose icon"
                                color: "#CCC"
                                font.pixelSize: 11
                                visible: false // Enable true if a signature is needed
                            }
                        }

                        onClicked: {
                            // Clear the temporary field so the picker doesn't "pick up" the old string
                            try {
                                inIcon.text = "";
                                editFormWindow.editModel = editFormWindow.editModel || {};
                                editFormWindow.editModel.icon = editFormWindow.editModel.icon || "";
                                editFormWindow.editModel.iconFilePath = editFormWindow.editModel.iconFilePath || "";
                            } catch(e) {}
                            if (!iconPickerLoader.item) iconPickerLoader.active = true
                                Qt.callLater(function(){ if (iconPickerLoader.item && typeof iconPickerLoader.item.open === "function") iconPickerLoader.item.open() })
                        }
                    }
                }

                Loader {
                    id: iconPickerLoader
                    source: Qt.resolvedUrl("IconPicker.qml")
                    asynchronous: true
                    visible: false

                    onLoaded: {
                        try {
                            if (!iconPickerLoader.item) return

                                // Disconnect old subscriptions, if any
                                try { iconPickerLoader.item.accepted.disconnect(); } catch(e) {}
                                try { iconPickerLoader.item.rejected.disconnect(); } catch(e) {}

                                // Attach a new handler that takes the current editingIndex into account
                                iconPickerLoader.item.accepted.connect(function(v) {
                                    try {
                                        var val = v || "";
                                        // Normalize: if path -> iconFilePath, otherwise theme name
                                        var chosenIcon = { icon: "", iconFilePath: "" }
                                        if (val.indexOf("file://") === 0 || val.indexOf("/") === 0) {
                                            var fp = (val.indexOf("file://") === 0) ? val : ("file://" + val);
                                            chosenIcon.iconFilePath = fp;
                                            chosenIcon.icon = "";
                                        } else {
                                            chosenIcon.icon = val.toString().trim().replace(/\.(png|svg|xpm)$/i,"");
                                            chosenIcon.iconFilePath = "";
                                        }

                                        // Update local fields (preview and text field)
                                        try {
                                            inIcon.text = chosenIcon.iconFilePath || chosenIcon.icon || "";
                                            editFormWindow.editModel = editFormWindow.editModel || {};
                                            if (val.indexOf("file://") === 0 || val.indexOf("/") === 0) {
                                                var fp = (val.indexOf("file://") === 0) ? val : ("file://" + val);
                                                editFormWindow.editModel.iconFilePath = fp;
                                                editFormWindow.editModel.icon = "";
                                                editFormWindow.previewIconSource = fp;
                                                inIcon.text = fp;
                                            } else {
                                                var themeName = val.toString().trim().replace(/\.(png|svg|xpm)$/i,"");
                                                editFormWindow.editModel.icon = themeName;
                                                editFormWindow.editModel.iconFilePath = "";
                                                editFormWindow.previewIconSource = "image://theme/" + themeName;
                                                inIcon.text = themeName;
                                            }
                                        } catch(e) {}

                                        // Save only icon fields in the edited record (by editingIndex)
                                        try {
                                            var idx = editFormWindow.editingIndex;
                                            if (typeof idx === "number" && idx >= 0 && editDialogWindow.configObj && editDialogWindow.configObj.appsModel) {
                                                var m = editDialogWindow.configObj.appsModel;
                                                var old = m[idx] || {};
                                                var newObj = Object.assign({}, old);
                                                newObj.icon = chosenIcon.icon || "";
                                                newObj.iconFilePath = chosenIcon.iconFilePath || "";
                                                m.splice(idx, 1, newObj);

                                                // Save and notify
                                                if (typeof editDialogWindow.configObj.persistAndNotify === "function") {
                                                    editDialogWindow.configObj.persistAndNotify();
                                                } else {
                                                    if (typeof editDialogWindow.configObj.save === "function") editDialogWindow.configObj.save();
                                                    try { editDialogWindow.configObj.appsModelUpdated() } catch(e) {}
                                                }

                                                // Update models/dropdowns locally (so the preview in the list is updated)
                                                Qt.callLater(function() {
                                                    try { if (typeof popupGrid !== "undefined" && popupGrid) popupGrid.model = editDialogWindow.configObj.appsModel } catch(e) {}
                                                    try { if (typeof listViewModel !== "undefined" && listViewModel) listViewModel.model = editDialogWindow.configObj.appsModel } catch(e) {}
                                                    try { editList.model = editDialogWindow.configObj.appsModel } catch(e) {}
                                                });
                                            }
                                        } catch(e) { Utils.dbg("DBG icon accepted persist failed", e) }
                                    } catch(e) { Utils.dbg("DBG EditDialog: iconPicker accepted handler failed", e) }
                                })
                        } catch(e) { Utils.dbg("DBG EditDialog: iconPickerLoader.onLoaded failed", e) }
                    }
                }
            }

            RowLayout {
                spacing: 12
                CheckBox {
                    id: runInTerminalCheck
                    text: "Run in terminal"
                    checked: (editFormWindow.editModel && typeof editFormWindow.editModel.runInTerminal !== "undefined") ? !!editFormWindow.editModel.runInTerminal : false
                }
                Item { width: 10 }
                TextField {
                    id: inWorkingDir
                    placeholderText: "Working directory (optional)"
                    // Make the field wide: Uses the available space in the ColumnLayout
                    Layout.fillWidth: true
                    // If you need to limit the minimum width:
                    // Layout.preferredWidth: 360
                }
            }
            RowLayout { Layout.alignment: Qt.AlignRight
                Button { text: "Cancel"; onClicked: editFormWindow.visible = false }
                Button {
                    text: "OK"
                    onClicked: {
                        var idx = editFormWindow.editingIndex
                        if (idx >= 0 && editDialogWindow.configObj && editDialogWindow.configObj.appsModel) {
                            var m = editDialogWindow.configObj.appsModel
                            var old = m[idx] || {}
                            var rawExec = inExec.text && inExec.text.length ? inExec.text.trim() : (old.execRaw || old.execFull || old.exec || "")
                            var normalized = ""
                            try { normalized = (editDialogWindow.configObj && typeof editDialogWindow.configObj.normalizeExec === "function") ? editDialogWindow.configObj.normalizeExec(rawExec) : rawExec.replace(/%[fFuUdDnNickk%]/g,"").replace(/\s+/g," ").trim() } catch(e) { normalized = rawExec }
                            var iconText = (typeof inIcon !== "undefined") ? (inIcon.text || "") : (old.icon || "")
                            var iconFilePathVal = ""
                            var iconThemeVal = ""

                            // If an absolute path or file:// is entered in the field, put it in iconFilePath
                            if (iconText && iconText.length) {
                                if (iconText.indexOf("file://") === 0) {
                                    iconFilePathVal = iconText
                                    iconThemeVal = ""
                                } else if (iconText.indexOf("/") === 0) {
                                    iconFilePathVal = "file://" + iconText
                                    iconThemeVal = ""
                                } else {
                                    // Theme/icon name - remove the extension if any
                                    iconThemeVal = iconText.toString().trim().replace(/\.(png|svg|xpm)$/i,"")
                                    iconFilePathVal = ""
                                }
                            } else {
                                // If the field is empty, try to save the old values ​​(compat)
                                iconThemeVal = old.icon || ""
                                iconFilePathVal = old.iconFilePath || ""
                            }

                            var newObj = {
                                file: old.file || "",
                                name: inName.text && inName.text.length ? inName.text : (old.name || ""),
                                icon: iconThemeVal || "",
                                iconFilePath: iconFilePathVal || "",
                                execRaw: rawExec,
                                execFull: normalized,
                                exec: normalized ? normalized.split(/\s+/)[0] : (rawExec ? rawExec.split(/\s+/)[0] : ""),
                                runInTerminal: !!runInTerminalCheck.checked,
                                workingDir: (typeof inWorkingDir !== "undefined") ? (inWorkingDir.text || "") : (old.workingDir || "")
                            }
                            m.splice(idx, 1, newObj)
                            try {
                                if (typeof editDialogWindow.configObj.persistAndNotify === "function") {
                                    editDialogWindow.configObj.persistAndNotify()
                                } else {
                                    if (typeof editDialogWindow.configObj.save === "function") editDialogWindow.configObj.save()
                                        try { if (typeof editDialogWindow.configObj.appsModelUpdated === "function") editDialogWindow.configObj.appsModelUpdated() } catch(e) {}
                                }
                            } catch(e) { Utils.dbg("DBG EditDialog: save/persist failed", e) }

                            // Clear models (if you did this) - you can leave them, but be sure to restore them below
                            try { if (typeof popupGrid !== "undefined" && popupGrid) popupGrid.model = [] } catch(e) {}
                            try { if (typeof listViewModel !== "undefined" && listViewModel) listViewModel.model = [] } catch(e) {}
                            try { editList.model = [] } catch(e) {}

                            // Restore models and force a popup redraw
                            Qt.callLater(function() {
                                try { if (typeof popupGrid !== "undefined" && popupGrid) popupGrid.model = (editDialogWindow.configObj && editDialogWindow.configObj.appsModel) ? editDialogWindow.configObj.appsModel : [] } catch(e) {}
                                try { if (typeof listViewModel !== "undefined" && listViewModel) listViewModel.model = (editDialogWindow.configObj && editDialogWindow.configObj.appsModel) ? editDialogWindow.configObj.appsModel : [] } catch(e) {}
                                try { editList.model = (editDialogWindow.configObj && editDialogWindow.configObj.appsModel) ? editDialogWindow.configObj.appsModel : [] } catch(e) {}

                                // If EditDialog signals main.qml to reload the popup, call it
                                try { if (typeof editDialogWindow.requestReloadPopup === "function") editDialogWindow.requestReloadPopup()
                                } catch(e) { Utils.dbg("DBG EditDialog: requestReloadPopup emit failed", e) }
                            })
                        }
                        editFormWindow.visible = false
                    }
                }
            }
        }

        function openForIndex(idx) {
            try {
                editingIndex = (typeof idx === "number") ? idx : -1;
                editModel = {};
                inName.text = ""; inExec.text = ""; inIcon.text = "";
                previewIconSource = ""; //"image://theme/image-missing";

                if (typeof editingIndex === "number" && editingIndex >= 0 && editDialogWindow.configObj && editDialogWindow.configObj.appsModel) {
                    var item = editDialogWindow.configObj.appsModel[editingIndex] || {};
                    editModel = {
                        icon: item.icon || "",
                        iconFilePath: item.iconFilePath || "",
                        runInTerminal: !!item.runInTerminal,
                        name: item.name || "",
                        execRaw: item.execRaw || item.execFull || item.exec || "",
                        workingDir: item.workingDir || ""
                    };
                    inName.text = editModel.name || "";
                    inExec.text = editModel.execRaw || "";
                    inIcon.text = editModel.iconFilePath && editModel.iconFilePath.length ? editModel.iconFilePath : (editModel.icon || "");
                    if (editModel.iconFilePath && editModel.iconFilePath.length) previewIconSource = editModel.iconFilePath;
                    else if (editModel.icon && editModel.icon.length) previewIconSource = "image://theme/" + editModel.icon.toString().trim().replace(/\.(png|svg|xpm)$/i,"");
                }
                visible = true;
                requestActivate && requestActivate();
            } catch(e) { Utils.dbg("DBG openForIndex failed", e) }
        }
    }

    Component.onCompleted: {
        Utils.dbg("DBG EditDialogWindow: Component.onCompleted; size:", editDialogWindow.width, editDialogWindow.height)
        try {
            updateModels()
            try {
                if (editDialogWindow.configObj && !editDialogWindow._appsModelConnected
                    && typeof editDialogWindow.configObj.appsModelUpdated !== "undefined"
                    && editDialogWindow.configObj.appsModelUpdated
                    && typeof editDialogWindow.configObj.appsModelUpdated.connect === "function") {

                    editDialogWindow.configObj.appsModelUpdated.connect(function() {
                        try { updateModels() } catch(e) { Utils.dbg("DBG EditDialog: appsModelUpdated handler failed", e) }
                    })
                    editDialogWindow._appsModelConnected = true
                    Utils.dbg("DBG EditDialog: connected appsModelUpdated")
                }
            } catch(e) { Utils.dbg("DBG EditDialog: attach appsModelUpdated failed", e) }
        } catch(e) { Utils.dbg("DBG EditDialog: onCompleted attach failed", e) }
    }
}
