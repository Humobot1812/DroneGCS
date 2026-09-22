#include "AiAssistant.h"
#include "DroneManager.h"
#include "DroneVehicle.h"
#include "AudioAnnunciator.h"
#include "AppSettings.h"

#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QRegularExpression>
#include <QSslSocket>
#include <QProcess>
#include <QDebug>

AiAssistant::AiAssistant(DroneManager *droneManager, AudioAnnunciator *audioAnnunciator, AppSettings *appSettings, QObject *parent)
    : QObject(parent)
    , m_droneManager(droneManager)
    , m_audioAnnunciator(audioAnnunciator)
    , m_appSettings(appSettings)
    , m_netManager(new QNetworkAccessManager(this))
    , m_thinkingTimer(new QTimer(this))
    , m_hazardCountdownTimer(new QTimer(this))
{
    if (m_appSettings) {
        connect(m_appSettings, &AppSettings::geminiApiKeyChanged, this, &AiAssistant::geminiStatusChanged);
    }

    m_thinkingTimer->setInterval(100);
    connect(m_thinkingTimer, &QTimer::timeout, this, &AiAssistant::onThinkingTimerTick);

    m_hazardCountdownTimer->setInterval(100);
    connect(m_hazardCountdownTimer, &QTimer::timeout, this, &AiAssistant::onHazardTimerTick);

    // Initial welcome message from AI Copilot
    QString welcome = hasGeminiKey() 
        ? "Tactical AI Copilot online. Powered by Google Gemini AI & Local Autonomous Engine with complete UAV and GCS control permissions."
        : "Tactical AI Copilot online. Operating with Local Autonomous Engine. Add a Gemini API Key in Settings for generative multi-turn reasoning.";
    addMessage("ai", welcome, "ONLINE", true);
}

DroneVehicle* AiAssistant::activeDrone() const
{
    if (!m_droneManager) return nullptr;
    return m_droneManager->activeDrone();
}

bool AiAssistant::hasGeminiKey() const
{
    if (!m_appSettings) return false;
    return m_appSettings->hasGeminiKey();
}

bool AiAssistant::isGeminiActive() const
{
    return hasGeminiKey();
}

void AiAssistant::setGeminiApiKey(const QString &key)
{
    if (m_appSettings) {
        m_appSettings->setGeminiApiKey(key);
        m_appSettings->save();
        emit geminiStatusChanged();
        addMessage("ai", "Google Gemini AI API Key updated. Full cognitive copilot active.", "GEMINI_CONFIG", true);
    }
}

QString AiAssistant::getGeminiApiKey() const
{
    return m_appSettings ? m_appSettings->geminiApiKey() : QString();
}

void AiAssistant::addMessage(const QString &role, const QString &text, const QString &actionTag, bool success)
{
    QVariantMap map;
    map["role"] = role;
    map["text"] = text;
    map["actionTag"] = actionTag;
    map["success"] = success;
    map["time"] = QDateTime::currentDateTime().toString("HH:mm:ss");

    m_conversationHistory.append(map);
    if (m_conversationHistory.size() > 100) {
        m_conversationHistory.removeFirst();
    }
    emit conversationHistoryChanged();
}

void AiAssistant::respondAndSpeak(const QString &replyText, const QString &actionTag, bool success)
{
    addMessage("ai", replyText, actionTag, success);
    m_lastSpokenResponse = replyText;
    emit lastSpokenResponseChanged();

    if (m_audioAnnunciator) {
        m_audioAnnunciator->say(replyText, true);
    }
    emit commandExecuted(actionTag, success, replyText);
}

void AiAssistant::onThinkingTimerTick()
{
    if (!m_isProcessing) {
        m_thinkingTimer->stop();
        return;
    }

    m_thinkingElapsedMs += 100;
    emit thinkingElapsedMsChanged();

    QString newPhase;
    if (m_thinkingElapsedMs < 2000) {
        newPhase = "Analyzing live SITREP & calculating trajectory...";
    } else if (m_thinkingElapsedMs < 4000) {
        newPhase = "Synthesizing spatial constraints & vehicle dynamics...";
    } else if (m_thinkingElapsedMs < 6500) {
        newPhase = "Evaluating safety interlocks & mission parameters...";
    } else {
        newPhase = "Synthesizing flight control payload & tactical commands...";
    }

    if (newPhase != m_thinkingPhase) {
        m_thinkingPhase = newPhase;
        emit thinkingPhaseChanged();
    }
}

void AiAssistant::onHazardTimerTick()
{
    if (!m_hasPendingHazardAction) {
        m_hazardCountdownTimer->stop();
        return;
    }

    m_pendingHazardRemainingMs -= 100;
    if (m_pendingHazardRemainingMs <= 0) {
        m_hazardCountdownTimer->stop();
        QString act = m_pendingHazardAction;
        QString param = m_pendingHazardParam;
        m_hasPendingHazardAction = false;
        m_pendingHazardAction.clear();
        m_pendingHazardParam.clear();
        m_pendingHazardRemainingMs = 3000;
        emit pendingHazardActionChanged();

        executePhysicalAction(act, param);
    } else {
        emit pendingHazardActionChanged();
    }
}

void AiAssistant::scheduleHazardousAction(const QString &action, const QString &param)
{
    m_hasPendingHazardAction = true;
    m_pendingHazardAction = action;
    m_pendingHazardParam = param;
    m_pendingHazardRemainingMs = 3000;
    m_hazardCountdownTimer->start();
    emit pendingHazardActionChanged();

    QString spokenAct = action;
    spokenAct.replace("_", " ");
    if (m_audioAnnunciator) {
        m_audioAnnunciator->say(QString("Warning! Hazardous action %1 requested. Three seconds to abort.").arg(spokenAct), true);
    }
    addMessage("ai", QString("⚠️ HAZARDOUS ACTION REQUESTED: %1. 3.0s safety countdown initiated. Click ABORT or press ESC to cancel.").arg(action), "HAZARD_ALERT", false);
}

