/**
 * DRONE_GCS 3D Geospatial Engine (CesiumJS)
 * Milestone 6 (Requirement 13) - Real-Time 3D Map and Flight Visualization
 *
 * Provides:
 * - Hardware-accelerated WGS84 ECEF 3D Globe
 * - 6-DOF aerospace attitude & heading transformation (MAVLink NED to ECEF quaternion)
 * - 3D GLB tactical quadcopter model rendering
 * - Vertical ground drop line (stem) & ground footprint
 * - Multi-mode aerospace camera tracking (FOLLOW, FREE, TOP_DOWN, OVERVIEW)
 * - Base imagery providers (ESRI Satellite, CartoDB Dark, OpenStreetMap, Google Hybrid)
 * - Terrain provider with seamless offline fallback to EllipsoidTerrainProvider
 * - 3D OSM buildings layer with fallback
 * - GPU resource idling (setRenderLoopActive)
 * - QWebChannel bridge integration
 */

'use strict';

// ── Configuration & State ───────────────────────────────────────────────────
const DEFAULT_CENTER = {
    lat: 28.613939,
    lon: 77.209021,
    alt: 25.0
};

let currentCameraMode = 'FOLLOW'; // 'FOLLOW', 'FREE', 'TOP_DOWN', 'OVERVIEW'
let cameraPitchDeg = -25.0;       // Follow camera pitch (negative = looking down)
let cameraRange = 45.0;           // Distance behind vehicle in meters

let lastDroneState = {
    sysId: 1,
    lat: DEFAULT_CENTER.lat,
    lon: DEFAULT_CENTER.lon,
    altAmsl: DEFAULT_CENTER.alt,
    altRel: 0.0,
    heading: 0.0,
    pitch: 0.0,
    roll: 0.0,
    groundSpeed: 0.0,
    airSpeed: 0.0,
    climbRate: 0.0,
    isArmed: false,
    flightMode: 'DISARMED',
    gpsFix: 3,
    isStale: false
};

let homePosition = null; // { lat, lon, alt }
let missionWaypointsList = [];

// ── Base Imagery Providers ──────────────────────────────────────────────────
const imageryProviders = {
    "Satellite": new Cesium.UrlTemplateImageryProvider({
        url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        maximumLevel: 19,
        credit: new Cesium.Credit('Tiles © Esri, Maxar, Earthstar Geographics', true)
    }),
    "Tactical Dark": new Cesium.UrlTemplateImageryProvider({
        url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
        subdomains: ['a', 'b', 'c', 'd'],
        maximumLevel: 20,
        credit: new Cesium.Credit('© CartoDB, © OpenStreetMap contributors', true)
    }),
    "OpenStreetMap": new Cesium.UrlTemplateImageryProvider({
        url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        maximumLevel: 19,
        credit: new Cesium.Credit('© OpenStreetMap contributors', true)
    }),
    "Google Hybrid": new Cesium.UrlTemplateImageryProvider({
        url: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
        maximumLevel: 20,
        credit: new Cesium.Credit('Google Hybrid Imagery', true)
    }),
    "Google Satellite": new Cesium.UrlTemplateImageryProvider({
        url: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
        maximumLevel: 20,
        credit: new Cesium.Credit('Google Satellite Imagery', true)
    })
};

let currentImageryName = "Satellite";

// ── Cesium Viewer Initialization ────────────────────────────────────────────
const viewer = new Cesium.Viewer('cesiumContainer', {
    baseLayerPicker: false,
    geocoder: false,
    homeButton: false,
    infoBox: false,
    navigationHelpButton: false,
    sceneModePicker: false,
    timeline: false,
    animation: false,
    fullscreenButton: false,
    vrButton: false,
    selectionIndicator: false,
    shadows: false,
    terrainShadows: Cesium.ShadowMode.DISABLED,
    scene3DOnly: true,
    shouldAnimate: true,
    imageryProvider: imageryProviders["Satellite"]
});

// Tactical dark globe styling
viewer.scene.globe.baseColor = Cesium.Color.fromCssColorString('#090D14');
viewer.scene.backgroundColor = Cesium.Color.fromCssColorString('#090D14');
viewer.scene.globe.depthTestAgainstTerrain = true;
viewer.scene.globe.enableLighting = false;

// Disable default mouse double-click track/zoom
viewer.screenSpaceEventHandler.removeInputAction(Cesium.ScreenSpaceEventType.LEFT_DOUBLE_CLICK);

// ── Terrain Provider with Offline Fallback ──────────────────────────────────
viewer.terrainProvider = new Cesium.EllipsoidTerrainProvider();

if (window.CESIUM_ION_TOKEN && window.CESIUM_ION_TOKEN.length > 10) {
    Cesium.Ion.defaultAccessToken = window.CESIUM_ION_TOKEN;
}

if (Cesium.Ion.defaultAccessToken && Cesium.Ion.defaultAccessToken.length > 10 && navigator.onLine) {
    Cesium.createWorldTerrainAsync({
        requestWaterMask: false,
        requestVertexNormals: true
    }).then(function(terrain) {
        viewer.terrainProvider = terrain;
        console.log("Cesium World Terrain loaded successfully");
    }).catch(function(err) {
        console.warn("World Terrain unavailable, retaining Ellipsoid fallback:", err);
        viewer.terrainProvider = new Cesium.EllipsoidTerrainProvider();
    });
}

// ── 3D OSM Buildings with Offline Fallback ───────────────────────────────────
let osmBuildingsTileset = null;
if (Cesium.Ion.defaultAccessToken && Cesium.Ion.defaultAccessToken.length > 10 && navigator.onLine) {
    Cesium.createOsmBuildingsAsync().then(function(tileset) {
        osmBuildingsTileset = tileset;
        viewer.scene.primitives.add(tileset);
        console.log("3D OSM Buildings loaded successfully");
    }).catch(function(err) {
        console.warn("3D OSM Buildings unavailable:", err);
    });
}

