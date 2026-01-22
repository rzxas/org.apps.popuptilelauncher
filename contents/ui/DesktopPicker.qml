import QtQuick 6
import QtQuick.Controls 6
import Qt.labs.platform 1
import "../config"

Item {
    id: root
    signal desktopChosen(string path, string contents)
    function open() { fileDialog.open() }

    FileDialog {
        id: fileDialog
        title: "Choose .desktop file"
        nameFilters: ["Desktop entry files (*.desktop)","All files (*)"]

        onAccepted: {
            // robust selection -> always produce a plain string
            var sel = ""
            if (typeof fileDialog.fileUrl !== "undefined" && fileDialog.fileUrl) {
                try { sel = fileDialog.fileUrl.toString(); } catch(e) { sel = String(fileDialog.fileUrl) }
            } else if (fileDialog.fileUrls && fileDialog.fileUrls.length) {
                try { sel = fileDialog.fileUrls[0].toString(); } catch(e) { sel = String(fileDialog.fileUrls[0]) }
            } else if (typeof fileDialog.file !== "undefined" && fileDialog.file) {
                sel = String(fileDialog.file)
            } else if (typeof fileDialog.folder !== "undefined" && fileDialog.folder) {
                sel = String(fileDialog.folder)
            } else if (typeof fileDialog.url !== "undefined" && fileDialog.url) {
                sel = String(fileDialog.url)
            }

            Utils.dbg("DBG DesktopPicker: FileDialog accepted, raw:", sel)
            if (!sel) { Utils.dbg("DBG DesktopPicker: no file selected"); return }

            // normalize file:// URL to absolute path string
            var abs = String(sel)
            if (abs.indexOf("file://") === 0) abs = decodeURIComponent(abs.substring(7))
            Utils.dbg("DBG DesktopPicker: normalized path:", abs)

            // Try native Launcher.readDesktop first (preferred)
            try {
                if (typeof Launcher !== "undefined" && Launcher && typeof Launcher.readDesktop === "function") {
                    try {
                        var meta = Launcher.readDesktop(abs)
                        // meta is expected to be a QVariantMap-like object with exec/name/icon optional
                        if (meta && (meta.exec || meta.name || meta.icon)) {
                            Utils.dbg("DBG DesktopPicker: Launcher.readDesktop returned:", meta)
                            // Launcher.readDesktop doesn't provide raw contents; emit with empty contents
                            desktopChosen(String(abs), "")
                            return
                        } else {
                            Utils.dbg("DBG DesktopPicker: Launcher.readDesktop returned no useful fields, falling back")
                        }
                    } catch(e) {
                        Utils.dbg("DBG DesktopPicker: Launcher.readDesktop threw", e)
                    }
                } else {
                    Utils.dbg("DBG DesktopPicker: Launcher.readDesktop not available, falling back")
                }
            } catch(e) {
                Utils.dbg("DBG DesktopPicker: error while attempting Launcher.readDesktop", e)
            }

            // Fallback: direct file:// XHR read (no helper)
            function tryDirectReadAndEmit(absPath) {
                try {
                    var fileUrl = "file://" + absPath
                    Utils.dbg("DBG DesktopPicker: attempting direct file read:", fileUrl)
                    var xr_local = new XMLHttpRequest()
                    var handledLocal = false
                    xr_local.open("GET", fileUrl)
                    xr_local.onreadystatechange = function() {
                        if (xr_local.readyState === XMLHttpRequest.DONE) {
                            handledLocal = true
                            if (xr_local.status === 200 || xr_local.status === 0) {
                                Utils.dbg("DBG DesktopPicker: direct file read OK; len=", (xr_local.responseText ? xr_local.responseText.length : 0))
                                desktopChosen(String(absPath), xr_local.responseText)
                            } else {
                                Utils.dbg("DBG DesktopPicker: direct file read failed; status=", xr_local.status)
                                desktopChosen(String(absPath), "")
                            }
                        }
                    }
                    xr_local.onerror = function(e) {
                        handledLocal = true
                        Utils.dbg("DBG DesktopPicker: direct file XHR error", e)
                        desktopChosen(String(absPath), "")
                    }

                    // timeout fallback: if XHR doesn't finish in 400ms, emit empty contents
                    var to_local = Qt.createQmlObject('import QtQuick 6; Timer { interval: 400; repeat: false }', root)
                    to_local.triggered.connect(function() {
                        if (!handledLocal) {
                            try { xr_local.abort() } catch(e) {}
                            Utils.dbg("DBG DesktopPicker: direct file XHR timed out, emitting empty contents")
                            desktopChosen(String(absPath), "")
                        }
                        try { to_local.destroy() } catch(e) {}
                    })
                    to_local.start()

                    try { xr_local.send() } catch(e) {
                        try { to_local.stop(); to_local.destroy() } catch(e) {}
                        Utils.dbg("DBG DesktopPicker: direct file XHR send threw", e)
                        desktopChosen(String(absPath), "")
                    }
                } catch(e) {
                    Utils.dbg("DBG DesktopPicker: tryDirectReadAndEmit threw", e)
                    desktopChosen(String(absPath), "")
                }
            }

            // call direct read fallback immediately (we already tried Launcher.readDesktop above)
            tryDirectReadAndEmit(abs)
        }

        onRejected: { Utils.dbg("DBG DesktopPicker: FileDialog rejected") }
    }
}