void AiAssistant::abortHazardAction()
{
    if (!m_hasPendingHazardAction) return;

    m_hazardCountdownTimer->stop();
    QString act = m_pendingHazardAction;
    m_hasPendingHazardAction = false;
    m_pendingHazardAction.clear();
    m_pendingHazardParam.clear();
    m_pendingHazardRemainingMs = 3000;
    emit pendingHazardActionChanged();

    if (m_audioAnnunciator) {
        m_audioAnnunciator->say("Command aborted by operator.", true);
    }
    addMessage("ai", QString("⛔ Action %1 ABORTED by operator.").arg(act), "ABORTED", true);
}

void AiAssistant::confirmHazardActionNow()
{
    if (!m_hasPendingHazardAction) return;

    m_hazardCountdownTimer->stop();
    QString act = m_pendingHazardAction;
    QString param = m_pendingHazardParam;
    m_hasPendingHazardAction = false;
    m_pendingHazardAction.clear();
    m_pendingHazardParam.clear();
    m_pendingHazardRemainingMs = 3000;
    emit pendingHazardActionChanged();

    executePhysicalAction(act, param);
}

void AiAssistant::clearHistory()
{
    m_conversationHistory.clear();
    addMessage("ai", "Tactical AI Copilot logs cleared. Standing by for flight commands.", "CLEAR", true);
    emit conversationHistoryChanged();
}

void AiAssistant::executeQuickAction(const QString &action)
{
    processCommand(action);
}