function set3DBuildingsVisible(visible) {
    if (osmBuildingsTileset) {
        osmBuildingsTileset.show = Boolean(visible);
    }
}

// ── 6-DOF Attitude & Heading Math ───────────────────────────────────────────
/**
 * Converts MAVLink vehicle attitude (roll, pitch, yaw in NED) into
 * an ECEF orientation quaternion for the Cesium 3D model.
 *
 * MAVLink NED convention:
 * - yaw/heading: degrees clockwise from North [0, 360)
 * - pitch: degrees nose up (+) / down (-)
 * - roll: degrees bank right (+) / bank left (-)
 */
function computeDroneOrientation(lon, lat, altAMSL, headingDeg, pitchDeg, rollDeg) {
    try {
        const cLon = Number.isFinite(lon) ? Math.max(-180.0, Math.min(180.0, lon)) : DEFAULT_CENTER.lon;
        const cLat = Number.isFinite(lat) ? Math.max(-90.0, Math.min(90.0, lat)) : DEFAULT_CENTER.lat;
        const cAlt = Number.isFinite(altAMSL) ? Math.max(-1000.0, Math.min(100000.0, altAMSL)) : DEFAULT_CENTER.alt;

        const hDeg = Number.isFinite(headingDeg) ? ((headingDeg % 360) + 360) % 360 : 0.0;
        const pDeg = Number.isFinite(pitchDeg) ? Math.max(-90.0, Math.min(90.0, pitchDeg)) : 0.0;
        const rDeg = Number.isFinite(rollDeg) ? Math.max(-180.0, Math.min(180.0, rollDeg)) : 0.0;

        const position = Cesium.Cartesian3.fromDegrees(cLon, cLat, cAlt);
        const heading = Cesium.Math.toRadians(hDeg);
        const pitch = Cesium.Math.toRadians(pDeg);
        const roll = Cesium.Math.toRadians(rDeg);

        // In glTF model coordinate frame: +Y is Forward, +X is Right, +Z is Up
        // Aerospace NED to ENU intrinsic rotation:
        // Heading (Yaw) rotates clockwise around +Z (North to East)
        // Pitch rotates around +X (lateral wing axis: nose up +pitch lifts +Y)
        // Roll rotates around +Y (longitudinal nose axis: bank right +roll drops +X)
        const qYaw = Cesium.Quaternion.fromAxisAngle(Cesium.Cartesian3.UNIT_Z, -heading);
        const qPitch = Cesium.Quaternion.fromAxisAngle(Cesium.Cartesian3.UNIT_X, pitch);
        const qRoll = Cesium.Quaternion.fromAxisAngle(Cesium.Cartesian3.UNIT_Y, roll);

        let qLocal = Cesium.Quaternion.multiply(qYaw, qPitch, new Cesium.Quaternion());
        qLocal = Cesium.Quaternion.multiply(qLocal, qRoll, qLocal);

        // Transform local ENU quaternion to ECEF fixed frame
        const enuToFixed = Cesium.Transforms.eastNorthUpToFixedFrame(position);
        const rotEnu = Cesium.Matrix4.getMatrix3(enuToFixed, new Cesium.Matrix3());
        const qEnu = Cesium.Quaternion.fromRotationMatrix(rotEnu);
        return Cesium.Quaternion.multiply(qEnu, qLocal, new Cesium.Quaternion());
    } catch (err) {
        console.warn("computeDroneOrientation failed, returning identity quaternion:", err);
        return Cesium.Quaternion.clone(Cesium.Quaternion.IDENTITY);
    }
}

// ── 3D Drone Entity, Trajectory & Ground Drop Line ──────────────────────────
let dronePositionECEF = Cesium.Cartesian3.fromDegrees(
    DEFAULT_CENTER.lon, DEFAULT_CENTER.lat, DEFAULT_CENTER.alt
);
let groundPositionECEF = Cesium.Cartesian3.fromDegrees(
    DEFAULT_CENTER.lon, DEFAULT_CENTER.lat, 0.0
);
let droneOrientationQuat = computeDroneOrientation(
    DEFAULT_CENTER.lon, DEFAULT_CENTER.lat, DEFAULT_CENTER.alt, 0, 0, 0
);

// Zero-Extrapolation Position Property (strictly halts extrapolation when stale)
const dronePositionProperty = new Cesium.SampledPositionProperty();
dronePositionProperty.forwardExtrapolationType = Cesium.ExtrapolationType.HOLD;
dronePositionProperty.backwardExtrapolationType = Cesium.ExtrapolationType.HOLD;
dronePositionProperty.setInterpolationOptions({
    interpolationDegree: 1,
    interpolationAlgorithm: Cesium.LinearApproximation
});

// Drone Model Entity
const droneEntity = viewer.entities.add({
    name: "Tactical Drone",
    position: new Cesium.CallbackProperty(function() {
        return dronePositionECEF;
    }, false),
    orientation: new Cesium.CallbackProperty(function() {
        return droneOrientationQuat;
    }, false),
    model: {
        uri: 'models/drone.glb',
        minimumPixelSize: 48,
        maximumScale: 150,
        runAnimations: true,
        clampAnimations: true,
        shadows: Cesium.ShadowMode.DISABLED,
        heightReference: Cesium.HeightReference.NONE,
        colorBlendMode: Cesium.ColorBlendMode.MIX,
        colorBlendAmount: 0.7,
        color: new Cesium.CallbackProperty(function() {
            if (lastDroneState.isStale) {
                // Amber/translucent warning shader or blend color (Section 13.D & Task 3)
                return Cesium.Color.ORANGE.withAlpha(0.65);
            }
            return Cesium.Color.WHITE;
        }, false)
    }
});

