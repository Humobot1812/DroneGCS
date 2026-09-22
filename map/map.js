'use strict';

// ── Base Map Providers ────────────────────────────────────────────────────────
const baseLayers = {
    "Google Hybrid": L.tileLayer('https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', {
        maxZoom: 21,
        attribution: 'Google Hybrid'
    }),
    "Google Satellite": L.tileLayer('https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}', {
        maxZoom: 21,
        attribution: 'Google Satellite'
    }),
    "ESRI Satellite": L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
        maxZoom: 19,
        attribution: 'Tiles &copy; Esri'
    }),
    "Tactical Dark": L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        maxZoom: 20,
        subdomains: 'abcd',
        attribution: '&copy; CartoDB'
    }),
    "OpenStreetMap": L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 20,
        attribution: '&copy; OpenStreetMap contributors'
    }),
    "Google Terrain": L.tileLayer('https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}', {
        maxZoom: 20,
        attribution: 'Google Terrain'
    })
};

// ── Map initialisation ────────────────────────────────────────────────────────
const mapEl = document.getElementById('map');
console.log('#map element dimensions:', mapEl ? (mapEl.offsetWidth + 'x' + mapEl.offsetHeight + ', window=' + window.innerWidth + 'x' + window.innerHeight) : 'NOT FOUND');

const map = L.map('map', {
    center: [28.613939, 77.209021],   // India Gate / New Delhi default demo center
    zoom: 16,
    zoomControl: false,
    attributionControl: false,
    layers: [baseLayers["Google Hybrid"]]
});
L.control.zoom({ position: 'bottomright' }).addTo(map);

let currentBaseLayer = baseLayers["Google Hybrid"];
let currentBaseLayerName = "Google Hybrid";

// Auto invalidate size on resize and load
window.addEventListener('resize', function() { map.invalidateSize(); });
setTimeout(function() { map.invalidateSize(); }, 200);
setTimeout(function() { map.invalidateSize(); }, 800);
setTimeout(function() { map.invalidateSize(); }, 2000);

// Prevent map zoom / pan when scrolling over the AI Copilot Drawer (right 460px)
window._aiDrawerOpen = false;
window.setAiDrawerOpen = function(isOpen) {
    window._aiDrawerOpen = Boolean(isOpen);
};

window.addEventListener('wheel', function(e) {
    if (window._aiDrawerOpen && e.clientX >= window.innerWidth - 460) {
        e.stopPropagation();
        e.stopImmediatePropagation();
        e.preventDefault();
    }
}, { capture: true, passive: false });

// Log tile loading events
for (const key in baseLayers) {
    baseLayers[key].on('tileloadstart', function(e) {
        console.log('Tile load start:', key, e.tile ? e.tile.src : '');
    });
    baseLayers[key].on('tileload', function(e) {
        console.log('Tile LOADED successfully:', key);
    });
    baseLayers[key].on('tileerror', function(err) {
        console.warn('Map Tile Load Error for', key, err.tile ? err.tile.src : err);
    });
}

// ── Overlays and Feature Groups ───────────────────────────────────────────────
const droneMarkers  = {};   // sysId → {marker, polyline, points[]}
const waypointLayer = L.featureGroup().addTo(map);
const geofenceLayer = L.featureGroup().addTo(map);
const batteryRthLayer = L.featureGroup().addTo(map);
const replayLayer   = L.featureGroup().addTo(map);
const measureLayer  = L.featureGroup().addTo(map);
const drawnLayer    = L.featureGroup().addTo(map);
let   drawingLayer  = null;

// Leaflet Layer Control (top-right)
const layerControl = L.control.layers(baseLayers, {
    "Waypoints & Route": waypointLayer,
    "Geofence": geofenceLayer,
    "Safe RTH Radius": batteryRthLayer,
    "Replay Track": replayLayer,
    "Survey Polygons": drawnLayer,
    "Measurements": measureLayer
}, { position: 'topright', collapsed: true }).addTo(map);

// ── Coordinate & Status HUD ───────────────────────────────────────────────────
const hudLat = document.getElementById('hud-lat');
const hudLon = document.getElementById('hud-lon');
const hudZoom = document.getElementById('hud-zoom');
const hudLayer = document.getElementById('hud-layer');
const modeBadge = document.getElementById('mode-badge');

