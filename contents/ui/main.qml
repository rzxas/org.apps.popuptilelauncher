import QtQuick 6
import QtQuick.Controls 6
import QtQuick.Layouts 1
import QtQuick.Window 2
import Qt.labs.platform
import org.kde.plasma.plasmoid
import org.apps.launcher 1
import "../config"

PlasmoidItem {
    id: root
    width: 48
    height: 48
    clip: false

    property var configObj: null
    property var openSystemPicker: null
    property bool dropdownVisible: false
    property bool examplesInjectedOnce: false

    property int lastClickX: -1
    property int lastClickY: -1
    property int lastClickScreenX: -1
    property int lastClickScreenY: -1
    property bool lastClickHasScreen: false

    property var probeX: undefined
    property var probeY: undefined

    property var lastOpenTs: 0
    property int openThrottleMs: 120

    property bool useListView: false
    property string _appsModelUpdatedConnectedFor: ""

    Component.onCompleted: Utils.dbg("DBG LOADED main.qml from: /home/../.../main.qml")

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onClicked: {
            Utils.dbg("DBG root MouseArea: click at", mouse.x, mouse.y, "global:", root.mapToItem(null, mouse.x, mouse.y))
            // try to display coordinates relative to the popupGrid, if it exists
            try {
                if (typeof popupGrid !== "undefined" && popupGrid) {
                    var p = popupGrid.mapFromItem(root, mouse.x, mouse.y)
                    Utils.dbg("DBG root MouseArea: mapped to popupGrid:", p.x, p.y)
                }
            } catch(e) { Utils.dbg("DBG root MouseArea: mapFromItem failed", e) }
        }
    }

    function launchRequested(app, index) {
        try {
            Utils.dbg("DBG launchRequested called; app=", JSON.stringify(app))
            try {
                if (typeof index === "number" && configObj && configObj.appsModel && index >= 0 && index < configObj.appsModel.length) {
                    var fresh = configObj.appsModel[index]
                    if (fresh) app = fresh
                }
            } catch(e) { /* not critical */ }

            var template = ""
            try {
                template = (app && app.execFullRaw) ? app.execFullRaw
                : (app && app.execFull) ? app.execFull
                : (app && app.exec) ? app.exec
                : ""
            } catch(e) { template = (app && app.exec) ? app.exec : "" }

            var cmd = ""
            try {
                if (configObj && typeof configObj.renderExec === "function") {
                    cmd = configObj.renderExec(template, "")
                } else {
                    cmd = template.replace(/\s+/g, " ").trim()
                }
            } catch(e) { cmd = template }

            Utils.dbg("DBG launch debug: template=", template)
            Utils.dbg("DBG launch debug: cmd=", cmd)
            Utils.dbg("DBG helper presence:", typeof HelperBridge, typeof HelperBridge.runCommand, typeof HelperBridge.runCommandInTerminal)

            var runInTerminal = (app && (app.runInTerminal === true || app.runInTerminal === "true")) ? true : false
            var workingDir = (app && app.workingDir) ? app.workingDir : ""

            // If there is a command, try launching via the helper (preferred)
            if (cmd && cmd.length) {
                if (runInTerminal) {
                    if (typeof HelperBridge !== "undefined" && HelperBridge && typeof HelperBridge.runCommandInTerminal === "function") {
                        HelperBridge.runCommandInTerminal(cmd, workingDir || "")
                        try { hideDropdownWindow(); } catch(e) {}
                        return
                    }
                } else {
                    if (typeof HelperBridge !== "undefined" && HelperBridge && typeof HelperBridge.runCommand === "function") {
                        HelperBridge.runCommand(cmd)
                        try { hideDropdownWindow(); } catch(e) {}
                        return
                    }
                }
            }
            // fallback runDesktop
            if (app && app.file && typeof HelperBridge !== "undefined" && HelperBridge && typeof HelperBridge.runDesktop === "function") {
                HelperBridge.runDesktop(app.file)
                try { hideDropdownWindow(); } catch(e) {}
                return
            }

            // If there is no command, but a .desktop file exists, try RunDesktop
            try {
                if (app && app.file && typeof HelperBridge !== "undefined" && HelperBridge && typeof HelperBridge.runDesktop === "function") {
                    HelperBridge.runDesktop(app.file)
                    return
                }
            } catch(e) { Utils.dbg("DBG launch: HelperBridge.runDesktop failed", e) }

            // Last fallback: open as URL/path
            try {
                if (cmd && cmd.length) {
                    if (cmd.indexOf("/") === 0 || cmd.indexOf("file://") === 0) {
                        Qt.openUrlExternally(cmd)
                        return
                    }
                }
                Utils.dbg("DBG launch: nothing executed; cmd empty or helper unavailable")
            } catch(e) { Utils.dbg("DBG launch: fallback Qt.openUrlExternally failed", e) }

        } catch(e) {
            Utils.dbg("DBG launchRequested exception", e)
        }
    }

    function updateModels() {
        try {
            var m = (configObj && configObj.appsModel) ? configObj.appsModel : [];
            // only update known lists to avoid "Unable to assign [undefined] to QObject*"
            if (typeof popupGrid !== "undefined" && popupGrid && typeof popupGrid.model !== "undefined") popupGrid.model = m;
            if (typeof listViewModel !== "undefined" && listViewModel && typeof listViewModel.model !== "undefined") listViewModel.model = m;
            Utils.dbg("DBG updateModels: applied model length=", (m ? m.length : 0));
        } catch(e) { Utils.dbg("DBG updateModels failed", e) }
    }

    function reloadPopupGrid() {
        try {
            if (typeof popupGrid !== "undefined" && popupGrid) {
                var old = popupGrid.model;
                popupGrid.model = [];
                Qt.callLater(function() {
                    Qt.callLater(function() {
                        try { popupGrid.model = old } catch(e) { Utils.dbg("DBG reloadPopupGrid: restore failed", e) }
                        try { updateModels() } catch(e) {}
                    })
                })
                return;
            }
            Qt.callLater(function() {
                try {
                    if (typeof popupGrid !== "undefined" && popupGrid) reloadPopupGrid()
                        else Utils.dbg("DBG reloadPopupGrid: popupGrid not found")
                } catch(e) { Utils.dbg("DBG reloadPopupGrid deferred failed", e) }
            })
        } catch(e) { Utils.dbg("DBG reloadPopupGrid exception", e) }
    }

    function breakAtChars(s, n) {
        try {
            if (!s || typeof s !== "string") return ""
            s = s.trim()
            if (s.length <= n) return s
            var part1 = s.substring(0, n)
            var rest = s.substring(n).trim()
            if (rest.length > n) {
                var part2 = rest.substring(0, n-1) + "…"
                return part1 + "\n" + part2
            }
            return part1 + "\n" + rest
        } catch(e) { return s }
    }

    function getScreenInfo() {
        try {
            if (overlayWindow && overlayWindow.screen) {
                return {
                    width: overlayWindow.screen.width || overlayWindow.width || 1280,
                    height: overlayWindow.screen.height || overlayWindow.height || 800,
                    dpr: (typeof overlayWindow.screen.devicePixelRatio === "number") ? overlayWindow.screen.devicePixelRatio : 1
                }
            }
            if (root.window && root.window.screen) {
                return {
                    width: root.window.screen.width || root.window.width || 1280,
                    height: root.window.screen.height || root.window.height || 800,
                    dpr: (typeof root.window.screen.devicePixelRatio === "number") ? root.window.screen.devicePixelRatio : 1
                }
            }
            if (typeof screen !== "undefined" && screen && screen.width && screen.height) {
                return { width: screen.width, height: screen.height, dpr: 1 }
            }
        } catch(e) {}
        return { width: 1280, height: 800, dpr: 1 }
    }

    Loader {
        id: configLoader
        source: Qt.resolvedUrl("../config/config.qml")
        asynchronous: true
        visible: false

        onLoaded: {
            Utils.dbg("DBG: configLoader.onLoaded; item:", configLoader.item ? "ok" : "null")
            if (!configLoader.item) return

            try {
                var ik = ""
                try {
                    if (plasmoid && plasmoid.containment && typeof plasmoid.containment.id !== "undefined" && typeof plasmoid.id !== "undefined") {
                        ik = "pinst-" + plasmoid.containment.id + "-" + plasmoid.id
                    }
                } catch(e) { ik = "" }

                if (!ik) {
                    try {
                        var cont = (plasmoid && plasmoid.containment && plasmoid.containment.geometry) ? plasmoid.containment.geometry : null
                        if (cont && typeof cont.x !== "undefined") ik = "pinst-" + (cont.x || 0) + "-" + (cont.y || 0) + "-" + Date.now()
                    } catch(e) { ik = "pinst-" + Date.now() }
                }

                if (configLoader.item) {
                    if (typeof configLoader.item.instanceKey !== "undefined") {
                        try { configLoader.item.instanceKey = ik } catch(e) { Utils.dbg("DBG: assign instanceKey failed", e) }
                    }
                    configObj = configLoader.item
                    try {
                        function tryAssignPopupGrid() {
                            try {
                                if (typeof popupGrid !== "undefined" && popupGrid) {
                                    try { popupGrid.configObj = configObj } catch(e) {}
                                    try { popupGrid.model = (configObj && configObj.appsModel) ? configObj.appsModel : [] } catch(e) {}

                                    try {
                                        Utils.dbg("DBG tryAssignPopupGrid: skipping dynamic connect; ensure TileGrid in main.qml has onLaunchRequested handler");
                                    } catch(e) { Utils.dbg("DBG tryAssignPopupGrid: connect failed", e) }

                                    try { if (typeof listViewModel !== "undefined" && listViewModel) listViewModel.configObj = configObj } catch(e) {}

                                    return true
                                }
                            } catch(e) { Utils.dbg("DBG tryAssignPopupGrid top error", e) }
                            return false
                        }

                        if (!tryAssignPopupGrid()) {
                            var __tries = 0
                            var __t = Qt.createQmlObject('import QtQuick 6; Timer { interval: 50; repeat: true }', root)
                            __t.triggered.connect(function() {
                                __tries++
                                if (tryAssignPopupGrid() || __tries > 40) {
                                    __t.stop()
                                    __t.destroy()
                                }
                            })
                            __t.start()
                        }
                    } catch(e) { Utils.dbg("DBG: deferred assign failed", e) }
                } else {
                    configObj = null
                }
                Utils.dbg("DBG: assigned instanceKey to configObj ->", ik)

                // subscribe to appsModelUpdated so UI refreshes immediately
                try {
                    var ikNow = (typeof configObj.instanceKey === "string" && configObj.instanceKey.length) ? configObj.instanceKey : ("inst-" + Date.now());
                    if (_appsModelUpdatedConnectedFor !== ikNow) {
                        if (configObj && typeof configObj.appsModelUpdated !== "undefined") {
                            // Diagnostic log: type appsModelUpdated
                            Utils.dbg("DBG: appsModelUpdated type:", typeof configObj.appsModelUpdated);

                            // If this is a signal (connection is available), we connect.
                            if (configObj.appsModelUpdated && typeof configObj.appsModelUpdated.connect === "function") {
                                configObj.appsModelUpdated.connect(function() {
                                    try {
                                        Utils.dbg("DBG: configObj.appsModelUpdated handler ENTER; popupGrid exists:", typeof popupGrid !== "undefined" && popupGrid, "appsList exists:", typeof appsList !== "undefined" && appsList);
                                        // Securely assign models
                                        var m = (configObj && configObj.appsModel) ? configObj.appsModel : [];
                                        if (typeof popupGrid !== "undefined" && popupGrid && typeof popupGrid.model !== "undefined") {
                                            popupGrid.model = m;
                                        } else {
                                            Utils.dbg("DBG: popupGrid not ready when appsModelUpdated fired");
                                        }
                                        if (typeof appsList !== "undefined" && appsList && typeof appsList.model !== "undefined") {
                                            appsList.model = m;
                                        } else {
                                            Utils.dbg("DBG: appsList not ready when appsModelUpdated fired");
                                        }
                                        // Force a popup reload, if necessary
                                        try { if (typeof root.reloadPopupGrid === "function") root.reloadPopupGrid(); } catch(e) { Utils.dbg("DBG: reloadPopupGrid call failed", e) }
                                        Utils.dbg("DBG: configObj.appsModelUpdated handler EXIT; applied model length=", (m ? m.length : 0));
                                    } catch(e) { Utils.dbg("DBG: appsModelUpdated handler failed", e); }
                                });
                                _appsModelUpdatedConnectedFor = ikNow;
                                Utils.dbg("DBG: connected appsModelUpdated for", ikNow);
                            } else {
                                // If connect is unavailable, it might be a normal function; log it
                                Utils.dbg("DBG: appsModelUpdated has no connect() — it may be a function; will rely on explicit calls");
                            }
                        }
                    } else {
                        Utils.dbg("DBG: appsModelUpdated already connected for", ikNow);
                    }
                } catch(e) { Utils.dbg("DBG: attach appsModelUpdated snippet failed", e); }

                Utils.dbg("DBG runtime: configObj.addAppFromDesktop exists:", !!configObj && typeof configObj.addAppFromDesktop === "function")
            } catch(e) {
                Utils.dbg("DBG: configLoader onLoaded top-level error", e)
                configObj = configLoader.item || null
            }

            try {
                root.useListView = !!(configObj && configObj.displayAsList)
                if (configObj && typeof configObj.displayAsListChanged !== "undefined" && typeof configObj.displayAsListChanged.connect === "function") {
                    configObj.displayAsListChanged.connect(function() {
                        try {
                            var v = !!configObj.displayAsList;
                            Utils.dbg("DBG: configObj.displayAsList changed ->", v);
                            root.useListView = v;
                            Qt.callLater(function(){ try{ updateModels() }catch(e){} });
                        } catch(e) { Utils.dbg("DBG: displayAsList handler failed", e) }
                    });
                }
            } catch(e) { Utils.dbg("DBG: attach displayAsList handler failed", e) }

            if (configObj && !configObj.appsModel) configObj.appsModel = []
            updateModels()
            try { tryInjectExamples() } catch(e) { Utils.dbg("DBG: tryInjectExamples failed", e) }
        }

        onStatusChanged: {
            if (status === Loader.Error) {
                Utils.dbg("DBG: config Loader error; status=", configLoader.status, "source=", configLoader.source, "errorString=", configLoader.item ? configLoader.item : "<no-item>")
                var retries = 0
                var rt = Qt.createQmlObject('import QtQuick 6; Timer { interval: 200; repeat: true }', root)
                rt.triggered.connect(function() {
                    retries++
                    Utils.dbg("DBG: configLoader retry attempt", retries)
                    if (configLoader.status !== Loader.Error) {
                        rt.stop(); rt.destroy()
                        Utils.dbg("DBG: configLoader recovered, status=", configLoader.status)
                        configObj = configLoader.item || configObj
                        updateModels()
                        return
                    }
                    if (retries >= 6) {
                        rt.stop(); rt.destroy()
                        Utils.dbg("DBG: configLoader final fallback after retries")
                        if (!configObj || !configObj.addAppFromDesktop) {
                            configObj = {
                                columns: 4, rows: 3, tileSize: 72, spacing: 8, bgOpacity: 0.6,
                                appsModel: [],
                                save: function(){ Utils.dbg("DBG: fallback save") },
                                addAppFromDesktop: function(path, contents){ Utils.dbg("DBG: fallback addAppFromDesktop called", path) },
                                removeApp: function(i){ try { this.appsModel.splice(i,1); this.save(); } catch(e){ Utils.dbg("DBG fallback remove fail", e) } }
                            }
                            updateModels()
                        }
                    } else {
                        try { configLoader.source = configLoader.source } catch(e) { Utils.dbg("DBG: reload attempt failed", e) }
                    }
                })
                rt.start()
            }
        }
    }

    Component { id: editDialogComp; EditDialog { id: editDialogInstance } }
    Loader {
        id: editDialogLoader
        sourceComponent: editDialogComp
        asynchronous: true
        onLoaded: {
            if (!editDialogLoader.item) return
            function tryAssignEdit() {
                try {
                    if (configObj) {
                        try {
                            editDialogLoader.item.configObj = configObj
                            try {
                                if (editDialogLoader.item && typeof editDialogLoader.item.requestReloadPopup !== "undefined") {
                                    // Disconnect old connections, if necessary (protection)
                                    try { editDialogLoader.item.requestReloadPopup.disconnect(); } catch(e) {}
                                    editDialogLoader.item.requestReloadPopup.connect(function() {
                                        try { root.reloadPopupGrid(); } catch(e) { Utils.dbg("DBG main: requestReloadPopup handler failed", e); }
                                    })
                                    Utils.dbg("DBG main: connected requestReloadPopup")
                                }
                            } catch(e) { Utils.dbg("DBG main: connect requestReloadPopup failed", e) }
                            try { if (typeof editDialogLoader.item.updateModels === "function") editDialogLoader.item.updateModels() } catch(e){}
                            // ensure EditDialog also refreshes when configObj emits appsModelUpdated
                            try {
                                if (configObj && typeof configObj.appsModelUpdated !== "undefined" && configObj.appsModelUpdated && typeof configObj.appsModelUpdated.connect === "function") {
                                    configObj.appsModelUpdated.connect(function() {
                                        try { if (typeof editDialogLoader.item.updateModels === "function") editDialogLoader.item.updateModels() } catch(e) { Utils.dbg("DBG editDialog: appsModelUpdated handler failed", e) }
                                    })
                                }
                            } catch(e) { Utils.dbg("DBG editDialog: attach appsModelUpdated failed", e) }
                        } catch(e) { Utils.dbg("DBG editDialogLoader: assign configObj failed", e) }
                        return true
                    }
                    return false
                } catch(e) { return false }
            }
            if (!tryAssignEdit()) {
                var tries = 0
                var ti = Qt.createQmlObject('import QtQuick 6; Timer { interval: 50; repeat: true }', root)
                ti.triggered.connect(function() {
                    tries++
                    if (tryAssignEdit() || tries > 40) {
                        ti.stop()
                        ti.destroy()
                        if (!configObj) Utils.dbg("DBG editDialogLoader: deferred assign gave up (no configObj after tries)")
                    }
                })
                ti.start()
            }
        }
    }

    DesktopPicker { id: desktopPicker
        onDesktopChosen: function(path, contents) {
            try {
                Utils.dbg("DBG main: DesktopPicker.onDesktopChosen ENTER; path=", path, "contents-len=", (contents?contents.length:0))

                if (!configObj) {
                    var __tries = 0
                    var __t = Qt.createQmlObject('import QtQuick 6; Timer { interval: 50; repeat: true }', root)
                    __t.triggered.connect(function() {
                        __tries++
                        if (configObj) {
                            try { __t.stop(); __t.destroy() } catch(e) {}
                            try { desktopPicker.onDesktopChosen(path, contents) } catch(e) { Utils.dbg("DBG DesktopPicker: deferred re-call failed", e) }
                            return
                        }
                        if (__tries > 40) {
                            try { __t.stop(); __t.destroy() } catch(e) {}
                            try { desktopPicker.tryLocalAdd(contents || "") } catch(e) { Utils.dbg("DBG DesktopPicker: give-up fallback failed", e) }
                        }
                    })
                    __t.start()
                    return
                }

                var absPath = path
                if (typeof absPath === "string" && absPath.indexOf("file://") === 0) absPath = absPath.substring(7)

                function finishWith(text) {
                    try {
                        Utils.dbg("DBG main: finishWith immediate; contents-len", (text ? text.length : 0));
                        if (configObj && typeof configObj.addAppFromDesktop === "function") {
                            configObj.addAppFromDesktop(absPath, text);
                        } else {
                            tryLocalAdd(text);
                        }
                        try { if (configObj && typeof configObj.save === "function") configObj.save() } catch(e) { Utils.dbg("DBG main: save() threw", e) }
                        try { if (typeof appsList !== "undefined" && appsList) appsList.model = configObj.appsModel } catch(e) {}
                        try { if (typeof popupGrid !== "undefined" && popupGrid) popupGrid.model = configObj.appsModel } catch(e) {}
                    } catch(e) { Utils.dbg("DBG main: finishWith exception", e) }
                }

                function tryFileXhr() {
                    Utils.dbg("DBG main: tryFileXhr ENTER; absPath=", absPath)
                    try {
                        var url = (typeof path === "string" && path.indexOf("file://") === 0) ? path : ("file://" + absPath)
                        var xr = new XMLHttpRequest()
                        var handled = false

                        xr.open("GET", url)
                        xr.onreadystatechange = function() {
                            if (xr.readyState === XMLHttpRequest.DONE) {
                                Utils.dbg("DBG main: file XHR status=", xr.status, "len=", (xr.responseText ? xr.responseText.length : 0))
                                handled = true
                                if (xr.status === 200 || xr.status === 0) finishWith(xr.responseText)
                                else finishWith("")
                            }
                        }
                        xr.onerror = function(e) {
                            Utils.dbg("DBG main: file XHR error", e)
                            handled = true
                            finishWith("")
                        }

                        // Timeout fallback: if XHR hasn't completed within 400 ms, synthesize a record
                        var to = Qt.createQmlObject('import QtQuick 6; Timer { interval: 400; repeat: false }', root)
                        to.triggered.connect(function() {
                            if (!handled) {
                                try { xr.abort() } catch(e) {}
                                Utils.dbg("DBG main: file XHR timed out, calling finishWith fallback")
                                finishWith("")
                            }
                            try { to.destroy() } catch(e) {}
                        })
                        to.start()

                        try { xr.send() } catch(e) {
                            Utils.dbg("DBG main: file XHR send threw", e)
                            try { to.stop(); to.destroy() } catch(e) {}
                            finishWith("")
                        }
                    } catch(e) {
                        Utils.dbg("DBG main: file XHR threw", e)
                        finishWith("")
                    }
                }

                // decision point: if we already have contents, use them; else if local path, call tryFileXhr
                if (contents && contents.length) { finishWith(contents); return }

                if (typeof absPath === "string" && absPath.length > 0 && absPath.indexOf("/") === 0) {
                    Utils.dbg("DBG main: local path detected, calling tryFileXhr; absPath=", absPath)
                    tryFileXhr()
                    return
                }

                // fallback for other paths (keep the existing generic XHR)
                try {
                    var url = (typeof path === "string" && path.indexOf("file://") === 0) ? path : ("file://" + absPath)
                    var xr = new XMLHttpRequest()
                    xr.open("GET", url)
                    xr.onreadystatechange = function() {
                        if (xr.readyState === XMLHttpRequest.DONE) {
                            if (xr.status === 200 || xr.status === 0) finishWith(xr.responseText)
                            else finishWith("")
                        }
                    }
                    xr.onerror = function(e) { finishWith("") }
                    xr.send()
                } catch(e) {
                    try { finishWith("") } catch(e2) { Utils.dbg("DBG DesktopPicker: XHR fallback failed", e2) }
                }
            } catch(e) { Utils.dbg("DBG main: DesktopPicker.onDesktopChosen top exception", e) }
        }

        function tryLocalAdd(text) {
            try {
                function parseDesktop(text) {
                    var out={name:"",exec:"",icon:"",nodisplay:false}
                    if (!text) return out
                    var lines = text.split(/\r?\n/); var inDesktop=false
                    for (var i=0;i<lines.length;i++) {
                        var l = lines[i].trim()
                        if (l === "[Desktop Entry]") { inDesktop=true; continue }
                        if (!inDesktop) continue;
                        if (l==="" || l[0]==="#") continue
                        var idx = l.indexOf("="); if (idx===-1) continue
                        var k = l.substring(0,idx).trim(); var v = l.substring(idx+1).trim()
                        if (k==="Name" && !out.name) out.name = v
                        else if (k==="Exec" && !out.exec) out.exec = v.split(/\s+/)[0]
                        else if (k==="Icon" && !out.icon) out.icon = v
                        else if (k==="NoDisplay" && (v==="true"||v==="1")) out.nodisplay = true
                    }
                    return out
                }
                var parsed = parseDesktop(text)
                if (parsed.nodisplay) { Utils.dbg("DBG DesktopPicker: local add NoDisplay, skipping"); return }
                if (!configObj) configObj = { appsModel: [], save: function(){ Utils.dbg("DBG: ephemeral save") } }
                if (!configObj.appsModel) configObj.appsModel = []
                var theAbs = (typeof path === "string" && path.indexOf("file://") === 0) ? path.substring(7) : (typeof path === "string" ? path : "")
                for (var k=0;k<configObj.appsModel.length;k++) {
                    try { if (configObj.appsModel[k].file === theAbs || configObj.appsModel[k].exec === parsed.exec) { Utils.dbg("DBG DesktopPicker: already exists, skip"); return } } catch(e){}
                }
                configObj.appsModel.push({
                    file: theAbs || absPath,
                    name: parsed.name || parsed.exec || absPath,
                    execRaw: parsed.exec || "",
                    execFull: parsed.exec || "",
                    exec: parsed.exec || parsed.name || absPath,
                    icon: parsed.icon || "",
                    runInTerminal: false,
                    workingDir: ""
                })
                if (configObj.save) configObj.save()
                updateModels()
                Utils.dbg("DBG DesktopPicker: local add pushed; len=", configObj.appsModel.length)
            } catch(e) { Utils.dbg("DBG DesktopPicker: tryLocalAdd exception", e) }
        }

        Component.onCompleted: {
            try {
                // expose helper on root so Settings can call it reliably
                root.openSystemPicker = function() {
                    try {
                        if (desktopPicker && typeof desktopPicker.open === "function") {
                            Utils.dbg("DBG main: root.openSystemPicker -> opening main desktopPicker")
                            desktopPicker.open()
                        } else {
                            Utils.dbg("DBG main: root.openSystemPicker -> desktopPicker not available")
                        }
                    } catch(e) { Utils.dbg("DBG main: root.openSystemPicker threw", e) }
                }
                Utils.dbg("DBG main: root.openSystemPicker assigned")

                // NEW: ensure we receive the desktopChosen signal and forward it to our handler
                try {
                    if (desktopPicker && typeof desktopPicker.desktopChosen !== "undefined" && desktopPicker.desktopChosen && typeof desktopPicker.desktopChosen.connect === "function") {
                        desktopPicker.desktopChosen.connect(function(path, contents) {
                            try {
                                Utils.dbg("DBG main: desktopPicker.desktopChosen signal received; path=", path, "contents-len=", (contents?contents.length:0))
                            } catch(e) { Utils.dbg("DBG main: desktopChosen handler wrapper threw", e) }
                        })
                        Utils.dbg("DBG main: connected to desktopPicker.desktopChosen signal")
                    } else {
                        Utils.dbg("DBG main: desktopPicker.desktopChosen signal not available to connect")
                    }
                } catch(e) { Utils.dbg("DBG main: connect to desktopChosen threw", e) }

            } catch(e) { Utils.dbg("DBG main: assign root.openSystemPicker failed", e) }

            Qt.callLater(function() {
                try {
                    if (root && root.window) {
                        rootWindowConn.target = root.window
                        rootWindowConn.enabled = true
                        if (overlayWindow) {
                            overlayWindow.width = root.window.width
                            overlayWindow.height = root.window.height
                        }
                    } else {
                        // try again a little later if the window appears later
                        Qt.callLater(function() {
                            if (root && root.window) {
                                rootWindowConn.target = root.window
                                rootWindowConn.enabled = true
                            }
                        })
                    }
                    // other deferred initializations
                } catch(e) {
                    Utils.dbg("DBG main: deferred init failed", e)
                }
                try {
                    if (popupGrid && configObj) popupGrid.configObj = configObj
                } catch(e) { Utils.dbg("DBG main: assign popupGrid.configObj failed", e) }
            })
        }
    }

    function dbg(msg) { try { Utils.dbg("DBG:", msg) } catch(e) {} }

    function computeGlobalPos() {
        try {
            if (plasmoid && plasmoid.containment && plasmoid.containment.geometry
                && typeof plasmoid.containment.geometry.x === "number"
                && typeof plasmoid.containment.geometry.y === "number") {
                var c = plasmoid.containment.geometry;
                var localX = (typeof root.x === "number") ? root.x : 0;
                var localY = (typeof root.y === "number") ? root.y : 0;
                return { x: Math.floor(c.x + localX), y: Math.floor(c.y + localY) };
            }
        } catch(e) {}

        try {
            if (plasmoid && plasmoid.geometry && typeof plasmoid.geometry.x === "number") {
                return { x: Math.floor(plasmoid.geometry.x), y: Math.floor(plasmoid.geometry.y) };
            }
        } catch(e) {}

        try {
            var p = root.mapToItem(null, root.width/2, root.height/2);
            if (p && !isNaN(p.x) && !isNaN(p.y)) {
                return { x: Math.floor(p.x), y: Math.floor(p.y) };
            }
        } catch(e) {}

        var scrInfo = getScreenInfo()
        var sx = scrInfo.width || 1280
        var sy = scrInfo.height || 800
        return { x: Math.floor(sx / 2), y: Math.floor(sy / 2) };
    }

    function updateProbeFromLastClick() {
        try {
            if (typeof lastClickX !== "number" || typeof lastClickY !== "number" || lastClickX < 0 || lastClickY < 0) {
                probeX = undefined; probeY = undefined
                Utils.dbg("DBG probe not set: no lastClick")
                return
            }
            var pr = root.mapToItem(null, lastClickX, lastClickY)
            if (pr && !isNaN(pr.x) && !isNaN(pr.y)) {
                probeX = Math.floor(pr.x)
                probeY = Math.floor(pr.y)
                Utils.dbg("DBG probe set", probeX, probeY)
            } else {
                probeX = undefined; probeY = undefined
                Utils.dbg("DBG probe not available")
            }
        } catch(e) {
            probeX = undefined; probeY = undefined
            Utils.dbg("DBG probe mapToItem failed", e)
        }
    }

    function computePopupPosition(preferredX, preferredY, popupW, popupH, mappedCenter) {
        var scrInfo = getScreenInfo()
        var screenW = scrInfo.width || 1280
        var screenH = scrInfo.height || 800

        var gx = Math.floor(preferredX - popupW/2)
        gx = Math.max(8, Math.min(screenW - popupW - 8, gx))

        var panelH = 0
        try {
            if (plasmoid && plasmoid.containment && plasmoid.containment.geometry && typeof plasmoid.containment.geometry.height === "number")
                panelH = Math.floor(plasmoid.containment.geometry.height)
            else panelH = 0
        } catch(e){ panelH = 0 }

        var mappedGlobalY = undefined
        try {
            if (typeof preferredY === "number" && preferredY >= 0 && preferredY <= screenH) {
                mappedGlobalY = preferredY
            } else {
                var winOffsetY = 0
                if (typeof overlayWindow !== "undefined" && typeof overlayWindow.y === "number") winOffsetY = overlayWindow.y
                else if (root.window && typeof root.window.y === "number") winOffsetY = root.window.y
                mappedGlobalY = (mappedCenter && typeof mappedCenter.y === "number") ? (mappedCenter.y + winOffsetY) : undefined
            }
        } catch(e) {
            mappedGlobalY = (mappedCenter && typeof mappedCenter.y === "number") ? mappedCenter.y : undefined
        }

        if ((typeof mappedGlobalY !== "number" || mappedGlobalY <= 0) && lastClickHasScreen && lastClickScreenY >= 0) {
            mappedGlobalY = lastClickScreenY
        }

        var likelyPanel = null
        var loc = (plasmoid && typeof plasmoid.location !== "undefined") ? plasmoid.location : null
        try {
            if (loc === 4) {
                likelyPanel = "bottom"
            } else if (loc === 3) {
                likelyPanel = "top"
            } else {
                if (typeof mappedGlobalY === "number") {
                    if (mappedGlobalY > Math.floor(screenH * 0.66)) likelyPanel = "bottom"
                    else if (mappedGlobalY < Math.floor(screenH * 0.33)) likelyPanel = "top"
                    else likelyPanel = "center"
                } else {
                    likelyPanel = null
                }
            }
        } catch(e) { likelyPanel = null }

        var nudge = 18
        var finalYCandidate

        if (likelyPanel === "bottom") {
            var panelComp = 8
            var cand = Math.floor(preferredY - popupH - nudge - panelComp)
            if (cand < 8) cand = Math.max(8, Math.floor(preferredY + nudge))
            finalYCandidate = cand
        } else if (likelyPanel === "top") {
            var cand2 = Math.floor(preferredY + nudge)
            if (cand2 + popupH > screenH - 8) cand2 = Math.max(8, screenH - popupH - 8)
            finalYCandidate = cand2
        } else {
            var below = Math.floor(preferredY + nudge)
            finalYCandidate = (below + popupH <= screenH - 8) ? below : Math.max(8, Math.floor(preferredY - popupH - nudge))
        }

        var finalX = gx
        var finalY = finalYCandidate
        try {
            if (overlayWindow && typeof overlayWindow.x === "number" && typeof overlayWindow.y === "number") {
                finalX = overlayWindow.x + gx
                finalY = overlayWindow.y + finalYCandidate
            } else if (root.window && typeof root.window.x === "number" && typeof root.window.y === "number") {
                finalX = root.window.x + gx
                finalY = root.window.y + finalYCandidate
            }
        } catch(e){}

        finalX = Math.max(0, Math.min(finalX, screenW - 1))
        finalY = Math.max(0, Math.min(finalY, screenH - 1))

        return { x: finalX, y: finalY, relX: gx, relY: finalYCandidate, panelH: panelH, likelyPanel: likelyPanel }
    }

    function showDropdownWindow() {
        try {
            var now = Date.now()
            if (typeof lastOpenTs === "number" && typeof openThrottleMs === "number" && now - lastOpenTs < openThrottleMs) {
                return
            }
            lastOpenTs = now
        } catch(e) {}

        try { if (localSettings && localSettings.visible) localSettings.visible = false } catch(e) {}
        try {
            if (root && root.window) {
                try { overlayWindow.width = root.window.width } catch(e) {}
                try { overlayWindow.height = root.window.height } catch(e) {}
                try { overlayWindow.x = root.window.x } catch(e) {}
                try { overlayWindow.y = root.window.y } catch(e) {}
            }
        } catch(e) {}
        try { overlayWindow.visible = false } catch(e) {}

        try { updateModels(); } catch(e) { Utils.dbg("DBG: updateModels() failed", e) }

        Utils.dbg("DBG debug: list model len:", (configObj && configObj.appsModel) ? configObj.appsModel.length : "<no-model>");
        Utils.dbg("DBG debug: useListView:", root.useListView);

        try { root.useListView = !!(configObj && configObj.displayAsList) } catch(e) {}

        try { Qt.callLater(function(){ try{ updateModels() }catch(e){Utils.dbg("DBG updateModels deferred failed",e)} }) } catch(e){}

        var base = computeGlobalPos()
        try { updateProbeFromLastClick() } catch(e) {}

        var mappedCenter = undefined
        try { mappedCenter = root.mapToItem(null, root.width/2, root.height/2) } catch(e) {}
        if (!mappedCenter || isNaN(mappedCenter.x) || isNaN(mappedCenter.y)) {
            var scrInfo = getScreenInfo()
            mappedCenter = { x: (base && base.x) ? base.x + Math.floor(root.width/2) : ((scrInfo && scrInfo.width) ? Math.floor(scrInfo.width/2) : 640),
                             y: (base && base.y) ? base.y + Math.floor(root.height/2) : ((scrInfo && scrInfo.height) ? Math.floor(scrInfo.height/2) : 400) }
        }

        var popupW = (configObj ? configObj.popupWidth || 360 : 360)
        var popupH = (configObj ? configObj.popupHeight || 360 : 360)

        var absX = undefined, absY = undefined

        if (typeof probeX === "number" && typeof probeY === "number") {
            absX = probeX; absY = probeY
        } else if (lastClickHasScreen && lastClickScreenX >= 0 && lastClickScreenY >= 0) {
            absX = lastClickScreenX; absY = lastClickScreenY
        } else if (typeof lastClickX === "number" && typeof lastClickY === "number" && lastClickX >= 0 && lastClickY >= 0) {
            try {
                var mapped = root.mapToItem(null, lastClickX, lastClickY)
                if (mapped && !isNaN(mapped.x) && !isNaN(mapped.y)) { absX = Math.floor(mapped.x); absY = Math.floor(mapped.y) }
            } catch(e) {}
        }

        if (typeof absX !== "number" || typeof absY !== "number") {
            absX = mappedCenter.x
            absY = mappedCenter.y
        }

        try {
            var scrInfo = getScreenInfo()
            if (root.window) {
                overlayWindow.width = root.window.width
                overlayWindow.height = root.window.height
                overlayWindow.x = root.window.x || 0
                overlayWindow.y = root.window.y || 0
            } else if (plasmoid && plasmoid.containment && plasmoid.containment.geometry) {
                var c = plasmoid.containment.geometry
                overlayWindow.x = c.x || 0
                overlayWindow.y = c.y || 0
                overlayWindow.width = c.width || (scrInfo ? scrInfo.width : 1280)
                overlayWindow.height = c.height || (scrInfo ? scrInfo.height : 800)
            } else {
                overlayWindow.x = 0; overlayWindow.y = 0
                overlayWindow.width = scrInfo ? scrInfo.width : 1280
                overlayWindow.height = scrInfo ? scrInfo.height : 800
            }
            overlayWindow.visible = true
            overlayWindow.requestActivate()
        } catch(e) { Utils.dbg("DBG overlay setup failed", e) }

        try { updateModels() } catch(e) {}
        try {
            // do not assign popupGrid/listView.visible here other than via root.useListView binding
        } catch(e) {}

        var pos = computePopupPosition(absX, absY, popupW, popupH, mappedCenter)
        var finalGlobalX = pos.x
        var finalGlobalY = pos.y

        try {
            popupItem.width = popupW
            popupItem.height = popupH

            try {
                var globalX = pos.x
                var globalY = pos.y
                var scrInfo2 = getScreenInfo()
                var dpr = scrInfo2.dpr || 1
                var overlayX = overlayWindow.x || 0
                var overlayY = overlayWindow.y || 0
                var localTargetX = Math.floor((globalX - overlayX) / dpr)
                var localTargetY = Math.floor((globalY - overlayY) / dpr)

                if (pos.likelyPanel === "bottom") {
                    var panelH_local = (typeof pos.panelH === "number" && pos.panelH > 0) ? pos.panelH : 0
                    var ovY = overlayWindow.y || 0
                    var ovH = overlayWindow.height || (scrInfo2.height || 800)
                    var screenH = scrInfo2.height || 800

                    if (panelH_local > 0) {
                        var panelTopGlobal = ovY + ovH - panelH_local
                        var desiredGlobalY = Math.floor(panelTopGlobal - popupItem.height - 8)
                        desiredGlobalY = Math.max(8, Math.min(desiredGlobalY, screenH - popupItem.height - 8))
                        localTargetY = Math.floor((desiredGlobalY - overlayY) / dpr)
                    } else {
                        var desiredGlobalY_fb = Math.floor(screenH - popupItem.height - 8)
                        if (typeof absY === "number" && absY > popupItem.height && absY < screenH) {
                            var tryY = Math.floor(absY - popupItem.height - 12)
                            if (tryY > 8 && tryY < screenH - popupItem.height - 8) desiredGlobalY_fb = tryY
                        }
                        localTargetY = Math.floor((desiredGlobalY_fb - overlayY) / dpr)
                    }
                } else if (pos.likelyPanel === "top" && typeof absY === "number") {
                    var nudge2 = -11
                    var desiredGlobalY2 = Math.floor(absY + nudge2)
                    desiredGlobalY2 = Math.max(8, Math.min(desiredGlobalY2, (scrInfo2.height || 800) - popupItem.height - 8))
                    localTargetY = Math.floor((desiredGlobalY2 - overlayY) / dpr)
                }

                if (typeof absX === "number") {
                    var desiredGlobalX = Math.floor(absX - popupItem.width / 2)
                    desiredGlobalX = Math.max(8, Math.min(desiredGlobalX, (scrInfo2.width || 1280) - popupItem.width - 8))
                    localTargetX = Math.floor((desiredGlobalX - overlayX) / dpr)
                }

                var minX = 8, minY = 8
                var maxX = Math.max(minX, Math.floor(overlayWindow.width / dpr) - popupItem.width - 8)
                var maxY = Math.max(minY, Math.floor(overlayWindow.height / dpr) - popupItem.height - 8)
                popupItem.x = Math.max(minX, Math.min(maxX, localTargetX))
                popupItem.y = Math.max(minY, Math.min(maxY, localTargetY))

            } catch(e) {
                try {
                    var desiredLocalX = Math.floor((finalGlobalX - (overlayWindow.x||0)) / (getScreenInfo().dpr||1))
                    var desiredLocalY = Math.floor((finalGlobalY - (overlayWindow.y||0)) / (getScreenInfo().dpr||1))
                    var minX = 8, minY = 8
                    var maxX = Math.max(minX, Math.floor(overlayWindow.width / (getScreenInfo().dpr||1)) - popupItem.width - 8)
                    var maxY = Math.max(minY, Math.floor(overlayWindow.height / (getScreenInfo().dpr||1)) - popupItem.height - 8)
                    popupItem.x = Math.max(minX, Math.min(maxX, desiredLocalX))
                    popupItem.y = Math.max(minY, Math.min(maxY, desiredLocalY))
                } catch(e2) { Utils.dbg("DBG fallback placement failed", e2) }
            }
        } catch(e) { Utils.dbg("DBG assign popup geometry failed", e) }

        try {
            popupItem.visible = true
            popupItem.forceActiveFocus()
            dropdownVisible = true

            var reapply1 = Qt.createQmlObject('import QtQuick 6; Timer { interval: 80; repeat: false }', root)
            reapply1.triggered.connect(function() {
                try {
                    var scrInfo3 = getScreenInfo()
                    var dpr = scrInfo3.dpr || 1
                    var overlayX = overlayWindow.x || 0
                    var overlayY = overlayWindow.y || 0
                    var minX = 8, minY = 8
                    var maxX = Math.max(minX, Math.floor(overlayWindow.width / dpr) - popupItem.width - 8)
                    var maxY = Math.max(minY, Math.floor(overlayWindow.height / dpr) - popupItem.height - 8)
                    popupItem.x = Math.max(minX, Math.min(maxX, popupItem.x))
                    popupItem.y = Math.max(minY, Math.min(maxY, popupItem.y))
                    try { popupItem.forceActiveFocus() } catch(e){}
                    Utils.dbg("DBG re-applied popupItem position (1) after show", popupItem.x, popupItem.y)
                } catch(e) { Utils.dbg("DBG reposition after show failed (1)", e) }
                try { reapply1.destroy() } catch(e) {}
            })
            reapply1.start()

            var reapply2 = Qt.createQmlObject('import QtQuick 6; Timer { interval: 220; repeat: false }', root)
            reapply2.triggered.connect(function() {
                try {
                    var scrInfo4 = getScreenInfo()
                    var dpr = scrInfo4.dpr || 1
                    var overlayX = overlayWindow.x || 0
                    var overlayY = overlayWindow.y || 0
                    var minX = 8, minY = 8
                    var maxX = Math.max(minX, Math.floor(overlayWindow.width / dpr) - popupItem.width - 8)
                    var maxY = Math.max(minY, Math.floor(overlayWindow.height / dpr) - popupItem.height - 8)
                    popupItem.x = Math.max(minX, Math.min(maxX, popupItem.x))
                    popupItem.y = Math.max(minY, Math.min(maxY, popupItem.y))
                    Utils.dbg("DBG re-applied popupItem position (2) after show", popupItem.x, popupItem.y)
                } catch(e) { Utils.dbg("DBG reposition after show failed (2)", e) }
                try { reapply2.destroy() } catch(e) {}
            })
            reapply2.start()
        } catch(e) {
            Utils.dbg("DBG show/reapply failed", e)
        }

        Utils.dbg("DBG showDropdown: scheduled final placement finalGlobalX,finalGlobalY =", finalGlobalX, finalGlobalY, "popupW/H=", popupW, popupH, "preferred=", absX, absY)
    }

    function hideDropdownWindow() {
        try { popupItem.visible = false } catch(e) {}
        try { overlayWindow.visible = false } catch(e) {}
        dropdownVisible = false
    }

    Rectangle {
        id: compactButton
        anchors.fill: parent
        color: "transparent"
        radius: 6

        Image {
            id: widgetIconImage
            anchors.centerIn: parent
            // width: 28; height: 28
            width: 48; height: 48
            source: (configObj && configObj.widgetIcon && configObj.widgetIcon.indexOf("/") !== -1) ? configObj.widgetIcon
                    : ((configObj && configObj.widgetIcon) ? ("image://theme/" + configObj.widgetIcon) : "")
            visible: source !== "" && source !== "null"
        }

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: function(event) {
                try {
                    lastClickX = event.x
                    lastClickY = event.y
                    if (event.hasOwnProperty("globalX") && event.hasOwnProperty("globalY")) {
                        lastClickScreenX = event.globalX
                        lastClickScreenY = event.globalY
                        lastClickHasScreen = true
                    } else {
                        lastClickScreenX = -1
                        lastClickScreenY = -1
                        lastClickHasScreen = false
                    }
                    updateProbeFromLastClick()
                } catch(e) { Utils.dbg("DBG compactMouse.onClicked error", e) }
                if (event.button === Qt.LeftButton) dropdownVisible = !dropdownVisible
            }

            onPressed: function(event) {
                if (event.button === Qt.RightButton) {
                    try { hideDropdownWindow(); } catch(e) {}
                    try { overlayWindow.visible = false } catch(e) {}
                    try { popupItem.visible = false } catch(e) {}
                    try { localSettings.visible = true; localSettings.requestActivate() } catch(e) { Utils.dbg("DBG: localSettings.open failed", e) }
                }
            }
        }
    }

    Window {
        id: overlayWindow
        visible: false
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        modality: Qt.NonModal
        color: "transparent"
        opacity: 0.0
        x: 0; y: 0

        Component.onCompleted: {
            var s = getScreenInfo()
            width = s.width || 1920
            height = s.height || 1080
        }

        MouseArea { anchors.fill: parent; onClicked: hideDropdownWindow(); hoverEnabled: false }

        Item {
            id: popupItem
            visible: false
            x: 0; y: 0
            width: 260; height: 260
            z: 1000

            Rectangle {
                anchors.fill: parent
                color: "#222"
                radius: 8
                border.color: "#444"
                border.width: 1
            }

            FocusScope { anchors.fill: parent; focus: true
                Item { width: parent.width; height: 6 }
                Item {
                    id: popupContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
                    anchors.margins: 6
                    y: 6

                    // Column {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            TileGrid {
                                id: popupGrid
                                anchors.fill: parent
                                model: (configObj && configObj.appsModel) ? configObj.appsModel : []
                                useListView: root.useListView
                                tileSize: (configObj && typeof configObj.tileSize === "number") ? configObj.tileSize : 72
                                spacing: (configObj && typeof configObj.spacing === "number") ? configObj.spacing : 8
                                columns: (configObj && typeof configObj.columns === "number") ? configObj.columns : 4
                                rows: (configObj && typeof configObj.rows === "number") ? configObj.rows : 3

                                onLaunchRequested: function(modelData, index) {
                                    try {
                                        root.launchRequested(modelData, index)
                                    } catch(e) {
                                        Utils.dbg("DBG main: forward launch failed", e)
                                    }
                                }
                                function onRemoveRequested(idx) {
                                    try { if (root && typeof root.removeRequested === "function") root.removeRequested(idx) } catch(e) { Utils.dbg("DBG main: forward remove failed", e) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        id: rootWindowConn
        target: null
        enabled: false

        function onWidthChanged() {
            if (overlayWindow && root && root.window) overlayWindow.width = root.window.width
        }
        function onHeightChanged() {
            if (overlayWindow && root && root.window) overlayWindow.height = root.window.height
        }
    }

    Window {
        id: localSettings
        visible: false
        flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        modality: Qt.NonModal
        width: 410
        height: 360

        Rectangle { anchors.fill: parent; color: "#2a2a2a"; radius: 8; border.color: "#444"; border.width: 1 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Loader {
                id: settingsLoader
                source: Qt.resolvedUrl("../ui/Settings.qml")
                asynchronous: true
                onLoaded: {
                    if (!settingsLoader.item) return
                    function tryAssign() {
                        try {
                            if (configObj) {
                                if (settingsLoader.item && configObj) {
                                    try { settingsLoader.item.configObj = configObj } catch(e) { Utils.dbg("DBG settingsLoader: assign configObj failed", e) }
                                }
                                try {
                                    if (settingsLoader.item && settingsLoader.item.hasOwnProperty("closeSettings")) {
                                        try {
                                            settingsLoader.item.closeSettings = function() { localSettings.visible = false }
                                        } catch(e) {}
                                    }
                                } catch(e) {}
                                return true
                            } else return false
                        } catch(e) { return false }
                    }
                    if (!tryAssign()) {
                        var tries = 0
                        var ti = Qt.createQmlObject('import QtQuick 6; Timer { interval: 50; repeat: true }', root)
                        ti.triggered.connect(function() {
                            tries++
                            if (tryAssign() || tries > 40) {
                                ti.stop()
                                ti.destroy()
                                if (!configObj) Utils.dbg("DBG settingsLoader: deferred assign gave up (no configObj after tries)")
                            }
                        })
                        ti.start()
                    }
                }
                onStatusChanged: {
                    if (status === Loader.Error) {
                        var fb = Qt.createQmlObject('import QtQuick 6; import QtQuick.Controls 6; Rectangle { color: "#2a2a2a"; anchors.fill: parent; Label { text: "Settings failed to load"; anchors.centerIn: parent; color: "#EEE" } }', localSettings)
                    }
                }
            }
        }

        onVisibleChanged: {
            if (visible) {
                try { localSettings.requestActivate() } catch(e) {}
                try { updateModels() } catch(e) {}
            }
        }
    }

    Window {
        id: manualDialog
        visible: false
        flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        modality: Qt.NonModal
        width: 380
        height: 220
        property string pickedIcon: ""

        Rectangle {
            anchors.fill: parent
            color: "#2a2a2a"
            radius: 6
            border.color: "#444"
            border.width: 1

            property string pickedIcon: ""

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        id: leftCol
                        Layout.preferredWidth: 320
                        spacing: 8

                        TextField { id: mName; placeholderText: "Name"; Layout.fillWidth: true }
                        TextField { id: mExec; placeholderText: "Exec command (full)"; Layout.fillWidth: true }
                        TextField {
                            id: mIcon
                            placeholderText: "Icon name or path"
                            Layout.fillWidth: true
                            onTextChanged: manualDialog.pickedIcon = text || ""
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 120
                            radius: 8
                            color: "transparent"
                            border.color: "#444"
                            border.width: 1
                            clip: true

                            ToolButton {
                                anchors.fill: parent
                                padding: 0
                                onClicked: {
                                    if (!iconPickerLoader.item) iconPickerLoader.active = true
                                        Qt.callLater(function(){ if (iconPickerLoader.item && typeof iconPickerLoader.item.open === "function") iconPickerLoader.item.open() })
                                }
                                contentItem: Item {
                                    anchors.fill: parent
                                    Image {
                                        id: manualIconPreview
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, 48)
                                        height: Math.min(parent.height, 48)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        source: (manualDialog.pickedIcon && manualDialog.pickedIcon.length)
                                        ? ((manualDialog.pickedIcon.indexOf("file://") === 0 || manualDialog.pickedIcon.indexOf("/") === 0)
                                        ? manualDialog.pickedIcon
                                        : ("image://theme/" + manualDialog.pickedIcon.toString().trim().replace(/\.(png|svg|xpm)$/i,"")))
                                        : ""
                                        visible: source !== "" && source !== "null"
                                    }
                                }
                            }
                        }
                    }
                } // RowLayout main

                RowLayout {
                    spacing: 8
                    CheckBox { id: mRunInTerminal; text: "Run in terminal"; checked: false }
                    Item { width: 4 }
                    TextField {
                        id: mWorkingDir
                        placeholderText: "Working directory (optional)"
                        Layout.fillWidth: true
                        text: ""
                    }
                }

                RowLayout { Layout.alignment: Qt.AlignRight; spacing: 8
                    Button { text: "Cancel"; onClicked: manualDialog.visible = false }
                    Button {
                        text: "Add"
                        onClicked: {
                            try {
                                var execFull = (mExec && mExec.text) ? mExec.text.trim() : ""
                                var execBase = ""
                                if (execFull.length) { var parts = execFull.split(/\s+/); execBase = parts.length ? parts[0] : execFull }
                                var iconVal = (manualDialog.pickedIcon && manualDialog.pickedIcon.length) ? manualDialog.pickedIcon : (mIcon && mIcon.text ? mIcon.text.trim() : "")
                                var workDirVal = (mWorkingDir && mWorkingDir.text) ? mWorkingDir.text.trim() : ""

                                // normalize icon value
                                var iconField = ""
                                var iconFilePathField = ""
                                if (iconVal && iconVal.length) {
                                    if (iconVal.indexOf("file://") === 0) {
                                        iconFilePathField = iconVal
                                    } else if (iconVal.indexOf("/") === 0) {
                                        // absolute path -> store as file://...
                                        iconFilePathField = "file://" + iconVal.replace(/^file:\/\//, "")
                                    } else {
                                        // theme name: strip extension if present
                                        iconField = iconVal.toString().trim().replace(/\.(png|svg|xpm)$/i,"")
                                    }
                                }

                                var toPush = {
                                    file: "",
                                    name: (mName && mName.text && mName.text.length) ? mName.text.trim() : (execBase || "Unnamed"),
                                    exec: execBase || execFull,
                                    execFullRaw: execFull,
                                    execFull: execFull,
                                    icon: iconField,
                                    iconFilePath: iconFilePathField,
                                    runInTerminal: !!(mRunInTerminal && mRunInTerminal.checked),
                                    workingDir: workDirVal
                                }

                                if (typeof configObj !== "undefined" && configObj && Array.isArray(configObj.appsModel)) {
                                    configObj.appsModel.push(toPush)
                                    try {
                                        if (typeof configObj.persistAndNotify === "function") configObj.persistAndNotify()
                                            else {
                                                if (typeof configObj.save === "function") configObj.save()
                                                    try { if (typeof configObj.appsModelUpdated === "function") configObj.appsModelUpdated() } catch(e) {}
                                            }
                                    } catch(e) { Utils.dbg("DBG manualDialog: persist failed", e) }
                                } else {
                                    Utils.dbg("DBG manualDialog: configObj/appsModel not available")
                                }

                                // clean and close
                                mName.text = ""; mExec.text = ""; mIcon.text = ""; mWorkingDir.text = ""; manualDialog.pickedIcon = ""; mRunInTerminal.checked = false
                                manualDialog.visible = false
                            } catch(e) { Utils.dbg("DBG manualDialog Add clicked exception", e) }
                        }
                    }
                }
            }

            // Local Loader for IconPicker
            Loader {
                id: iconPickerLoader
                source: Qt.resolvedUrl("IconPicker.qml")
                asynchronous: true
                visible: false
                onLoaded: {
                    try {
                        if (iconPickerLoader.item && typeof iconPickerLoader.item.accepted !== "undefined" && iconPickerLoader.item.accepted && typeof iconPickerLoader.item.accepted.connect === "function") {
                            iconPickerLoader.item.accepted.connect(function(v){ manualDialog.pickedIcon = v || ""; mIcon.text = manualDialog.pickedIcon })
                        }
                    } catch(e) { Utils.dbg("DBG manualDialog: iconPickerLoader connect failed", e) }
                }
            }
        }
    }

    Connections { target: root
        function onDropdownVisibleChanged() {
            if (dropdownVisible) showDropdownWindow(); else hideDropdownWindow();
        }
    }

    MouseArea {
        id: outsideClickCatcher
        anchors.fill: parent
        enabled: popupItem.visible || localSettings.visible || manualDialog.visible
        z: 1500; hoverEnabled: false

        onPressed: function(event) {
            var mx = event.x; var my = event.y;
            if (popupItem.visible) {
                var gx = overlayWindow.x + popupItem.x
                var gy = overlayWindow.y + popupItem.y
                var globalX = (root.mapToItem(null,0,0).x || 0) + event.x
                var globalY = (root.mapToItem(null,0,0).y || 0) + event.y
                var inPopup = globalX >= gx && globalX <= gx + popupItem.width
                    && globalY >= gy && globalY <= gy + popupItem.height
                if (!inPopup) hideDropdownWindow();
            }
            if (localSettings.visible) {
                var inSettings = mx >= localSettings.x && mx <= localSettings.x + localSettings.width
                    && my >= localSettings.y && my <= localSettings.y + localSettings.height;
                if (!inSettings) localSettings.visible = false;
            }
        }
        propagateComposedEvents: true
    }

    Timer {
        id: examplesInjectTimer
        interval: 100
        repeat: false
        onTriggered: { tryInjectExamples() }
    }

    function tryInjectExamples() {
        try {
            if (examplesInjectedOnce) return
            if (!configObj) { examplesInjectTimer.start(); return }
            if (configObj.appsModel && configObj.appsModel.length > 0) { examplesInjectedOnce = true; return }
            var base = Qt.resolvedUrl("../examples/")
            var exampleFiles = ["example-firefox.desktop", "example-terminal.desktop"]
            for (var i=0;i<exampleFiles.length;i++) {
                var url = base + exampleFiles[i]
                var abs = (typeof url === "string" && url.indexOf("file://")===0) ? decodeURIComponent(url.substring(7)) : url
                try {
                    if (configObj && typeof configObj.addAppFromDesktop === "function") {
                        configObj.addAppFromDesktop(abs, "")
                    }
                } catch(e) {}
            }
            examplesInjectedOnce = true
        } catch(e) {}
    }

    function runViaDbus(desktopPath) {
        try {
            var iface = Qt.createQmlObject('import QtDBus 6; QtObject {}', root)
            var conn = QDBusConnection.sessionBus
            var ifaceName = "org.apps.PlasmaHelper"
            var objPath = "/org/apps/PlasmaHelper"
            var msg = QDBusMessage.createMethodCall(ifaceName, objPath, "org.apps.PlasmaHelper", "RunDesktop")
            msg << desktopPath
            var reply = conn.call(msg)
            if (reply.type === QDBusMessage.ReplyMessage) {
                var ok = reply.arguments[0]
                return ok
            } else {
                return false
            }
        } catch(e) { return false }
    }

    function launchApp(appEntry) {
        try {
            if (!appEntry) return;
            var desktopPath = appEntry.file || appEntry.desktop || ""
            if (desktopPath && typeof desktopPath === "string" && desktopPath.toLowerCase().endsWith(".desktop")) {
                if (typeof Launcher !== "undefined" && Launcher && typeof Launcher.runDesktop === "function") {
                    try { Launcher.runDesktop(desktopPath); return } catch(e) { Utils.dbg("launchApp: Launcher.runDesktop threw", e) }
                }
                if (typeof HelperBridge !== "undefined" && HelperBridge && typeof HelperBridge.runDesktop === "function") {
                    try {
                        var ok = HelperBridge.runDesktop(desktopPath)
                        if (ok) return
                    } catch(e) { Utils.dbg("launchApp: HelperBridge.runDesktop threw", e) }
                }
                try {
                    if (runViaDbus(desktopPath)) return
                } catch(e) { Utils.dbg("launchApp: runViaDbus threw", e) }
                return
            }
            return
        } catch(e) { Utils.dbg("DBG launchApp exception:", e) }
    }
}