// Flown Trajectory Polyline (Frozen when stale, grows during live flight)
let flownTrajectoryPositions = [
    Cesium.Cartesian3.clone(dronePositionECEF)
];
const trajectoryEntity = viewer.entities.add({
    name: "Flown Trajectory",
    polyline: {
        positions: new Cesium.CallbackProperty(function() {
            return flownTrajectoryPositions;
        }, false),
        width: 3.0,
        material: new Cesium.PolylineGlowMaterialProperty({
            glowPower: 0.25,
            taperPower: 1.0,
            color: Cesium.Color.fromCssColorString('#00D4FF').withAlpha(0.85)
        })
    }
});

// Vertical Drop Line (Stem) connecting drone model to terrain surface
const dropLineEntity = viewer.entities.add({
    name: "Ground Drop Line",
    polyline: {
        positions: new Cesium.CallbackProperty(function() {
            return [dronePositionECEF, groundPositionECEF];
        }, false),
        width: 2.0,
        material: new Cesium.PolylineDashMaterialProperty({
            color: Cesium.Color.fromCssColorString('#00D4FF').withAlpha(0.7),
            gapColor: Cesium.Color.TRANSPARENT,
            dashLength: 8.0
        })
    }
});

// Ground Footprint Marker (Circle at terrain intersection)
const groundFootprintEntity = viewer.entities.add({
    name: "Ground Footprint",
    position: new Cesium.CallbackProperty(function() {
        return groundPositionECEF;
    }, false),
    point: {
        pixelSize: 8,
        color: Cesium.Color.fromCssColorString('#00D4FF'),
        outlineColor: Cesium.Color.fromCssColorString('#090D14'),
        outlineWidth: 2
    }
});

// ── Multi-Mode Camera System ────────────────────────────────────────────────
/**
 * Update camera position according to active camera mode.
 * Invoked per frame / telemetry update.
 */
function updateCamera() {
    try {
        if (!dronePositionECEF) return;

        if (currentCameraMode === 'FOLLOW') {
            const h = Number.isFinite(lastDroneState.heading) ? lastDroneState.heading : 0.0;
            const headingRad = Cesium.Math.toRadians(h);
            const pitchRad = Cesium.Math.toRadians(Number.isFinite(cameraPitchDeg) ? cameraPitchDeg : -25.0);
            const range = Number.isFinite(cameraRange) ? cameraRange : 45.0;
            viewer.camera.lookAt(
                dronePositionECEF,
                new Cesium.HeadingPitchRange(headingRad, pitchRad, range)
            );
        } else if (currentCameraMode === 'TOP_DOWN') {
            const range = Number.isFinite(cameraRange) ? Math.max(cameraRange * 3.0, 150.0) : 150.0;
            viewer.camera.lookAt(
                dronePositionECEF,
                new Cesium.HeadingPitchRange(0.0, -Cesium.Math.PI_OVER_TWO, range)
            );
        }
        // FREE mode: user controls camera via mouse, no lookAt override
    } catch (err) {
        console.warn("updateCamera failed:", err);
    }
}

/**
 * Set active camera tracking mode:
 * - 'FOLLOW': Third-person chase cam locked to drone heading
 * - 'FREE': Unconstrained orbit, pan, tilt, zoom
 * - 'TOP_DOWN': Nadir vertical orthographic view (-90°)
 * - 'OVERVIEW': Bounding sphere framing vehicle and operational theater
 */
function setCameraMode(mode) {
    if (!mode) return;
    const cleanMode = String(mode).toUpperCase();
    console.log("Setting 3D camera mode:", cleanMode);

    if (cleanMode === 'FREE') {
        currentCameraMode = 'FREE';
        try {
            viewer.camera.lookAtTransform(Cesium.Matrix4.IDENTITY);
        } catch (err) {
            console.warn("lookAtTransform reset failed:", err);
        }
    } else if (cleanMode === 'FOLLOW') {
        currentCameraMode = 'FOLLOW';
        updateCamera();
    } else if (cleanMode === 'TOP_DOWN' || cleanMode === 'TOP-DOWN' || cleanMode === 'NADIR') {
        currentCameraMode = 'TOP_DOWN';
        updateCamera();
    } else if (cleanMode === 'OVERVIEW') {
        currentCameraMode = 'OVERVIEW';
        try {
            viewer.camera.lookAtTransform(Cesium.Matrix4.IDENTITY);

            const points = [dronePositionECEF];
            if (homePosition && Number.isFinite(homePosition.lat) && Number.isFinite(homePosition.lon)) {
                points.push(Cesium.Cartesian3.fromDegrees(
                    homePosition.lon, homePosition.lat, Number.isFinite(homePosition.alt) ? homePosition.alt : 0.0
                ));
            }
            for (let i = 0; i < missionWaypointsList.length; i++) {
                const wp = missionWaypointsList[i];
                if (wp && Number.isFinite(wp.lat) && Number.isFinite(wp.lon)) {
                    points.push(Cesium.Cartesian3.fromDegrees(wp.lon, wp.lat, Number.isFinite(wp.alt) ? wp.alt : 0.0));
                }
            }

            const sphere = Cesium.BoundingSphere.fromPoints(points);
            const targetRadius = Math.max(sphere.radius * 2.5, 350.0);
            const h = Number.isFinite(lastDroneState.heading) ? lastDroneState.heading : 0.0;
            viewer.camera.flyToBoundingSphere(sphere, {
                offset: new Cesium.HeadingPitchRange(
                    Cesium.Math.toRadians(h),
                    Cesium.Math.toRadians(-40.0),
                    targetRadius
                ),
                duration: 1.2
            });
        } catch (err) {
            console.warn("OVERVIEW camera flight failed:", err);
        }
    }

    const hudCam = document.getElementById('hud-cam');
    if (hudCam) hudCam.textContent = currentCameraMode;
}

/**
 * Adjust camera pitch/tilt in degrees.
 * E.g., -20° (shallow), -45° (medium), -90° (nadir).
 */
