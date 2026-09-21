#include "TelemetryStore.h"

TelemetryStore::TelemetryStore(QObject *parent) : QObject(parent) {}

void TelemetryStore::clear()
{
    m_alt.clear();
    m_spd.clear();
    m_bat.clear();
    emit historyChanged();
}
