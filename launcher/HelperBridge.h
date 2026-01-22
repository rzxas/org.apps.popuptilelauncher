#pragma once
#include <QObject>
#include <QString>
#include <QVariantMap>

class HelperBridge : public QObject
{
    Q_OBJECT
public:
    explicit HelperBridge(QObject *parent = nullptr);

    // Q_INVOKABLE — acess from QML
    Q_INVOKABLE QString readDesktop(const QString &filePath);
    Q_INVOKABLE bool runDesktop(const QString &filePath);
    Q_INVOKABLE bool runCommand(const QString &cmd);
    Q_INVOKABLE bool runCommandInTerminal(const QString &cmd, const QString &workingDir);
    Q_INVOKABLE QVariantMap parseDesktop(const QString &filePath);
    Q_INVOKABLE bool startUnit(const QString &unitName);
    Q_INVOKABLE bool stopUnit(const QString &unitName);
    Q_INVOKABLE QString resolveIcon(const QString &nameOrPath);
    Q_INVOKABLE QString readInstanceFile(const QString &instanceKey);
    Q_INVOKABLE bool writeInstanceFile(const QString &instanceKey, const QString &content);
    Q_INVOKABLE bool removeInstanceFile(const QString &instanceKey);
    Q_INVOKABLE QStringList listInstanceFiles();
    Q_INVOKABLE bool ensureInstanceFile(const QString &instanceKey);

private:
    QString normalizePath(const QString &p) const;
};