function setCameraTilt(pitchDeg) {
    let p = parseFloat(pitchDeg);
    if (Number.isFinite(p)) {
        if (p > 0) p = -p; // Allow both 30 and -30 conventions
        cameraPitchDeg = Math.max(-90.0, Math.min(-10.0, p));
        if (currentCameraMode === 'FOLLOW') {
            updateCamera();
        }
    }
}

/**
 * Re-centers camera onto the drone position.
 */
function recenter() {
    if (currentCameraMode === 'FREE') {
        try {
            viewer.camera.flyTo({
                destination: Cesium.Cartesian3.fromDegrees(
                    lastDroneState.lon,
                    lastDroneState.lat,
                    lastDroneState.altAmsl + 100.0
                ),
                duration: 1.0
            });
        } catch (err) {
            console.warn("recenter camera flight failed:", err);
        }
    } else {
        updateCamera();
    }
}

/**
 * Flies camera to arbitrary lat/lon/alt coordinates.
 */
function centerOn(lat, lon, alt) {
    const numLat = parseFloat(lat);
    const numLon = parseFloat(lon);
    if (!Number.isFinite(numLat) || !Number.isFinite(numLon)) {
        console.warn("centerOn ignored invalid coordinates:", lat, lon);
        return;
    }
    const clampedLat = Math.max(-90.0, Math.min(90.0, numLat));
    const clampedLon = Math.max(-180.0, Math.min(180.0, numLon));
    const parsedAlt = parseFloat(alt);
    const targetAlt = Number.isFinite(parsedAlt) ? Math.max(-1000.0, Math.min(100000.0, parsedAlt)) : 300.0;
    try {
        viewer.camera.flyTo({
            destination: Cesium.Cartesian3.fromDegrees(clampedLon, clampedLat, targetAlt),
            duration: 1.2
        });
    } catch (err) {
        console.warn("centerOn camera flight failed:", err);
    }
}

// ── GPU Resource Idling Control ─────────────────────────────────────────────
/**
 * Enables or pauses the Cesium WebGL render loop.
 * When in 2D mode, pausing consumes 0% GPU/CPU overhead.
 */
function setRenderLoopActive(active) {
    const shouldRun = Boolean(active);
    viewer.useDefaultRenderLoop = shouldRun;
    if (shouldRun) {
        viewer.resize();
        viewer.scene.requestRender();
    }
    console.log("Cesium render loop active:", shouldRun);
}

// ── Telemetry Update Ingestion ──────────────────────────────────────────────
/**
 * Primary 6-DOF telemetry update handler.
 * Called continuously from C++ / QML bridge.
 */
function updateDrone3D(sysId, lat, lon, altAmsl, altRel, heading, pitch, roll,
                       groundSpeed, airSpeed, climbRate, isArmed, flightMode,
                       gpsFix, isStale) {
    const numLat = parseFloat(lat);
    const numLon = parseFloat(lon);
    if (!Number.isFinite(numLat) || !Number.isFinite(numLon)) {
        console.warn("updateDrone3D ignored non-finite coordinates:", lat, lon);
        return;
    }

    const clampedLat = Math.max(-90.0, Math.min(90.0, numLat));
    const clampedLon = Math.max(-180.0, Math.min(180.0, numLon));

    const pAltAmsl = parseFloat(altAmsl);
    const numAltAmsl = Number.isFinite(pAltAmsl) ? Math.max(-1000.0, Math.min(100000.0, pAltAmsl)) : 0.0;

    const pAltRel = parseFloat(altRel);
    const numAltRel = Number.isFinite(pAltRel) ? Math.max(-1000.0, Math.min(100000.0, pAltRel)) : 0.0;

    const pHdg = parseFloat(heading);
    const numHeading = Number.isFinite(pHdg) ? ((pHdg % 360) + 360) % 360 : 0.0;

    const pPitch = parseFloat(pitch);
    const numPitch = Number.isFinite(pPitch) ? Math.max(-90.0, Math.min(90.0, pPitch)) : 0.0;

    const pRoll = parseFloat(roll);
    const numRoll = Number.isFinite(pRoll) ? Math.max(-180.0, Math.min(180.0, pRoll)) : 0.0;

    const pGndSpd = parseFloat(groundSpeed);
    const numGndSpd = Number.isFinite(pGndSpd) ? Math.max(0.0, Math.min(1000.0, pGndSpd)) : 0.0;

    const pAirSpd = parseFloat(airSpeed);
    const numAirSpd = Number.isFinite(pAirSpd) ? Math.max(0.0, Math.min(1000.0, pAirSpd)) : 0.0;

    const pClimb = parseFloat(climbRate);
    const numClimb = Number.isFinite(pClimb) ? Math.max(-100.0, Math.min(100.0, pClimb)) : 0.0;

    const pGps = parseInt(gpsFix, 10);
    const numGpsFix = Number.isFinite(pGps) ? Math.max(0, Math.min(8, pGps)) : 0;

    // Automatic home position initialization if not yet set
    if (!homePosition) {
        homePosition = {
            lat: clampedLat,
            lon: clampedLon,
            alt: numAltAmsl
        };
    }

    // Telemetry freshness & stale watchdog handling (Task 3)
    const explicitStale = Boolean(isStale);
    if (explicitStale) {
        lastDroneState.isStale = true;
        triggerStaleState(3000);
    } else {
        lastTelemetryTimestamp = Date.now();
        if (lastDroneState.isStale) {
            clearStaleState();
        }
    }

    lastDroneState = {
        sysId: sysId || 1,
        lat: clampedLat,
        lon: clampedLon,
        altAmsl: numAltAmsl,
        altRel: numAltRel,
        heading: numHeading,
        pitch: numPitch,
        roll: numRoll,
        groundSpeed: numGndSpd,
        airSpeed: numAirSpd,
        climbRate: numClimb,
        isArmed: Boolean(isArmed),
        flightMode: flightMode || 'DISARMED',
        gpsFix: numGpsFix,
        isStale: lastDroneState.isStale
    };

    // Calibrated dual-reference altitude & anti-sink terrain guard (Task 2)
    const altResult = computeCalibratedAltitude(clampedLon, clampedLat, numAltAmsl, numAltRel);

    try {
        dronePositionECEF = Cesium.Cartesian3.fromDegrees(clampedLon, clampedLat, altResult.visualAlt);
        groundPositionECEF = Cesium.Cartesian3.fromDegrees(clampedLon, clampedLat, altResult.groundHeight);
        droneOrientationQuat = computeDroneOrientation(clampedLon, clampedLat, altResult.visualAlt, numHeading, numPitch, numRoll);

        // Update SampledPositionProperty with zero-extrapolation guarantees
        try {
            const timeJulian = Cesium.JulianDate.now();
            dronePositionProperty.addSample(timeJulian, dronePositionECEF);
        } catch (e) {}

        // Trajectory management: append when live, freeze when stale
        if (!lastDroneState.isStale) {
            if (flownTrajectoryPositions.length === 0) {
                flownTrajectoryPositions.push(Cesium.Cartesian3.clone(dronePositionECEF));
            } else {
                const lastPos = flownTrajectoryPositions[flownTrajectoryPositions.length - 1];
                const dist = Cesium.Cartesian3.distance(lastPos, dronePositionECEF);
                if (dist >= 0.25) {
                    flownTrajectoryPositions.push(Cesium.Cartesian3.clone(dronePositionECEF));
                    if (flownTrajectoryPositions.length > 10000) {
                        flownTrajectoryPositions.shift();
                    }
                }
            }
        }
    } catch (err) {
        console.warn("Cartesian position generation failed:", err);
    }

    // Update camera if tracking
    if (currentCameraMode === 'FOLLOW' || currentCameraMode === 'TOP_DOWN') {
        updateCamera();
    }

    // Update HUD: AMSL and AGL explicitly displayed
    updateHud(clampedLat, clampedLon, numAltAmsl, numAltRel, numHeading);
    if (!lastDroneState.isStale) {
        updateStatusBadge(false, lastDroneState.flightMode);
    }
}

