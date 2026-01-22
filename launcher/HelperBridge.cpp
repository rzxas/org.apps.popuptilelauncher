#include "HelperBridge.h"
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusMessage>
#include <QDebug>
#include <QVariantMap>

HelperBridge::HelperBridge(QObject *parent) : QObject(parent) {}

QString HelperBridge::normalizePath(const QString &p) const
{
    if (p.startsWith("file://")) return p.mid(7);
    return p;
}

QString HelperBridge::readDesktop(const QString &filePath)
{
    const QString path = normalizePath(filePath);
    // Call org.apps.PlasmaHelper.ReadDesktop on session bus
    QDBusInterface iface("org.apps.PlasmaHelper",
                         "/org/apps/PlasmaHelper",
                         "org.apps.PlasmaHelper",
                         QDBusConnection::sessionBus());

    if (!iface.isValid()) {
        qWarning() << "HelperBridge::readDesktop: DBus interface not available";
        return QString();
    }

    QDBusReply<QString> reply = iface.call("ReadDesktop", path);
    if (reply.isValid()) return reply.value();
    qWarning() << "HelperBridge::readDesktop: DBus call failed:" << reply.error().message();
    return QString();
}

QString HelperBridge::resolveIcon(const QString &nameOrPath)
{
    QDBusInterface iface("org.apps.PlasmaHelper", "/org/apps/PlasmaHelper", "org.apps.PlasmaHelper", QDBusConnection::sessionBus());
    if (!iface.isValid()) { qWarning() << "resolveIcon: DBus iface not available"; return QString(); }
    QDBusReply<QString> reply = iface.call("ResolveIcon", nameOrPath);
    if (reply.isValid()) return reply.value();
    qWarning() << "resolveIcon: DBus call failed:" << iface.lastError().message();
    return QString();
}

QString HelperBridge::readInstanceFile(const QString &instanceKey)
{
    QDBusInterface iface("org.apps.PlasmaHelper", "/org/apps/PlasmaHelper", "org.apps.PlasmaHelper", QDBusConnection::sessionBus());
    if (!iface.isValid()) { qWarning() << "readInstanceFile: DBus iface not available"; return QString(); }
    QDBusReply<QString> reply = iface.call("ReadInstanceFile", instanceKey);
    if (reply.isValid()) return reply.value();
    qWarning() << "readInstanceFile: DBus call failed:" << iface.lastError().message();
    return QString();
}

bool HelperBridge::writeInstanceFile(const QString &instanceKey, const QString &content)
{
    QDBusInterface iface("org.apps.PlasmaHelper", "/org/apps/PlasmaHelper", "org.apps.PlasmaHelper", QDBusConnection::sessionBus());
    if (!iface.isValid()) { qWarning() << "writeInstanceFile: DBus iface not available"; return false; }
    QDBusReply<bool> reply = iface.call("WriteInstanceFile", instanceKey, content);
    if (reply.isValid()) return reply.value();
    qWarning() << "writeInstanceFile: DBus call failed:" << iface.lastError().message();
    return false;
}

bool HelperBridge::removeInstanceFile(const QString &instanceKey)
{
    QDBusInterface iface("org.apps.PlasmaHelper", "/org/apps/PlasmaHelper", "org.apps.PlasmaHelper", QDBusConnection::sessionBus());
    if (!iface.isValid()) { qWarning() << "removeInstanceFile: DBus iface not available"; return false; }
    QDBusReply<bool> reply = iface.call("RemoveInstanceFile", instanceKey);
    if (reply.isValid()) return reply.value();
    qWarning() << "removeInstanceFile: DBus call failed:" << iface.lastError().message();
    return false;
}

QStringList HelperBridge::listInstanceFiles()
{
    QDBusInterface iface("org.apps.PlasmaHelper", "/org/apps/PlasmaHelper", "org.apps.PlasmaHelper", QDBusConnection::sessionBus());
    QStringList empty;
    if (!iface.isValid()) { qWarning() << "listInstanceFiles: DBus iface not available"; return empty; }
    QDBusReply<QStringList> reply = iface.call("ListInstanceFiles");
    if (reply.isValid()) return reply.value();
    qWarning() << "listInstanceFiles: DBus call failed:" << iface.lastError().message();
    return empty;
}

bool HelperBridge::ensureInstanceFile(const QString &instanceKey)
{
    QDBusInterface iface("org.apps.PlasmaHelper", "/org/apps/PlasmaHelper", "org.apps.PlasmaHelper", QDBusConnection::sessionBus());
    if (!iface.isValid()) { qWarning() << "ensureInstanceFile: DBus iface not available"; return false; }
    QDBusReply<bool> reply = iface.call("EnsureInstanceFile", instanceKey);
    if (reply.isValid()) return reply.value();
    qWarning() << "ensureInstanceFile: DBus call failed:" << iface.lastError().message();
    return false;
}

