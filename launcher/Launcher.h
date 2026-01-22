#pragma once
#include <QObject>
#include <QVariantMap>

class Launcher : public QObject {
    Q_OBJECT
public:
    explicit Launcher(QObject *parent = nullptr);
    Q_INVOKABLE QVariantMap readDesktop(const QString &path);
    Q_INVOKABLE bool runDesktop(const QString &path);
};