/**
 * 2D Bridge compatibility shim for updateDroneMarker.
 */
function updateDroneMarker(sysId, lat, lon, heading, color, name) {
    updateDrone3D(sysId, lat, lon, lastDroneState.altAmsl, lastDroneState.altRel,
                  heading, 0, 0, 0, 0, 0, true, "AUTO", 3, false);
}

// ── 3D Mission & Geofence Geospatial Visualization ────────────────────────
let waypointEntities = [];
let plannedMissionPolylineEntity = null;
let geofenceEntities = [];
let geofenceCircleEntity = null;
let batteryRthEntity = null;
let activeHighlightedWaypointIndex = -1;

function setWaypoints(wps) {
    setWaypoints3D(wps);
}

function setWaypoints3D(wps) {
    clearWaypoints();
    missionWaypointsList = Array.isArray(wps) ? wps : [];
    if (missionWaypointsList.length === 0) return;

    const plannedPositions = [];

    missionWaypointsList.forEach(function(wp, i) {
        const numLat = parseFloat(wp.lat);
        const numLon = parseFloat(wp.lon);
        if (!Number.isFinite(numLat) || !Number.isFinite(numLon)) return;

        const wpAltRel = Number.isFinite(parseFloat(wp.alt)) ? parseFloat(wp.alt) : 15.0;
        const altRes = computeCalibratedAltitude(numLon, numLat, 0.0, wpAltRel);
        const wpPos = Cesium.Cartesian3.fromDegrees(numLon, numLat, altRes.visualAlt);
        const groundPos = Cesium.Cartesian3.fromDegrees(numLon, numLat, altRes.groundHeight);

        plannedPositions.push(wpPos);

        // 1. Vertical ground drop line (dashed pillar)
        const stemEntity = viewer.entities.add({
            name: `WP ${i + 1} Stem`,
            polyline: {
                positions: [wpPos, groundPos],
                width: 1.5,
                material: new Cesium.PolylineDashMaterialProperty({
                    color: Cesium.Color.fromCssColorString('#00D4FF').withAlpha(0.6),
                    gapColor: Cesium.Color.TRANSPARENT,
                    dashLength: 6.0
                })
            }
        });
        waypointEntities.push(stemEntity);

        // 2. Ground footprint circle
        const groundPin = viewer.entities.add({
            name: `WP ${i + 1} Ground Pin`,
            position: groundPos,
            point: {
                pixelSize: 6,
                color: Cesium.Color.fromCssColorString('#00D4FF').withAlpha(0.8),
                outlineColor: Cesium.Color.fromCssColorString('#090D14'),
                outlineWidth: 1.5
            }
        });
        waypointEntities.push(groundPin);

        // 3. 3D Waypoint Marker & Label
        const wpEntity = viewer.entities.add({
            name: `WP ${i + 1}`,
            position: wpPos,
            point: {
                pixelSize: 12,
                color: Cesium.Color.fromCssColorString('#00D4FF'),
                outlineColor: Cesium.Color.WHITE,
                outlineWidth: 2,
                disableDepthTestDistance: Number.POSITIVE_INFINITY
            },
            label: {
                text: `WP ${i + 1} (${wpAltRel.toFixed(0)}m)`,
                font: 'bold 11px JetBrains Mono, monospace',
                style: Cesium.LabelStyle.FILL_AND_OUTLINE,
                fillColor: Cesium.Color.WHITE,
                outlineColor: Cesium.Color.fromCssColorString('#090D14'),
                outlineWidth: 3,
                verticalOrigin: Cesium.VerticalOrigin.BOTTOM,
                pixelOffset: new Cesium.Cartesian2(0, -14),
                disableDepthTestDistance: Number.POSITIVE_INFINITY
            }
        });
        waypointEntities.push(wpEntity);
    });

    // 4. 3D Planned Mission Flight Path (Polyline connecting waypoints at flight altitude)
    if (plannedPositions.length >= 2) {
        plannedMissionPolylineEntity = viewer.entities.add({
            name: "Planned Mission Flight Path",
            polyline: {
                positions: plannedPositions,
                width: 3.5,
                material: new Cesium.PolylineGlowMaterialProperty({
                    glowPower: 0.25,
                    taperPower: 1.0,
                    color: Cesium.Color.fromCssColorString('#00D4FF').withAlpha(0.9)
                })
            }
        });
    }

    console.log(`3D Waypoints rendered. Count: ${missionWaypointsList.length}`);
}

