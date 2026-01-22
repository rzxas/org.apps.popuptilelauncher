#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

class PlasmaHelper : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.apps.PlasmaHelper")
public:
    explicit PlasmaHelper(QObject *parent = nullptr);

public slots:
    QString ReadDesktop(const QString &filePath);
    bool RunDesktop(const QString &filePath);
    bool RunCommand(const QString &cmd);
    bool RunCommandInTerminal(const QString &cmd, const QString &workingDir);
    QVariantMap ParseDesktop(const QString &filePath);
    bool StartUnit(const QString &unitName);
    bool StopUnit(const QString &unitName);
    QString ResolveIcon(const QString &nameOrPath);
    QString ReadInstanceFile(const QString &instanceKey);
    bool WriteInstanceFile(const QString &instanceKey, const QString &content);
    bool RemoveInstanceFile(const QString &instanceKey);
    QStringList ListInstanceFiles();
    bool EnsureInstanceFile(const QString &instanceKey);
};
