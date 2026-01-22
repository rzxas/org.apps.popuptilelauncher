#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusError>
#include "PlasmaHelper.h"

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    // Register object on session bus
    if (!QDBusConnection::sessionBus().isConnected()) {
        qWarning() << "Session D-Bus is not available; exiting.";
        return 1;
    }
    const QString serviceName = QStringLiteral("org.apps.PlasmaHelper");
    if (!QDBusConnection::sessionBus().registerService(serviceName)) {
        qWarning() << "Could not register service name:" << QDBusConnection::sessionBus().lastError().message();
    }
    PlasmaHelper helper;
    if (!QDBusConnection::sessionBus().registerObject(QStringLiteral("/org/apps/PlasmaHelper"), &helper, QDBusConnection::ExportAllSlots)) {
        qWarning() << "Failed to register DBus object:" << QDBusConnection::sessionBus().lastError().message();
        return 2;
    }
    return app.exec();
}
