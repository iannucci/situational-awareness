// Emergency Response Mapping Application
let map;
let incidentLayer, personnelLayer, shelterLayer;

// const TILE_SERVER_URL = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
const TILE_SERVER_URL = "http://pa-map-tiles.local.mesh/hot/{z}/{x}/{y}.png";
const PALO_ALTO_BOUNDS = {
    center: [37.4419, -122.1430],
    bounds: [[37.3894, -122.1965], [37.4944, -122.0895]],
    zoom: 11
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
        attribution: "© OpenStreetMap contributors | Emergency Response System"
    });
    tileLayer.addTo(map);
    
    const boundaryRectangle = L.rectangle(PALO_ALTO_BOUNDS.bounds, {
        color: "#3498db",
        weight: 2,
        fillOpacity: 0.1,
        dashArray: "10, 10"
    }).addTo(map);
    boundaryRectangle.bindPopup("<b>Palo Alto Service Area</b><br/>Emergency Response Coverage Zone");
    
    incidentLayer = L.layerGroup().addTo(map);
    personnelLayer = L.layerGroup().addTo(map);
    shelterLayer = L.layerGroup().addTo(map);
    
    loadDemoData();
}

function loadDemoData() {
    const incidents = [
        { location: [37.4419, -122.1630], type: "Fire", severity: "High", description: "Structure fire on University Ave" },
        { location: [37.4505, -122.1334], type: "Medical", severity: "Medium", description: "Medical emergency at Stanford Shopping Center" }
    ];
    
    incidents.forEach(incident => {
        const marker = L.circleMarker(incident.location, {
            color: "#e74c3c", fillColor: "#e74c3c", fillOpacity: 0.8, radius: 8
        }).bindPopup(`<b>${incident.type}</b><br/>${incident.description}<br/>Severity: ${incident.severity}`);
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
        { location: [37.4282, -122.1549], name: "Mitchell Park Community Center", capacity: 150, available: 75 },
        { location: [37.4092, -122.1345], name: "Cubberley Community Center", capacity: 200, available: 120 }
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
        console.error("Error loading incidents:", error);
    }
}

async function loadPersonnel() {
    try {
        const response = await fetch(`${API_BASE}/personnel/status`);
        const data = await response.json();
        if (data.success) updatePersonnelMarkers(data.data);
    } catch (error) {
        console.error("Error loading personnel:", error);
    }
}

async function loadShelters() {
    try {
        const response = await fetch(`${API_BASE}/shelters/available`);
        const data = await response.json();
        if (data.success) updateShelterMarkers(data.data);
    } catch (error) {
        console.error("Error loading shelters:", error);
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

function loadIncidentsByType() { alert("Loading incidents by type..."); }
function loadUnits() { loadPersonnel(); }
function loadResources() { alert("Loading resource centers..."); }

document.addEventListener("DOMContentLoaded", function() {
    initMap();
    console.log("Emergency Response System initialized for Palo Alto, CA");
});

setInterval(() => {
    loadIncidents();
    loadPersonnel(); 
    loadShelters();
}, 30000);
