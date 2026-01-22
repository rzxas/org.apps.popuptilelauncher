#include "Launcher.h"
#include <QFile>
#include <QProcess>
#include <QFileInfo>
#include <QVariantMap>
#include <KDesktopFile>
#include <KConfigGroup>
#include <QDebug>

#if 1
// We expect KF6::Service and KF6::KIO to be available via CMake for the launcher target.
// If they are available, include the headers to use KService + ApplicationLauncherJob.
#include <KService>
#include <KIO/ApplicationLauncherJob>
#endif

Launcher::Launcher(QObject *parent) : QObject(parent) {}

QVariantMap Launcher::readDesktop(const QString &path) {
    QVariantMap out;
    out["file"] = path;
    if (path.isEmpty()) return out;
    QFile f(path);
    if (!f.exists()) return out;

    KDesktopFile df(path);
    KConfigGroup g = df.desktopGroup();
    QString name = g.readEntry("Name", QString());
    QString exec = g.readEntry("Exec", QString());
    QString icon = g.readEntry("Icon", QString());
    out["name"] = name;
    out["exec"] = exec;
    out["icon"] = icon;
    return out;
}

bool Launcher::runDesktop(const QString &path) {
    if (path.isEmpty()) return false;
    QFile f(path);
    if (!f.exists()) return false;

    // Try to launch via KService + KIO job (recommended in KDE session).
    // This properly handles .desktop semantics, tokens, mime and environment.
    // serviceByDesktopPath returns a KService::Ptr for the .desktop entry.
    KService::Ptr service = KService::serviceByDesktopPath(path);
    if (service) {
        qWarning() << "Launcher::runDesktop: launching via KService:" << service->entryPath();
        KIO::ApplicationLauncherJob *job = new KIO::ApplicationLauncherJob(service);
        job->setRunFlags(KIO::ApplicationLauncherJob::RunFlags());
        job->start();
        return true;
    }

    // Fallback: try to read Exec and spawn program without shell.
    KDesktopFile df(path);
    KConfigGroup g = df.desktopGroup();
    QString execLine = g.readEntry("Exec", QString()).trimmed();
    if (execLine.isEmpty()) {
        // No Exec, fallback to xdg-open on the .desktop file
        qWarning() << "Launcher::runDesktop: no Exec, falling back to xdg-open for" << path;
        return QProcess::startDetached(QStringLiteral("xdg-open"), QStringList() << path);
    }

    QStringList parts = QProcess::splitCommand(execLine);
    if (parts.isEmpty()) {
        qWarning() << "Launcher::runDesktop: Exec parse empty, fallback to xdg-open for" << path;
        return QProcess::startDetached(QStringLiteral("xdg-open"), QStringList() << path);
    }

    QString program = parts.first();
    QStringList args = parts.mid(1);
    // Remove desktop tokens like %u %f etc.
    for (int i = args.count() - 1; i >= 0; --i) {
        if (args[i].startsWith('%')) args.removeAt(i);
    }

    qWarning() << "Launcher::runDesktop: fallback startDetached program=" << program << " args=" << args;
    if (QProcess::startDetached(program, args)) return true;

    // Final fallback: xdg-open the .desktop
    qWarning() << "Launcher::runDesktop: startDetached failed, final fallback xdg-open for" << path;
    return QProcess::startDetached(QStringLiteral("xdg-open"), QStringList() << path);
}