// ─────────────────────────────────────────────────────────────────────────────
// TELEMETRY CONTEXT BUILDER (Supplies live GCS & UAV status to Gemini AI)
// ─────────────────────────────────────────────────────────────────────────────
QString AiAssistant::buildFullUavTelemetryContext() const
{
    DroneVehicle *drone = activeDrone();
    QString ctx = "=== LIVE GCS & UAV SITREP ===\n";

    if (!drone || !drone->isConnected()) {
        ctx += "Aircraft Connection: NO ACTIVE VEHICLE CONNECTED.\n";
        ctx += "GCS State: Ready to connect via UDP 14550, TCP, or Serial.\n";
        return ctx;
    }

    ctx += QString("Aircraft Name: %1 (System ID: %2)\n").arg(drone->name()).arg(drone->sysId());
    ctx += QString("Vehicle Frame: %1\n").arg(drone->vehicleType().isEmpty() ? "Quadrotor" : drone->vehicleType());
    ctx += QString("Autopilot Type: %1\n").arg(drone->autopilotType());
    ctx += QString("Motor Status: %1\n").arg(drone->isArmed() ? "ARMED (PROPELLERS SPINNING)" : "DISARMED (SAFE)");
    ctx += QString("Current Flight Mode: %1\n").arg(drone->flightMode());

    ctx += QString("Position & Altitude: Lat %1, Lon %2 | Rel Alt: %3 m | MSL Alt: %4 m\n")
               .arg(drone->latitude(), 0, 'f', 6)
               .arg(drone->longitude(), 0, 'f', 6)
               .arg(drone->relAltitude(), 0, 'f', 1)
               .arg(drone->altitude(), 0, 'f', 1);

    ctx += QString("Kinematics: Groundspeed %1 m/s (%2 km/h) | Airspeed %3 m/s | Climb Rate %4 m/s | Heading %5 deg\n")
               .arg(drone->groundSpeed(), 0, 'f', 1)
               .arg(drone->groundSpeed() * 3.6, 0, 'f', 1)
               .arg(drone->airSpeed(), 0, 'f', 1)
               .arg(drone->climbRate(), 0, 'f', 1)
               .arg(drone->headingDeg(), 0, 'f', 1);

    ctx += QString("Attitude Angles: Roll %1 deg | Pitch %2 deg | Yaw %3 deg\n")
               .arg(drone->roll(), 0, 'f', 1)
               .arg(drone->pitch(), 0, 'f', 1)
               .arg(drone->yaw(), 0, 'f', 1);

    ctx += QString("GPS Telemetry: Fix Type %1 | Satellites %2 | HDOP %3\n")
               .arg(drone->gpsFixType())
               .arg(drone->gpsSats())
               .arg(drone->gpsHDOP(), 0, 'f', 2);

    int estMin = drone->batteryPercent() * 25 / 100;
    ctx += QString("Battery Power: %1 V | Remaining %2 % | Est. Remaining %3 min\n")
               .arg(drone->batteryVoltage(), 0, 'f', 2)
               .arg(drone->batteryPercent())
               .arg(estMin);

    ctx += QString("Safety Geofence: Status %1 | Circular Fence %2 | Radius %3 m | Ceiling %4 m | Breach Status: %5\n")
               .arg(drone->geofenceEnabled() ? "ENABLED" : "DISABLED")
               .arg(drone->circularFenceEnabled() ? "ACTIVE" : "OFF")
               .arg(drone->geofenceRadius(), 0, 'f', 0)
               .arg(drone->geofenceMaxAlt(), 0, 'f', 0)
               .arg(drone->geofenceBreached() ? QString("BREACHED (%1)").arg(drone->geofenceBreachReason()) : "NOMINAL");

    ctx += QString("Autonomous Mission: Waypoint Count %1 | Current WP %2\n")
               .arg(drone->missionTotal())
               .arg(drone->missionCurrent());

    return ctx;
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMAND PROCESSING ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────
void AiAssistant::processCommand(const QString &input)
{
    QString trimmed = input.trimmed();
    if (trimmed.isEmpty()) return;

    // Record user command in chat history
    addMessage("user", trimmed);

    // If Gemini API Key is configured and valid, use Gemini AI
    if (hasGeminiKey()) {
        sendGeminiRequest(trimmed);
    } else {
        // Instant local autonomous processing
        executeLocalAutonomousCommand(trimmed);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// GOOGLE GEMINI AI API CLIENT
// ─────────────────────────────────────────────────────────────────────────────
void AiAssistant::sendGeminiRequest(const QString &input)
{
    if (!m_appSettings || !m_netManager) {
        executeLocalAutonomousCommand(input);
        return;
    }

    QString apiKey = m_appSettings->geminiApiKey();
    if (apiKey.isEmpty()) {
        executeLocalAutonomousCommand(input);
        return;
    }

    m_isProcessing = true;
    emit isProcessingChanged();

    QString model = m_appSettings->geminiModel();
    if (model.isEmpty() || model.contains("2.0") || model.contains("1.5") || model.contains("2.5")) {
        model = "gemini-3.6-flash";
    }

    // Construct Gemini System Instruction with Full UAV Context & Permissions
    QString systemPrompt =
        "You are the Tactical Autonomous AI Flight Copilot embedded inside the DRONE_GCS Unmanned Aerial Vehicle Ground Control Station.\n"
        "You have COMPLETE ACCESS and FULL AUTONOMOUS PERMISSION to command the drone, execute maneuvers, arm/disarm motors, alter geofences, trigger missions, and control GCS displays.\n"
        "Whatever the pilot asks or instructs you to do in any phrasing or language, you must acknowledge and execute it immediately.\n\n"
        + buildFullUavTelemetryContext() +
        "\n\nSTRICT JSON RESPONSE SPECIFICATION:\n"
        "You must respond ONLY with a raw JSON object (no markdown, no backticks) matching this exact format:\n"
        "{\n"
        "  \"reply\": \"<Concise tactical audio confirmation to speak aloud to pilot (1-2 sentences, military/aviation style)>\",\n"
        "  \"actions\": [\n"
        "    {\"action\": \"<ACTION_NAME>\", \"param\": \"<PARAM_VALUE>\"}\n"
        "  ]\n"
        "}\n\n"
        "SUPPORTED ACTION CODES:\n"
        "- \"ARM\": Arm drone propulsion motors (param: \"\")\n"
        "- \"DISARM\": Disarm drone motors (param: \"\")\n"
        "- \"TAKEOFF\": Take off to target altitude (param: altitude in meters as integer string e.g. \"15\" or \"25\")\n"
        "- \"LAND\": Initiate autonomous landing immediately (param: \"\")\n"
        "- \"RTL\": Return to launch home immediately and land (param: \"\")\n"
        "- \"EMERGENCY_KILL\": Immediately cut all motor power (param: \"\")\n"
        "- \"SET_MODE\": Change flight mode (param: \"GUIDED\", \"AUTO\", \"LOITER\", \"STABILIZE\", \"POSHOLD\", \"BRAKE\", \"RTL\", \"LAND\")\n"
        "- \"GEOFENCE_ENABLE\": Enable geofence enforcement (param: \"true\")\n"
        "- \"GEOFENCE_DISABLE\": Disable geofence enforcement (param: \"\")\n"
        "- \"GEOFENCE_RADIUS\": Set circular geofence radius (param: radius in meters, e.g. \"50\")\n"
        "- \"GEOFENCE_ACTION\": Set action on fence breach (param: \"LAND\", \"RTL\", \"LOITER\", \"WARN\")\n"
        "- \"GEOFENCE_MIN_ALT\": Set minimum altitude floor for geofence (param: altitude in meters, e.g. \"0\" or \"5\")\n"
        "- \"GEOFENCE_MAX_ALT\": Set maximum altitude ceiling for geofence (param: altitude in meters, e.g. \"120\")\n"
        "- \"MISSION_START\": Start or resume autonomous waypoint mission (param: \"\")\n"
        "- \"MISSION_PAUSE\": Pause autonomous waypoint mission (param: \"\")\n"
        "- \"CLEAR_MISSION\": Clear all loaded waypoints (param: \"\")\n"
        "- \"NAVIGATE_PAGE\": Switch GCS view (param: \"0\"=Map, \"1\"=Mission, \"2\"=Parameters, \"3\"=Video)\n"
        "- \"TOGGLE_PIP\": Toggle picture-in-picture video stream (param: \"\")\n"
        "- \"OPEN_LOGS\": Open flight log recorder and CSV export dialog (param: \"\")\n"
        "- \"OPEN_SETTINGS\": Open GCS configuration dialog (param: \"\")\n"
        "- \"RUN_PREFLIGHT\": Run pre-flight sensor checklist (param: \"\")\n"
        "- \"NONE\": For telemetry queries, status reports, questions, or advisory answers without physical drone actuation.\n\n"
        "CRITICAL RULES:\n"
        "1. DISTINGUISH QUERIES FROM COMMANDS: If the pilot asks a question (e.g. 'what is geofence altitude range', 'what is the battery status', 'how high is the drone'), formulate a precise answer in 'reply' from the SITREP and set action to 'NONE'. DO NOT ACTUATE THE DRONE OR MODIFY SETTINGS ON QUERIES!\n"
        "2. GEOFENCE CONFIGURATION vs IMMEDIATE FLIGHT: When the pilot configures geofence failsafe (e.g. 'if drone breaches geofence it should RTL' or 'set breach action to Land'), use 'GEOFENCE_ACTION' with param 'RTL' or 'LAND'. NEVER execute an immediate 'RTL' or 'LAND' action when setting up geofence rules!\n"
        "3. COMPOUND INSTRUCTIONS: If a command asks for multiple configurations, include ALL matching actions in the 'actions' array.\n";

    QJsonObject systemInstructionObj;
    QJsonArray sysParts;
    QJsonObject sysPart;
    sysPart["text"] = systemPrompt;
    sysParts.append(sysPart);
    systemInstructionObj["parts"] = sysParts;

    QJsonObject userContent;
    userContent["role"] = "user";
    QJsonArray userParts;
    QJsonObject userPart;
    userPart["text"] = input;
    userParts.append(userPart);
    userContent["parts"] = userParts;

    QJsonArray contentsArray;
    contentsArray.append(userContent);

    QJsonObject genConfig;
    genConfig["temperature"] = 0.2;
    genConfig["responseMimeType"] = "application/json";

    QJsonObject rootPayload;
    rootPayload["systemInstruction"] = systemInstructionObj;
    rootPayload["contents"] = contentsArray;
    rootPayload["generationConfig"] = genConfig;

    QJsonDocument doc(rootPayload);
    QByteArray postData = doc.toJson(QJsonDocument::Compact);

    // Start thinking telemetry reasoning pulse
    m_isProcessing = true;
    m_thinkingElapsedMs = 0;
    m_thinkingPhase = "Analyzing live SITREP & calculating trajectory...";
    m_thinkingTimer->start();
    emit isProcessingChanged();
    emit thinkingPhaseChanged();
    emit thinkingElapsedMsChanged();

    // If Qt runtime doesn't have SSL support loaded, use asynchronous curl transport immediately
    if (!QSslSocket::supportsSsl()) {
        qInfo() << "AiAssistant: Qt QSslSocket reports no SSL support. Using asynchronous curl transport.";
        sendGeminiViaCurl(input, apiKey, model, postData);
        return;
    }

    QString urlStr = QString("https://generativelanguage.googleapis.com/v1beta/models/%1:generateContent?key=%2")
                         .arg(model, apiKey);

    QNetworkRequest request;
    request.setUrl(QUrl(urlStr));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QNetworkReply *reply = m_netManager->post(request, postData);
    connect(reply, &QNetworkReply::finished, this, [this, reply, input, apiKey, model, postData]() {
        onGeminiReplyFinished(reply, input);
    });
}

void AiAssistant::sendGeminiViaCurl(const QString &input, const QString &apiKey, const QString &model, const QByteArray &postData)
{
    m_isProcessing = true;
    if (!m_thinkingTimer->isActive()) {
        m_thinkingElapsedMs = 0;
        m_thinkingPhase = "Analyzing live SITREP & calculating trajectory...";
        m_thinkingTimer->start();
        emit thinkingPhaseChanged();
        emit thinkingElapsedMsChanged();
    }
    emit isProcessingChanged();

    QString urlStr = QString("https://generativelanguage.googleapis.com/v1beta/models/%1:generateContent?key=%2")
                         .arg(model, apiKey);

    QProcess *proc = new QProcess(this);
    QStringList args;
    args << "-s" << "-X" << "POST"
         << "-H" << "Content-Type: application/json"
         << "--data-binary" << "@-"
         << urlStr;

    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [this, proc, input](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitStatus);
        m_isProcessing = false;
        m_thinkingTimer->stop();
        emit isProcessingChanged();

        QByteArray output = proc->readAllStandardOutput();
        proc->deleteLater();

        if (exitCode == 0 && !output.isEmpty()) {
            processGeminiJsonResponse(output, input);
        } else {
            qWarning() << "AiAssistant: curl transport failed (exit code:" << exitCode << "). Using local fallback.";
            executeLocalAutonomousCommand(input);
        }
    });

    proc->start("curl", args);
    proc->write(postData);
    proc->closeWriteChannel();
}

void AiAssistant::onGeminiReplyFinished(QNetworkReply *reply, const QString &originalInput)
{
    m_isProcessing = false;
    m_thinkingTimer->stop();
    emit isProcessingChanged();

    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "AiAssistant: Gemini QNetworkReply error:" << reply->errorString()
                   << "HTTP status:" << reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        // If network reply failed, try curl transport as reliable fallback
        QString apiKey = m_appSettings ? m_appSettings->geminiApiKey() : "";
        QString model = m_appSettings ? m_appSettings->geminiModel() : "gemini-3.6-flash";
        if (model.isEmpty() || model.contains("2.0") || model.contains("1.5") || model.contains("2.5")) {
            model = "gemini-3.6-flash";
        }
        if (!apiKey.isEmpty()) {
            qInfo() << "AiAssistant: Retrying Gemini request via asynchronous curl transport...";
            
            // Build minimal payload for curl retry
            QJsonObject genConfig;
            genConfig["temperature"] = 0.2;
            genConfig["responseMimeType"] = "application/json";

            QJsonObject rootPayload;
            QJsonObject userContent;
            userContent["role"] = "user";
            QJsonArray userParts;
            QJsonObject userPart;
            userPart["text"] = originalInput;
            userParts.append(userPart);
            userContent["parts"] = userParts;

            QJsonArray contentsArray;
            contentsArray.append(userContent);
            rootPayload["contents"] = contentsArray;
            rootPayload["generationConfig"] = genConfig;

            sendGeminiViaCurl(originalInput, apiKey, model, QJsonDocument(rootPayload).toJson(QJsonDocument::Compact));
            return;
        }

        executeLocalAutonomousCommand(originalInput);
        return;
    }

    QByteArray responseData = reply->readAll();
    processGeminiJsonResponse(responseData, originalInput);
}

