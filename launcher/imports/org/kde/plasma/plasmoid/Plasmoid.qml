import QtQuick 6.4

Item {
    id: root
    // default sizes if main.qml expects
    property int width: 400
    property int height: 400

    // frequently used properties in plasmoid templates - add those needed
    property bool isPlasma: true
    property alias visible: root.visible

    // overridable methods, expand main.qml as errors occur
    function open() { /* stub */ }
    function addAppFromDesktop(path) {
        console.log("shim: addAppFromDesktop", path)
    }
    function requestLaunch(modelData, index) {
        console.log("shim: requestLaunch", modelData, index)
    }

    // signal/slot forwarding if main.qml is subscribed
    signal launchRequested(var modelData, int index)

    Component.onCompleted: {
        // debug
        console.log("Plasmoid shim loaded")
    }
}
