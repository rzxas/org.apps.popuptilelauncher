pragma Singleton
import QtQuick 2

QtObject {
    id: utils
    property bool debugLogs: false
    property string prefix: "DBG"

    function dbg() {
        if (!utils.debugLogs) return;
        var args = Array.prototype.slice.call(arguments);
        args.unshift(utils.prefix + ":");
        console.log.apply(console, args);
    }

    function warn() {
        if (!utils.debugLogs) return;
        var args = Array.prototype.slice.call(arguments);
        args.unshift(utils.prefix + " WARN:");
        console.warn.apply(console, args);
    }

    function err() {
        var args = Array.prototype.slice.call(arguments);
        args.unshift(utils.prefix + " ERROR:");
        console.error.apply(console, args);
    }
}
