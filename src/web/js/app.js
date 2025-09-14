// Situational Awareness Application
//
// Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.
//

// import { paloAltoBoundary } from './paloAltoBoundary.js';

let map;
let incidentLayer, personnelLayer, shelterLayer;

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
    personnelLayer = L.layerGroup().addTo(map);
    shelterLayer = L.layerGroup().addTo(map);
    
    loadDemoData();
}

function loadDemoData() {
    const incidents = [
        { location: [37.45308016263716, -122.1276251638624], type: "Stage 1", severity: "Medium", description: "San Francisquito @ W. Bayshore", url: "https://cc-webfile.cityofpaloalto.org/creekmonitor/storm2.png", width: 300, height: 300 },
        { location: [37.4510260206479, -122.16704514852604], type: "Stage 2", severity: "High", description: "San Francisquito @ Waverley", url: "https://cc-webfile.cityofpaloalto.org/creekmonitor/storm2.png", width: 300, height: 300 },
        { location: [37.45652728272695, -122.15370626837039], type: "Stage 2", severity: "High", description: "San Francisquito @ Chaucer", url: "https://cc-webfile.cityofpaloalto.org/creekmonitor/storm2.png", width: 300, height: 300 },
        { location: [37.44031131828777, -122.11335214734531], type: "Stage 2", severity: "High", description: "Matadero @ W. Bayshore", url: "https://cc-webfile.cityofpaloalto.org/creekmonitor/storm2.png", width: 300, height: 300 },
        { location: [37.429437549693056, -122.10516541081658], type: "Stage 2", severity: "High", description: "Adobe @ E. Meadow", url: "https://cc-webfile.cityofpaloalto.org/creekmonitor/storm2.png", width: 300, height: 300 }
    ];
    
    incidents.forEach(incident => {
        console.log("[app] Adding incident marker:", incident);
        const mySvgIcon = L.icon({
            iconUrl: 'assets/icons/bridge-water-solid-full.svg',
            iconSize: [38, 95], // size of the icon
            iconAnchor: [19, 47], // point of the icon which will correspond to marker's location
            popupAnchor: [-3, -76] // point from which the popup should open relative to the iconAnchor
        });
        // const marker = L.marker([incident.latitude, incident.longitude], { icon: mySvgIcon }).addTo(map);
        const marker = L.marker(incident.location, { icon: mySvgIcon, color: "#e74c3c" }).bindPopup(`<b>${incident.type}</b><br/>${incident.description}<br/>Severity: ${incident.severity}<br/><img src="${incident.url}" width=${incident.width} height=${incident.height}>`);
        incidentLayer.addLayer(marker);
    });
    
    const personnel = [
        { location: [37.4614, -122.1576], id: "PAFD-E01", status: "Available", type: "Fire Engine" },
        { location: [37.4349, -122.1540], id: "PAEMS-M01", status: "Dispatched", type: "Ambulance" }
    ];
    
    personnel.forEach(unit => {
        const marker = L.circleMarker(unit.location, {
            color: "#3498db", fillColor: "#3498db", fillOpacity: 0.8, radius: 6
        }).bindPopup(`<b>${unit.id}</b><br/>Type: ${unit.type}<br/>Status: ${unit.status}`);
        personnelLayer.addLayer(marker);
    });
    
    const shelters = [
        { location: [37.422469634374515, -122.11322286246323], name: "Mitchell Park Community Center", capacity: 150, available: 75 },
        { location: [37.417331206600764, -122.10844229634911], name: "Cubberley Community Center", capacity: 200, available: 120 }
    ];
    
    shelters.forEach(shelter => {
        const marker = L.circleMarker(shelter.location, {
            color: "#27ae60", fillColor: "#27ae60", fillOpacity: 0.8, radius: 10
        }).bindPopup(`<b>${shelter.name}</b><br/>Capacity: ${shelter.capacity}<br/>Available: ${shelter.available}`);
        shelterLayer.addLayer(marker);
    });
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

async function loadPersonnel() {
    try {
        const response = await fetch(`${API_BASE}/personnel/status`);
        const data = await response.json();
        if (data.success) updatePersonnelMarkers(data.data);
    } catch (error) {
        console.error("[app] Error loading personnel:", error);
    }
}

async function loadShelters() {
    try {
        const response = await fetch(`${API_BASE}/shelters/available`);
        const data = await response.json();
        if (data.success) updateShelterMarkers(data.data);
    } catch (error) {
        console.error("[app] Error loading shelters:", error);
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

function updatePersonnelMarkers(personnel) {
    personnelLayer.clearLayers();
    personnel.forEach(unit => {
        if (unit.longitude && unit.latitude) {
            const marker = L.circleMarker([unit.latitude, unit.longitude], {
                color: "#3498db", fillColor: "#3498db", fillOpacity: 0.8, radius: 6
            }).bindPopup(`<b>${unit.unit_id}</b><br/>Type: ${unit.unit_type}<br/>Status: ${unit.status}`);
            personnelLayer.addLayer(marker);
        }
    });
}

function updateShelterMarkers(shelters) {
    shelterLayer.clearLayers();
    shelters.forEach(shelter => {
        if (shelter.longitude && shelter.latitude) {
            const marker = L.circleMarker([shelter.latitude, shelter.longitude], {
                color: "#27ae60", fillColor: "#27ae60", fillOpacity: 0.8, radius: 10
            }).bindPopup(`<b>${shelter.facility_name}</b><br/>Capacity: ${shelter.total_capacity}<br/>Available: ${shelter.available_capacity}`);
            shelterLayer.addLayer(marker);
        }
    });
}

function loadIncidentsByType() { 
    alert("Loading incidents by type..."); 
}

function loadUnits() { 
    loadPersonnel(); 
}

function loadResources() { 
    alert("Loading resource centers..."); 
}

document.addEventListener("DOMContentLoaded", function() {
    initMap();
    console.log("[app] Situational Awareness System initialized");
});

setInterval(() => {
    loadIncidents();
    loadPersonnel(); 
    loadShelters();
}, 30000);
