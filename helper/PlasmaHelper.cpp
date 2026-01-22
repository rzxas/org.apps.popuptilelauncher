#include "PlasmaHelper.h"

#include <QFile>
#include <QTextStream>
#include <QProcess>
#include <QVariantMap>
#include <QRegularExpression>
#include <QDBusError>
#include <QDebug>
#include <QFileInfo>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusObjectPath>
#include <QIcon>
#include <QStandardPaths>
#include <QDir>
#include <QSaveFile>

PlasmaHelper::PlasmaHelper(QObject *parent) : QObject(parent) {}

QString PlasmaHelper::ReadDesktop(const QString &filePath)
{
    QString p = filePath;
    if (p.startsWith("file://")) p = p.mid(7);
    QFile f(p);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "PlasmaHelper::ReadDesktop: cannot open file" << p << "-" << f.errorString();
        return QString();
    }
    QTextStream in(&f);
    return in.readAll();
}

static QString instancesBaseDir()
{
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) base = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    if (base.isEmpty()) base = QDir::homePath() + "/.local/share/plasma_helper";
    QDir d(base);
    if (!d.exists()) d.mkpath(".");
    QDir instDir(d.filePath("instances"));
    if (!instDir.exists()) instDir.mkpath(".");
    return instDir.absolutePath();
}

static QString instanceFilePath(const QString &instanceKey)
{
    QString dir = instancesBaseDir();
    QString safeName = instanceKey;
    safeName.replace(QRegularExpression("[^A-Za-z0-9_\\-]"), "_");
    return QDir(dir).filePath(safeName + ".json");
}

QString PlasmaHelper::ResolveIcon(const QString &nameOrPath)
{
    if (nameOrPath.isEmpty()) return QString();

    QString s = nameOrPath.trimmed();

    // absolute path or file://
    if (s.startsWith("file://")) {
        QString p = s.mid(7);
        if (QFileInfo::exists(p)) return QStringLiteral("file://") + QFileInfo(p).absoluteFilePath();
            return QString();
    }
    if (s.startsWith("/")) {
        if (QFileInfo::exists(s)) return QStringLiteral("file://") + QFileInfo(s).absoluteFilePath();
            return QString();
    }

    // try QIcon::fromTheme
    QIcon ic = QIcon::fromTheme(s);
    if (!ic.isNull()) {
        // try to locate file in common icon dirs
        QStringList roots;
        roots << QStringLiteral("/usr/share/icons") << QDir::homePath() + "/.local/share/icons" << QStringLiteral("/usr/share/pixmaps");
        QStringList exts = { ".svg", ".png", ".xpm" };
        for (const QString &root : roots) {
            QDir r(root);
            if (!r.exists()) continue;
            // check common subdirs
            QStringList subdirs = r.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
            for (const QString &sd : subdirs) {
                QDir candidate(r.filePath(sd));
                QStringList tryDirs = { candidate.filePath("apps"), candidate.filePath("actions"), candidate.filePath("places"), candidate.filePath("status") };
                for (const QString &td : tryDirs) {
                    for (const QString &ext : exts) {
                        QString f = QDir(td).filePath(s + ext);
                        if (QFileInfo::exists(f)) return QStringLiteral("file://") + QFileInfo(f).absoluteFilePath();
                    }
                }
            }
            // fallback: root/<name>.<ext>
            for (const QString &ext : exts) {
                QString f = r.filePath(s + ext);
                if (QFileInfo::exists(f)) return QStringLiteral("file://") + QFileInfo(f).absoluteFilePath();
            }
        }
    }

    // last resort: hicolor scalable
    QString fallback = QDir(QStringLiteral("/usr/share/icons/hicolor/scalable/apps")).filePath(s + ".svg");
    if (QFileInfo::exists(fallback)) return QStringLiteral("file://") + QFileInfo(fallback).absoluteFilePath();

        return QString();
}

QString PlasmaHelper::ReadInstanceFile(const QString &instanceKey)
{
    if (instanceKey.isEmpty()) return QString();
    QString path = instanceFilePath(instanceKey);
    QFile f(path);
    if (!f.exists()) return QString();
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "ReadInstanceFile: cannot open" << path << "-" << f.errorString();
        return QString();
    }
    QTextStream in(&f);
    QString content = in.readAll();
    f.close();
    return content;
}

