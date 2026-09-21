#include "PythonBridge.h"
#include <QJsonDocument>
#include <QJsonParseError>
#include <QDebug>

PythonBridge::PythonBridge(QObject *parent) : QObject(parent) {}

PythonBridge::~PythonBridge()
{
    for (auto *proc : m_processes)
        proc->kill();
}

void PythonBridge::launch(const QString &name, const QString &scriptPath,
                           const QStringList &args)
{
    if (m_processes.contains(name)) {
        qWarning() << "PythonBridge: already running" << name;
        return;
    }

    auto *proc = new QProcess(this);
    m_processes[name] = proc;
    m_processNames[proc] = name;
    m_lineBuffers[proc] = QByteArray();

    QObject::connect(proc, &QProcess::readyReadStandardOutput,
                     this, &PythonBridge::onReadyReadStdout);
    QObject::connect(proc, &QProcess::readyReadStandardError,
                     this, &PythonBridge::onReadyReadStderr);
    QObject::connect(proc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
                     this, &PythonBridge::onFinished);

    QStringList fullArgs = {scriptPath};
    fullArgs += args;
    proc->start("python3", fullArgs);

    if (!proc->waitForStarted(3000)) {
        qWarning() << "PythonBridge: failed to start" << scriptPath;
        emit scriptError(name, "Failed to start process");
        return;
    }

    qDebug() << "PythonBridge: launched" << name << scriptPath;
    emit scriptStarted(name);
}

void PythonBridge::send(const QString &name, const QJsonObject &obj)
{
    if (!m_processes.contains(name)) {
        qWarning() << "PythonBridge: not running" << name;
        return;
    }
    QByteArray line = QJsonDocument(obj).toJson(QJsonDocument::Compact) + "\n";
    m_processes[name]->write(line);
}

void PythonBridge::stop(const QString &name)
{
    if (!m_processes.contains(name)) return;
    m_processes[name]->terminate();
}

bool PythonBridge::isRunning(const QString &name) const
{
    return m_processes.contains(name) &&
           m_processes[name]->state() == QProcess::Running;
}

QStringList PythonBridge::runningScripts() const
{
    QStringList result;
    for (auto it = m_processes.begin(); it != m_processes.end(); ++it)
        if (it.value()->state() == QProcess::Running)
            result << it.key();
    return result;
}

void PythonBridge::onReadyReadStdout()
{
    auto *proc = qobject_cast<QProcess*>(sender());
    if (!proc) return;
    const QString name = m_processNames.value(proc);

    m_lineBuffers[proc] += proc->readAllStandardOutput();

    // Parse complete JSON lines
    while (true) {
        int nl = m_lineBuffers[proc].indexOf('\n');
        if (nl < 0) break;
        QByteArray line = m_lineBuffers[proc].left(nl).trimmed();
        m_lineBuffers[proc] = m_lineBuffers[proc].mid(nl + 1);

        if (line.isEmpty()) continue;

        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(line, &err);
        if (err.error != QJsonParseError::NoError) {
            qWarning() << "PythonBridge: JSON parse error from" << name << ":" << line;
            continue;
        }
        emit dataReceived(name, doc.object());
    }
}

void PythonBridge::onReadyReadStderr()
{
    auto *proc = qobject_cast<QProcess*>(sender());
    if (!proc) return;
    const QString name = m_processNames.value(proc);
    QString msg = QString::fromUtf8(proc->readAllStandardError()).trimmed();
    if (!msg.isEmpty()) {
        qWarning() << "[Python:" << name << "]" << msg;
        emit scriptError(name, msg);
    }
}

void PythonBridge::onFinished(int exitCode, QProcess::ExitStatus)
{
    auto *proc = qobject_cast<QProcess*>(sender());
    if (!proc) return;
    const QString name = m_processNames.take(proc);
    m_processes.remove(name);
    m_lineBuffers.remove(proc);
    proc->deleteLater();
    qDebug() << "PythonBridge:" << name << "exited with code" << exitCode;
    emit scriptFinished(name, exitCode);
}
