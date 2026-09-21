#pragma once
#include <QObject>
#include <QProcess>
#include <QJsonObject>
#include <QMap>

/**
 * PythonBridge — runs Python scripts as child processes and provides
 * bidirectional JSON-lines communication over stdin/stdout.
 *
 * Usage:
 *   bridge->launch("survey_planner", "/path/to/survey_planner.py", {"-p", "polygon.json"});
 *   bridge->send("survey_planner", {{"cmd","generate"},{"spacing_m",25}});
 *   connect(bridge, &PythonBridge::dataReceived, ...);
 */
class PythonBridge : public QObject
{
    Q_OBJECT
public:
    explicit PythonBridge(QObject *parent = nullptr);
    ~PythonBridge() override;

    Q_INVOKABLE void launch(const QString &name,
                             const QString &scriptPath,
                             const QStringList &args = {});
    Q_INVOKABLE void send(const QString &name, const QJsonObject &obj);
    Q_INVOKABLE void stop(const QString &name);
    Q_INVOKABLE bool isRunning(const QString &name) const;
    Q_INVOKABLE QStringList runningScripts() const;

signals:
    void dataReceived(const QString &scriptName, const QJsonObject &data);
    void scriptError(const QString &scriptName, const QString &error);
    void scriptStarted(const QString &scriptName);
    void scriptFinished(const QString &scriptName, int exitCode);

private slots:
    void onReadyReadStdout();
    void onReadyReadStderr();
    void onFinished(int exitCode, QProcess::ExitStatus status);

private:
    QMap<QString, QProcess*> m_processes;
    QMap<QProcess*, QString> m_processNames;
    QMap<QProcess*, QByteArray> m_lineBuffers;
};