function highlightWaypoint(index) {
    activeHighlightedWaypointIndex = index;
    waypointEntities.forEach(function(ent) {
        if (ent.name && ent.name.startsWith("WP ") && !ent.name.includes("Stem") && !ent.name.includes("Ground Pin")) {
            const isMatch = ent.name === `WP ${index + 1}`;
            if (ent.point) {
                ent.point.color = isMatch ? Cesium.Color.fromCssColorString('#FFB300') : Cesium.Color.fromCssColorString('#00D4FF');
                ent.point.pixelSize = isMatch ? 16 : 12;
            }
        }
    });
}

function clearWaypoints() {
    waypointEntities.forEach(function(ent) {
        viewer.entities.remove(ent);
    });
    waypointEntities = [];
    if (plannedMissionPolylineEntity) {
        viewer.entities.remove(plannedMissionPolylineEntity);
        plannedMissionPolylineEntity = null;
    }
    missionWaypointsList = [];
    console.log("3D Waypoints cleared");
}

function getWaypoints() {
    return JSON.stringify(missionWaypointsList);
}

function setGeofence(poly) {
    setGeofence3D(poly, 120.0, true);
}

function setGeofence3D(poly, maxAlt, isKeepIn) {
    clearGeofence();
    if (!Array.isArray(poly) || poly.length < 3) return;

    const fenceAlt = (Number.isFinite(maxAlt) && maxAlt > 0) ? maxAlt : 120.0;
    const closedPoly = poly.slice();
    closedPoly.push(poly[0]); // Ensure closed loop

    const wallDegreesArray = [];
    const maxHeights = [];
    const minHeights = [];

    closedPoly.forEach(function(p) {
        const numLat = parseFloat(p.lat);
        const numLon = parseFloat(p.lon);
        if (Number.isFinite(numLat) && Number.isFinite(numLon)) {
            wallDegreesArray.push(numLon, numLat);
            maxHeights.push(fenceAlt);
            minHeights.push(0.0);
        }
    });

    if (wallDegreesArray.length < 6) return;

    // Extruded 3D Geofence Boundary Wall
    const wallEntity = viewer.entities.add({
        name: "3D Geofence Wall",
        wall: {
            positions: Cesium.Cartesian3.fromDegreesArray(wallDegreesArray),
            maximumHeights: maxHeights,
            minimumHeights: minHeights,
            material: Cesium.Color.fromCssColorString('#FF4D4D').withAlpha(0.25),
            outline: true,
            outlineColor: Cesium.Color.fromCssColorString('#FF4D4D').withAlpha(0.9),
            outlineWidth: 2
        }
    });
    geofenceEntities.push(wallEntity);

    console.log(`3D Geofence Wall rendered. Vertices: ${poly.length}`);
}

function clearGeofence() {
    geofenceEntities.forEach(function(ent) {
        viewer.entities.remove(ent);
    });
    geofenceEntities = [];
    clearGeofenceCircle();
    console.log("3D Geofence cleared");
}

function setGeofenceRadius(homeLat, homeLon, radiusM) {
    clearGeofenceCircle();
    const numLat = parseFloat(homeLat);
    const numLon = parseFloat(homeLon);
    const numRadius = parseFloat(radiusM);
    if (!Number.isFinite(numLat) || !Number.isFinite(numLon) || !Number.isFinite(numRadius) || numRadius <= 0) return;

    geofenceCircleEntity = viewer.entities.add({
        name: "3D Circular Geofence Cylinder",
        position: Cesium.Cartesian3.fromDegrees(numLon, numLat, 60.0),
        cylinder: {
            length: 120.0,
            topRadius: numRadius,
            bottomRadius: numRadius,
            material: Cesium.Color.fromCssColorString('#FF4D4D').withAlpha(0.18),
            outline: true,
            outlineColor: Cesium.Color.fromCssColorString('#FF4D4D').withAlpha(0.75),
            outlineWidth: 2
        }
    });
    console.log(`3D Circular Geofence rendered at (${numLat}, ${numLon}), radius: ${numRadius}m`);
}

function clearGeofenceCircle() {
    if (geofenceCircleEntity) {
        viewer.entities.remove(geofenceCircleEntity);
        geofenceCircleEntity = null;
    }
}

function setBatteryRthRadius(homeLat, homeLon, radiusM) {
    if (batteryRthEntity) {
        viewer.entities.remove(batteryRthEntity);
        batteryRthEntity = null;
    }
    const numLat = parseFloat(homeLat);
    const numLon = parseFloat(homeLon);
    const numRadius = parseFloat(radiusM);
    if (!Number.isFinite(numLat) || !Number.isFinite(numLon) || !Number.isFinite(numRadius) || numRadius <= 0) return;

    batteryRthEntity = viewer.entities.add({
        name: "3D Battery RTH Boundary",
        position: Cesium.Cartesian3.fromDegrees(numLon, numLat, 0.5),
        ellipse: {
            semiMinorAxis: numRadius,
            semiMajorAxis: numRadius,
            height: 0.5,
            material: Cesium.Color.TRANSPARENT,
            outline: true,
            outlineColor: Cesium.Color.fromCssColorString('#FFB300').withAlpha(0.7),
            outlineWidth: 2
        }
    });
}