function updateHud(lat, lon) {
    if (hudLat && lat !== undefined) hudLat.textContent = lat.toFixed(6) + '°';
    if (hudLon && lon !== undefined) hudLon.textContent = lon.toFixed(6) + '°';
    if (hudZoom) hudZoom.textContent = map.getZoom();
    if (hudLayer) hudLayer.textContent = currentBaseLayerName;
}

map.on('mousemove', function(e) {
    updateHud(e.latlng.lat, e.latlng.lng);
});

map.on('zoomend', function() {
    if (hudZoom) hudZoom.textContent = map.getZoom();
});

// ── QWebChannel bridge ────────────────────────────────────────────────────────
let bridge = null;

try {
    if (typeof QWebChannel !== 'undefined' && typeof qt !== 'undefined' && qt.webChannelTransport) {
        new QWebChannel(qt.webChannelTransport, function(channel) {
            bridge = channel.objects.bridge;
            console.log('QWebChannel connected successfully');
        });
    }
} catch(e) {
    console.warn('QWebChannel init notice:', e);
}

// ── Switch Provider from QML ──────────────────────────────────────────────────
function setMapProvider(name) {
    for (const key in baseLayers) {
        if (key.toLowerCase().includes(name.toLowerCase()) || name.toLowerCase().includes(key.toLowerCase())) {
            if (map.hasLayer(currentBaseLayer)) {
                map.removeLayer(currentBaseLayer);
            }
            currentBaseLayer = baseLayers[key];
            currentBaseLayerName = key;
            map.addLayer(currentBaseLayer);
            currentBaseLayer.bringToBack();
            updateHud();
            console.log('Switched base layer to:', key);
            return;
        }
    }
}

// ── Custom Tile URL (for Mapbox, Bing, or Private Server) ─────────────────────
function setCustomTileUrl(urlTemplate, maxZoom) {
    if (!urlTemplate) return;
    if (map.hasLayer(currentBaseLayer)) {
        map.removeLayer(currentBaseLayer);
    }
    currentBaseLayer = L.tileLayer(urlTemplate, { maxZoom: maxZoom || 20 }).addTo(map);
    currentBaseLayerName = "Custom API";
    currentBaseLayer.bringToBack();
    updateHud();
    console.log('Applied custom tile URL:', urlTemplate);
}

