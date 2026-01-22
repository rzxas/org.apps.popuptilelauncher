import QtQuick 6
import QtQuick.Controls 6
import QtQuick.Layouts 1
import Qt.labs.platform 1
import "../config"

ColumnLayout {
    anchors.fill: parent
    spacing: 6
    anchors.margins: 8
    anchors.topMargin: 2
    anchors.bottomMargin: 2

    property var configObj
    property var closeSettings: function() { }
    property bool _appsModelConnected: false
    property var _prevConfigObj: null

    // pending values ​​— changes are stored here until Apply
    property int pendingColumns: 4
    property int pendingRows: 3
    property int pendingTileSize: 72
    property int pendingSpacing: 8
    property int pendingPopupWidth: 360
    property int pendingPopupHeight: 360
    property bool pendingDisplayAsList: false
    property int pendingListIconSize: 32
    property string pendingWidgetIcon: ""

    function iconSourceFromValue(v) {
        if (!v || v.length === 0) return Qt.resolvedUrl("../icons/default-i.png")
        if (v.indexOf("file://") === 0 || v.indexOf("/") === 0) return v
        return "image://theme/" + v
    }

    // Initialize pending fields from configObj
    function loadPendingFromConfig() {
        try {
            if (!configObj) return
            pendingColumns = (typeof configObj.columns === "number") ? configObj.columns : pendingColumns
            pendingRows = (typeof configObj.rows === "number") ? configObj.rows : pendingRows
            pendingTileSize = (typeof configObj.tileSize === "number") ? configObj.tileSize : pendingTileSize
            pendingSpacing = (typeof configObj.spacing === "number") ? configObj.spacing : pendingSpacing
            pendingPopupWidth = (typeof configObj.popupWidth === "number") ? configObj.popupWidth : pendingPopupWidth
            pendingPopupHeight = (typeof configObj.popupHeight === "number") ? configObj.popupHeight : pendingPopupHeight
            pendingDisplayAsList = (typeof configObj.displayAsList === "boolean") ? configObj.displayAsList : pendingDisplayAsList
            pendingListIconSize = (typeof configObj.listIconSize === "number") ? configObj.listIconSize : pendingListIconSize

            // widgetIcon: prefer instance value if available
            try {
                var instVal = (configObj && typeof configObj.getInstanceValue === "function") ? configObj.getInstanceValue("widgetIcon") : undefined
                if (typeof instVal === "string" && instVal.length) pendingWidgetIcon = instVal
                else if (configObj && typeof configObj.widgetIcon === "string" && configObj.widgetIcon.length) pendingWidgetIcon = configObj.widgetIcon
            } catch(e) { /* ignore */ }

            // refresh UI bindings that depend on pending*
            try { appsList.model = (configObj && configObj.appsModel) ? configObj.appsModel : [] } catch(e) {}
        } catch(e) { Utils.dbg("DBG Settings: loadPendingFromConfig failed", e) }
    }

    onConfigObjChanged: {
        try {
            // Update the list of applications
            try { appsList.model = (configObj && configObj.appsModel) ? configObj.appsModel : [] } catch(e) {}

            // Reset the signal connection flag when the object changes
            if (_prevConfigObj !== configObj) {
                _appsModelConnected = false
                _prevConfigObj = configObj
            }

            // Connect appsModelUpdated once
            try {
                if (configObj && typeof configObj.appsModelUpdated !== "undefined"
                    && configObj.appsModelUpdated
                    && typeof configObj.appsModelUpdated.connect === "function") {

                        configObj.appsModelUpdated.connect(function() {
                            try {
                                if (typeof appsList !== "undefined" && appsList) {
                                    appsList.model = (configObj && configObj.appsModel) ? configObj.appsModel : []
                                }
                                Utils.dbg("DBG Settings: appsModelUpdated -> refreshed appsList.model; len=", (configObj && configObj.appsModel ? configObj.appsModel.length : 0))
                            } catch(e) { Utils.dbg("DBG Settings: appsModelUpdated handler failed", e) }
                        })
                        _appsModelConnected = true
                        Utils.dbg("DBG Settings: connected appsModelUpdated (onConfigObjChanged)")
                    }
            } catch(e) { Utils.dbg("DBG Settings: attach appsModelUpdated failed", e) }

            // Load pending values ​​from the current config
            Qt.callLater(function(){ loadPendingFromConfig() })
        } catch(e) { Utils.dbg("DBG Settings: onConfigObjChanged failed", e) }
        try {
            // Synchronize the main controls
            displayAsListCheck.checked = !!(configObj && configObj.displayAsList)
            columnsSpin.value = (configObj && typeof configObj.columns === "number") ? configObj.columns : columnsSpin.value
            rowsSpin.value = (configObj && typeof configObj.rows === "number") ? configObj.rows : rowsSpin.value
            tileSizeSpin.value = (configObj && typeof configObj.tileSize === "number") ? configObj.tileSize : tileSizeSpin.value
            spacingSpin.value = (configObj && typeof configObj.spacing === "number") ? configObj.spacing : spacingSpin.value
            popupWidthSpin.value = (configObj && typeof configObj.popupWidth === "number") ? configObj.popupWidth : popupWidthSpin.value
            popupHeightSpin.value = (configObj && typeof configObj.popupHeight === "number") ? configObj.popupHeight : popupHeightSpin.value

            // Debug log
            try {
                var instDbg = (configObj && typeof configObj.getInstanceValue === "function")
                ? configObj.getInstanceValue("debugLogs")
                : undefined
                var cfgDbg = (configObj && typeof configObj.debugLogs !== "undefined") ? configObj.debugLogs : undefined
                var finalDbg = (typeof instDbg !== "undefined") ? instDbg : ((typeof cfgDbg !== "undefined") ? cfgDbg : false)
                Utils.debugLogs = !!finalDbg
                debugLogsCheck.checked = Utils.debugLogs
            } catch(e) {
                Utils.dbg("DBG Settings: failed to init debugLogs from config", e)
            }

            // widget icon preview
            var wv = (configObj && typeof configObj.getInstanceValue === "function") ? (configObj.getInstanceValue("widgetIcon") || "") : (configObj ? (configObj.widgetIcon || "") : "")
            widgetIconName.text = wv
            try { widgetIconBtn.contentItem.source = iconSourceFromValue(wv) } catch(e) {}
        } catch(e) { Utils.dbg("DBG Settings: onConfigObjChanged sync failed", e) }
    }

    // DesktopPicker wrapper
    Item {
        id: dpWrapper
        width: 0; height: 0
        DesktopPicker {
            id: dp
            visible: false
            anchors.fill: parent

            onDesktopChosen: {
                try {
                    // If there is a desktopPicker in main, forward it there (centralized handler)
                    try {
                        if (root && root.desktopPicker && typeof root.desktopPicker.onDesktopChosen === "function") {
                            root.desktopPicker.onDesktopChosen(path, contents || "")
                            return
                        }
                    } catch(e) { /* fallback below */ }

                    // If configObj can add, use it
                    if (configObj && typeof configObj.addAppFromDesktop === "function") {
                        configObj.addAppFromDesktop(path, contents || "")
                        return
                    }

                    // As a last resort, attempt a local add (minimal fallback)
                    try { dp.tryLocalAdd(contents || "") } catch(e) { Utils.dbg("DBG Settings: fallback tryLocalAdd failed", e) }
                } catch(e) {
                    Utils.dbg("DBG Settings: onDesktopChosen exception", e)
                }
            }
        }
    }

    RowLayout {
        spacing: 12
        Item { width: 2 }
        Label { text: "Widget icon:" }

        Loader { id: iconPickerLoader; source: Qt.resolvedUrl("IconPicker.qml") }
        Connections {
            target: iconPickerLoader.item
            function onAccepted(v) {
                try {
                    pendingWidgetIcon = v || ""
                    widgetIconName.text = pendingWidgetIcon
                    try { widgetIconBtn.contentItem.source = iconSourceFromValue(pendingWidgetIcon) } catch(e) {}
                } catch(e) { Utils.dbg("DBG Settings: IconPicker accepted handler threw", e) }
            }
            function onRejected() { /* optional */ }
        }

        Rectangle {
            id: widgetIconBtnFrame
            Layout.preferredWidth: 52
            Layout.preferredHeight: 52
            radius: 8
            color: "transparent"
            border.color: "#444"
            border.width: 1

            ToolButton {
                id: widgetIconBtn
                anchors.fill: parent
                padding: 0
                width: 48; height: 48
                onClicked: {
                    if (!iconPickerLoader.item) iconPickerLoader.active = true
                    Qt.callLater(function(){ if (iconPickerLoader.item) iconPickerLoader.item.open() })
                }
                contentItem: Item {
                    anchors.fill: parent
                    Image {
                        id: widgetIconPreview
                        anchors.centerIn: parent
                        width: Math.min(parent.width, 48)
                        height: Math.min(parent.height, 48)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        // preview uses pendingWidgetIcon first, then config
                        source: (pendingWidgetIcon && pendingWidgetIcon.length)
                            ? iconSourceFromValue(pendingWidgetIcon)
                            : (configObj && typeof configObj.getInstanceValue === "function"
                                ? iconSourceFromValue(configObj.getInstanceValue("widgetIcon") || (configObj.widgetIcon || ""))
                                : iconSourceFromValue(configObj ? (configObj.widgetIcon || "") : ""))
                    }
                }
            }
        }

        TextField {
            id: widgetIconName
            placeholderText: "Icon name (theme) or file path"
            text: pendingWidgetIcon
            width: 220
            onTextChanged: {
                pendingWidgetIcon = text || ""
                try { widgetIconBtn.contentItem.source = iconSourceFromValue(pendingWidgetIcon) } catch(e) {}
            }
        }
    }

    Rectangle {
        id: groupRect
        Layout.preferredWidth: 376
        color: "transparent"
        border.color: "#444"
        border.width: 1
        radius: 8
        z: 1

        ColumnLayout {
            id: groupCol
            anchors.fill: parent
            spacing: 8
            Layout.fillWidth: true
            Item { height: 1 }

            RowLayout {
                spacing: 12
                Item { width: 14 }
                Label { text: "List icon size:" }
                SpinBox {
                    id: listIconSpin
                    leftPadding: 6
                    rightPadding: 14
                    from: 12; to: 128
                    value: pendingListIconSize
                    onValueChanged: pendingListIconSize = value
                }
                Item { width: 18 }
                Label { id: displayLabel; text: "Display as list"; verticalAlignment: Text.AlignVCenter }

                CheckBox {
                    id: displayAsListCheck
                    text: ""
                    checked: pendingDisplayAsList
                    onCheckedChanged: pendingDisplayAsList = checked
                }
            }

            RowLayout {
                spacing: 12
                Item { width: 14 }
                Label { text: "Columns:" }
                Item { width: 10 }
                SpinBox {
                    id: columnsSpin
                    leftPadding: 6
                    rightPadding: 22
                    from: 1; to: 10
                    value: pendingColumns
                    onValueChanged: pendingColumns = value
                }
                Item { width: 18 }
                Label { text: "Rows:" }
                Item { width: 19 }
                SpinBox {
                    id: rowsSpin
                    leftPadding: 6
                    rightPadding: 22
                    from: 1; to: 10
                    value: pendingRows
                    onValueChanged: pendingRows = value
                }
            }

            RowLayout {
                spacing: 12
                Item { width: 14 }
                Label { text: "Tile size:" }
                Item { width: 16 }
                SpinBox {
                    id: tileSizeSpin
                    leftPadding: 6
                    rightPadding: 14
                    from: 24; to: 256
                    value: pendingTileSize
                    onValueChanged: pendingTileSize = value
                }
                Item { width: 20 }
                Label { text: "Spacing:" }
                Item { width: 1 }
                SpinBox {
                    id: spacingSpin
                    leftPadding: 6
                    rightPadding: 22
                    from: 0; to: 64
                    value: pendingSpacing
                    onValueChanged: pendingSpacing = value
                }
            }

            RowLayout {
                spacing: 12
                Item { width: 14 }
                Label { text: "Popup width:" }
                SpinBox {
                    id: popupWidthSpin
                    leftPadding: 6
                    rightPadding: 12
                    from: 100; to: 2000
                    value: pendingPopupWidth
                    onValueChanged: pendingPopupWidth = value
                }
                Item { width: 9 }
                Label { text: "Popup height:" }
                SpinBox {
                    id: popupHeightSpin
                    leftPadding: 6
                    rightPadding: 12
                    from: 100; to: 2000
                    value: pendingPopupHeight
                    onValueChanged: pendingPopupHeight = value
                }
            }
            Item { height: 2 }
        }

        implicitWidth: groupCol.implicitWidth + 15
        implicitHeight: groupCol.implicitHeight + 15
    }

    RowLayout {
        spacing: 14
        Layout.alignment: Qt.AlignVCenter
        Layout.rightMargin: 20
        Item { width: 1 }
        Label { text: "App:" }
        Button {
            text: "Add From System"
            font.pixelSize: 8
            padding: 5
            onClicked: {
                try {
                    if (root && typeof root.openSystemPicker === "function") root.openSystemPicker()
                    else dp.open()
                } catch(e) { dp.open() }
            }
        }
        Button {
            text: "Add Manually"
            font.pixelSize: 8
            padding: 5
            onClicked: { manualDialog.visible = true }
        }
        Button {
            text: "Edit"
            font.pixelSize: 8
            padding: 5
            Layout.preferredWidth: 70
            onClicked: {
                try {
                    if (root) {
                        if (root.overlayWindow && typeof root.overlayWindow.visible !== "undefined") root.overlayWindow.visible = false
                        if (root.globalDropdownWindow && typeof root.globalDropdownWindow.visible !== "undefined") root.globalDropdownWindow.visible = false
                    }
                } catch(e) {}
                if (editDialogLoader && editDialogLoader.item) {
                    if (typeof editDialogLoader.item.open === "function") {
                        editDialogLoader.item.open()
                        try { editDialogLoader.item.requestActivate && editDialogLoader.item.requestActivate() } catch(e) {}
                    } else {
                        editDialogLoader.item.visible = true
                        try { editDialogLoader.item.requestActivate && editDialogLoader.item.requestActivate() } catch(e) {}
                    }
                }
            }
        }
    }

    Item { height: 2 }

    RowLayout { Layout.alignment: Qt.AlignRight
        spacing: 10
        Layout.rightMargin: 18

        ToolButton {
            id: helpBtn
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            padding: 0
            ToolTip.visible: false

            contentItem: Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: Qt.resolvedUrl("../icons/help-question.png")
            }

            onClicked: {
                try {
                    var readmeUrl = Qt.resolvedUrl("../ReadMe.txt") || ""
                    Utils.dbg("DBG Settings: Help -> resolved ReadMe URL:", readmeUrl)

                    if (!readmeUrl || readmeUrl.length === 0) {
                        Utils.dbg("DBG Settings: Help -> ReadMe URL empty")
                        return
                    }

                    // Attempt to open using the standard method (recommended)
                    try {
                        var ok = Qt.openUrlExternally(readmeUrl)
                        Utils.dbg("DBG Settings: Help -> Qt.openUrlExternally returned", ok, "url=", readmeUrl)
                        if (ok) return
                    } catch(e) {
                        Utils.dbg("DBG Settings: Help -> Qt.openUrlExternally threw", e)
                    }

                    // Fallback: If Qt.openUrlExternally doesn't work, try xdg-open via HelperBridge (if available)
                    try {
                        var path = readmeUrl
                        // HelperBridge.runCommand waits for a command; xdg-open accepts file:// or an absolute path
                        if (path.indexOf("file://") === 0) path = path.substring(7)
                            var cmd = "xdg-open \"" + path.replace(/"/g, '\\"') + "\""
                            if (typeof HelperBridge !== "undefined" && HelperBridge && typeof HelperBridge.runCommand === "function") {
                                var res = HelperBridge.runCommand(cmd)
                                Utils.dbg("DBG Settings: Help -> HelperBridge.runCommand(", cmd, ") returned", res)
                                return
                            } else {
                                Utils.dbg("DBG Settings: Help -> HelperBridge.runCommand not available; cmd would be:", cmd)
                            }
                    } catch(e) {
                        Utils.dbg("DBG Settings: Help -> fallback runCommand threw", e)
                    }

                    // If all else fails, log
                    Utils.dbg("DBG Settings: Help -> failed to open ReadMe:", readmeUrl)
                } catch(e) {
                    Utils.dbg("DBG Settings: Help button handler exception", e)
                }
            }
        }

        CheckBox {
            id: debugLogsCheck
            text: "Enable debug logs"
            checked: Utils.debugLogs
            onCheckedChanged: {
                Utils.debugLogs = checked
            }
            Layout.alignment: Qt.AlignVCenter
        }

        Button {
            text: "Close"
            onClicked: {
                try {
                    if (configObj && typeof configObj.loadInstanceConfig === "function") {
                        configObj.loadInstanceConfig()
                    }
                } catch(e) { Utils.dbg("DBG Settings: Close -> loadInstanceConfig failed", e) }

                // Delayed rollback of pending values ​​to give QML time to apply changes to configObj
                Qt.callLater(function() {
                    try {
                        loadPendingFromConfig()
                        // Synchronize controls with pending values
                        displayAsListCheck.checked = !!pendingDisplayAsList
                        columnsSpin.value = pendingColumns
                        rowsSpin.value = pendingRows
                        tileSizeSpin.value = pendingTileSize
                        spacingSpin.value = pendingSpacing
                        popupWidthSpin.value = pendingPopupWidth
                        popupHeightSpin.value = pendingPopupHeight
                        widgetIconName.text = pendingWidgetIcon
                        try { widgetIconBtn.contentItem.source = iconSourceFromValue(pendingWidgetIcon || "") } catch(e) {}

                        // Reset Utils.debugLogs to the saved value (if any)
                        try {
                            var instDbg = (configObj && typeof configObj.getInstanceValue === "function")
                            ? configObj.getInstanceValue("debugLogs")
                            : undefined
                            var cfgDbg = (configObj && typeof configObj.debugLogs !== "undefined") ? configObj.debugLogs : undefined
                            var finalDbg = (typeof instDbg !== "undefined") ? instDbg : ((typeof cfgDbg !== "undefined") ? cfgDbg : false)
                            Utils.debugLogs = !!finalDbg
                            debugLogsCheck.checked = Utils.debugLogs
                        } catch(e) { Utils.dbg("DBG Settings: Close -> restore debugLogs failed", e) }
                    } catch(e) { Utils.dbg("DBG Settings: Close -> deferred UI sync failed", e) }
                })

                if (typeof closeSettings === "function") closeSettings()
            }
        }

        Button {
            text: "Apply"
            onClicked: {
                Utils.dbg("DBG Settings: Apply clicked")
                if (!configObj) return

                try {
                    // Apply all pending values ​​in configObj and save
                    try { if (typeof pendingColumns === "number") configObj.columns = pendingColumns } catch(e) {}
                    try { if (typeof pendingRows === "number") configObj.rows = pendingRows } catch(e) {}
                    try { if (typeof pendingTileSize === "number") configObj.tileSize = pendingTileSize } catch(e) {}
                    try { if (typeof pendingSpacing === "number") configObj.spacing = pendingSpacing } catch(e) {}
                    try { if (typeof pendingPopupWidth === "number") configObj.popupWidth = pendingPopupWidth } catch(e) {}
                    try { if (typeof pendingPopupHeight === "number") configObj.popupHeight = pendingPopupHeight } catch(e) {}
                    try { if (typeof pendingDisplayAsList === "boolean") configObj.displayAsList = pendingDisplayAsList } catch(e) {}
                    try { if (typeof pendingListIconSize === "number") configObj.listIconSize = pendingListIconSize } catch(e) {}

                    // WidgetIcon — save via setInstanceValue to write to per-instance storage
                    try {
                        var toSave = (pendingWidgetIcon && pendingWidgetIcon.length) ? pendingWidgetIcon : ""
                        if (toSave && configObj && typeof configObj.setInstanceValue === "function") {
                            configObj.setInstanceValue("widgetIcon", toSave)
                        } else if (toSave && configObj) {
                            // fallback: set property directly
                            configObj.widgetIcon = toSave
                        }
                    } catch(e) { Utils.dbg("DBG Settings: apply -> setInstanceValue(widgetIcon) failed", e) }

                    // Debug checkbox
                    try {
                        if (configObj && typeof configObj.setInstanceValue === "function") {
                            // Write the current runtime value of Utils.debugLogs
                            configObj.setInstanceValue("debugLogs", !!(typeof Utils !== "undefined" ? Utils.debugLogs : false))
                        } else if (configObj) {
                            configObj.debugLogs = !!(typeof Utils !== "undefined" ? Utils.debugLogs : false)
                        }
                    } catch(e) { Utils.dbg("DBG Settings: apply -> save debugLogs failed", e) }

                    // Save the config (persistAndNotify calls save + appsModelUpdated)
                    try {
                        if (configObj && typeof configObj.persistAndNotify === "function") {
                            configObj.persistAndNotify()
                        } else {
                            if (configObj && typeof configObj.save === "function") configObj.save()
                            try { if (configObj && typeof configObj.appsModelUpdated === "function") configObj.appsModelUpdated() } catch(e) {}
                        }
                    } catch(e) { Utils.dbg("DBG Settings: post-apply persist failed", e) }

                    // Update the UI in main
                    Qt.callLater(function() {
                        try { if (root && typeof root.updateModels === "function") root.updateModels() } catch(e) {}
                        try { if (root && typeof root.reloadPopupGrid === "function") root.reloadPopupGrid() } catch(e) {}
                    })
                } catch(e) { Utils.dbg("DBG Settings: Apply top-level exception", e) }
            }
        }
    }

    Component.onCompleted: {
        try {
            // Initialize pending values ​​at startup
            loadPendingFromConfig()

            // Enable appsModelUpdated if not already enabled
            try {
                if (configObj && !this._appsModelConnected && typeof configObj.appsModelUpdated === "function") {
                    configObj.appsModelUpdated.connect(function() {
                        appsList.model = (configObj && configObj.appsModel) ? configObj.appsModel : []
                        Utils.dbg("DBG Settings: appsModelUpdated -> refreshed appsList.model; len=", (configObj && configObj.appsModel ? configObj.appsModel.length : 0))
                    })
                    this._appsModelConnected = true
                }
            } catch(e) { Utils.dbg("DBG Settings: onCompleted attach appsModelUpdated failed", e) }
        } catch(e) { Utils.dbg("DBG Settings: onCompleted failed", e) }
    }
}