// ── Milestone 8 Camera Contract Aliases ──────────────────────────────────────
function setCameraMode3D(mode) {
    setCameraMode(mode);
}

function setCameraTilt3D(pitchDeg) {
    setCameraTilt(pitchDeg);
}

function recenter3D() {
    recenter();
}

// ── Switch Imagery Provider from QML ────────────────────────────────────────
function setMapProvider(name) {
    if (!name) return;
    for (const key in imageryProviders) {
        if (key.toLowerCase() === name.toLowerCase()) {
            viewer.imageryLayers.removeAll();
            viewer.imageryLayers.addImageryProvider(imageryProviders[key]);
            currentImageryName = key;
            const hudLayer = document.getElementById('hud-layer');
            if (hudLayer) hudLayer.textContent = key;
            console.log("3D Imagery provider switched to:", key);
            return;
        }
    }
    console.warn("Unknown 3D imagery provider:", name);
}

// ── HUD and Telemetry UI Updaters ───────────────────────────────────────────
const hudLat = document.getElementById('hud-lat');
const hudLon = document.getElementById('hud-lon');
const hudAlt = document.getElementById('hud-alt');
const hudAgl = document.getElementById('hud-agl');
const hudHdg = document.getElementById('hud-hdg');
const hudCam = document.getElementById('hud-cam');
const hudLayer = document.getElementById('hud-layer');
const statusBadge = document.getElementById('status-badge');
const badgeText = document.getElementById('badge-text');

function updateHud(lat, lon, altAmsl, altRel, heading) {
    if (hudLat) {
        hudLat.textContent = (typeof lat === 'number' && Number.isFinite(lat)) ? (lat.toFixed(6) + '°') : '--';
    }
    if (hudLon) {
        hudLon.textContent = (typeof lon === 'number' && Number.isFinite(lon)) ? (lon.toFixed(6) + '°') : '--';
    }
    if (hudAlt) {
        hudAlt.textContent = (typeof altAmsl === 'number' && Number.isFinite(altAmsl)) ? (altAmsl.toFixed(1) + ' m AMSL') : '--';
    }
    if (hudAgl) {
        hudAgl.textContent = (typeof altRel === 'number' && Number.isFinite(altRel)) ? (altRel.toFixed(1) + ' m AGL') : '--';
    }
    if (hudHdg) {
        if (typeof heading === 'number' && Number.isFinite(heading)) {
            const normHdg = ((Math.round(heading) % 360) + 360) % 360;
            hudHdg.textContent = String(normHdg).padStart(3, '0') + '°';
        } else {
            hudHdg.textContent = '--';
        }
    }
    if (hudCam) hudCam.textContent = currentCameraMode;
    if (hudLayer) hudLayer.textContent = currentImageryName;
}

function updateStatusBadge(isStale, flightMode, elapsedSec) {
    if (!statusBadge || !badgeText) return;
    if (isStale) {
        statusBadge.className = 'stale';
        const s = (elapsedSec !== undefined && elapsedSec !== null) ? elapsedSec : '3.0';
        badgeText.textContent = `⚠️ STALE TELEMETRY (${s}s)`;
    } else {
        statusBadge.className = '';
        badgeText.textContent = flightMode ? ('3D ENGINE - ' + flightMode) : '3D TACTICAL ENGINE ACTIVE';
    }
}

// ── Calibrated Dual-Reference Altitude & Anti-Sink Guard (Task 2) ───────────
const DELTA_SKIDS = 0.15; // 0.15m skids ground clearance guard

function computeCalibratedAltitude(clampedLon, clampedLat, altAmsl, altRel) {
    const isFlatEllipsoid = !viewer.terrainProvider || (viewer.terrainProvider instanceof Cesium.EllipsoidTerrainProvider);

    let zMeshHome = 0.0;
    let zMeshCurrent = 0.0;

    if (!isFlatEllipsoid) {
        // Query home mesh elevation from terrain provider
        if (homePosition && Number.isFinite(homePosition.lat) && Number.isFinite(homePosition.lon)) {
            try {
                const cartoHome = Cesium.Cartographic.fromDegrees(homePosition.lon, homePosition.lat);
                const sampleHome = viewer.scene.globe.getHeight(cartoHome);
                if (Number.isFinite(sampleHome)) {
                    zMeshHome = Math.max(-1000.0, Math.min(100000.0, sampleHome));
                } else if (Number.isFinite(homePosition.alt) && homePosition.alt !== 0.0) {
                    zMeshHome = homePosition.alt;
                }
            } catch (e) {
                if (Number.isFinite(homePosition.alt)) zMeshHome = homePosition.alt;
            }
        } else if (Number.isFinite(altAmsl) && altAmsl !== 0.0) {
            zMeshHome = altAmsl;
        }

        // Query current mesh elevation from terrain provider
        try {
            const cartoCurrent = Cesium.Cartographic.fromDegrees(clampedLon, clampedLat);
            const sampleCurrent = viewer.scene.globe.getHeight(cartoCurrent);
            if (Number.isFinite(sampleCurrent)) {
                zMeshCurrent = Math.max(-1000.0, Math.min(100000.0, sampleCurrent));
            } else {
                zMeshCurrent = zMeshHome;
            }
        } catch (e) {
            zMeshCurrent = zMeshHome;
        }
    }

    // Calibrated dual-reference model formulated in survey 2:
    // h_visual(t) = Z_mesh(home) + h_rel(t)
    // Fallback for flat ellipsoid (EllipsoidTerrainProvider): Z_mesh = 0, h_visual = h_rel
    const hVisual = isFlatEllipsoid ? altRel : (zMeshHome + altRel);

    // Anti-sink ground clearance guard:
    // h_final(t) = max(h_visual(t), Z_mesh(current) + delta_skids)
    // with delta_skids = 0.15m, guaranteeing the 3D drone model never sinks into terrain
    // or hovers in air when disarmed.
    const hFinal = Math.max(hVisual, zMeshCurrent + DELTA_SKIDS);

    return {
        visualAlt: Math.max(-1000.0, Math.min(100000.0, hFinal)),
        groundHeight: Math.max(-1000.0, Math.min(100000.0, zMeshCurrent)),
        zMeshHome: zMeshHome,
        zMeshCurrent: zMeshCurrent
    };
}