void AiAssistant::processGeminiJsonResponse(const QByteArray &responseData, const QString &originalInput)
{
    QJsonDocument doc = QJsonDocument::fromJson(responseData);
    if (!doc.isObject()) {
        qWarning() << "AiAssistant: Invalid JSON received from Gemini:" << responseData.left(200);
        executeLocalAutonomousCommand(originalInput);
        return;
    }

    QJsonObject rootObj = doc.object();
    QJsonArray candidates = rootObj["candidates"].toArray();
    if (candidates.isEmpty()) {
        qWarning() << "AiAssistant: No candidates in Gemini response:" << responseData.left(200);
        executeLocalAutonomousCommand(originalInput);
        return;
    }

    QJsonObject firstCandidate = candidates[0].toObject();
    QJsonObject contentObj = firstCandidate["content"].toObject();
    QJsonArray parts = contentObj["parts"].toArray();
    if (parts.isEmpty()) {
        executeLocalAutonomousCommand(originalInput);
        return;
    }

    QString rawText = parts[0].toObject()["text"].toString().trimmed();
    
    // Strip markdown fences if present
    if (rawText.startsWith("```json")) {
        rawText = rawText.mid(7);
    } else if (rawText.startsWith("```")) {
        rawText = rawText.mid(3);
    }
    if (rawText.endsWith("```")) {
        rawText.chop(3);
    }
    rawText = rawText.trimmed();

    QJsonDocument innerDoc = QJsonDocument::fromJson(rawText.toUtf8());
    if (!innerDoc.isObject()) {
        respondAndSpeak(rawText, "GEMINI_REPLY", true);
        return;
    }

    QJsonObject parsed = innerDoc.object();
    QString replyText = parsed["reply"].toString();
    QJsonArray actions = parsed["actions"].toArray();

    QString primaryAction = "GEMINI_AI";
    if (!actions.isEmpty()) {
        primaryAction = actions[0].toObject()["action"].toString().toUpper();
    }

    // Execute every action commanded by Gemini
    for (const QJsonValue &val : actions) {
        QJsonObject act = val.toObject();
        QString actionName = act["action"].toString();
        QString param = act["param"].toString();
        executeAction(actionName, param);
    }

    if (replyText.isEmpty()) {
        replyText = "Command processed and executed successfully by Gemini Copilot.";
    }

    respondAndSpeak(replyText, primaryAction, true);
}