// ── Drone SVG Icon Factory (Professional Dark Stealth Tactical Quadcopter) ──
function makeDroneIcon(color) {
    const accent = color || '#388bfd';
    const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" style="filter: drop-shadow(0 3px 10px rgba(0,0,0,0.92));">
      <!-- Carbon Fiber Arm Struts (Dual Carbon Tubes) -->
      <line x1="24" y1="24" x2="10" y2="10" stroke="#0d1117" stroke-width="4.5" stroke-linecap="round"/>
      <line x1="24" y1="24" x2="38" y2="10" stroke="#0d1117" stroke-width="4.5" stroke-linecap="round"/>
      <line x1="24" y1="24" x2="10" y2="38" stroke="#0d1117" stroke-width="4.5" stroke-linecap="round"/>
      <line x1="24" y1="24" x2="38" y2="38" stroke="#0d1117" stroke-width="4.5" stroke-linecap="round"/>

      <line x1="24" y1="24" x2="10" y2="10" stroke="#21262d" stroke-width="2.2" stroke-linecap="round"/>
      <line x1="24" y1="24" x2="38" y2="10" stroke="#21262d" stroke-width="2.2" stroke-linecap="round"/>
      <line x1="24" y1="24" x2="10" y2="38" stroke="#21262d" stroke-width="2.2" stroke-linecap="round"/>
      <line x1="24" y1="24" x2="38" y2="38" stroke="#21262d" stroke-width="2.2" stroke-linecap="round"/>

      <!-- Dark Smoke Rotor Discs & Motor Mounts -->
      <!-- Front Left -->
      <circle cx="10" cy="10" r="8.5" fill="#12171f" fill-opacity="0.65" stroke="#30363d" stroke-width="1.2" stroke-dasharray="2,2"/>
      <circle cx="10" cy="10" r="3.4" fill="#161b22" stroke="#484f58" stroke-width="1.2"/>
      <circle cx="10" cy="10" r="1.3" fill="#8b949e"/>

      <!-- Front Right -->
      <circle cx="38" cy="10" r="8.5" fill="#12171f" fill-opacity="0.65" stroke="#30363d" stroke-width="1.2" stroke-dasharray="2,2"/>
      <circle cx="38" cy="10" r="3.4" fill="#161b22" stroke="#484f58" stroke-width="1.2"/>
      <circle cx="38" cy="10" r="1.3" fill="#8b949e"/>

      <!-- Rear Left -->
      <circle cx="10" cy="38" r="8.5" fill="#12171f" fill-opacity="0.65" stroke="#30363d" stroke-width="1.2" stroke-dasharray="2,2"/>
      <circle cx="10" cy="38" r="3.4" fill="#161b22" stroke="#484f58" stroke-width="1.2"/>
      <circle cx="10" cy="38" r="1.3" fill="#8b949e"/>

      <!-- Rear Right -->
      <circle cx="38" cy="38" r="8.5" fill="#12171f" fill-opacity="0.65" stroke="#30363d" stroke-width="1.2" stroke-dasharray="2,2"/>
      <circle cx="38" cy="38" r="3.4" fill="#161b22" stroke="#484f58" stroke-width="1.2"/>
      <circle cx="38" cy="38" r="1.3" fill="#8b949e"/>

      <!-- Aerodynamic Stealth Fuselage Chassis -->
      <polygon points="24,13 31,21 27,33 21,33 17,21" fill="#0d1117" stroke="#30363d" stroke-width="2"/>
      <polygon points="24,16 29,22 26,30 22,30 19,22" fill="#161b22" stroke="#21262d" stroke-width="1"/>

      <!-- Directional Heading Nose Indicator (High-Visibility Crisp Stealth Triangle) -->
      <polygon points="24,4 30,14 18,14" fill="#161b22" stroke="#f0f6fc" stroke-width="1.5" stroke-linejoin="round"/>
      <polygon points="24,6 28,13 20,13" fill="#f0f6fc" opacity="0.9"/>

      <!-- Central Avionics Core & Status LED -->
      <circle cx="24" cy="24" r="3.6" fill="#0d1117" stroke="#484f58" stroke-width="1.2"/>
      <circle cx="24" cy="24" r="2.0" fill="${accent}"/>
    </svg>`;
    return L.divIcon({
        html: svg,
        className: 'drone-svg-marker',
        iconSize: [48, 48],
        iconAnchor: [24, 24]
    });
}

// ── Drone marker update (called from C++ / QML) ───────────────────────────────
function updateDroneMarker(sysId, lat, lon, heading, color, name) {
    if (!droneMarkers[sysId]) {
        const marker = L.marker([lat, lon], {
            icon: makeDroneIcon(color),
            zIndexOffset: 1000 + sysId
        });
        marker.bindPopup(makeDronePopup(sysId, name, lat, lon, heading), { className: 'drone-popup' });
        marker.addTo(map);

        const poly = L.polyline([], { color: color, weight: 2.5, opacity: 0.85, dashArray: '5 5' }).addTo(map);
        droneMarkers[sysId] = { marker, polyline: poly, points: [] };

        if (Object.keys(droneMarkers).length === 1) {
            map.setView([lat, lon], 16);
        }
    }

    const dm = droneMarkers[sysId];
    dm.marker.setLatLng([lat, lon]);

    const el = dm.marker.getElement();
    if (el) {
        const svg = el.querySelector('svg');
        if (svg) svg.style.transform = `rotate(${heading}deg)`;
    }

    dm.marker.setPopupContent(makeDronePopup(sysId, name, lat, lon, heading));

    dm.points.push([lat, lon]);
    if (dm.points.length > 500) dm.points.shift();
    dm.polyline.setLatLngs(dm.points);
}

function makeDronePopup(sysId, name, lat, lon, hdg) {
    return `<div style="padding: 2px;">
      <b style="color: #00d4ff; font-size: 13px;">${name}</b><br>
      <div style="font-size: 11px; margin-top: 4px; line-height: 1.6;">
        <span>🌐 <b>Lat:</b> ${lat.toFixed(6)}</span><br>
        <span>🌐 <b>Lon:</b> ${lon.toFixed(6)}</span><br>
        <span>🧭 <b>Heading:</b> ${hdg.toFixed(1)}°</span><br>
        <span>⚡ <b>SYS_ID:</b> ${sysId}</span>
      </div>
    </div>`;
}

// ── Waypoint Spline Turn Smoothing Helper ────────────────────────────────────
function generateSplinePoints(pts, segmentsPerLeg) {
    if (!pts || pts.length < 3) return pts;
    segmentsPerLeg = segmentsPerLeg || 10;
    const result = [];
    result.push(pts[0]);

    for (let i = 0; i < pts.length - 1; i++) {
        const p0 = i > 0 ? pts[i - 1] : pts[i];
        const p1 = pts[i];
        const p2 = pts[i + 1];
        const p3 = (i < pts.length - 2) ? pts[i + 2] : p2;

        for (let t = 1; t <= segmentsPerLeg; t++) {
            const u = t / segmentsPerLeg;
            const u2 = u * u;
            const u3 = u2 * u;

            // Catmull-Rom formulation for trajectory turn smoothing
            const lat = 0.5 * (
                (2 * p1[0]) +
                (-p0[0] + p2[0]) * u +
                (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * u2 +
                (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * u3
            );
            const lon = 0.5 * (
                (2 * p1[1]) +
                (-p0[1] + p2[1]) * u +
                (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * u2 +
                (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * u3
            );
            result.push([lat, lon]);
        }
    }
    return result;
}

// ── Waypoints (Curved Spline Turn Smoothing & Visual Hierarchy) ───────────────
function setWaypoints(wps) {
    waypointLayer.clearLayers();
    if (!wps || wps.length === 0) return;

    const latLngs = [];
    wps.forEach(function(wp, i) {
        latLngs.push([wp.lat, wp.lon]);

        const icon = L.divIcon({
            className: 'wp-icon',
            html: `<div style="background:#00d4ff;color:#0d1117;border-radius:50%;width:24px;height:24px;display:flex;align-items:center;justify-content:center;font:bold 11px monospace;border:2px solid #ffffff;box-shadow: 0 2px 6px rgba(0,0,0,0.6)">${i+1}</div>`,
            iconSize: [24, 24],
            iconAnchor: [12, 12]
        });
        const m = L.marker([wp.lat, wp.lon], { icon, draggable: true }).addTo(waypointLayer);
        m.bindTooltip(`WP ${i+1}: Alt ${wp.alt || 15}m`, { permanent: false, direction: 'top' });

        m.on('dragend', function(e) {
            const pos = e.target.getLatLng();
            if (bridge && typeof bridge.onWaypointMoved === 'function') {
                bridge.onWaypointMoved(i, pos.lat, pos.lng);
            }
        });
    });

    // 1. Direct Leg Reference Vector (Subtle dashed connector)
    L.polyline(latLngs, { color: '#58a6ff', weight: 1.2, opacity: 0.35, dashArray: '4 4' }).addTo(waypointLayer);

    // 2. Continuous Curved Spline Flight Trajectory
    const smoothedPoints = generateSplinePoints(latLngs, 12);
    L.polyline(smoothedPoints, { color: '#00d4ff', weight: 3.0, opacity: 0.95 }).addTo(waypointLayer);

    map.fitBounds(waypointLayer.getBounds(), { padding: [50, 50] });
}

// ── Geofence (High-Contrast STANAG 4586 Boundary Differentiation) ─────────────
let geofenceRadiusCircle = null;

function setGeofence(poly) {
    setGeofencePolygon(poly, true);
}

function setGeofencePolygon(poly, isKeepIn) {
    if (!poly || poly.length < 3) return;
    const latLngs = poly.map(p => [p.lat, p.lon]);
    const isKeepInZone = (isKeepIn === undefined || isKeepIn);

    // Keep-In: Solid Amber (#d29922) | Keep-Out Threat: Flashing Hazard Red (#f85149)
    const strokeColor = isKeepInZone ? '#d29922' : '#f85149';
    const fillColor   = isKeepInZone ? '#d29922' : '#f85149';
    const dashPattern = isKeepInZone ? '' : '8 6';
    const fillOp      = isKeepInZone ? 0.18 : 0.28;

    L.polygon(latLngs, {
        color: strokeColor,
        weight: 3.0,
        fillColor: fillColor,
        fillOpacity: fillOp,
        dashArray: dashPattern
    }).bindTooltip(isKeepInZone ? "🛡️ Keep-In Safe Perimeter" : "⛔ Threat Keep-Out Zone (WARNING)", { permanent: false, direction: 'center' })
      .addTo(geofenceLayer);
}

function setGeofenceRadius(homeLat, homeLon, radiusM) {
    if (geofenceRadiusCircle) {
        geofenceLayer.removeLayer(geofenceRadiusCircle);
        geofenceRadiusCircle = null;
    }
    if (!radiusM || radiusM <= 0 || !homeLat || !homeLon) return;
    geofenceRadiusCircle = L.circle([homeLat, homeLon], {
        radius: radiusM,
        color: '#f85149',
        weight: 2.5,
        opacity: 0.90,
        fillColor: '#f85149',
        fillOpacity: 0.10,
        dashArray: '8 6'
    }).bindTooltip(`🛡️ Max Flight Geofence Radius: ${radiusM}m`, { permanent: false, direction: 'top' })
      .addTo(geofenceLayer);
}

function clearGeofenceCircle() {
    if (geofenceRadiusCircle) {
        geofenceLayer.removeLayer(geofenceRadiusCircle);
        geofenceRadiusCircle = null;
    }
}

function clearGeofence() {
    geofenceLayer.clearLayers();
    geofenceRadiusCircle = null;
}

// ── Dynamic Battery Safe Return Radius ─────────────────────────────────────────
let batteryRthCircle = null;

function setBatteryRthRadius(homeLat, homeLon, radiusM) {
    batteryRthLayer.clearLayers();
    if (!radiusM || radiusM <= 0 || !homeLat || !homeLon) return;
    const isCritical = radiusM < 400;
    batteryRthCircle = L.circle([homeLat, homeLon], {
        radius: radiusM,
        color: isCritical ? '#f85149' : '#00d4ff',
        weight: 2.5,
        opacity: 0.90,
        fillColor: isCritical ? '#f85149' : '#00d4ff',
        fillOpacity: 0.08,
        dashArray: '6 6'
    }).bindTooltip(`🔋 Dynamic Safe Return Radius: ${Math.round(radiusM)}m`, { permanent: false, direction: 'bottom' })
      .addTo(batteryRthLayer);
}

// ── Interactive Telemetry Replay Flight Trail & Ghost UAV ─────────────────────
let replayGhostMarker = null;

function setReplayTrack(records) {
    replayLayer.clearLayers();
    replayGhostMarker = null;
    if (!records || records.length === 0) return;

    const latLngs = [];
    for (let i = 0; i < records.length; i++) {
        if (records[i].lat && records[i].lon) {
            latLngs.push([records[i].lat, records[i].lon]);
        }
    }
    if (latLngs.length === 0) return;

    // Tactical Purple/Violet historical track with glow
    L.polyline(latLngs, {
        color: '#bc8cff',
        weight: 3.5,
        opacity: 0.95,
        dashArray: '4 4'
    }).addTo(replayLayer);

    map.fitBounds(replayLayer.getBounds(), { padding: [60, 60] });

    const first = records[0];
    setReplayGhost(first.lat, first.lon, 0, first.alt, first.speed);
}

function setReplayGhost(lat, lon, hdg, alt, spd) {
    if (!lat || !lon) return;
    if (!replayGhostMarker) {
        const icon = L.divIcon({
            className: 'replay-ghost-icon',
            html: `<div style="transform: rotate(${hdg || 0}deg); width:32px; height:32px; display:flex; align-items:center; justify-content:center; filter: drop-shadow(0 0 6px #bc8cff);">
                     <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
                       <path d="M12 2L2 22L12 18L22 22L12 2Z" fill="#bc8cff" stroke="#ffffff" stroke-width="1.8"/>
                     </svg>
                   </div>`,
            iconSize: [32, 32],
            iconAnchor: [16, 16]
        });
        replayGhostMarker = L.marker([lat, lon], { icon }).addTo(replayLayer);
    } else {
        replayGhostMarker.setLatLng([lat, lon]);
        const el = replayGhostMarker.getElement();
        if (el) {
            const inner = el.querySelector('div');
            if (inner) inner.style.transform = `rotate(${hdg || 0}deg)`;
        }
    }
    replayGhostMarker.bindTooltip(`✈️ <b>Replay</b>: Alt ${alt ? alt.toFixed(1) : 0}m | Spd ${spd ? spd.toFixed(1) : 0}m/s`, { permanent: false, direction: 'top' });
}

function clearReplayTrack() {
    replayLayer.clearLayers();
    replayGhostMarker = null;
}

function setManualWaypointList(wps) {
    manualWaypointList = wps || [];
    refreshManualWaypoints();
}

function highlightWaypoint(idx) {
    if (idx < 0 || idx >= manualWaypointList.length) return;
    const wp = manualWaypointList[idx];
    map.setView([wp.lat, wp.lon], Math.max(map.getZoom(), 17), { animate: true });
}

// ── Survey polygon draw tool ──────────────────────────────────────────────────
let drawControl = null;

function startDrawPolygon() {
    if (drawControl) map.removeControl(drawControl);

    drawControl = new L.Control.Draw({
        draw: {
            polygon:   { shapeOptions: { color: '#3fb950', fillOpacity: 0.2, weight: 2 }, showArea: true },
            polyline:  false, rectangle: false, circle: false, marker: false, circlemarker: false
        },
        edit: { featureGroup: drawnLayer }
    });
    map.addControl(drawControl);

    new L.Draw.Polygon(map, drawControl.options.draw.polygon).enable();
}

function stopDraw() {
    if (drawControl) {
        map.removeControl(drawControl);
        drawControl = null;
    }
}

map.on(L.Draw.Event.CREATED, function(e) {
    drawnLayer.clearLayers();
    drawnLayer.addLayer(e.layer);
    stopDraw();

    const coords = e.layer.getLatLngs()[0].map(p => ({ lat: p.lat, lon: p.lng }));
    if (bridge && typeof bridge.onPolygonDrawn === 'function') {
        bridge.onPolygonDrawn(JSON.stringify(coords));
    }
});

// ── Interactive Map Modes (Click-to-Fly, Measure, Add Waypoints) ───────────────
let currentInteractionMode = null;
let measurePoints = [];


map.on('click', function(e) {
    if (!currentInteractionMode) return;

    if (currentInteractionMode === 'addwp') {
        addManualWaypoint(e.latlng.lat, e.latlng.lng, manualWpDefaultAlt);
        // Update the badge count
        if (modeBadge) modeBadge.textContent = `📍 CLICK TO ADD WAYPOINT  ·  WPs: ${manualWaypointList.length}`;
    } else if (currentInteractionMode === 'measure') {
        measurePoints.push(e.latlng);
        L.circleMarker(e.latlng, { radius: 5, color: '#f59e0b', fillColor: '#f59e0b', fillOpacity: 1 }).addTo(measureLayer);
        if (measurePoints.length > 1) {
            const p1 = measurePoints[measurePoints.length - 2];
            const p2 = measurePoints[measurePoints.length - 1];
            const dist = p1.distanceTo(p2);
            L.polyline([p1, p2], { color: '#f59e0b', weight: 2.5, dashArray: '4 4' }).addTo(measureLayer);
            L.popup()
                .setLatLng(p2)
                .setContent(`<b style="color:#f59e0b">📏 Segment:</b> ${dist < 1000 ? dist.toFixed(1) + ' m' : (dist/1000).toFixed(2) + ' km'}`)
                .openOn(map);
        }
    }
});


// ── Utilities ─────────────────────────────────────────────────────────────────
function centerOn(lat, lon) {
    map.setView([lat, lon], Math.max(map.getZoom(), 16), { animate: true });
}

function clearAll() {
    waypointLayer.clearLayers();
    // Safety geofences (circular and polygons) are preserved and not cleared by overlay reset
    drawnLayer.clearLayers();
    measureLayer.clearLayers();
    measurePoints = [];
    manualWaypointList = [];
    manualWpLayer.clearLayers();
    setInteractionMode(null);
}

function clearWaypoints() {
    manualWaypointList = [];
    manualWpLayer.clearLayers();
    if (manualWpPolyline) {
        manualWpPolyline.setLatLngs([]);
    }
    waypointLayer.clearLayers();
    if (modeBadge && currentInteractionMode === 'addwp') {
        modeBadge.textContent = '📍 CLICK TO ADD WAYPOINT  ·  WPs: 0';
    }
}

// ── Manual Waypoint Click Tool ─────────────────────────────────────────────────
const manualWpLayer = L.featureGroup().addTo(map);
let manualWaypointList = [];  // [{lat, lon, alt}]
let manualWpPolyline = L.polyline([], {
    color: '#f59e0b', weight: 2.5, opacity: 0.9, dashArray: '8 4'
}).addTo(manualWpLayer);

// Default altitude for manually dropped waypoints (metres AGL)
let manualWpDefaultAlt = 15;

function setManualWpAlt(alt) {
    manualWpDefaultAlt = alt || 15;
}

function addManualWaypoint(lat, lon, alt) {
    alt = alt || manualWpDefaultAlt;
    const idx = manualWaypointList.length;
    manualWaypointList.push({ lat, lon, alt });

    const icon = L.divIcon({
        className: '',
        html: `<div style="
            background: linear-gradient(135deg,#f59e0b,#d97706);
            color:#0d1117; border-radius:50%; width:28px; height:28px;
            display:flex; align-items:center; justify-content:center;
            font:bold 11px 'JetBrains Mono',monospace;
            border:2px solid #fff; box-shadow:0 2px 8px rgba(0,0,0,0.7);
            cursor:move;">${idx + 1}</div>`,
        iconSize: [28, 28], iconAnchor: [14, 14]
    });

    const marker = L.marker([lat, lon], { icon, draggable: true }).addTo(manualWpLayer);
    marker.bindTooltip(`WP ${idx + 1} · Alt: ${alt}m`, { permanent: false, direction: 'top' });

    marker.on('dragend', function(e) {
        const p = e.target.getLatLng();
        manualWaypointList[idx].lat = p.lat;
        manualWaypointList[idx].lon = p.lng;
        redrawManualRoute();
        if (bridge && typeof bridge.onWaypointMoved === 'function')
            bridge.onWaypointMoved(idx, p.lat, p.lng);
    });

    marker.on('contextmenu', function() {
        manualWaypointList.splice(idx, 1);
        refreshManualWaypoints();
    });

    redrawManualRoute();
}