bool PlasmaHelper::WriteInstanceFile(const QString &instanceKey, const QString &content)
{
    if (instanceKey.isEmpty()) return false;
    QString path = instanceFilePath(instanceKey);
    QSaveFile sf(path);
    if (!sf.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "WriteInstanceFile: cannot open" << path << "-" << sf.errorString();
        return false;
    }
    QByteArray data = content.toUtf8();
    if (sf.write(data) != data.size()) {
        qWarning() << "WriteInstanceFile: write failed for" << path;
        sf.cancelWriting();
        return false;
    }
    if (!sf.commit()) {
        qWarning() << "WriteInstanceFile: commit failed for" << path << "-" << sf.errorString();
        return false;
    }
    return true;
}

bool PlasmaHelper::RemoveInstanceFile(const QString &instanceKey)
{
    if (instanceKey.isEmpty()) return false;
    QString path = instanceFilePath(instanceKey);
    QFile f(path);
    if (!f.exists()) return true;
    if (!f.remove()) {
        qWarning() << "RemoveInstanceFile: failed to remove" << path << "-" << f.errorString();
        return false;
    }
    return true;
}

QStringList PlasmaHelper::ListInstanceFiles()
{
    QString dir = instancesBaseDir();
    QDir d(dir);
    QStringList out;
    if (!d.exists()) return out;
    QStringList files = d.entryList(QStringList() << "*.json", QDir::Files | QDir::NoSymLinks);
    for (const QString &f : files) {
        QString base = f;
        if (base.endsWith(".json")) base.chop(5);
        out << base;
    }
    return out;
}

bool PlasmaHelper::EnsureInstanceFile(const QString &instanceKey)
{
    if (instanceKey.isEmpty()) return false;
    QString path = instanceFilePath(instanceKey);
    QFile f(path);
    if (f.exists()) return true;
    QSaveFile sf(path);
    if (!sf.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "EnsureInstanceFile: cannot create" << path << "-" << sf.errorString();
        return false;
    }
    QByteArray data = QByteArrayLiteral("{}");
    if (sf.write(data) != data.size()) { sf.cancelWriting(); return false; }
    if (!sf.commit()) { qWarning() << "EnsureInstanceFile: commit failed" << path; return false; }
    return true;
}

bool PlasmaHelper::StartUnit(const QString &unitName)
{
    if (unitName.isEmpty()) return false;
    QDBusInterface iface("org.freedesktop.systemd1",
                         "/org/freedesktop/systemd1",
                         "org.freedesktop.systemd1.Manager",
                         QDBusConnection::systemBus());
    if (!iface.isValid()) {
        qWarning() << "StartUnit: system bus interface invalid:" << QDBusConnection::systemBus().lastError().message();
        return false;
    }
    QDBusReply<QDBusObjectPath> reply = iface.call("StartUnit", unitName, QString("replace"));
    if (!reply.isValid()) {
        qWarning() << "StartUnit call failed:" << iface.lastError().message();
        return false;
    }
    qWarning() << "StartUnit: started" << unitName << "job=" << reply.value().path();
    return true;
}

bool PlasmaHelper::StopUnit(const QString &unitName)
{
    if (unitName.isEmpty()) return false;
    QDBusInterface iface("org.freedesktop.systemd1",
                         "/org/freedesktop/systemd1",
                         "org.freedesktop.systemd1.Manager",
                         QDBusConnection::systemBus());
    if (!iface.isValid()) {
        qWarning() << "StopUnit: system bus interface invalid:" << QDBusConnection::systemBus().lastError().message();
        return false;
    }
    QDBusReply<QDBusObjectPath> reply = iface.call("StopUnit", unitName, QString("replace"));
    if (!reply.isValid()) {
        qWarning() << "StopUnit call failed:" << iface.lastError().message();
        return false;
    }
    qWarning() << "StopUnit: stopped" << unitName << "job=" << reply.value().path();
    return true;
}