// ─────────────────────────────────────────────────────────────────────────────
// PHYSICAL ACTION DISPATCHER ACROSS DRONE & GCS
// ─────────────────────────────────────────────────────────────────────────────
void AiAssistant::executeAction(const QString &action, const QString &param)
{
    QString act = action.trimmed().toUpper().replace("-", "_");
    DroneVehicle *drone = activeDrone();

    bool isHazardous = (act == "EMERGENCY_KILL" || act == "KILL" ||
                        (act == "DISARM" && drone && (drone->isArmed() || drone->relAltitude() > 0.8)) ||
                        act == "TAKEOFF" || act == "LAUNCH");

    if (isHazardous) {
        scheduleHazardousAction(act, param);
        return;
    }

    executePhysicalAction(act, param);
}

void AiAssistant::executePhysicalAction(const QString &action, const QString &param)
{
    DroneVehicle *drone = activeDrone();
    QString act = action.trimmed().toUpper().replace("-", "_");

    if (act == "ARM") {
        if (drone) drone->arm();
    } else if (act == "DISARM") {
        if (drone) drone->disarm();
    } else if (act == "TAKEOFF" || act == "LAUNCH") {
        if (drone) {
            double alt = param.toDouble();
            if (alt <= 0.0) alt = 15.0;
            drone->takeoff(alt);
        }
    } else if (act == "LAND") {
        if (drone) drone->land();
    } else if (act == "RTL" || act == "RETURN_TO_LAUNCH" || act == "RETURN_HOME" || act == "RTH") {
        if (drone) drone->returnToLaunch();
    } else if (act == "EMERGENCY_KILL" || act == "KILL") {
        if (drone) drone->emergencyKill();
    } else if (act == "SET_MODE" || act == "MODE") {
        if (drone) drone->setFlightMode(param.toUpper());
    } else if (act == "GEOFENCE_ENABLE" || act == "ENABLE_GEOFENCE" || act == "SET_GEOFENCE_ENABLE") {
        if (drone) {
            drone->setGeofenceEnabled(true);
            drone->setCircularFenceEnabled(true);
        }
    } else if (act == "GEOFENCE_DISABLE" || act == "DISABLE_GEOFENCE" || act == "SET_GEOFENCE_DISABLE") {
        if (drone) drone->setGeofenceEnabled(false);
    } else if (act == "GEOFENCE_RADIUS" || act == "SET_GEOFENCE_RADIUS" || act == "RADIUS") {
        if (drone) {
            double r = param.toDouble();
            if (r >= 5.0) drone->setGeofenceRadius(r);
        }
    } else if (act == "GEOFENCE_ACTION" || act == "SET_GEOFENCE_ACTION") {
        if (drone) {
            QString p = param.toUpper();
            if (p.contains("LAND")) drone->setGeofenceAction(2);
            else if (p.contains("RTL") || p.contains("RETURN")) drone->setGeofenceAction(1);
            else if (p.contains("LOITER") || p.contains("HOLD") || p.contains("BRAKE")) drone->setGeofenceAction(3);
            else if (p.contains("WARN") || p.contains("REPORT") || p.contains("ALERT")) drone->setGeofenceAction(0);
            else {
                bool ok = false;
                int actVal = param.toInt(&ok);
                if (ok) drone->setGeofenceAction(actVal);
            }
        }
    } else if (act == "GEOFENCE_MIN_ALT" || act == "SET_GEOFENCE_MIN_ALT" || act == "SET_GEOFENCE_MIN_ALTITUDE" || act == "MIN_ALT") {
        if (drone) {
            double a = param.toDouble();
            drone->setGeofenceMinAlt(a);
        }
    } else if (act == "GEOFENCE_ALT" || act == "GEOFENCE_MAX_ALT" || act == "SET_GEOFENCE_MAX_ALT" || act == "SET_GEOFENCE_MAX_ALTITUDE" || act == "MAX_ALT") {
        if (drone) {
            double a = param.toDouble();
            if (a >= 5.0) drone->setGeofenceMaxAlt(a);
        }
    } else if (act == "MISSION_START" || act == "START_MISSION") {
        if (drone) drone->startMission();
    } else if (act == "MISSION_PAUSE" || act == "PAUSE_MISSION") {
        if (drone) drone->pauseMission();
    } else if (act == "CLEAR_MISSION" || act == "MISSION_CLEAR") {
        if (drone) drone->clearMission();
    } else if (act == "NAVIGATE_PAGE" || act == "PAGE") {
        emit requestPageNavigation(param.toInt());
    } else if (act == "TOGGLE_PIP" || act == "PIP") {
        emit requestTogglePip();
    } else if (act == "OPEN_LOGS" || act == "LOGS") {
        emit requestOpenFlightLogs();
    } else if (act == "OPEN_SETTINGS" || act == "SETTINGS") {
        emit requestOpenSettings();
    } else if (act == "RUN_PREFLIGHT" || act == "PREFLIGHT") {
        emit requestRunPreflight();
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// LOCAL AUTONOMOUS COMMAND PARSER (Rock-solid Zero-Latency Offline Fallback)
// ─────────────────────────────────────────────────────────────────────────────
void AiAssistant::executeLocalAutonomousCommand(const QString &input)
{
    QString text = input.toLower().trimmed();
    DroneVehicle *drone = activeDrone();

    // ─────────────────────────────────────────────────────────────────────────
    // 0. INFORMATIONAL QUERIES (Never actuate aircraft or mutate config on questions!)
    // ─────────────────────────────────────────────────────────────────────────
    bool isQuery = text.startsWith("what") || text.startsWith("how") || text.startsWith("tell me") ||
                   text.startsWith("status") || text.startsWith("report") || text.startsWith("show me") ||
                   text.contains("?") || text.contains("altitude range") || text.contains("battery status");

    if (isQuery) {
        // Geofence query
        if (text.contains("geofence") || text.contains("fence")) {
            if (!drone) {
                respondAndSpeak("Negative. No drone is currently connected.", "ERROR", false);
                return;
            }
            QString actionStr = "Warning Only";
            if (drone->geofenceAction() == 1) actionStr = "Return to Launch (RTL)";
            else if (drone->geofenceAction() == 2) actionStr = "Immediate Land";
            else if (drone->geofenceAction() == 3) actionStr = "Loiter";

            QString rep = QString("Geofence is %1. Altitude limits: %2m floor to %3m ceiling. Circular radius: %4m. Failsafe action on breach: %5.")
                              .arg(drone->geofenceEnabled() ? "ENABLED" : "DISABLED")
                              .arg(drone->geofenceMinAlt(), 0, 'f', 0)
                              .arg(drone->geofenceMaxAlt(), 0, 'f', 0)
                              .arg(drone->geofenceRadius(), 0, 'f', 0)
                              .arg(actionStr);
            respondAndSpeak(rep, "GEOFENCE_STATUS", true);
            return;
        }

        // Battery query
        if (text.contains("battery") || text.contains("power") || text.contains("voltage") || text.contains("remaining")) {
            if (!drone) { respondAndSpeak("No drone connected.", "ERROR", false); return; }
            int pct = drone->batteryPercent();
            double v = drone->batteryVoltage();
            int remMin = pct * 25 / 100;
            respondAndSpeak(QString("Battery power is at %1 percent (%2 volts). Estimated endurance is %3 minutes remaining.")
                                .arg(pct).arg(v, 0, 'f', 1).arg(remMin), "BATTERY_STATUS", true);
            return;
        }

        // Altitude query
        if (text.contains("altitude") || text.contains("how high") || text.contains("height")) {
            if (!drone) { respondAndSpeak("No drone connected.", "ERROR", false); return; }
            respondAndSpeak(QString("Current altitude is %1 meters relative, %2 meters MSL. Climb rate %3 m/s.")
                                .arg(drone->relAltitude(), 0, 'f', 1)
                                .arg(drone->altitude(), 0, 'f', 1)
                                .arg(drone->climbRate(), 0, 'f', 1), "ALTITUDE_STATUS", true);
            return;
        }

        // Speed query
        if (text.contains("speed") || text.contains("how fast")) {
            if (!drone) { respondAndSpeak("No drone connected.", "ERROR", false); return; }
            respondAndSpeak(QString("Current groundspeed is %1 m/s (%2 km/h). Airspeed %3 m/s.")
                                .arg(drone->groundSpeed(), 0, 'f', 1)
                                .arg(drone->groundSpeed() * 3.6, 0, 'f', 1)
                                .arg(drone->airSpeed(), 0, 'f', 1), "SPEED_STATUS", true);
            return;
        }

        // GPS query
        if (text.contains("gps") || text.contains("satellites") || text.contains("location") || text.contains("coordinate")) {
            if (!drone) { respondAndSpeak("No drone connected.", "ERROR", false); return; }
            respondAndSpeak(QString("GPS fix: %1 with %2 satellites locked. Latitude %3, Longitude %4.")
                                .arg(drone->gpsFixType())
                                .arg(drone->gpsSats())
                                .arg(drone->latitude(), 0, 'f', 6)
                                .arg(drone->longitude(), 0, 'f', 6), "GPS_STATUS", true);
            return;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. EMERGENCY KILL (Highest safety priority)
    // ─────────────────────────────────────────────────────────────────────────
    if (text.contains("emergency kill") || text.contains("kill motor") || text.contains("emergency stop") || text.contains("cut motor")) {
        if (!drone) {
            respondAndSpeak("Negative. No drone is currently connected.", "ERROR", false);
            return;
        }
        drone->emergencyKill();
        respondAndSpeak("Emergency motor kill executed immediately. Propulsion stopped.", "EMERGENCY_KILL", true);
        return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. GEOFENCE CONFIGURATION & SAFETY BOUNDARIES
    // (Evaluated BEFORE standalone flight modes/RTL so compound breach failsafe rules don't abort flight!)
    // ─────────────────────────────────────────────────────────────────────────
    if (text.contains("geofence") || text.contains("geo fence") || (text.contains("fence") && !text.contains("defense")) || text.contains("breach")) {
        if (!drone) {
            respondAndSpeak("Negative. No drone is currently connected.", "ERROR", false);
            return;
        }

        bool isDisable = text.contains("disable") || text.contains("turn off") || text.contains("deactivate");
        if (isDisable && !text.contains("enable") && !text.contains("set") && !text.contains("radius")) {
            drone->setGeofenceEnabled(false);
            respondAndSpeak("Safety geofence perimeter deactivated. Proceed with caution.", "GEOFENCE_OFF", true);
            return;
        }

        // Configure and enable geofence
        drone->setGeofenceEnabled(true);
        drone->setCircularFenceEnabled(true);

        QStringList details;

        // A. Minimum Altitude floor (e.g. "minimum altitude height to 0", "min alt 5m")
        QRegularExpression minRe("(?:minimum|min)\\s*(?:altitude|height)?\\s*(?:to|is|=)?\\s*(\\d+(?:\\.\\d+)?)");
        QRegularExpressionMatch mMin = minRe.match(text);
        if (mMin.hasMatch()) {
            double minVal = mMin.captured(1).toDouble();
            drone->setGeofenceMinAlt(minVal);
            details.append(QString("minimum altitude set to %1 meters").arg(minVal, 0, 'f', 0));
        }

        // B. Maximum Altitude ceiling (e.g. "maximum altitude to 120", "ceiling 100m")
        QRegularExpression maxRe("(?:maximum|max|ceiling)\\s*(?:altitude|height)?\\s*(?:to|is|=)?\\s*(\\d+(?:\\.\\d+)?)");
        QRegularExpressionMatch mMax = maxRe.match(text);
        if (mMax.hasMatch()) {
            double maxVal = mMax.captured(1).toDouble();
            if (maxVal >= 5.0 && maxVal <= 500.0) {
                drone->setGeofenceMaxAlt(maxVal);
                details.append(QString("maximum altitude ceiling set to %1 meters").arg(maxVal, 0, 'f', 0));
            }
        }

        // C. Circular Radius (e.g. "50 m radius", "50m", "radius of 50m", "50 meters")
        QRegularExpression radRe("(\\d+(?:\\.\\d+)?)\\s*(?:m|meter|meters)?\\s*(?:radius|circle)");
        QRegularExpressionMatch mRad = radRe.match(text);
        double targetRad = -1.0;
        if (mRad.hasMatch()) {
            targetRad = mRad.captured(1).toDouble();
        } else {
            QRegularExpression radRe2("(?:radius|circle|perimeter|fence)\\s*(?:of)?\\s*(\\d+(?:\\.\\d+)?)");
            QRegularExpressionMatch mRad2 = radRe2.match(text);
            if (mRad2.hasMatch()) {
                targetRad = mRad2.captured(1).toDouble();
            } else {
                QRegularExpression anyNum("(\\d+(?:\\.\\d+)?)");
                QRegularExpressionMatch mAny = anyNum.match(text);
                if (mAny.hasMatch()) {
                    double val = mAny.captured(1).toDouble();
                    if (val >= 5.0 && val <= 5000.0 && !text.contains("minimum") && !text.contains("min")) {
                        targetRad = val;
                    }
                }
            }
        }

        if (targetRad >= 5.0 && targetRad <= 5000.0) {
            drone->setGeofenceRadius(targetRad);
            details.append(QString("circular radius set to %1 meters").arg(targetRad, 0, 'f', 0));
        }

        // D. Breach Failsafe Action: Land, RTL, Loiter, Warn
        if (text.contains("land")) {
            drone->setGeofenceAction(2); // Land
            details.append("breach action set to immediate landing");
        } else if (text.contains("rtl") || text.contains("return home") || text.contains("return to launch")) {
            drone->setGeofenceAction(1); // RTL
            details.append("breach action set to return to launch");
        } else if (text.contains("loiter") || text.contains("hold position") || text.contains("hover")) {
            drone->setGeofenceAction(3); // Loiter
            details.append("breach action set to loiter");
        } else if (text.contains("warn") || text.contains("alert")) {
            drone->setGeofenceAction(0); // Warn
            details.append("breach action set to warning alert only");
        }

        if (details.isEmpty()) {
            details.append(QString("circular radius %1 meters, ceiling %2 meters").arg(drone->geofenceRadius(), 0, 'f', 0).arg(drone->geofenceMaxAlt(), 0, 'f', 0));
        }

        QString fullReply = "Safety geofence active: " + details.join(", ") + ".";
        respondAndSpeak(fullReply, "GEOFENCE_CONFIG", true);
        return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. ARMING & DISARMING
    // ─────────────────────────────────────────────────────────────────────────
    if (text == "arm" || text.contains("arm drone") || text.contains("arm motor") || text.contains("start propulsion") || text.contains("arm vehicle")) {
        if (!drone) {
            respondAndSpeak("Negative. No drone is currently connected.", "ERROR", false);
            return;
        }
        drone->arm();
        respondAndSpeak("Arming drone propulsion systems now. Stand clear of propellers.", "ARM", true);
        return;
    }

    if (text == "disarm" || text.contains("disarm drone") || text.contains("disarm motor") || text.contains("shut down motor")) {
        if (!drone) {
            respondAndSpeak("Negative. No drone is currently connected.", "ERROR", false);
            return;
        }
        drone->disarm();
        respondAndSpeak("Disarming aircraft motors. Vehicle safe.", "DISARM", true);
        return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. TAKEOFF
    // ─────────────────────────────────────────────────────────────────────────
    if (text.contains("take off") || text.contains("takeoff") || text.contains("launch drone") || text.contains("climb to")) {
        if (!drone) {
            respondAndSpeak("Negative. No drone is currently connected.", "ERROR", false);
            return;
        }
        double targetAlt = 15.0;
        QRegularExpression re("(\\d+(?:\\.\\d+)?)\\s*(?:m|meter|meters)?");
        QRegularExpressionMatch match = re.match(text);
        if (match.hasMatch()) {
            double parsed = match.captured(1).toDouble();
            if (parsed >= 2.0 && parsed <= 150.0) targetAlt = parsed;
        }
        if (!drone->isArmed()) drone->arm();
        drone->takeoff(targetAlt);
        respondAndSpeak(QString("Takeoff sequence initiated. Ascending to %1 meters.").arg(targetAlt, 0, 'f', 0), "TAKEOFF", true);
        return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. RETURN TO LAUNCH / HOME
    // ─────────────────────────────────────────────────────────────────────────
    if (text.contains("return home") || text.contains("return to launch") || text == "rtl" || text.contains("go home") || text.contains("fly home") || text.contains("rth")) {
        if (!drone) {
            respondAndSpeak("Negative. No drone is currently connected.", "ERROR", false);
            return;
        }
        drone->returnToLaunch();
        respondAndSpeak("Return to Launch commanded. Aircraft returning to home coordinate.", "RTL", true);
        return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. LAND
    // ─────────────────────────────────────────────────────────────────────────
    if (text.contains("land now") || text.contains("touch down") || text == "land" || text.contains("descend and land")) {
        if (!drone) {
            respondAndSpeak("Negative. No drone is currently connected.", "ERROR", false);
            return;
        }
        drone->land();
        respondAndSpeak("Autonomous landing sequence initiated. Descending immediately.", "LAND", true);
        return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. FLIGHT MODES
    // ─────────────────────────────────────────────────────────────────────────
    if (text.contains("guided") || text.contains("switch to guided")) {
        if (!drone) { respondAndSpeak("No drone connected.", "ERROR", false); return; }
        drone->setFlightMode("GUIDED");
        respondAndSpeak("Flight mode switched to Guided. Ready for GPS coordinate navigation.", "MODE_GUIDED", true);
        return;
    }
    if (text.contains("loiter") || text.contains("hold position") || text.contains("hover")) {
        if (!drone) { respondAndSpeak("No drone connected.", "ERROR", false); return; }
        drone->setFlightMode("LOITER");
        respondAndSpeak("Flight mode set to Loiter. Aircraft holding GPS position and altitude.", "MODE_LOITER", true);
        return;
    }
    if (text.contains("auto mode") || text.contains("switch to auto") || text.contains("autonomous mode")) {
        if (!drone) { respondAndSpeak("No drone connected.", "ERROR", false); return; }
        drone->setFlightMode("AUTO");
        respondAndSpeak("Flight mode set to Auto. Executing programmed waypoint mission.", "MODE_AUTO", true);
        return;
    }
    if (text.contains("stabilize") || text.contains("manual mode")) {
        if (!drone) { respondAndSpeak("No drone connected.", "ERROR", false); return; }
        drone->setFlightMode("STABILIZE");
        respondAndSpeak("Flight mode set to Stabilize. Manual attitude control active.", "MODE_STABILIZE", true);
        return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. MISSION CONTROLS
    // ─────────────────────────────────────────────────────────────────────────
    if (text.contains("start mission") || text.contains("run mission") || text.contains("resume mission")) {
        if (!drone) { respondAndSpeak("No drone connected.", "ERROR", false); return; }
        drone->startMission();
        respondAndSpeak("Autonomous waypoint mission commenced. Tracking waypoint path.", "MISSION_START", true);
        return;
    }
    if (text.contains("pause mission") || text.contains("stop mission") || text.contains("hold mission")) {
        if (!drone) { respondAndSpeak("No drone connected.", "ERROR", false); return; }
        drone->pauseMission();
        respondAndSpeak("Waypoint mission paused. Aircraft loitering in place.", "MISSION_PAUSE", true);
        return;
    }
    if (text.contains("clear mission") || text.contains("clear waypoints") || text.contains("delete mission")) {
        if (!drone) { respondAndSpeak("No drone connected.", "ERROR", false); return; }
        drone->clearMission();
        respondAndSpeak("Mission waypoints cleared from flight controller.", "MISSION_CLEAR", true);
        return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. GENERAL SITREP
    // ─────────────────────────────────────────────────────────────────────────
    if (text.contains("sitrep") || text.contains("status") || text.contains("report")) {
        if (!drone) {
            respondAndSpeak("GCS status nominal. No aircraft connected on telemetry datalink.", "SITREP", true);
            return;
        }
        QString sitrep = QString("SITREP: Aircraft %1 is %2 in %3 mode. Battery %4 percent. Altitude %5 meters. Speed %6 m/s. %7 satellites locked.")
                             .arg(drone->name())
                             .arg(drone->isArmed() ? "ARMED" : "DISARMED")
                             .arg(drone->flightMode())
                             .arg(drone->batteryPercent())
                             .arg(drone->relAltitude(), 0, 'f', 1)
                             .arg(drone->groundSpeed(), 0, 'f', 1)
                             .arg(drone->gpsSats());
        respondAndSpeak(sitrep, "SITREP", true);
        return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. GCS UI NAVIGATION
    // ─────────────────────────────────────────────────────────────────────────
    if (text.contains("show map") || text.contains("open map") || text.contains("map view")) {
        emit requestPageNavigation(0);
        respondAndSpeak("Switching to Tactical Map navigation view.", "NAV_MAP", true);
        return;
    }
    if (text.contains("show mission") || text.contains("mission planner") || text.contains("mission page")) {
        emit requestPageNavigation(1);
        respondAndSpeak("Switching to Mission Waypoint Planner view.", "NAV_MISSION", true);
        return;
    }
    if (text.contains("show telemetry") || text.contains("parameters") || text.contains("telemetry page")) {
        emit requestPageNavigation(2);
        respondAndSpeak("Switching to Vehicle Telemetry and Parameter console.", "NAV_TELEMETRY", true);
        return;
    }
    if (text.contains("show video") || text.contains("camera") || text.contains("fpv") || text.contains("video stream")) {
        emit requestTogglePip();
        respondAndSpeak("Toggling Tactical Video Stream camera feed.", "TOGGLE_PIP", true);
        return;
    }
    if (text.contains("flight log") || text.contains("export log") || text.contains("download log") || text.contains("logs")) {
        emit requestOpenFlightLogs();
        respondAndSpeak("Opening Flight Telemetry Log Recorder dialog.", "OPEN_LOGS", true);
        return;
    }
    if (text.contains("preflight") || text.contains("checklist") || text.contains("sensor check")) {
        emit requestRunPreflight();
        respondAndSpeak("Running pre-flight sensor and safety verification checklist.", "PREFLIGHT", true);
        return;
    }
    if (text.contains("settings") || text.contains("configure")) {
        emit requestOpenSettings();
        respondAndSpeak("Opening Ground Control Station configuration settings.", "OPEN_SETTINGS", true);
        return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 11. GREETINGS & HELP
    // ─────────────────────────────────────────────────────────────────────────
    if (text.contains("hello") || text.contains("hi") || text == "hey" || text.contains("who are you")) {
        respondAndSpeak("Tactical AI Copilot standing by. Ready to execute flight commands, telemetry queries, safety geofences, and mission planning.", "GREETING", true);
        return;
    }

    // DEFAULT ADVISORY
    respondAndSpeak(QString("Instruction acknowledged: '%1'. Enter a Gemini API Key for deep reasoning, or use standard flight commands like Takeoff, Return Home, Guided, Geofence, or SITREP.").arg(input), "ACK", true);
}