bool HelperBridge::startUnit(const QString &unitName)
{
    if (unitName.isEmpty()) return false;
    QDBusInterface iface("org.apps.PlasmaHelper",
                         "/org/apps/PlasmaHelper",
                         "org.apps.PlasmaHelper",
                         QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        qWarning() << "HelperBridge::startUnit: DBus interface not available";
        return false;
    }
    QDBusReply<bool> reply = iface.call("StartUnit", unitName);
    if (reply.isValid()) return reply.value();
    qWarning() << "HelperBridge::startUnit: DBus call failed:" << iface.lastError().message();
    return false;
}

bool HelperBridge::stopUnit(const QString &unitName)
{
    if (unitName.isEmpty()) return false;
    QDBusInterface iface("org.apps.PlasmaHelper",
                         "/org/apps/PlasmaHelper",
                         "org.apps.PlasmaHelper",
                         QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        qWarning() << "HelperBridge::stopUnit: DBus interface not available";
        return false;
    }
    QDBusReply<bool> reply = iface.call("StopUnit", unitName);
    if (reply.isValid()) return reply.value();
    qWarning() << "HelperBridge::stopUnit: DBus call failed:" << iface.lastError().message();
    return false;
}

bool HelperBridge::runDesktop(const QString &filePath)
{
    const QString path = normalizePath(filePath);
    QDBusInterface iface("org.apps.PlasmaHelper",
                         "/org/apps/PlasmaHelper",
                         "org.apps.PlasmaHelper",
                         QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        qWarning() << "HelperBridge::runDesktop: DBus interface not available; lastError =" << iface.lastError().message();
        return false;
    }
    qWarning() << "HelperBridge::runDesktop: calling RunDesktop for" << path;
    QDBusReply<bool> reply = iface.call("RunDesktop", path);
    if (reply.isValid()) {
        qWarning() << "HelperBridge::runDesktop: reply valid ->" << reply.value();
        return reply.value();
    }
    qWarning() << "HelperBridge::runDesktop: DBus call failed:" << reply.error().message();
    return false;
}

bool HelperBridge::runCommand(const QString &cmd)
{
    if (cmd.isEmpty()) return false;

    QDBusInterface iface("org.apps.PlasmaHelper",
                         "/org/apps/PlasmaHelper",
                         "org.apps.PlasmaHelper",
                         QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        qWarning() << "HelperBridge::runCommand: DBus interface not available";
        return false;
    }
    // qWarning() << "HelperBridge::runCommand: calling RunCommand for" << cmd;
    QDBusReply<bool> reply = iface.call("RunCommand", cmd);
    if (reply.isValid()) {
        // qWarning() << "HelperBridge::runCommand: reply ->" << reply.value();
        return reply.value();
    }
    qWarning() << "HelperBridge::runCommand: DBus call failed:" << reply.error().message();
    return false;
}

bool HelperBridge::runCommandInTerminal(const QString &cmd, const QString &workingDir)
{
    if (cmd.isEmpty()) return false;

    QDBusInterface iface("org.apps.PlasmaHelper",
                         "/org/apps/PlasmaHelper",
                         "org.apps.PlasmaHelper",
                         QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        qWarning() << "HelperBridge::runCommandInTerminal: DBus interface not available";
        return false;
    }
    // qWarning() << "HelperBridge::runCommandInTerminal: calling RunCommandInTerminal for" << cmd << "wd=" << workingDir;
    QDBusReply<bool> reply = iface.call("RunCommandInTerminal", cmd, workingDir);
    if (reply.isValid()) {
        // qWarning() << "HelperBridge::runCommandInTerminal: reply ->" << reply.value();
        return reply.value();
    }
    qWarning() << "HelperBridge::runCommandInTerminal: DBus call failed:" << reply.error().message();
    return false;
}

QVariantMap HelperBridge::parseDesktop(const QString &filePath)
{
    const QString path = normalizePath(filePath);
    QVariantMap empty;
    QDBusInterface iface("org.apps.PlasmaHelper",
                         "/org/apps/PlasmaHelper",
                         "org.apps.PlasmaHelper",
                         QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        qWarning() << "HelperBridge::parseDesktop: DBus interface not available";
        return empty;
    }
    QDBusMessage msg = iface.call("ParseDesktop", path);
    if (msg.type() == QDBusMessage::ReplyMessage && !msg.arguments().isEmpty()) {
        // expecting a{sv} -> QVariantMap
        QVariant v = msg.arguments().at(0);
        if (v.canConvert<QVariantMap>()) return v.toMap();
    }
    qWarning() << "HelperBridge::parseDesktop: DBus call failed or returned unexpected:" << iface.lastError().message();
    return empty;
}
