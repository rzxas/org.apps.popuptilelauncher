import QtQuick 6.4

Item {
    id: root
    width: 400
    height: 400

    // internal content container (without aliases)
    Item {
        id: content
        anchors.fill: parent
    }

    // minimal properties and signals - give them different names to avoid conflicts
    property bool shimIsPlasma: true
    signal shimLaunchRequested(var modelData, int index)

    function shimRequestLaunch(modelData, index) {
        console.log("shim PlasmoidItem.requestLaunch", modelData, index)
        shimLaunchRequested(modelData, index)
    }

    Component.onCompleted: console.log("PlasmoidItem shim loaded")
}
