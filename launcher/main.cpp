#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QCoreApplication>
#include <qqml.h>
#include <QQmlContext>
#include "HelperBridge.h"
#include "Launcher.h"

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    qmlRegisterSingletonType<Launcher>("org.apps.launcher", 1, 0, "Launcher",
        [](QQmlEngine*, QJSEngine*) -> QObject* { return new Launcher(); });
    QCoreApplication::setOrganizationName(QStringLiteral("rzxa.org.name"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("rzxas.org.domain"));
    QCoreApplication::setApplicationName(QStringLiteral("popup-tile-launcher"));
    QQmlApplicationEngine engine;
    HelperBridge helperBridge;
    engine.rootContext()->setContextProperty(QStringLiteral("HelperBridge"), &helperBridge);
    // engine.load(QUrl(QStringLiteral("qrc:/main.qml"))); // if test drop main.qml в qrc
    engine.addImportPath(QStringLiteral("qrc:/ui/imports"));
    engine.load(QUrl(QStringLiteral("qrc:/ui/contents/ui/main.qml")));
    return app.exec();
}