bool PlasmaHelper::RunDesktop(const QString &filePath)
{
    QString p = filePath;
    if (p.startsWith("file://")) p = p.mid(7);

    // If this is a .desktop file, try to extract Exec= line and run it.
    if (p.endsWith(".desktop")) {
        QFile f(p);
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&f);
            QString line;
            bool inDesktop = false;
            QString execLine;
            while (!in.atEnd()) {
                line = in.readLine().trimmed();
                if (line == QLatin1String("[Desktop Entry]")) { inDesktop = true; continue; }
                if (!inDesktop) continue;
                if (line.isEmpty() || line.startsWith('#')) continue;
                if (line.startsWith(QLatin1String("Exec=")) && execLine.isEmpty()) {
                    execLine = line.mid(5).trimmed();
                    break;
                }
            }
            f.close();

            if (!execLine.isEmpty()) {
                QStringList parts = QProcess::splitCommand(execLine);
                if (!parts.isEmpty()) {
                    QString program = parts.first();
                    QStringList args = parts.mid(1);
                    for (int i = args.count() - 1; i >= 0; --i) {
                        if (args[i].startsWith('%')) args.removeAt(i);
                    }
                    qWarning() << "PlasmaHelper::RunDesktop: starting exec from .desktop:" << program << args;
                    if (QProcess::startDetached(program, args)) return true;
                    qWarning() << "PlasmaHelper::RunDesktop: startDetached failed for" << program;
                }
            } else {
                qWarning() << "PlasmaHelper::RunDesktop: no Exec= found in" << p;
            }
        } else {
            qWarning() << "PlasmaHelper::RunDesktop: cannot open file" << p << "-" << f.errorString();
        }
    }

    // If the path itself is an executable file, run it directly.
    if (QFileInfo(p).isExecutable()) {
        qWarning() << "PlasmaHelper::RunDesktop: starting executable file" << p;
        if (QProcess::startDetached(p)) return true;
    }

    // Last resort: xdg-open (may open the .desktop file in editor — fallback only)
    if (QProcess::startDetached(QStringLiteral("xdg-open"), QStringList() << p)) {
        qWarning() << "PlasmaHelper::RunDesktop: started via xdg-open fallback" << p;
        return true;
    }

    qWarning() << "PlasmaHelper::RunDesktop: failed to start" << p;
    return false;
}

bool PlasmaHelper::RunCommand(const QString &cmd)
{
    if (cmd.isEmpty()) {
        qWarning() << "PlasmaHelper::RunCommand: empty command";
        return false;
    }
    bool ok = QProcess::startDetached(QStringLiteral("/bin/sh"),
                                      QStringList() << QStringLiteral("-c") << cmd);
    qWarning() << "PlasmaHelper::RunCommand: starting via shell:" << cmd << "ok=" << ok;
    return ok;
}