function setHomePosition(lat, lon, alt) {
    const numLat = parseFloat(lat);
    const numLon = parseFloat(lon);
    if (!Number.isFinite(numLat) || !Number.isFinite(numLon)) {
        return;
    }
    const parsedAlt = parseFloat(alt);
    homePosition = {
        lat: Math.max(-90.0, Math.min(90.0, numLat)),
        lon: Math.max(-180.0, Math.min(180.0, numLon)),
        alt: Number.isFinite(parsedAlt) ? Math.max(-1000.0, Math.min(100000.0, parsedAlt)) : 0.0
    };
    console.log("3D Map Home position configured:", homePosition);
}

// ── Stale Telemetry Watchdog & Zero-Extrapolation Fail-Safe (Task 3) ─────────
const STALE_TIMEOUT_MS = 3000;      // 3.0-second watchdog
const WATCHDOG_INTERVAL_MS = 200;  // 5 Hz check frequency

let lastTelemetryTimestamp = Date.now();
let staleWatchdogTimer = setInterval(checkStaleWatchdog, WATCHDOG_INTERVAL_MS);

function checkStaleWatchdog() {
    const now = Date.now();
    const elapsedMs = now - lastTelemetryTimestamp;
    if (elapsedMs >= STALE_TIMEOUT_MS) {
        triggerStaleState(elapsedMs);
    } else if (lastDroneState.isStale && elapsedMs < 1000) {
        clearStaleState();
    } else if (lastDroneState.isStale) {
        const elapsedSec = (elapsedMs / 1000.0).toFixed(1);
        updateStatusBadge(true, lastDroneState.flightMode, elapsedSec);
    }
}

function triggerStaleState(elapsedMs) {
    lastDroneState.isStale = true;

    // 1. Halt Cesium forward extrapolation immediately
    dronePositionProperty.forwardExtrapolationType = Cesium.ExtrapolationType.HOLD;
    dronePositionProperty.forwardExtrapolationDuration = 0;

    // 2. Display warning badge: ⚠️ STALE TELEMETRY (X.Xs)
    const elapsedSec = (elapsedMs / 1000.0).toFixed(1);
    updateStatusBadge(true, lastDroneState.flightMode, elapsedSec);

    // 3. Freeze flown trajectory polyline at exact last known GPS coordinate
    // (flownTrajectoryPositions is not appended to while isStale is true)
}

function clearStaleState() {
    lastDroneState.isStale = false;
    // Restore forward extrapolation to HOLD (never invent flight movement)
    dronePositionProperty.forwardExtrapolationType = Cesium.ExtrapolationType.HOLD;
    updateStatusBadge(false, lastDroneState.flightMode);
}

// Export for testing and QWebChannel inspection
if (typeof window !== 'undefined') {
    window.droneEntity = droneEntity;
    window.dronePositionProperty = dronePositionProperty;
    window.flownTrajectoryPositions = flownTrajectoryPositions;
    window.computeCalibratedAltitude = computeCalibratedAltitude;
    window.setHomePosition = setHomePosition;
    window.checkStaleWatchdog = checkStaleWatchdog;
    window.triggerStaleState = triggerStaleState;
    window.clearStaleState = clearStaleState;
    window.DELTA_SKIDS = DELTA_SKIDS;

    // Milestone 8 Camera & Workspace Contract Aliases
    window.setCameraMode = setCameraMode;
    window.setCameraMode3D = setCameraMode3D;
    window.setCameraTilt = setCameraTilt;
    window.setCameraTilt3D = setCameraTilt3D;
    window.recenter = recenter;
    window.recenter3D = recenter3D;
    window.setRenderLoopActive = setRenderLoopActive;
    window.setWaypoints = setWaypoints;
    window.setWaypoints3D = setWaypoints3D;
    window.highlightWaypoint = highlightWaypoint;
    window.clearWaypoints = clearWaypoints;
    window.setGeofence = setGeofence;
    window.setGeofence3D = setGeofence3D;
    window.clearGeofence = clearGeofence;
    window.clearGeofenceCircle = clearGeofenceCircle;
    window.getWaypoints = getWaypoints;
    window.setGeofenceRadius = setGeofenceRadius;
    window.setBatteryRthRadius = setBatteryRthRadius;
    window.updateDrone3D = updateDrone3D;
    window.set3DBuildingsVisible = set3DBuildingsVisible;
    window.setMapProvider = setMapProvider;
}

// Initial HUD formatting
updateHud(DEFAULT_CENTER.lat, DEFAULT_CENTER.lon, DEFAULT_CENTER.alt, 0.0, 0.0);

// ── QWebChannel Bridge Setup ────────────────────────────────────────────────
let mapBridge = null;

try {
    if (typeof QWebChannel !== 'undefined' && typeof qt !== 'undefined' && qt.webChannelTransport) {
        new QWebChannel(qt.webChannelTransport, function(channel) {
            mapBridge = channel.objects.map3dBridge || channel.objects.bridge;
            console.log("3D Map QWebChannel bridge connected successfully");
        });
    }
} catch(err) {
    console.warn("3D QWebChannel initialization notice:", err);
}

// Initial camera framing
try {
    viewer.camera.flyTo({
        destination: Cesium.Cartesian3.fromDegrees(DEFAULT_CENTER.lon, DEFAULT_CENTER.lat, 250.0),
        orientation: {
            heading: Cesium.Math.toRadians(0.0),
            pitch: Cesium.Math.toRadians(-35.0),
            roll: 0.0
        },
        duration: 1.5
    });
} catch(e) {
    console.warn("Initial camera framing failed:", e);
}
