import QtQuick 6
import QtCore 6
import org.apps.launcher 1
import "../config"

Item {
    id: configRoot
    width: 0; height: 0
    signal appsModelUpdated()

    property int widgetIconSize: 32
    property int columns: 4
    property int rows: 4
    property int tileSize: 52
    property int listIconSize: 22
    property int spacing: 6
    property real bgOpacity: 0.6
    property var appsModel: []

    property bool displayAsList: false
    property int popupWidth: 260
    property int popupHeight: 260
    property string widgetIcon: Qt.resolvedUrl("../icons/default-i.png")
    property bool _loadingInstanceConfig: false

    property string instanceKey: ""

    Settings {
        id: store
        property string instancesJson: "{}"
    }

    function computeInstanceKey() {
        try {
            if (instanceKey && instanceKey.length) return instanceKey
            try {
                if (typeof plasmoid !== "undefined" && plasmoid) {
                    var contId = (plasmoid.containment && typeof plasmoid.containment.id !== "undefined") ? plasmoid.containment.id : null
                    var appId = (typeof plasmoid.id !== "undefined") ? plasmoid.id : null
                    if (contId !== null && appId !== null) {
                        instanceKey = "pinst-" + contId + "-" + appId
                        return instanceKey
                    }
                }
            } catch(e) {}
            instanceKey = "pinst-ephemeral-" + Date.now()
            return instanceKey
        } catch(e) {
            instanceKey = "pinst-ephemeral-" + Date.now()
            return instanceKey
        }
    }

    function _loadAllInstances() {
        try {
            var raw = "{}"
            try { raw = _readInstanceRaw(computeInstanceKey()) || "{}" } catch(e) { raw = "{}" }
            Utils.dbg("DBG _loadAllInstances raw:", (raw ? raw.substr(0,200) : "<empty>"));
            var obj = {}
            try { obj = JSON.parse(raw || "{}") || {} } catch(e) { obj = {} }
            Utils.dbg("DBG _loadAllInstances: parsed-keys=", Object.keys(obj || {}).slice(0,20));
            if (!obj || typeof obj !== "object" || Array.isArray(obj)) obj = {}
            return obj
        } catch(e) { Utils.dbg("DBG _loadAllInstances exception", e); return {} }
    }

    function _saveAllInstances(obj) {
        try {
            var safe = {}
            try { safe = (obj && typeof obj === "object" && !Array.isArray(obj)) ? obj : {} } catch(e) { safe = {} }
            try {
                var keys = Object.keys(safe)
                Utils.dbg("DBG config._saveAllInstances: keys=", keys, "num=", keys.length, "json-snippet=", JSON.stringify(safe).substr(0,1024))
            } catch(e) { Utils.dbg("DBG config._saveAllInstances: keys-dump failed", e) }
            try {
                if (store) store.instancesJson = JSON.stringify(safe || {})
                else Utils.dbg("DBG config._saveAllInstances: no store available")
            } catch(e) { Utils.dbg("DBG config._saveAllInstances: write failed", e) }
        } catch(e) {
            Utils.dbg("DBG config: _saveAllInstances fatal", e)
        }
    }

    function _readInstanceRaw(ik) {
        try {
            if (!ik) ik = computeInstanceKey()
                // Prefer HelperBridge if available
                if (typeof HelperBridge !== "undefined" && HelperBridge && typeof HelperBridge.readInstanceFile === "function") {
                    try {
                        var r = HelperBridge.readInstanceFile(ik)
                        if (r && r.length) return r
                    } catch(e) { /* ignore and fallback */ }
                }
                // Fallback to old store
                try { return (store && typeof store.instancesJson === "string" && store.instancesJson.length) ? store.instancesJson : "{}" } catch(e) { return "{}" }
        } catch(e) { return "{}" }
        Utils.dbg("DBG _readInstanceRaw: ik=", ik, "HelperBridge=", (typeof HelperBridge !== "undefined"));
        Utils.dbg("DBG _readInstanceRaw: raw-len=", (r ? r.length : 0), "raw-snippet=", (r ? r.substr(0,512) : "<empty>"));
    }

    function _writeInstanceRaw(ik, jsonText) {
        try {
            if (!ik) ik = computeInstanceKey()
                if (typeof HelperBridge !== "undefined" && HelperBridge && typeof HelperBridge.writeInstanceFile === "function") {
                    try {
                        var ok = HelperBridge.writeInstanceFile(ik, jsonText)
                        if (ok) return true
                    } catch(e) { /* ignore and fallback */ }
                }
                // Fallback: write into store.instancesJson (legacy)
                try {
                    if (store) {
                        var parsed = {};
                        try { parsed = JSON.parse(jsonText || "{}"); } catch(e) { parsed = {}; }
                        var keys = Object.keys(parsed || {});
                        var hasPinst = keys.some(function(k){ return k.indexOf("pinst-") === 0; });
                        if (hasPinst) {
                            store.instancesJson = jsonText;
                        } else {
                            var map = {};
                            map[ik] = parsed;
                            store.instancesJson = JSON.stringify(map);
                        }
                        return true;
                    }
                } catch(e) { /* fallback false */ }
                return false
        } catch(e) { return false }
    }

    function getInstanceData() {
        try {
            var ik = computeInstanceKey()
            var all = _loadAllInstances()
            if (!all[ik]) all[ik] = {}
            return all[ik]
        } catch(e) { return {} }
    }

    // Get the key value for the current instance (or undefined)
    function getInstanceValue(key) {
        try {
            var ik = computeInstanceKey()
            var all = _loadAllInstances()
            if (!all || typeof all !== "object") return undefined

                var inst = all[ik] || {}
                if (typeof inst[key] !== "undefined") return inst[key]

                    // Legacy fallback: If the key is in the top-level (old format), return it
                    if (typeof all[key] !== "undefined") return all[key]

                        return undefined
        } catch(e) { Utils.dbg("DBG config.getInstanceValue threw", e); return undefined }
    }

    function setInstanceValue(key, value) {
        try {
            var ik = computeInstanceKey()
            var all = _loadAllInstances()
            if (!all || typeof all !== "object") all = {}
            if (!all[ik] || typeof all[ik] !== "object") all[ik] = {}

            // If the key exists at top-level (legacy), remove it from there to avoid duplication
            try {
                if (typeof all[key] !== "undefined") {
                    // move legacy top-level key into instance (unless instance already has it)
                    if (typeof all[ik][key] === "undefined") {
                        all[ik][key] = all[key]
                    }
                    delete all[key]
                }
            } catch(e) { /* ignore */ }

            // Write the value into the instance object
            all[ik][key] = value

            // Save all instances (legacy storage)
            try {
                // keep all map up-to-date (we already modified all[ik] above)
                var allJson = JSON.stringify(all || {});
                var wrotePerInstance = false;
                try {
                    // Try to write the full map via helper (helper may still accept per-instance file)
                    wrotePerInstance = _writeInstanceRaw(ik, allJson);
                } catch(e) { wrotePerInstance = false; Utils.dbg("DBG setInstanceValue: _writeInstanceRaw threw", e); }

                Utils.dbg("DBG config.setInstanceValue: wrote key=", key, "value=", value, "into ik=", ik, "wrotePerInstance=", wrotePerInstance);

                if (!wrotePerInstance) {
                    // fallback: ensure legacy store contains full map
                    try { _saveAllInstances(all); } catch(e) { Utils.dbg("DBG setInstanceValue: fallback _saveAllInstances failed", e); }
                } else {
                    // keep legacy store in sync (optional)
                    try { if (store) store.instancesJson = JSON.stringify(all); } catch(e) { Utils.dbg("DBG setInstanceValue: sync legacy store failed", e); }
                }
            } catch(e) {
                Utils.dbg("DBG setInstanceValue: write exception", e);
                try { _saveAllInstances(all); } catch(e) { Utils.dbg("DBG setInstanceValue: final fallback failed", e); }
            }

            // Update the current properties in memory (if it's a known key)
            try {
                if (key === "widgetIcon") {
                    widgetIcon = (typeof value === "string") ? value : ""
                } else if (key === "tileSize" && typeof value === "number") {
                    tileSize = value
                } else if (key === "widgetIconSize") {
                    try {
                        var n = (typeof value === "number") ? value : (parseInt(value) || 0);
                        if (n > 0) {
                            widgetIconSize = n;
                            // ensure stored value is numeric as well
                            all[ik][key] = n;
                        } else {
                            // if invalid, remove or keep existing
                            if (typeof all[ik][key] !== "undefined") {
                                // keep existing numeric value
                                var prev = parseInt(all[ik][key]) || widgetIconSize;
                                all[ik][key] = prev;
                                widgetIconSize = prev;
                            }
                        }
                    } catch(e) { Utils.dbg("DBG config.setInstanceValue widgetIconSize normalize failed", e) }
                } else if (key === "columns" || key === "rows") {
                    // Don't touch it here — loadInstanceConfig will pick it up on the next call
                }
            } catch(e) { Utils.dbg("DBG config.setInstanceValue update local prop failed", e) }

            // Notify the UI and save the snapshot (apps are already saved to all[ik].apps in saveInstanceConfig)
            try { appsModelUpdated() } catch(e) {}
            return true
        } catch(e) {
            Utils.dbg("DBG config.setInstanceValue exception", e)
            return false
        }
    }

    function loadInstanceConfig() {
        if (_loadingInstanceConfig) {
            Utils.dbg("DBG config: loadInstanceConfig skipped — already running")
            return
        }
        _loadingInstanceConfig = true
        try {
            var ik = computeInstanceKey()
            Utils.dbg("DBG config: loadInstanceConfig; instanceKey =", ik)

            // Try to read raw JSON via helper (per-instance) or fallback to store
            var raw = "{}"
            try { raw = _readInstanceRaw(ik) || "{}" } catch(e) { raw = "{}" }
            Utils.dbg("DBG loadInstanceConfig: _readInstanceRaw returned snippet:", (raw ? raw.substr(0,200) : "<empty>"))

            var all = {}
            try { all = JSON.parse(raw || "{}") || {} } catch(e) { all = {} }
            var topKeys = Object.keys(all || {});
            var hasPinstKeys = topKeys.some(function(k){ return k.indexOf("pinst-") === 0 });
            Utils.dbg("DBG loadInstanceConfig: ik=", ik, "topKeys=", topKeys, "hasPinstKeys=", hasPinstKeys);
            Utils.dbg("DBG loadInstanceConfig: all-snippet=", JSON.stringify(all).substr(0,1024));

            // If the JSON is a map that already contains instance keys (preferred)
            var inst = {}
            if (all && typeof all === "object") {
                if (all[ik] && typeof all[ik] === "object") {
                    inst = all[ik];
                } else if (Array.isArray(all.apps) || typeof all.apps !== "undefined") {
                    // Only migrate legacy top-level config if it looks like a single-instance dump
                    // (heuristic: no other pinst- keys present and object has only top-level fields)
                    var topKeys = Object.keys(all || {})
                    var hasPinstKeys = topKeys.some(function(k){ return k.indexOf("pinst-") === 0 })
                    if (!hasPinstKeys && topKeys.length <= 12) {
                        // treat as legacy single-instance config and migrate
                        inst = all
                        try {
                            if (_writeInstanceRaw(ik, JSON.stringify(inst))) {
                                Utils.dbg("DBG loadInstanceConfig: migrated legacy top-level config into per-instance for", ik)
                            } else {
                                Utils.dbg("DBG loadInstanceConfig: migration attempted but write failed; keeping legacy store")
                            }
                        } catch(e) { Utils.dbg("DBG loadInstanceConfig: migration exception", e) }
                    } else {
                        // Do not migrate: this looks like a global/template store — use defaults (empty inst)
                        inst = {}
                        Utils.dbg("DBG loadInstanceConfig: legacy top-level present but not migrated (using defaults) for", ik)
                    }
                } else {
                    // No instance data found
                    inst = {}
                }
            }

            // Populate appsModel from inst.apps if present
            var apps = []
            try { apps = Array.isArray(inst.apps) ? inst.apps : [] } catch(e) { apps = [] }
            appsModel.splice(0, appsModel.length)
            for (var i=0;i<apps.length;i++) appsModel.push(apps[i])

                // Load other instance properties (with safe defaults)
                try { columns = (typeof inst.columns === "number") ? inst.columns : columns } catch(e){}
                try { rows = (typeof inst.rows === "number") ? inst.rows : rows } catch(e){}
                try { tileSize = (typeof inst.tileSize === "number") ? inst.tileSize : tileSize } catch(e){}
                try { spacing = (typeof inst.spacing === "number") ? inst.spacing : spacing } catch(e){}
                try { bgOpacity = (typeof inst.bgOpacity === "number") ? inst.bgOpacity : bgOpacity } catch(e){}
                try { displayAsList = (typeof inst.displayAsList === "boolean") ? inst.displayAsList : displayAsList } catch(e){}
                try { popupWidth = (typeof inst.popupWidth === "number") ? inst.popupWidth : popupWidth } catch(e){}
                try { popupHeight = (typeof inst.popupHeight === "number") ? inst.popupHeight : popupHeight } catch(e){}
                try { widgetIcon = (typeof inst.widgetIcon === "string" && inst.widgetIcon.length) ? inst.widgetIcon : widgetIcon } catch(e){}
                try { widgetIconSize = (typeof inst.widgetIconSize === "number") ? inst.widgetIconSize : widgetIconSize } catch(e){}
                try { listIconSize = (typeof inst.listIconSize === "number") ? inst.listIconSize : listIconSize } catch(e){}

                Utils.dbg("DBG config: loaded appsModel length =", appsModel.length)
        } catch(e) {
            Utils.dbg("DBG config: loadInstanceConfig exception", e)
            appsModel.splice(0, appsModel.length)
        } finally {
            _loadingInstanceConfig = false
        }
    }

    function saveInstanceConfig() {
        try {
            var ik = computeInstanceKey();
            Utils.dbg("DBG config.saveInstanceConfig; instanceKey =", ik, "appsModel len=", (appsModel ? appsModel.length : "undefined"));

            // Load full map of instances (may be empty)
            var all = {};
            try {
                var loaded = _loadAllInstances();
                all = (loaded && typeof loaded === "object" && !Array.isArray(loaded)) ? loaded : {};
            } catch(e) {
                Utils.dbg("DBG config.saveInstanceConfig: _loadAllInstances threw, using empty all", e);
                all = {};
            }

            if (!all || typeof all !== "object") all = {};

            if (!ik || typeof ik !== "string") ik = computeInstanceKey();

            // Ensure target entry exists
            if (!all[ik] || typeof all[ik] !== "object") all[ik] = {};

            // Build snapshot of appsModel (safe copy)
            var snapshot = [];
            try {
                if (appsModel && typeof appsModel.length === "number") {
                    for (var i = 0; i < appsModel.length; i++) {
                        try { snapshot.push(appsModel[i]); } catch(e) {}
                    }
                }
            } catch(e) {
                try { snapshot = appsModel ? appsModel.slice(0) : []; } catch(e2) { snapshot = []; }
            }

            if ((!snapshot || snapshot.length === 0) && Array.isArray(existingInst.apps) && existingInst.apps.length > 0) {
                snapshot = existingInst.apps.slice(0);
            }
            // Merge existing instance with updated fields to avoid losing custom keys
            var existingInst = (all[ik] && typeof all[ik] === "object") ? all[ik] : {};
            var instToSave = Object.assign({}, existingInst, {
                apps: snapshot,
                columns: columns,
                rows: rows,
                tileSize: tileSize,
                spacing: spacing,
                bgOpacity: bgOpacity,
                displayAsList: displayAsList,
                popupWidth: popupWidth,
                popupHeight: popupHeight,
                widgetIcon: widgetIcon,
                widgetIconSize: widgetIconSize,
                listIconSize: listIconSize,
                debugLogs: (typeof existingInst.debugLogs !== "undefined") ? existingInst.debugLogs : !!(existingInst.debugLogs || false),
            });
            instToSave.debugLogs = !!(typeof Utils !== "undefined" ? Utils.debugLogs : instToSave.debugLogs);

            var instJson = JSON.stringify(instToSave || {});

            // Try per-instance write via helper; fallback to legacy full-map write
            var wrote = false;
            try {
                // wrote = _writeInstanceRaw(ik, instJson);
                all[ik] = instToSave;
                var allJson = JSON.stringify(all || {});
                var wrote = false;
                try { wrote = _writeInstanceRaw(ik, allJson); } catch(e) { wrote = false; Utils.dbg("DBG config.saveInstanceConfig: _writeInstanceRaw threw", e); }
                if (!wrote) {
                    _saveAllInstances(all);
                } else {
                    try { if (store) store.instancesJson = JSON.stringify(all); } catch(e) {}
                }
            } catch(e) {
                wrote = false;
                Utils.dbg("DBG config.saveInstanceConfig: _writeInstanceRaw threw", e);
            }

            if (!wrote) {
                // fallback: write full map into store.instancesJson (legacy)
                try {
                    Utils.dbg("DBG config.saveInstanceConfig: per-instance write failed, falling back to legacy store");
                    // keep all[ik] in sync with instToSave before saving full map
                    all[ik] = instToSave;
                    _saveAllInstances(all);
                } catch(e) {
                    Utils.dbg("DBG config.saveInstanceConfig: fallback _saveAllInstances threw", e);
                }
            } else {
                // per-instance write succeeded — keep optional legacy store in sync
                try {
                    // update in-memory map so future reads reflect the new instance
                    all[ik] = instToSave;
                    if (store) store.instancesJson = JSON.stringify(all);
                } catch(e) {
                    Utils.dbg("DBG config.saveInstanceConfig: sync legacy store failed after per-instance write", e);
                }
                Utils.dbg("DBG config.saveInstanceConfig: per-instance saved for", ik);
            }

            // Notify UI and schedule a no-op callLater to flush event loop if available
            try { appsModelUpdated(); } catch(e) { Utils.dbg("DBG config.saveInstanceConfig: appsModelUpdated emit failed", e); }
            try { if (typeof Qt !== "undefined" && Qt && typeof Qt.callLater === "function") Qt.callLater(function(){/*noop*/}); } catch(e) {}

        } catch(e) {
            Utils.dbg("DBG config.saveInstanceConfig exception", e);
        }
    }

    // helper: save and notify UI that appsModel changed
    function persistAndNotify() {
        try {
            saveInstanceConfig()
        } catch(e) { Utils.dbg("DBG config: persistAndNotify save threw", e) }
        try { appsModelUpdated() } catch(e) { Utils.dbg("DBG config: appsModelUpdated emit failed", e) }
    }

    function save() {
        saveInstanceConfig()
    }

    /*
     * parseDesktop:
     * - Returns an object { name, exec, execFull, icon, nodisplay }
     * - execFull: The original Exec string (without %u substitution, etc. — we don't replace it, we just save it)
     * - exec: The base command (the first token, without arguments)
     */
    function parseDesktop(text) {
        var out = { name: "", exec: "", execFull: "", icon: "", nodisplay: false }
        if (!text) return out
        var lines = text.split(/\r?\n/); var inDesktop = false
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (l === "[Desktop Entry]") { inDesktop = true; continue }
            if (!inDesktop) continue
            if (l === "" || l[0] === "#") continue
            var idx = l.indexOf("=")
            if (idx === -1) continue
            var k = l.substring(0, idx).trim()
            var v = l.substring(idx+1).trim()
            if (k === "Name" && !out.name) out.name = v
            else if (k === "Exec" && !out.execFull) {
                out.execFull = v
                out.execFullRaw = out.execFull || ""                     // Original
                out.execFull = normalizeExecForStorage(out.execFullRaw)  // Working version for storage
                if (!out.exec && out.execFull) {
                    var parts = out.execFull.split(/\s+/)
                    out.exec = parts.length ? parts[0] : out.execFull
                }
                // Base command — the first token before the space
                var parts = v.split(/\s+/)
                out.exec = parts.length ? parts[0] : v
            }
            else if (k === "Icon" && !out.icon) out.icon = v
            else if (k === "NoDisplay" && (v === "true" || v === "1")) out.nodisplay = true
        }
        return out
    }

    function normalizeExecForStorage(raw) {
        try {
            if (!raw || typeof raw !== "string") return ""
                return raw.replace(/\s+/g, " ").trim()
        } catch(e) { return raw || "" }
    }

    function normalizeExec(raw) {
        try { return normalizeExecForStorage(raw) } catch(e) { return (raw && raw.toString) ? raw.toString().replace(/\s+/g," ").trim() : "" }
    }

    function normalizeIconValue(raw) {
        try {
            if (!raw || typeof raw !== "string") return ""
                var s = raw.trim()
                if (s.indexOf("file://") === 0) return s
                    if (s.indexOf("/") === 0) return "file://" + s
                        // Theme: Remove extension
                        return s.replace(/\.(png|svg|xpm)$/i, "").trim()
        } catch(e) { return raw || "" }
    }

    // Renders the command to run: substitutes fileOrUrl in placeholders %f %F %u %U %n %N %k
    // If fileOrUrl is empty, removes placeholders but preserves the remaining arguments.
    function renderExec(template, fileOrUrl) {
        try {
            if (!template || typeof template !== "string") return ""
                var t = template

                var fileVal = (fileOrUrl && fileOrUrl.length) ? fileOrUrl : ""

                // Substitute file/URL placeholders
                t = t.replace(/%[fFuUnNkK]/g, function(m) { return fileVal })

                // Remove %i, %c, and other metadata that we don't substitute
                t = t.replace(/%[iIcC]/g, "")

                // Remove any remaining %X just in case
                t = t.replace(/%[a-zA-Z]/g, "")

                // Compress spaces and trim
                t = t.replace(/\s+/g, " ").trim()
                return t
        } catch(e) { return template || "" }
    }

    function addAppFromDesktop(path, contents) {
        try {
            Utils.dbg("DBG config.addAppFromDesktop start: instanceKey=", instanceKey, "computeInstanceKey=", computeInstanceKey(), "path=", path, "contents-len=", (contents?contents.length:0))

            if (!appsModel) appsModel = []

                var parsed = parseDesktop(contents || "")
                Utils.dbg("DBG config: parsed desktop ->", parsed)

                // If there is no execFull and we were given a path, we'll try to read the file synchronously (fallback)
                if ((!parsed.execFull || !parsed.exec) && typeof path === "string" && path.length) {
                    try {
                        var tryUrl = (path.indexOf("file://") === 0) ? path : ("file://" + path)
                        var syncXhr = new XMLHttpRequest()
                        try { syncXhr.open("GET", tryUrl, false) } catch(e) { syncXhr.open("GET", "file://" + path, false) }
                        try { syncXhr.send() } catch(e) { /* ignore */ }
                        if (syncXhr && (syncXhr.status === 0 || (syncXhr.status >= 200 && syncXhr.status < 300)) && syncXhr.responseText) {
                            try {
                                var p2 = parseDesktop(syncXhr.responseText)
                                if (p2 && p2.execFull) {
                                    parsed.name = parsed.name || p2.name
                                    parsed.execFull = parsed.execFull || p2.execFull
                                    parsed.exec = parsed.exec || p2.exec
                                    parsed.icon = parsed.icon || p2.icon
                                    Utils.dbg("DBG config: addAppFromDesktop sync XHR parse succeeded for", path)
                                } else {
                                    Utils.dbg("DBG config: addAppFromDesktop sync XHR parse returned nothing for", path)
                                }
                            } catch(e) { Utils.dbg("DBG config: sync XHR parse threw", e) }
                        } else {
                            Utils.dbg("DBG config: sync XHR failed status=", syncXhr ? syncXhr.status : "<no-xhr>", "for", tryUrl)
                        }
                    } catch(e) { Utils.dbg("DBG config: sync XHR fallback threw", e) }
                }

                if (parsed.nodisplay) {
                    Utils.dbg("DBG config.addAppFromDesktop skip NoDisplay for", path)
                    return
                }

                // Anti-ghosting: if there is no execFull and the file doesn't exist, skip
                var keyExecFull = parsed.execFull || ""
                var keyExecBase = parsed.exec || ""

                if (!keyExecFull) {
                    // Check for the existence of the file by path (synchronous HEAD/GET)
                    var tryUrl2 = (typeof path === "string" && path.indexOf("file://") === 0) ? path : ("file://" + path)
                    var fileExists = false
                    try {
                        var headXhr = new XMLHttpRequest()
                        try { headXhr.open("HEAD", tryUrl2, false) } catch(e) { headXhr.open("GET", tryUrl2, false) }
                        try { headXhr.send() } catch(e) {}
                        if (headXhr && (headXhr.status === 200 || headXhr.status === 0)) fileExists = true
                    } catch(e) { fileExists = false }

                    if (!fileExists && (!contents || contents.length === 0)) {
                        Utils.dbg("DBG config.addAppFromDesktop: skipping add — file does not exist and no Exec available:", path)
                        return
                    }

                    if (fileExists && !keyExecFull) {
                        try {
                            var syncXhr2 = new XMLHttpRequest()
                            try { syncXhr2.open("GET", tryUrl2, false) } catch(e) { syncXhr2.open("GET", "file://" + path, false) }
                            try { syncXhr2.send() } catch(e) {}
                            if (syncXhr2 && (syncXhr2.status === 0 || (syncXhr2.status >= 200 && syncXhr2.status < 300)) && syncXhr2.responseText) {
                                try {
                                    var p3 = parseDesktop(syncXhr2.responseText)
                                    if (p3 && p3.execFull) {
                                        keyExecFull = p3.execFull
                                        keyExecBase = keyExecBase || p3.exec
                                        parsed.name = parsed.name || p3.name
                                        parsed.icon = parsed.icon || p3.icon
                                        Utils.dbg("DBG config: addAppFromDesktop sync XHR parse succeeded for", path)
                                    } else {
                                        Utils.dbg("DBG config: addAppFromDesktop sync XHR parse returned no Exec for", path)
                                    }
                                } catch(e) { Utils.dbg("DBG config: sync XHR parse threw", e) }
                            } else {
                                Utils.dbg("DBG config: sync XHR failed status=", syncXhr2 ? syncXhr2.status : "<no-xhr>", "for", tryUrl2)
                            }
                        } catch(e) { Utils.dbg("DBG config: sync XHR fallback threw", e) }
                    }

                    // If after all there is no execFull, but there is a basic command, you can use the basic command as execFull (without arguments)
                    if (!keyExecFull && keyExecBase) {
                        keyExecFull = keyExecBase
                    }
                }

                // Final check: if there is no key, skip
                if (!keyExecFull) {
                    Utils.dbg("DBG config.addAppFromDesktop: final check — no execFull found, skipping add for", path)
                    return
                }

                // Check for duplicates:
                for (var i = 0; i < appsModel.length; i++) {
                    try {
                        var existing = appsModel[i] || {}
                        var existingExecFull = (typeof existing.execFull === "string" && existing.execFull.length) ? existing.execFull : null
                        var existingExecBase = (typeof existing.exec === "string" && existing.exec.length) ? existing.exec : null

                        if (existingExecFull && existingExecFull === keyExecFull) {
                            Utils.dbg("DBG config.addAppFromDesktop duplicate skip for execFull", keyExecFull, "existing-len=", appsModel.length)
                            return
                        }
                        if (!existingExecFull && existingExecBase && existingExecBase === keyExecBase) {
                            Utils.dbg("DBG config.addAppFromDesktop duplicate skip for exec base", keyExecBase, "existing-len=", appsModel.length)
                            return
                        }
                    } catch(e) {}
                }

                // Prepare exec/icon fields
                var finalExecFullRaw = parsed.execFullRaw || parsed.execFull || ""
                var finalExecFull = normalizeExecForStorage(finalExecFullRaw)
                var finalExecBase = finalExecFull ? finalExecFull.split(/\s+/)[0] : (parsed.exec || "")

                // Normalize parsed.icon into two canonical fields:
                // - icon: theme name (no extension) used with image://theme/
                // - iconFilePath: absolute file://... path to an icon file (preferred if available)
                var normalizedIcon = normalizeIconValue(parsed.icon || "")   // may return "file://..." or "/abs/path" -> converted to file:// or theme name without ext
                var resolvedIconPath = ""
                try {
                    if (typeof HelperBridge !== "undefined" && HelperBridge && typeof HelperBridge.resolveIcon === "function") {
                        try { resolvedIconPath = HelperBridge.resolveIcon(normalizedIcon || "") || "" } catch(e) { resolvedIconPath = "" }
                    }
                } catch(e) { resolvedIconPath = "" }

                // Helper to ensure file:// prefix
                function ensureFileUrl(p) {
                    if (!p || typeof p !== "string") return ""
                        if (p.indexOf("file://") === 0) return p
                            if (p.indexOf("/") === 0) return "file://" + p
                                return p
                }

                var iconField = ""
                var iconFilePathField = ""

                if (resolvedIconPath && resolvedIconPath.length) {
                    // HelperBridge returned something. Prefer it as file path.
                    iconFilePathField = ensureFileUrl(resolvedIconPath)
                    iconField = ""
                    Utils.dbg("DBG config.addAppFromDesktop: resolvedIconPath ->", iconFilePathField)
                } else {
                    // No helper resolution. Inspect parsed.icon / normalizedIcon.
                    if (parsed.icon && parsed.icon.length) {
                        // If original parsed.icon looked like a path or file://, normalize to file:// and store in iconFilePath
                        var raw = parsed.icon.toString().trim()
                        if (raw.indexOf("file://") === 0 || raw.indexOf("/") === 0) {
                            iconFilePathField = normalizeIconValue(raw)   // normalizeIconValue will prefix file:// if needed
                            iconField = ""
                            Utils.dbg("DBG config.addAppFromDesktop: parsed.icon treated as file path ->", iconFilePathField)
                        } else {
                            // Treat as theme name (remove extension if present)
                            iconField = normalizedIcon || raw.replace(/\.(png|svg|xpm)$/i,"").trim()
                            iconFilePathField = ""
                            Utils.dbg("DBG config.addAppFromDesktop: parsed.icon treated as theme name ->", iconField)
                        }
                    } else {
                        // No icon info at all
                        iconField = ""
                        iconFilePathField = ""
                    }
                }

                // Build the object to push: keep both fields for compatibility
                var toPush = {
                    file: path || "",
                    name: parsed.name || finalExecBase || "",
                    exec: finalExecBase || "",
                    execFullRaw: finalExecFullRaw || "",
                    execFull: finalExecFull || "",
                    // icon: theme name (without extension) — used with image://theme/
                    icon: (iconField && iconField.length) ? iconField : "",
                    // iconFilePath: absolute file:// path if resolved by HelperBridge or if parsed was absolute
                    iconFilePath: (iconFilePathField && iconFilePathField.length) ? iconFilePathField : "",
                    runInTerminal: false,
                    workingDir: ""
                }

                appsModel.push(toPush)
                Utils.dbg("DBG config: addAppFromDesktop pushed", keyExecFull, "now len=", appsModel.length)
                Utils.dbg("DBG config: addApp pushed:", JSON.stringify(toPush))

                // persist and notify UI
                try { persistAndNotify() } catch(e) { Utils.dbg("DBG config: persistAndNotify threw", e) }
        } catch(e) { Utils.dbg("DBG config: addAppFromDesktop exception", e) }
    }

    // New: remove app by index (used from UI right-click)
    function removeApp(index) {
        try {
            if (!appsModel || typeof appsModel.length !== "number") return false
            if (typeof index !== "number") {
                Utils.dbg("DBG config.removeApp: invalid index type", index)
                return false
            }
            if (index < 0 || index >= appsModel.length) {
                Utils.dbg("DBG config.removeApp: index out of range", index)
                return false
            }
            // splice model (works for JS array used as model)
            var removed = appsModel.splice(index, 1)
            Utils.dbg("DBG config.removeApp: removed index", index, "removed-length=", (removed ? removed.length : 0), "new-len=", appsModel.length)
            try { persistAndNotify() } catch(e) { Utils.dbg("DBG config.removeApp: persistAndNotify threw", e) }
            return true
        } catch(e) {
            Utils.dbg("DBG config.removeApp exception", e)
            return false
        }
    }

    Component.onCompleted: {
        Utils.dbg("DBG config: Component.onCompleted; filename=", Qt.resolvedUrl("."))
        // Defer initial load so main.qml's Loader has a chance to set instanceKey
        Qt.callLater(function() {
            try {
                Utils.dbg("DBG config: Component.onCompleted (deferred) calling loadInstanceConfig; current instanceKey=", instanceKey)
                loadInstanceConfig()
            } catch (e) { Utils.dbg("DBG config: deferred loadInstanceConfig threw", e) }
        })
        Utils.dbg("DBG config: addAppFromDesktop available")
    }

    onInstanceKeyChanged: {
        try {
            if (!instanceKey || instanceKey.length === 0) return
            Utils.dbg("DBG config: instanceKey changed ->", instanceKey, "re-loading instance config")
            loadInstanceConfig()
        } catch(e) { Utils.dbg("DBG config: onInstanceKeyChanged threw", e) }
    }
}
