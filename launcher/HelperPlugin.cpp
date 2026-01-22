#include "HelperPlugin.h"
#include "HelperBridge.h"
#include <qqml.h>
#include <QQmlEngine>

void HelperPlugin::registerTypes(const char *uri)
{
    Q_ASSERT(QString(uri) == QLatin1String("org.apps.launcher"));
    qmlRegisterSingletonType<HelperBridge>(uri, 1, 0, "HelperBridge",
                                           [](QQmlEngine *engine, QJSEngine *) -> QObject* {
                                               return new HelperBridge(static_cast<QObject*>(engine));
                                           });
}