bool PlasmaHelper::RunCommandInTerminal(const QString &cmd, const QString &workingDir)
{
    if (cmd.isEmpty()) {
        qWarning() << "PlasmaHelper::RunCommandInTerminal: empty command";
        return false;
    }

    #if defined(Q_OS_WIN)
    // Windows: try wt then fallback to cmd.exe /k
    {
        QString wd = workingDir.isEmpty() ? QString() : workingDir;
        QString full = wd.isEmpty() ? cmd : QStringLiteral("cd /d %1 && %2").arg(wd, cmd);
        if (QProcess::startDetached(QStringLiteral("wt"),
            QStringList() << QStringLiteral("new-tab") << QStringLiteral("cmd") << QStringLiteral("/k") << full)) {
            qWarning() << "PlasmaHelper::RunCommandInTerminal: started via wt:" << full;
        return true;
            }
            bool ok = QProcess::startDetached(QStringLiteral("cmd.exe"),
                                              QStringList() << QStringLiteral("/k") << full);
            qWarning() << "PlasmaHelper::RunCommandInTerminal: started via cmd.exe:" << full << "ok=" << ok;
            return ok;
    }
    #elif defined(Q_OS_MAC)
    // macOS: osascript -> Terminal
    {
        QString wd = workingDir.isEmpty() ? QStringLiteral("$(pwd)") : workingDir;
        QString escapedCmd = cmd;
        escapedCmd.replace(QLatin1Char('"'), QStringLiteral("\\\""));
        QString apple = QStringLiteral("tell application \"Terminal\" to do script \"cd %1 && %2; echo; echo \\\"--- Press Enter to close ---\\\"; read -r\"")
        .arg(wd, escapedCmd);
        bool ok = QProcess::startDetached(QStringLiteral("osascript"), QStringList() << QStringLiteral("-e") << apple);
        qWarning() << "PlasmaHelper::RunCommandInTerminal: started via osascript ok=" << ok;
        return ok;
    }
    #else
    // Linux / Unix: try common terminals, fallback to bash -lc
    {
        QString wd = workingDir;
        if (wd.isEmpty()) wd = QString();
        QString bashCmd;
        if (wd.isEmpty())
            bashCmd = QStringLiteral("%1; echo; echo '--- Press Enter to close ---'; read -r").arg(cmd);
        else
            bashCmd = QStringLiteral("cd %1 && %2; echo; echo '--- Press Enter to close ---'; read -r").arg(wd, cmd);

        // gnome-terminal
        if (QProcess::startDetached(QStringLiteral("gnome-terminal"),
            QStringList() << QStringLiteral("--") << QStringLiteral("bash") << QStringLiteral("-c") << bashCmd)) {
            qWarning() << "PlasmaHelper::RunCommandInTerminal: started via gnome-terminal";
        return true;
            }
            // konsole
            if (QProcess::startDetached(QStringLiteral("konsole"),
                QStringList() << QStringLiteral("-e") << QStringLiteral("bash") << QStringLiteral("-c") << bashCmd)) {
                qWarning() << "PlasmaHelper::RunCommandInTerminal: started via konsole";
            return true;
                }
                // xfce4-terminal
                if (QProcess::startDetached(QStringLiteral("xfce4-terminal"),
                    QStringList() << QStringLiteral("--command") << QStringLiteral("bash -c ") << bashCmd)) {
                    qWarning() << "PlasmaHelper::RunCommandInTerminal: started via xfce4-terminal";
                return true;
                    }
                    // xterm
                    if (QProcess::startDetached(QStringLiteral("xterm"),
                        QStringList() << QStringLiteral("-e") << QStringLiteral("bash -c") << bashCmd)) {
                        qWarning() << "PlasmaHelper::RunCommandInTerminal: started via xterm";
                    return true;
                        }

                        // Final fallback: bash -lc (may not open visible terminal)
                        bool ok = QProcess::startDetached(QStringLiteral("bash"), QStringList() << QStringLiteral("-lc") << bashCmd);
                        qWarning() << "PlasmaHelper::RunCommandInTerminal: fallback bash -lc started ok=" << ok;
                        return ok;
    }
    #endif
}

QVariantMap PlasmaHelper::ParseDesktop(const QString &filePath)
{
    QVariantMap out;
    QString txt = ReadDesktop(filePath);
    if (txt.isEmpty()) return out;

    QStringList lines = txt.split(QRegularExpression("\r?\n"));
    bool inDesktop = false;
    for (const QString &l0 : lines) {
        QString l = l0.trimmed();
        if (l == QLatin1String("[Desktop Entry]")) { inDesktop = true; continue; }
        if (!inDesktop) continue;
        if (l.isEmpty() || l.startsWith('#')) continue;
        int idx = l.indexOf('=');
        if (idx < 0) continue;
        QString k = l.left(idx).trimmed();
        QString v = l.mid(idx + 1).trimmed();
        if (k == QLatin1String("Name") && !out.contains("Name")) out["Name"] = v;
        else if (k == QLatin1String("Exec") && !out.contains("Exec")) out["Exec"] = v.split(QRegularExpression("\\s+")).first();
        else if (k == QLatin1String("Icon") && !out.contains("Icon")) out["Icon"] = v;
        else if (k == QLatin1String("NoDisplay") && (v == QLatin1String("true") || v == QLatin1String("1"))) out["NoDisplay"] = true;
    }
    return out;
}