function redrawManualRoute() {
    const latlngs = manualWaypointList.map(w => [w.lat, w.lon]);
    manualWpPolyline.setLatLngs(latlngs);
}

function refreshManualWaypoints() {
    // Rebuild all markers from scratch after a deletion
    manualWpLayer.clearLayers();
    manualWpPolyline = L.polyline([], {
        color: '#f59e0b', weight: 2.5, opacity: 0.9, dashArray: '8 4'
    }).addTo(manualWpLayer);
    const saved = manualWaypointList.slice();
    manualWaypointList = [];
    saved.forEach(w => addManualWaypoint(w.lat, w.lon, w.alt));
}

function clearManualWaypoints() {
    manualWaypointList = [];
    manualWpLayer.clearLayers();
    manualWpPolyline = L.polyline([], {
        color: '#f59e0b', weight: 2.5, opacity: 0.9, dashArray: '8 4'
    }).addTo(manualWpLayer);
}

// Called by QML to retrieve the waypoint list for upload
function getWaypoints() {
    return JSON.stringify(manualWaypointList);
}

// Update the interaction click handler to also support 'addwp' mode
function setInteractionMode(mode) {
    currentInteractionMode = mode;
    console.log('Map interaction mode:', mode);
    if (!modeBadge) return;

    if (mode === 'measure') {
        modeBadge.style.display = 'block';
        modeBadge.style.borderColor = '#f59e0b';
        modeBadge.style.color = '#f59e0b';
        modeBadge.textContent = '📏 CLICK POINTS TO MEASURE DISTANCE';
    } else if (mode === 'addwp') {
        modeBadge.style.display = 'block';
        modeBadge.style.borderColor = '#f59e0b';
        modeBadge.style.color = '#f59e0b';
        modeBadge.textContent = `📍 CLICK TO ADD WAYPOINT  ·  WPs: ${manualWaypointList.length}`;
    } else {
        modeBadge.style.display = 'none';
    }
}
