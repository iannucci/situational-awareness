// Situational Awareness Application
//
// Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.
//

// const { load } = require("mime");

// import { paloAltoBoundary } from './paloAltoBoundary.js';

let map;
let incidentLayer, assetLayer;

const TILE_SERVER_URL = "http://pa-map-tiles.local.mesh/hot/{z}/{x}/{y}.png";
const PALO_ALTO_BOUNDS = {
    center: [37.4419, -122.1430],
    bounds: [[37.3894, -122.1965], [37.4944, -122.0895]],
    zoom: 13
};
const API_BASE = "/api/v1";

function initMap() {
    map = L.map("map", {
        center: PALO_ALTO_BOUNDS.center,
        zoom: PALO_ALTO_BOUNDS.zoom,
        zoomControl: true,
        attributionControl: true
    });
    
    map.setMaxBounds(PALO_ALTO_BOUNDS.bounds);
    
    const tileLayer = L.tileLayer(TILE_SERVER_URL, {
        maxZoom: 18,
        attribution: "© OpenStreetMap contributors | © Bob Iannucci"
    });
    tileLayer.addTo(map);
    
    const boundaryRectangle = L.rectangle(PALO_ALTO_BOUNDS.bounds, {
        color: "#3498db",
        weight: 2,
        fillOpacity: 0.1,
        dashArray: "10, 10"
    }).addTo(map);
    boundaryRectangle.bindPopup("<b>Palo Alto Service Area</b><br/>Situational Awareness Coverage Zone");

    // L.geoJSON(paloAltoBoundary).addTo(map);
    
    incidentLayer = L.layerGroup().addTo(map);
    assetLayer = L.layerGroup().addTo(map);
    loadIncidents();
    loadAssets();
}

async function loadIncidents() {
    try {
        const response = await fetch(`${API_BASE}/incidents/active`);
        const data = await response.json();
        if (data.success) updateIncidentMarkers(data.data);
    } catch (error) {
        console.error("[app] Error loading incidents:", error);
    }
}

async function loadAssets() {
    try {
        const response = await fetch(`${API_BASE}/assets/status`);
        const data = await response.json();
        console.log(data);
        if (data.success) updateAssetMarkers(data.data);
    } catch (error) {
        console.error("[app] Error loading assets:", error);
    }
}

function updateIncidentMarkers(incidents) {
    incidentLayer.clearLayers();
    incidents.forEach(incident => {
        if (incident.longitude && incident.latitude) {
            const marker = L.circleMarker([incident.latitude, incident.longitude], {
                color: "#e74c3c", fillColor: "#e74c3c", fillOpacity: 0.8, radius: 8
            }).bindPopup(`<b>${incident.incident_type}</b><br/>${incident.title}<br/>Severity: ${incident.severity}`);
            incidentLayer.addLayer(marker);
        }
    });
}

function updateAssetMarkers(assets) {
    assetLayer.clearLayers();
    assets.forEach(asset => {
        console.log(asset);
        if (asset.longitude && asset.latitude) {
            var marker;
            switch (asset.type_code) {
                case 'BRIDGE':
                    const svgIcon = L.icon({
                        iconUrl: 'assets/icons/' + asset.icon + '.svg',
                        iconSize: [38, 95],     // size of the icon
                        iconAnchor: [19, 47],   // point of the icon which will correspond to marker's location
                        popupAnchor: [0, -20]   // point from which the popup should open relative to the iconAnchor
                    });
                    // marker = L.marker([asset.latitude, asset.longitude], { 
                    //     icon: svgIcon, color: "#e74c3c" 
                    // }).bindPopup(`<b>${asset.type_code}</b><br/>${asset.description}<br/>Severity: ${asset.severity}<br/><a href="${asset.url}" target="_blank">Info</a>`);
                    marker = L.marker([asset.latitude, asset.longitude], { icon: svgIcon, 
                        color: "#e74c3c" 
                    }).bindPopup(`<b>${asset.type_code}</b><br/>${asset.description}<br/>Severity: ${asset.severity}<br/><img src="${asset.url}" width=300 height=300>`);
                    break; 
                default:
                    marker = L.circleMarker([asset.latitude, asset.longitude], {
                        color: "#3498db", fillColor: "#3498db", fillOpacity: 0.8, radius: 6
                    }).bindPopup(`<b>${asset.asset_id}</b><br/>Type: ${asset.type_code}<br/>Status: ${asset.status}`);
            }
            assetLayer.addLayer(marker);
        }
    });
}

function loadIncidentsByType() { 
    alert("Loading incidents by type..."); 
}

document.addEventListener("DOMContentLoaded", function() {
    initMap();
    console.log("[app] Situational Awareness System initialized");
});

setInterval(() => {
    loadIncidents();
    loadAssets(); 
}, 15000);
