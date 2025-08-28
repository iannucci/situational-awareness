#!/bin/bash

# Palo Alto Emergency Response System - Project Generator (FIXED VERSION)
# This script creates the complete project structure with all files
# Run: chmod +x generate-project.sh && ./generate-project.sh

set -e

PROJECT_NAME="palo-alto-emergency-response"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚨 Palo Alto Emergency Response System Generator 🚨${NC}"
echo "=================================================="
echo

# Check if project directory exists
if [[ -d "$PROJECT_NAME" ]]; then
    echo -e "${YELLOW}Directory $PROJECT_NAME already exists. Remove it? (y/N):${NC}"
    read -r response
    if [[ $response =~ ^[Yy]$ ]]; then
        rm -rf "$PROJECT_NAME"
    else
        echo "Exiting..."
        exit 1
    fi
fi

echo -e "${BLUE}Creating project structure...${NC}"

# Create main directory
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Create directory structure
echo -e "${BLUE}Creating directories...${NC}"
mkdir -p .github/workflows
mkdir -p .github/ISSUE_TEMPLATE
mkdir -p docs/screenshots
mkdir -p src/web/css
mkdir -p src/web/js
mkdir -p src/web/assets/icons
mkdir -p src/web/assets/images
mkdir -p src/api/routes
mkdir -p src/api/middleware
mkdir -p src/api/config
mkdir -p src/api/models
mkdir -p src/api/services
mkdir -p src/api/tests/integration
mkdir -p src/api/tests/unit
mkdir -p database/migrations
mkdir -p database/seeds
mkdir -p database/backups
mkdir -p scripts
mkdir -p nginx/sites-enabled
mkdir -p nginx/ssl
mkdir -p monitoring/grafana/dashboards
mkdir -p monitoring/grafana/datasources
mkdir -p tests/e2e
mkdir -p tests/load
mkdir -p tests/security
mkdir -p logs

# Create placeholder files
touch database/backups/.gitkeep
touch nginx/ssl/.gitkeep
touch src/web/assets/icons/.gitkeep
touch src/web/assets/images/.gitkeep
touch logs/.gitkeep

echo -e "${GREEN}✅ Directory structure created${NC}"

# Create README.md
echo -e "${BLUE}Creating README.md...${NC}"
cat > README.md << 'EOF'
# Palo Alto Emergency Response Mapping System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17+-blue.svg)](https://www.postgresql.org/)
[![PostGIS](https://img.shields.io/badge/PostGIS-3.0+-green.svg)](https://postgis.net/)

A comprehensive web-based mapping application designed specifically for emergency first responders in Palo Alto, California.

## 🚨 Features

- **Real-time Incident Mapping** - Track active emergencies with severity levels
- **Personnel Tracking** - Monitor fire, EMS, and police unit locations  
- **Resource Management** - Manage emergency shelters and equipment
- **Geospatial Queries** - Advanced spatial analysis for optimal response

## 🚀 Quick Start

### Docker (Recommended)
```bash
git clone https://github.com/yourusername/palo-alto-emergency-response.git
cd palo-alto-emergency-response
docker-compose up -d
```

### System Installation  
```bash
chmod +x install.sh
sudo ./install.sh
```

## 🛠️ Technology Stack

- **Frontend**: HTML5, CSS3, JavaScript, Leaflet.js
- **Backend**: Node.js, Express.js, PostgreSQL
- **Database**: PostgreSQL with PostGIS and TimescaleDB

## 📄 License

This project is licensed under the MIT License.

---

**⚡ Built for Emergency Response Excellence ⚡**
EOF
echo -e "${GREEN}✅ Created: README.md${NC}"

# Create main HTML file
echo -e "${BLUE}Creating main HTML application...${NC}"
cat > src/web/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Emergency Response Mapping System</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.css" />
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
            height: 100vh;
            background: #1a1a1a;
            color: #fff;
            overflow: hidden;
        }
        
        .container { display: flex; height: 100vh; }
        
        .query-panel {
            width: 350px;
            background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
            border-right: 3px solid #3498db;
            padding: 20px;
            overflow-y: auto;
        }
        
        .map-container { flex: 1; position: relative; background: #0f1419; }
        #map { width: 100%; height: 100%; }
        
        .panel-header {
            background: rgba(52, 73, 94, 0.8);
            padding: 15px;
            margin: -20px -20px 20px -20px;
            border-bottom: 2px solid #3498db;
        }
        
        .panel-title {
            font-size: 18px;
            font-weight: bold;
            color: #ecf0f1;
            margin-bottom: 5px;
        }
        
        .query-section { margin-bottom: 25px; }
        
        .section-title {
            font-size: 14px;
            font-weight: bold;
            color: #3498db;
            margin-bottom: 10px;
            padding-bottom: 5px;
            border-bottom: 1px solid #34495e;
        }
        
        .query-button {
            width: 100%;
            padding: 12px;
            margin-bottom: 8px;
            background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%);
            border: none;
            border-radius: 6px;
            color: white;
            cursor: pointer;
            font-size: 13px;
            transition: all 0.3s ease;
        }
        
        .query-button:hover {
            background: linear-gradient(135deg, #c0392b 0%, #a93226 100%);
            transform: translateY(-1px);
        }
        
        .query-button.status { background: linear-gradient(135deg, #f39c12 0%, #e67e22 100%); }
        .query-button.location { background: linear-gradient(135deg, #27ae60 0%, #229954 100%); }
        
        .legend {
            position: absolute;
            bottom: 10px;
            right: 10px;
            background: rgba(0,0,0,0.9);
            padding: 15px;
            border-radius: 8px;
            z-index: 1000;
            border: 1px solid #3498db;
        }
        
        .legend-title { font-weight: bold; margin-bottom: 10px; color: #3498db; }
        
        .legend-item {
            display: flex;
            align-items: center;
            margin-bottom: 5px;
            font-size: 11px;
        }
        
        .legend-icon {
            width: 16px;
            height: 16px;
            margin-right: 8px;
            border-radius: 50%;
        }
        
        .incident { background: #e74c3c; }
        .personnel { background: #3498db; }
        .shelter { background: #27ae60; }
    </style>
</head>
<body>
    <div class="container">
        <div class="query-panel">
            <div class="panel-header">
                <div class="panel-title">Emergency Response System</div>
                <div style="font-size: 12px; color: #bdc3c7;">Palo Alto, California</div>
            </div>
            
            <div class="query-section">
                <div class="section-title">🚨 Incident Queries</div>
                <button class="query-button" onclick="loadIncidents()">Active Incidents</button>
                <button class="query-button" onclick="loadIncidentsByType()">Incidents by Type</button>
            </div>
            
            <div class="query-section">
                <div class="section-title">👥 Personnel</div>
                <button class="query-button status" onclick="loadPersonnel()">Personnel Status</button>
                <button class="query-button status" onclick="loadUnits()">Unit Locations</button>
            </div>
            
            <div class="query-section">
                <div class="section-title">🏠 Resources</div>
                <button class="query-button location" onclick="loadShelters()">Available Shelters</button>
                <button class="query-button location" onclick="loadResources()">Resource Centers</button>
            </div>
        </div>
        
        <div class="map-container">
            <div id="map"></div>
            
            <div class="legend">
                <div class="legend-title">Map Legend</div>
                <div class="legend-item">
                    <div class="legend-icon incident"></div>
                    <span>Active Incidents</span>
                </div>
                <div class="legend-item">
                    <div class="legend-icon personnel"></div>
                    <span>Personnel</span>
                </div>
                <div class="legend-item">
                    <div class="legend-icon shelter"></div>
                    <span>Shelters/Resources</span>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.js"></script>
    <script src="js/app.js"></script>
</body>
</html>
EOF
echo -e "${GREEN}✅ Created: src/web/index.html${NC}"

# Create JavaScript application
echo -e "${BLUE}Creating JavaScript application...${NC}"
cat > src/web/js/app.js << 'EOF'
// Emergency Response Mapping Application
let map;
let incidentLayer, personnelLayer, shelterLayer;

const TILE_SERVER_URL = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
const PALO_ALTO_BOUNDS = {
    center: [37.4419, -122.1430],
    bounds: [[37.3894, -122.1965], [37.4944, -122.0895]],
    zoom: 12
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
EOF
echo -e "${GREEN}✅ Created: src/web/js/app.js${NC}"

# Create package.json with better error handling and dependencies
echo -e "${BLUE}Creating API package.json...${NC}"
cat > src/api/package.json << 'EOF'
{
  "name": "palo-alto-emergency-response-api",
  "version": "1.0.0",
  "description": "Emergency Response System API Server",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "jest --detectOpenHandles",
    "health": "curl -f http://localhost:3000/api/health || exit 1"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "express-rate-limit": "^6.10.0",
    "pg": "^8.11.3",
    "ws": "^8.14.2",
    "express-validator": "^7.0.1",
    "compression": "^1.7.4",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.7.0"
  },
  "keywords": ["emergency", "response", "gis", "palo-alto"],
  "author": "Emergency Response Team",
  "license": "MIT",
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF
echo -e "${GREEN}✅ Created: src/api/package.json${NC}"

# Create API routes with better error handling
echo -e "${BLUE}Creating API routes...${NC}"

# Incidents route
cat > src/api/routes/incidents.js << 'EOF'
const express = require("express");
const router = express.Router();

router.get("/active", async (req, res) => {
    try {
        const pool = req.app.get("db");
        
        if (!pool) {
            console.warn("Database pool not available, using mock data");
            return res.json({
                success: true,
                data: getMockIncidents(),
                count: getMockIncidents().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database not connected"
            });
        }

        try {
            const result = await pool.query("SELECT * FROM active_incidents_view LIMIT 10");
            res.json({
                success: true,
                data: result.rows,
                count: result.rows.length,
                timestamp: new Date().toISOString()
            });
        } catch (dbError) {
            console.warn("Database query failed, using mock data:", dbError.message);
            res.json({
                success: true,
                data: getMockIncidents(),
                count: getMockIncidents().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database query failed"
            });
        }
    } catch (error) {
        console.error("Error in incidents/active:", error);
        res.status(500).json({
            success: false,
            error: { code: "INTERNAL_ERROR", message: "Failed to retrieve incidents" }
        });
    }
});

function getMockIncidents() {
    return [
        {
            id: 1,
            incident_number: "INC-2025-000001",
            incident_type: "Structure Fire",
            severity: "High",
            priority: 1,
            status: "Active",
            longitude: -122.1630,
            latitude: 37.4419,
            address: "450 University Ave",
            title: "Commercial Building Fire",
            description: "Heavy smoke showing from 2-story commercial building",
            reported_at: new Date().toISOString()
        },
        {
            id: 2,
            incident_number: "INC-2025-000002",
            incident_type: "Medical Emergency",
            severity: "Medium",
            priority: 2,
            status: "Active",
            longitude: -122.1334,
            latitude: 37.4505,
            address: "660 Stanford Shopping Center",
            title: "Medical Emergency",
            description: "Person collapsed, conscious and breathing",
            reported_at: new Date().toISOString()
        }
    ];
}

module.exports = router;
EOF
echo -e "${GREEN}✅ Created: src/api/routes/incidents.js${NC}"

# Personnel route
cat > src/api/routes/personnel.js << 'EOF'
const express = require("express");
const router = express.Router();

router.get("/status", async (req, res) => {
    try {
        const pool = req.app.get("db");
        
        if (!pool) {
            console.warn("Database pool not available, using mock data");
            return res.json({
                success: true,
                data: getMockPersonnel(),
                count: getMockPersonnel().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database not connected"
            });
        }

        try {
            const query = `
                SELECT 
                    u.id as unit_id,
                    u.call_sign,
                    ut.type_name as unit_type,
                    u.status,
                    ST_X(ul.location) as longitude,
                    ST_Y(ul.location) as latitude,
                    ul.timestamp as last_update
                FROM units u
                JOIN unit_types ut ON u.unit_type_id = ut.id
                LEFT JOIN LATERAL (
                    SELECT location, timestamp 
                    FROM unit_locations 
                    WHERE unit_id = u.id 
                    ORDER BY timestamp DESC 
                    LIMIT 1
                ) ul ON true
            `;
            const result = await pool.query(query);
            res.json({
                success: true,
                data: result.rows,
                count: result.rows.length,
                timestamp: new Date().toISOString()
            });
        } catch (dbError) {
            console.warn("Database query failed, using mock data:", dbError.message);
            res.json({
                success: true,
                data: getMockPersonnel(),
                count: getMockPersonnel().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database query failed"
            });
        }
    } catch (error) {
        console.error("Error in personnel/status:", error);
        res.status(500).json({
            success: false,
            error: { code: "INTERNAL_ERROR", message: "Failed to retrieve personnel status" }
        });
    }
});

function getMockPersonnel() {
    return [
        {
            unit_id: "PAFD-E01",
            call_sign: "Engine 1",
            unit_type: "Fire Engine",
            status: "Available",
            longitude: -122.1576,
            latitude: 37.4614,
            last_update: new Date().toISOString()
        },
        {
            unit_id: "PAEMS-M01",
            call_sign: "Medic 1",
            unit_type: "Ambulance",
            status: "Dispatched",
            longitude: -122.1540,
            latitude: 37.4349,
            last_update: new Date().toISOString()
        },
        {
            unit_id: "PAPD-01",
            call_sign: "Unit 1",
            unit_type: "Police Unit",
            status: "On Patrol",
            longitude: -122.1560,
            latitude: 37.4419,
            last_update: new Date().toISOString()
        }
    ];
}

module.exports = router;
EOF
echo -e "${GREEN}✅ Created: src/api/routes/personnel.js${NC}"

# Shelters route
cat > src/api/routes/shelters.js << 'EOF'
const express = require("express");
const router = express.Router();

router.get("/available", async (req, res) => {
    try {
        const pool = req.app.get("db");
        
        if (!pool) {
            console.warn("Database pool not available, using mock data");
            return res.json({
                success: true,
                data: getMockShelters(),
                count: getMockShelters().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database not connected"
            });
        }

        try {
            const query = `
                SELECT 
                    id, facility_name, facility_type,
                    ST_X(location) as longitude,
                    ST_Y(location) as latitude,
                    address, total_capacity, current_occupancy, available_capacity,
                    operational_status, has_kitchen, has_medical, wheelchair_accessible, contact_phone
                FROM shelters
                WHERE operational_status IN ('Available', 'Open')
                ORDER BY available_capacity DESC
            `;
            const result = await pool.query(query);
            res.json({
                success: true,
                data: result.rows,
                count: result.rows.length,
                timestamp: new Date().toISOString()
            });
        } catch (dbError) {
            console.warn("Database query failed, using mock data:", dbError.message);
            res.json({
                success: true,
                data: getMockShelters(),
                count: getMockShelters().length,
                timestamp: new Date().toISOString(),
                note: "Using mock data - database query failed"
            });
        }
    } catch (error) {
        console.error("Error in shelters/available:", error);
        res.status(500).json({
            success: false,
            error: { code: "INTERNAL_ERROR", message: "Failed to retrieve shelter information" }
        });
    }
});

function getMockShelters() {
    return [
        {
            id: "SHELTER-01",
            facility_name: "Mitchell Park Community Center",
            facility_type: "Community Center",
            longitude: -122.1549,
            latitude: 37.4282,
            address: "3700 Middlefield Rd, Palo Alto, CA",
            total_capacity: 150,
            current_occupancy: 0,
            available_capacity: 150,
            operational_status: "Available",
            has_kitchen: true,
            has_medical: true,
            wheelchair_accessible: true,
            contact_phone: "(650) 463-4920"
        },
        {
            id: "SHELTER-02",
            facility_name: "Cubberley Community Center",
            facility_type: "Community Center",
            longitude: -122.1345,
            latitude: 37.4092,
            address: "4000 Middlefield Rd, Palo Alto, CA",
            total_capacity: 200,
            current_occupancy: 80,
            available_capacity: 120,
            operational_status: "Available",
            has_kitchen: true,
            has_medical: false,
            wheelchair_accessible: true,
            contact_phone: "(650) 463-4950"
        }
    ];
}

module.exports = router;
EOF
echo -e "${GREEN}✅ Created: src/api/routes/shelters.js${NC}"

# Create API server with better error handling and database connection
echo -e "${BLUE}Creating API server...${NC}"
cat > src/api/server.js << 'EOF'
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const compression = require("compression");
const { Pool } = require("pg");
const WebSocket = require("ws");
const http = require("http");
const path = require("path");

// Load environment variables
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

console.log("🚨 Emergency Response System API Starting...");

// Route imports with error handling
let incidentsRouter, personnelRouter, sheltersRouter;

try {
    incidentsRouter = require("./routes/incidents");
    console.log("✅ Loaded incidents routes");
} catch (err) {
    console.warn("⚠️ incidents route not found, creating placeholder");
    incidentsRouter = express.Router();
    incidentsRouter.get("/active", (req, res) => res.json({ success: true, data: [], note: "Route not implemented" }));
}

try {
    personnelRouter = require("./routes/personnel");
    console.log("✅ Loaded personnel routes");
} catch (err) {
    console.warn("⚠️ personnel route not found, creating placeholder");
    personnelRouter = express.Router();
    personnelRouter.get("/status", (req, res) => res.json({ success: true, data: [], note: "Route not implemented" }));
}

try {
    sheltersRouter = require("./routes/shelters");
    console.log("✅ Loaded shelters routes");
} catch (err) {
    console.warn("⚠️ shelters route not found, creating placeholder");
    sheltersRouter = express.Router();
    sheltersRouter.get("/available", (req, res) => res.json({ success: true, data: [], note: "Route not implemented" }));
}

// Configuration
const config = {
    port: process.env.PORT || 3000,
    database: {
        host: process.env.DB_HOST || "localhost",
        port: parseInt(process.env.DB_PORT) || 5432,
        database: process.env.DB_NAME || "palo_alto_emergency",
        user: process.env.DB_USER || "emergency_user",
        password: process.env.DB_PASSWORD || "emergency_pass",
        ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
        connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 30000,
        max: 20,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 2000,
    }
};

console.log("📝 Configuration loaded:", {
    port: config.port,
    database: {
        host: config.database.host,
        port: config.database.port,
        database: config.database.database,
        user: config.database.user,
        ssl: config.database.ssl
    }
});

// Initialize Express app
const app = express();
const server = http.createServer(app);

// Database connection pool with better error handling
let pool = null;
try {
    pool = new Pool(config.database);
    
    // Test database connection with timeout
    const testConnection = async () => {
        try {
            const client = await pool.connect();
            console.log("🔌 Testing database connection...");
            const result = await client.query('SELECT NOW() as current_time');
            console.log("✅ Database connection successful:", result.rows[0].current_time);
            client.release();
            return true;
        } catch (err) {
            console.error("❌ Database connection failed:", err.message);
            console.log("⚠️ Continuing without database connection (using mock data)");
            return false;
        }
    };

    // Test connection on startup
    testConnection().then((connected) => {
        if (connected) {
            app.set("db", pool);
            console.log("✅ Database pool configured and ready");
        } else {
            console.log("⚠️ Running without database connection");
        }
    });

    // Handle pool errors
    pool.on('error', (err) => {
        console.error('❌ Database pool error:', err);
    });

} catch (error) {
    console.error("❌ Failed to create database pool:", error.message);
    console.log("⚠️ Continuing without database connection...");
}

// Middleware
app.use(helmet({ 
    contentSecurityPolicy: false, 
    crossOriginEmbedderPolicy: false,
    crossOriginResourcePolicy: { policy: "cross-origin" }
}));

app.use(cors({
    origin: true,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

app.use(compression());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 1000,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: { code: "RATE_LIMIT_EXCEEDED", message: "Too many requests" } }
});
app.use("/api", limiter);

// Request logging middleware
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
    next();
});

// API Routes
app.use("/api/v1/incidents", incidentsRouter);
app.use("/api/v1/personnel", personnelRouter);
app.use("/api/v1/shelters", sheltersRouter);

// Health check endpoint with more comprehensive checks
app.get("/api/health", async (req, res) => {
    const health = {
        success: true,
        status: "healthy",
        timestamp: new Date().toISOString(),
        services: {
            api: "running",
            database: "unknown",
            routes: "loaded"
        },
        version: "1.0.0",
        uptime: process.uptime()
    };

    try {
        if (pool) {
            const client = await pool.connect();
            await client.query('SELECT NOW()');
            client.release();
            health.services.database = "connected";
        } else {
            health.services.database = "disconnected";
            health.status = "partial";
        }
    } catch (error) {
        console.error("Health check database error:", error.message);
        health.services.database = "error";
        health.status = "partial";
    }

    const statusCode = health.status === "healthy" ? 200 : 206;
    res.status(statusCode).json(health);
});

// API root endpoint
app.get("/api/v1", (req, res) => {
    res.json({
        success: true,
        message: "Palo Alto Emergency Response System API",
        version: "1.0.0",
        endpoints: {
            health: "/api/health",
            incidents: "/api/v1/incidents/active",
            personnel: "/api/v1/personnel/status",
            shelters: "/api/v1/shelters/available"
        },
        documentation: "https://github.com/yourusername/palo-alto-emergency-response",
        timestamp: new Date().toISOString()
    });
});

// WebSocket setup for real-time updates
const wss = new WebSocket.Server({ server, path: "/ws" });
const wsClients = new Set();

wss.on("connection", (ws, req) => {
    console.log("🔌 WebSocket client connected from:", req.socket.remoteAddress);
    wsClients.add(ws);
    
    ws.send(JSON.stringify({
        type: "connection",
        message: "Connected to Emergency Response System",
        timestamp: new Date().toISOString()
    }));
    
    ws.on("close", () => { 
        console.log("🔌 WebSocket client disconnected");
        wsClients.delete(ws); 
    });
    
    ws.on("error", (error) => { 
        console.error("WebSocket error:", error); 
        wsClients.delete(ws); 
    });
});

// Broadcast updates to WebSocket clients
function broadcastUpdate(data) {
    const message = JSON.stringify({
        type: "update",
        data: data,
        timestamp: new Date().toISOString()
    });
    
    wsClients.forEach(ws => {
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(message);
        }
    });
}

// Error handling middleware
app.use((err, req, res, next) => {
    console.error("🚨 API Error:", err);
    res.status(500).json({
        success: false,
        error: { 
            code: "INTERNAL_ERROR", 
            message: process.env.NODE_ENV === 'production' ? "Internal server error" : err.message 
        }
    });
});

// 404 handler
app.use((req, res) => {
    console.log(`404 - Not found: ${req.method} ${req.path}`);
    res.status(404).json({
        success: false,
        error: { code: "NOT_FOUND", message: `Endpoint ${req.method} ${req.path} not found` }
    });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('🔄 Received SIGTERM, shutting down gracefully');
    server.close(() => {
        console.log('✅ HTTP server closed');
        if (pool) {
            pool.end(() => {
                console.log('✅ Database pool closed');
                process.exit(0);
            });
        } else {
            process.exit(0);
        }
    });
});

process.on('SIGINT', async () => {
    console.log('🔄 Received SIGINT, shutting down gracefully');
    server.close(() => {
        console.log('✅ HTTP server closed');
        if (pool) {
            pool.end(() => {
                console.log('✅ Database pool closed');
                process.exit(0);
            });
        } else {
            process.exit(0);
        }
    });
});

// Start server
server.listen(config.port, () => {
    console.log(`
🚨 Emergency Response System API Server
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🌐 Server: http://localhost:${config.port}
  📊 Health: http://localhost:${config.port}/api/health
  🔗 API Root: http://localhost:${config.port}/api/v1
  🔗 WebSocket: ws://localhost:${config.port}/ws
  📍 Service Area: Palo Alto, California
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚒 Ready for emergency response operations
    `);
});

module.exports = { app, server, pool, broadcastUpdate };
EOF
echo -e "${GREEN}✅ Created: src/api/server.js${NC}"

# Create database schema (same as original but with better error handling)
echo -e "${BLUE}Creating database schema...${NC}"
cat > database/schema.sql << 'EOF'
-- Emergency Response Database Schema for Palo Alto
-- PostgreSQL 17 with PostGIS and TimescaleDB extensions

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Incident Types
CREATE TABLE IF NOT EXISTS incident_types (
    id SERIAL PRIMARY KEY,
    type_code VARCHAR(20) UNIQUE NOT NULL,
    type_name VARCHAR(100) NOT NULL,
    default_severity VARCHAR(20) DEFAULT 'Medium',
    color_code VARCHAR(7) DEFAULT '#e74c3c',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO incident_types (type_code, type_name, default_severity, color_code) VALUES
('FIRE', 'Structure Fire', 'High', '#e74c3c'),
('MEDICAL', 'Medical Emergency', 'Medium', '#f39c12'),
('ACCIDENT', 'Traffic Accident', 'Medium', '#e67e22')
ON CONFLICT (type_code) DO NOTHING;

-- Unit Types  
CREATE TABLE IF NOT EXISTS unit_types (
    id SERIAL PRIMARY KEY,
    type_code VARCHAR(20) UNIQUE NOT NULL,
    type_name VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL,
    color_code VARCHAR(7) DEFAULT '#3498db',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO unit_types (type_code, type_name, department, color_code) VALUES
('FIRE_ENGINE', 'Fire Engine', 'PAFD', '#e74c3c'),
('AMBULANCE', 'Ambulance', 'PAEMS', '#f39c12'),
('POLICE_UNIT', 'Police Unit', 'PAPD', '#3498db')
ON CONFLICT (type_code) DO NOTHING;

-- Incidents Table
CREATE TABLE IF NOT EXISTS incidents (
    id SERIAL PRIMARY KEY,
    incident_number VARCHAR(50) UNIQUE NOT NULL,
    incident_type_id INTEGER NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('Low', 'Medium', 'High', 'Critical')),
    priority INTEGER NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    status VARCHAR(20) NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'In Progress', 'Resolved', 'Cancelled')),
    location GEOMETRY(POINT, 4326) NOT NULL,
    address VARCHAR(255),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    reported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    dispatched_at TIMESTAMPTZ,
    created_by VARCHAR(50) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT fk_incidents_type FOREIGN KEY (incident_type_id) REFERENCES incident_types(id)
);

-- Add incident_number generation function
CREATE OR REPLACE FUNCTION generate_incident_number() RETURNS TEXT AS $$
BEGIN
    RETURN 'INC-' || extract(year from now()) || '-' || lpad((SELECT COALESCE(MAX(CAST(SUBSTRING(incident_number FROM 10) AS INTEGER)), 0) + 1 FROM incidents WHERE incident_number LIKE 'INC-' || extract(year from now()) || '-%')::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- Set default for incident_number
ALTER TABLE incidents ALTER COLUMN incident_number SET DEFAULT generate_incident_number();

-- Convert to TimescaleDB hypertable (with error handling)
DO $$
BEGIN
    -- Try to create hypertable, ignore if already exists or TimescaleDB not available
    BEGIN
        PERFORM create_hypertable('incidents', 'reported_at', if_not_exists => TRUE);
        RAISE NOTICE 'Created TimescaleDB hypertable for incidents';
    EXCEPTION 
        WHEN OTHERS THEN
            RAISE NOTICE 'TimescaleDB not available or hypertable already exists for incidents: %', SQLERRM;
    END;
END $$;

-- Units Table
CREATE TABLE IF NOT EXISTS units (
    id VARCHAR(50) PRIMARY KEY,
    unit_type_id INTEGER NOT NULL,
    call_sign VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Available' CHECK (
        status IN ('Available', 'Dispatched', 'En Route', 'On Scene', 'Out of Service')
    ),
    station_name VARCHAR(100),
    station_location GEOMETRY(POINT, 4326),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT fk_units_type FOREIGN KEY (unit_type_id) REFERENCES unit_types(id)
);

-- Unit Location Tracking
CREATE TABLE IF NOT EXISTS unit_locations (
    unit_id VARCHAR(50) NOT NULL,
    location GEOMETRY(POINT, 4326) NOT NULL,
    status VARCHAR(20) NOT NULL,
    activity VARCHAR(100),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (unit_id, timestamp),
    CONSTRAINT fk_unit_locations_unit FOREIGN KEY (unit_id) REFERENCES units(id)
);

-- Convert unit_locations to hypertable (with error handling)
DO $$
BEGIN
    BEGIN
        PERFORM create_hypertable('unit_locations', 'timestamp', if_not_exists => TRUE);
        RAISE NOTICE 'Created TimescaleDB hypertable for unit_locations';
    EXCEPTION 
        WHEN OTHERS THEN
            RAISE NOTICE 'TimescaleDB not available or hypertable already exists for unit_locations: %', SQLERRM;
    END;
END $$;

-- Shelters
CREATE TABLE IF NOT EXISTS shelters (
    id VARCHAR(50) PRIMARY KEY,
    facility_name VARCHAR(255) NOT NULL,
    facility_type VARCHAR(50) NOT NULL,
    location GEOMETRY(POINT, 4326) NOT NULL,
    address VARCHAR(255) NOT NULL,
    total_capacity INTEGER NOT NULL DEFAULT 0,
    current_occupancy INTEGER NOT NULL DEFAULT 0,
    available_capacity INTEGER GENERATED ALWAYS AS (total_capacity - current_occupancy) STORED,
    has_kitchen BOOLEAN DEFAULT FALSE,
    has_medical BOOLEAN DEFAULT FALSE,
    wheelchair_accessible BOOLEAN DEFAULT FALSE,
    contact_phone VARCHAR(20),
    operational_status VARCHAR(20) DEFAULT 'Available',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Service boundaries table for Palo Alto
CREATE TABLE IF NOT EXISTS service_boundaries (
    id SERIAL PRIMARY KEY,
    boundary_name VARCHAR(100) NOT NULL,
    boundary_type VARCHAR(50) NOT NULL,
    jurisdiction VARCHAR(50) NOT NULL,
    boundary_geometry GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance (PostgreSQL 17 compatible)
CREATE INDEX IF NOT EXISTS idx_incidents_location ON incidents USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_incidents_reported_at ON incidents USING BTREE (reported_at);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents USING BTREE (status);
CREATE INDEX IF NOT EXISTS idx_incidents_severity ON incidents USING BTREE (severity);

CREATE INDEX IF NOT EXISTS idx_unit_locations_location ON unit_locations USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_unit_locations_timestamp ON unit_locations USING BTREE (timestamp);
CREATE INDEX IF NOT EXISTS idx_unit_locations_unit_id ON unit_locations USING BTREE (unit_id);

CREATE INDEX IF NOT EXISTS idx_units_status ON units USING BTREE (status);
CREATE INDEX IF NOT EXISTS idx_units_station_location ON units USING GIST (station_location);

CREATE INDEX IF NOT EXISTS idx_shelters_location ON shelters USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_shelters_status ON shelters USING BTREE (operational_status);

CREATE INDEX IF NOT EXISTS idx_service_boundaries_geometry ON service_boundaries USING GIST (boundary_geometry);

-- Functions for PostgreSQL 17
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers
DO $$
BEGIN
    -- Drop triggers if they exist and recreate
    DROP TRIGGER IF EXISTS update_incidents_updated_at ON incidents;
    DROP TRIGGER IF EXISTS update_units_updated_at ON units;
    DROP TRIGGER IF EXISTS update_shelters_updated_at ON shelters;
    
    CREATE TRIGGER update_incidents_updated_at 
        BEFORE UPDATE ON incidents 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
        
    CREATE TRIGGER update_units_updated_at 
        BEFORE UPDATE ON units 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
        
    CREATE TRIGGER update_shelters_updated_at 
        BEFORE UPDATE ON shelters 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
END $$;

-- Views (PostgreSQL 17 compatible)
CREATE OR REPLACE VIEW active_incidents_view AS
SELECT 
    i.id,
    i.incident_number,
    it.type_name as incident_type,
    i.severity,
    i.status,
    ST_X(i.location) as longitude,
    ST_Y(i.location) as latitude,
    i.address,
    i.title,
    i.description,
    i.reported_at
FROM incidents i
JOIN incident_types it ON i.incident_type_id = it.id
WHERE i.status IN ('Active', 'In Progress');

-- PostgreSQL 17 compatible spatial functions
CREATE OR REPLACE FUNCTION get_nearest_units(
    incident_location GEOMETRY,
    max_units INTEGER DEFAULT 5,
    unit_status VARCHAR DEFAULT 'Available'
)
RETURNS TABLE (
    unit_id VARCHAR,
    unit_type VARCHAR,
    distance_meters DOUBLE PRECISION,
    estimated_travel_time_minutes DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        ut.type_name,
        ST_Distance(ul.location::geography, incident_location::geography) as distance_meters,
        (ST_Distance(ul.location::geography, incident_location::geography) / 1609.34 / 35 * 60) as estimated_travel_time_minutes
    FROM units u
    JOIN unit_types ut ON u.unit_type_id = ut.id
    JOIN LATERAL (
        SELECT location 
        FROM unit_locations 
        WHERE unit_id = u.id 
        ORDER BY timestamp DESC 
        LIMIT 1
    ) ul ON true
    WHERE u.status = unit_status
    ORDER BY ST_Distance(ul.location, incident_location)
    LIMIT max_units;
END;
$$ LANGUAGE plpgsql;

-- Function to check if point is within service area
CREATE OR REPLACE FUNCTION is_within_service_area(check_location GEOMETRY)
RETURNS BOOLEAN AS $$
DECLARE
    within_boundary BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM service_boundaries 
        WHERE boundary_type = 'City Limits' 
        AND ST_Within(check_location, boundary_geometry)
        AND (effective_date <= CURRENT_DATE)
    ) INTO within_boundary;
    
    RETURN within_boundary;
END;
$$ LANGUAGE plpgsql;

-- Insert Palo Alto service boundary
INSERT INTO service_boundaries (boundary_name, boundary_type, jurisdiction, boundary_geometry) VALUES (
    'Palo Alto City Limits',
    'City Limits',
    'City of Palo Alto',
    ST_GeomFromText('POLYGON((-122.1965 37.3894, -122.0895 37.3894, -122.0895 37.4944, -122.1965 37.4944, -122.1965 37.3894))', 4326)
) ON CONFLICT DO NOTHING;

-- Sample data
INSERT INTO units (id, unit_type_id, call_sign, station_name, station_location) VALUES 
('PAFD-E01', 1, 'Engine 1', 'Station 1', ST_GeomFromText('POINT(-122.1576 37.4614)', 4326)),
('PAEMS-M01', 2, 'Medic 1', 'Station 1', ST_GeomFromText('POINT(-122.1576 37.4614)', 4326)),
('PAPD-01', 3, 'Unit 1', 'Police HQ', ST_GeomFromText('POINT(-122.1560 37.4419)', 4326))
ON CONFLICT (id) DO NOTHING;

INSERT INTO shelters (id, facility_name, facility_type, location, address, total_capacity, has_kitchen, wheelchair_accessible, contact_phone) VALUES
('SHELTER-01', 'Mitchell Park Community Center', 'Community Center', ST_GeomFromText('POINT(-122.1549 37.4282)', 4326), '3700 Middlefield Rd, Palo Alto, CA', 150, true, true, '(650) 463-4920'),
('SHELTER-02', 'Cubberley Community Center', 'Community Center', ST_GeomFromText('POINT(-122.1345 37.4092)', 4326), '4000 Middlefield Rd, Palo Alto, CA', 200, true, true, '(650) 463-4950')
ON CONFLICT (id) DO NOTHING;

-- Only insert incidents if the table is empty
INSERT INTO incidents (incident_type_id, severity, location, address, title, description) 
SELECT 1, 'High', ST_GeomFromText('POINT(-122.1630 37.4419)', 4326), '450 University Ave', 'Commercial Building Fire', 'Heavy smoke showing from 2-story building'
WHERE NOT EXISTS (SELECT 1 FROM incidents WHERE address = '450 University Ave');

INSERT INTO incidents (incident_type_id, severity, location, address, title, description) 
SELECT 2, 'Medium', ST_GeomFromText('POINT(-122.1334 37.4505)', 4326), '660 Stanford Shopping Center', 'Medical Emergency', 'Person collapsed, conscious and breathing'
WHERE NOT EXISTS (SELECT 1 FROM incidents WHERE address = '660 Stanford Shopping Center');

INSERT INTO unit_locations (unit_id, location, status, activity) VALUES
('PAFD-E01', ST_GeomFromText('POINT(-122.1576 37.4614)', 4326), 'Available', 'In Station'),
('PAEMS-M01', ST_GeomFromText('POINT(-122.1630 37.4419)', 4326), 'Dispatched', 'En Route'),
('PAPD-01', ST_GeomFromText('POINT(-122.1560 37.4419)', 4326), 'On Patrol', 'Routine Patrol')
ON CONFLICT (unit_id, timestamp) DO NOTHING;

-- Set up data retention policies for TimescaleDB (if available)
DO $$
BEGIN
    -- Try to set retention policies, ignore if TimescaleDB not available
    BEGIN
        PERFORM add_retention_policy('unit_locations', INTERVAL '30 days');
        PERFORM add_retention_policy('incidents', INTERVAL '7 years');
        RAISE NOTICE 'Added TimescaleDB retention policies';
    EXCEPTION 
        WHEN OTHERS THEN
            RAISE NOTICE 'TimescaleDB retention policies not set: %', SQLERRM;
    END;
END $$;

-- Create completion notification
DO $$
BEGIN
    RAISE NOTICE '=======================================================';
    RAISE NOTICE 'Emergency Response Database Schema Setup Complete!';
    RAISE NOTICE '=======================================================';
    RAISE NOTICE 'Database: Palo Alto Emergency Response System';
    RAISE NOTICE 'PostgreSQL Version: Compatible with PostgreSQL 17';
    RAISE NOTICE 'Extensions: PostGIS enabled, TimescaleDB attempted';
    RAISE NOTICE 'Tables created: % main tables with indexes', (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE');
    RAISE NOTICE 'Views created: % operational views', (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public');
    RAISE NOTICE 'Functions created: Helper functions for spatial queries';
    RAISE NOTICE 'Sample data: Palo Alto units, stations, and shelters loaded';
    RAISE NOTICE '=======================================================';
    RAISE NOTICE 'Ready for emergency response operations!';
    RAISE NOTICE '=======================================================';
END $$;
EOF
echo -e "${GREEN}✅ Created: database/schema.sql${NC}"

# Create configuration files
echo -e "${BLUE}Creating configuration files...${NC}"

cat > .gitignore << 'EOF'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment files
.env
.env.local
.env.production
.env.development

# Database files
*.db
*.sqlite

# Logs
logs/
*.log

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Build output
dist/
build/

# Docker
.dockerignore

# Upload directories
uploads/
temp/

# Backup files
*.backup
*.bak

# Config files with sensitive data
/config/production.json
/src/api/.env
/database/backups/*
!database/backups/.gitkeep
EOF
echo -e "${GREEN}✅ Created: .gitignore${NC}"

cat > .env.example << 'EOF'
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=palo_alto_emergency
DB_USER=emergency_user
DB_PASSWORD=your_secure_password_here
DB_SSL=false
DB_CONNECTION_TIMEOUT=30000

# Application Configuration
NODE_ENV=production
PORT=3000
WEB_PORT=80

# Security (optional)
JWT_SECRET=your_jwt_secret_here
API_KEY=your_api_key_here

# External Services (optional)
TILE_SERVER_URL=https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png
WEATHER_API_KEY=your_weather_api_key
GEOCODING_API_KEY=your_geocoding_api_key
EOF
echo -e "${GREEN}✅ Created: .env.example${NC}"

cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2025 Palo Alto Emergency Response System

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
echo -e "${GREEN}✅ Created: LICENSE${NC}"

# Create Docker files
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  database:
    image: timescale/timescaledb-ha:pg16-latest
    container_name: emergency-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: palo_alto_emergency
      POSTGRES_USER: emergency_user
      POSTGRES_PASSWORD: ${DB_PASSWORD:-emergency_secure_pass_2025}
      POSTGRES_HOST_AUTH_METHOD: ${POSTGRES_HOST_AUTH_METHOD:-scram-sha-256}
      # PostgreSQL settings
      POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256 --auth-local=peer"
      # TimescaleDB settings
      TIMESCALEDB_TELEMETRY: 'off'
      TS_TUNE_MEMORY: ${TS_TUNE_MEMORY:-4GB}
      TS_TUNE_NUM_CPUS: ${TS_TUNE_NUM_CPUS:-4}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/schema.sql:/docker-entrypoint-initdb.d/01-schema.sql
    ports:
      - "5432:5432"
    networks:
      - emergency-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U emergency_user -d palo_alto_emergency"]
      interval: 30s
      timeout: 10s
      retries: 5
    command: >
      postgres
      -c shared_preload_libraries=timescaledb
      -c max_connections=200
      -c shared_buffers=256MB
      -c effective_cache_size=1GB
      -c work_mem=4MB
      -c maintenance_work_mem=64MB

  api:
    build: 
      context: ./src/api
      dockerfile: Dockerfile
    container_name: emergency-api
    restart: unless-stopped
    environment:
      NODE_ENV: production
      PORT: 3000
      DB_HOST: database
      DB_PORT: 5432
      DB_NAME: palo_alto_emergency
      DB_USER: emergency_user
      DB_PASSWORD: ${DB_PASSWORD:-emergency_secure_pass_2025}
      # PostgreSQL connection settings
      DB_SSL: ${DB_SSL:-false}
      DB_CONNECTION_TIMEOUT: 30000
    ports:
      - "3000:3000"
    depends_on:
      database:
        condition: service_healthy
    networks:
      - emergency-network
    volumes:
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/api/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) }).on('error', () => process.exit(1))"]
      interval: 30s
      timeout: 10s
      retries: 3

  web:
    image: nginx:alpine
    container_name: emergency-web
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./src/web:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      - api
    networks:
      - emergency-network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 5s
      retries: 3

volumes:
  postgres_data:
    driver: local

networks:
  emergency-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF
echo -e "${GREEN}✅ Created: docker-compose.yml${NC}"

cat > src/api/Dockerfile << 'EOF'
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    mkdir -p /app/logs && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) }).on('error', () => process.exit(1))"

# Start the application
CMD ["node", "server.js"]
EOF
echo -e "${GREEN}✅ Created: src/api/Dockerfile${NC}"

# Create FIXED nginx configuration
cat > nginx.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; img-src 'self' data: https:; font-src 'self' https:; connect-src 'self' ws: wss:;" always;
    
    # Main application - serve static files
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            add_header Vary "Accept-Encoding";
        }
    }
    
    # API endpoints
    location /api {
        # Remove trailing slashes
        rewrite ^/api/(.*)$ /api/$1 break;
        
        proxy_pass http://api:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        
        # CORS headers for API
        add_header Access-Control-Allow-Origin $http_origin always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;
        add_header Access-Control-Allow-Credentials "true" always;
        
        # Handle OPTIONS requests for CORS
        if ($request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin $http_origin always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;
            add_header Access-Control-Allow-Credentials "true" always;
            add_header Access-Control-Max-Age 1728000 always;
            add_header Content-Length 0;
            add_header Content-Type "text/plain charset=UTF-8";
            return 204;
        }
    }
    
    # WebSocket support for real-time updates
    location /ws {
        proxy_pass http://api:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket timeouts
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_connect_timeout 60s;
    }
    
    # Health check endpoint (nginx level)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ \.(htaccess|htpasswd|ini|log|sh|sql|conf)$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/json
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Client settings
    client_max_body_size 10M;
    client_body_buffer_size 128k;
    
    # Proxy timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    proxy_buffering on;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    proxy_busy_buffers_size 8k;
}

# HTTPS configuration (uncomment and configure for production)
# server {
#     listen 443 ssl http2;
#     server_name your-domain.com;
#     
#     # SSL certificate files
#     ssl_certificate /etc/nginx/ssl/cert.pem;
#     ssl_certificate_key /etc/nginx/ssl/key.pem;
#     
#     # Modern SSL configuration
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-RSA-AES128-GCM-SHA256;
#     ssl_prefer_server_ciphers off;
#     
#     # SSL session settings
#     ssl_session_timeout 1d;
#     ssl_session_cache shared:SSL:10m;
#     ssl_session_tickets off;
#     
#     # OCSP stapling
#     ssl_stapling on;
#     ssl_stapling_verify on;
#     
#     # Security headers for HTTPS
#     add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
#     
#     # Same location blocks as HTTP server
#     # ... (copy from HTTP server block)
# }

# Redirect HTTP to HTTPS (uncomment for production with SSL)
# server {
#     listen 80;
#     server_name your-domain.com;
#     return 301 https://$server_name$request_uri;
# }
EOF
echo -e "${GREEN}✅ Created: nginx.conf${NC}"

# Create FIXED installer script with proper path handling
echo -e "${BLUE}Creating FIXED installer script...${NC}"
cat > install.sh << 'EOF'
#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚨 Palo Alto Emergency Response System Installer 🚨${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Get the absolute path of the project directory
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
echo -e "${BLUE}Project root: $PROJECT_ROOT${NC}"

# Verify we're in the correct directory
if [[ ! -f "$PROJECT_ROOT/database/schema.sql" ]]; then
    echo -e "${RED}Error: database/schema.sql not found at $PROJECT_ROOT/database/schema.sql${NC}"
    echo -e "${RED}Please ensure you're running this script from the project root directory${NC}"
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/src/api/package.json" ]]; then
    echo -e "${RED}Error: API package.json not found at $PROJECT_ROOT/src/api/package.json${NC}"
    exit 1
fi

echo -e "${BLUE}Installing system packages...${NC}"
if [[ -f /etc/debian_version ]]; then
    # Ubuntu/Debian - Install PostgreSQL 16 (more stable than 17)
    apt update
    apt install -y wget ca-certificates
    
    # Add PostgreSQL official APT repository
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    
    apt update
    apt install -y postgresql-16 postgresql-client-16 postgresql-16-postgis-3 nodejs npm nginx git curl
    
    # Install TimescaleDB (optional)
    apt install -y timescaledb-2-postgresql-16 || echo -e "${YELLOW}TimescaleDB not available, continuing without it${NC}"
    
elif [[ -f /etc/redhat-release ]]; then
    # RHEL/CentOS/Fedora
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm || \
    yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    
    dnf install -y postgresql16-server postgresql16 postgresql16-contrib postgis34_16 nodejs npm nginx git curl || \
    yum install -y postgresql16-server postgresql16 postgresql16-contrib postgis34_16 nodejs npm nginx git curl
    
    # Initialize PostgreSQL
    /usr/pgsql-16/bin/postgresql-16-setup initdb
    systemctl enable postgresql-16
    systemctl start postgresql-16
    
else
    echo -e "${RED}Unsupported operating system. Please install PostgreSQL 16+, PostGIS, Node.js, and nginx manually.${NC}"
    exit 1
fi

echo -e "${BLUE}Setting up PostgreSQL...${NC}"
# Start PostgreSQL service
if systemctl list-unit-files | grep -q "postgresql-16.service"; then
    systemctl start postgresql-16
    systemctl enable postgresql-16
    PG_SERVICE="postgresql-16"
else
    systemctl start postgresql
    systemctl enable postgresql  
    PG_SERVICE="postgresql"
fi

# Wait for PostgreSQL to be ready
sleep 5

# Generate secure password
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Configure PostgreSQL authentication
echo -e "${BLUE}Configuring PostgreSQL authentication...${NC}"
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP "PostgreSQL \K[0-9]+")
if [[ $PG_VERSION -ge 14 ]]; then
    PG_HBA_FILE=$(sudo -u postgres psql -t -c "SHOW hba_file;" | xargs)
    if [[ -f "$PG_HBA_FILE" ]]; then
        cp "$PG_HBA_FILE" "$PG_HBA_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        # Update authentication methods
        sed -i 's/local   all             all                                     peer/local   all             all                                     scram-sha-256/' "$PG_HBA_FILE" || true
        sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            scram-sha-256/' "$PG_HBA_FILE" || true
        systemctl reload $PG_SERVICE
        sleep 2
    fi
fi

# Create database and user
echo -e "${BLUE}Creating database and user...${NC}"
sudo -u postgres createdb palo_alto_emergency || echo -e "${YELLOW}Database may already exist${NC}"
sudo -u postgres psql -c "DROP USER IF EXISTS emergency_user;" || true
sudo -u postgres psql -c "CREATE USER emergency_user WITH PASSWORD '$DB_PASSWORD';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE palo_alto_emergency TO emergency_user;" || true
sudo -u postgres psql -c "ALTER USER emergency_user CREATEDB;" || true

# Grant schema permissions
echo -e "${BLUE}Setting up database permissions...${NC}"
sudo -u postgres psql -d palo_alto_emergency -c "GRANT ALL ON SCHEMA public TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO emergency_user;" || true
sudo -u postgres psql -d palo_alto_emergency -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO emergency_user;" || true

# Load database schema with absolute path
echo -e "${BLUE}Loading database schema from $PROJECT_ROOT/database/schema.sql...${NC}"
if [[ -f "$PROJECT_ROOT/database/schema.sql" ]]; then
    sudo -u postgres psql -d palo_alto_emergency -f "$PROJECT_ROOT/database/schema.sql" || echo -e "${YELLOW}Schema loading completed with warnings${NC}"
else
    echo -e "${RED}Error: Schema file not found at $PROJECT_ROOT/database/schema.sql${NC}"
    exit 1
fi

# Configure TimescaleDB if available
if command -v timescaledb-tune &> /dev/null; then
    echo -e "${BLUE}Configuring TimescaleDB...${NC}"
    timescaledb-tune --quiet --yes || echo -e "${YELLOW}TimescaleDB tuning skipped${NC}"
    systemctl restart $PG_SERVICE
    sleep 3
fi

echo -e "${BLUE}Installing Node.js dependencies...${NC}"
cd "$PROJECT_ROOT/src/api"

if [[ ! -f "package.json" ]]; then
    echo -e "${RED}Error: package.json not found in $PROJECT_ROOT/src/api/package.json${NC}"
    exit 1
fi

npm install --production
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: npm install failed${NC}"
    exit 1
fi

cd "$PROJECT_ROOT"

echo -e "${BLUE}Creating system service...${NC}"
API_DIR="$PROJECT_ROOT/src/api"

# Verify the API directory exists and has the server file
if [[ ! -f "$API_DIR/server.js" ]]; then
    echo -e "${RED}Error: server.js not found at $API_DIR/server.js${NC}"
    exit 1
fi

# Create logs directory with proper permissions
mkdir -p "$PROJECT_ROOT/logs"
chmod 755 "$PROJECT_ROOT/logs"

# Create environment file
cat > "$PROJECT_ROOT/.env" << ENVFILE
NODE_ENV=production
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=palo_alto_emergency
DB_USER=emergency_user
DB_PASSWORD=$DB_PASSWORD
DB_SSL=false
DB_CONNECTION_TIMEOUT=30000
ENVFILE

chmod 600 "$PROJECT_ROOT/.env"

# Create systemd service file
cat > /etc/systemd/system/emergency-response.service << SERVICEFILE
[Unit]
Description=Palo Alto Emergency Response System
Documentation=https://github.com/yourusername/palo-alto-emergency-response
After=network.target $PG_SERVICE.service
Wants=$PG_SERVICE.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$API_DIR
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=emergency-response

# Environment file
EnvironmentFile=$PROJECT_ROOT/.env

# Security restrictions
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$PROJECT_ROOT/logs

[Install]
WantedBy=multi-user.target
SERVICEFILE

systemctl daemon-reload
systemctl enable emergency-response

echo -e "${BLUE}Configuring Nginx...${NC}"
WEB_DIR="$PROJECT_ROOT/src/web"

if [[ ! -d "$WEB_DIR" ]]; then
    echo -e "${RED}Error: Web directory not found at $WEB_DIR${NC}"
    exit 1
fi

# Copy web files to standard location
WEB_ROOT="/var/www/emergency-response"
echo -e "${BLUE}Setting up web root at $WEB_ROOT...${NC}"
mkdir -p "$WEB_ROOT"
cp -r "$WEB_DIR/"* "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT" 2>/dev/null || chown -R nginx:nginx "$WEB_ROOT" 2>/dev/null || true
chmod -R 644 "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;

# Copy and configure nginx
if [[ -f "$PROJECT_ROOT/nginx.conf" ]]; then
    if [[ -d /etc/nginx/sites-available ]]; then
        # Ubuntu/Debian style
        cp "$PROJECT_ROOT/nginx.conf" /etc/nginx/sites-available/emergency-response
        # Update the web root path in the config
        sed -i "s|/usr/share/nginx/html|$WEB_ROOT|g" /etc/nginx/sites-available/emergency-response
        
        # Enable site
        ln -sf /etc/nginx/sites-available/emergency-response /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
    else
        # RHEL/CentOS style
        cp "$PROJECT_ROOT/nginx.conf" /etc/nginx/conf.d/emergency-response.conf
        # Update the web root path in the config
        sed -i "s|/usr/share/nginx/html|$WEB_ROOT|g" /etc/nginx/conf.d/emergency-response.conf
    fi
else
    echo -e "${RED}Error: nginx.conf not found at $PROJECT_ROOT/nginx.conf${NC}"
    exit 1
fi

# Test nginx configuration
if ! nginx -t; then
    echo -e "${RED}Nginx configuration test failed${NC}"
    exit 1
fi

# Start services
echo -e "${BLUE}Starting services...${NC}"
systemctl start emergency-response
nginx -t && systemctl restart nginx && systemctl enable nginx

# Save configuration
echo "DB_PASSWORD=$DB_PASSWORD" > /etc/emergency-response.conf
echo "PROJECT_ROOT=$PROJECT_ROOT" >> /etc/emergency-response.conf
echo "POSTGRES_VERSION=$PG_VERSION" >> /etc/emergency-response.conf
chmod 600 /etc/emergency-response.conf

# Create backup script
cat > /usr/local/bin/emergency-backup.sh << 'BACKUPEOF'
#!/bin/bash
BACKUP_DIR="/var/backups/emergency-response"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="palo_alto_emergency"
DB_USER="emergency_user"

# Load configuration
if [[ -f /etc/emergency-response.conf ]]; then
    source /etc/emergency-response.conf
fi

mkdir -p "$BACKUP_DIR"

# Database backup
if [[ -n "$DB_PASSWORD" ]]; then
    export PGPASSWORD="$DB_PASSWORD"
    pg_dump -h localhost -U "$DB_USER" "$DB_NAME" --no-password | gzip > "$BACKUP_DIR/database_$DATE.sql.gz"
fi

# Application backup
if [[ -n "$PROJECT_ROOT" ]] && [[ -d "$PROJECT_ROOT" ]]; then
    tar -czf "$BACKUP_DIR/application_$DATE.tar.gz" \
        --exclude='node_modules' \
        --exclude='logs' \
        --exclude='.git' \
        -C "$(dirname "$PROJECT_ROOT")" "$(basename "$PROJECT_ROOT")"
fi

# Keep only last 30 days of backups
find "$BACKUP_DIR" -type f -mtime +30 -delete

echo "Backup completed: $DATE"
BACKUPEOF

chmod +x /usr/local/bin/emergency-backup.sh

# Add to crontab for daily backups at 2 AM
(crontab -l 2>/dev/null | grep -v emergency-backup; echo "0 2 * * * /usr/local/bin/emergency-backup.sh") | crontab -

# Wait for services to fully start
sleep 10

# Verify services are running
echo -e "${BLUE}Verifying services...${NC}"

if systemctl is-active --quiet $PG_SERVICE; then
    echo -e "${GREEN}✅ PostgreSQL $PG_VERSION is running${NC}"
else
    echo -e "${RED}❌ PostgreSQL failed to start${NC}"
fi

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx is running${NC}"  
else
    echo -e "${RED}❌ Nginx failed to start${NC}"
    echo "Checking nginx error log:"
    tail -n 10 /var/log/nginx/error.log || true
fi

if systemctl is-active --quiet emergency-response; then
    echo -e "${GREEN}✅ Emergency Response System is running${NC}"
else
    echo -e "${RED}❌ Emergency Response System failed to start${NC}"
    echo "Checking service status:"
    systemctl status emergency-response --no-pager || true
    echo "Checking logs:"
    journalctl -u emergency-response -n 20 --no-pager || true
fi

# Test API health
sleep 5
API_HEALTH=$(curl -s -f http://localhost:3000/api/health || echo "FAILED")
if [[ "$API_HEALTH" != "FAILED" ]]; then
    echo -e "${GREEN}✅ API health check passed${NC}"
else
    echo -e "${YELLOW}⚠️ API health check failed, but service may still be starting${NC}"
fi

echo -e "${GREEN}✅ Installation completed!${NC}"
echo "=============================================="
echo -e "${BLUE}System Information:${NC}"
echo "🌐 Web Interface: http://$(hostname -I | awk '{print $1}')"
echo "📊 API Health Check: http://$(hostname -I | awk '{print $1}'):3000/api/health"
echo "🔧 Nginx Health Check: http://$(hostname -I | awk '{print $1}')/health"
echo "🗄️ Database: PostgreSQL $PG_VERSION with PostGIS"
echo "📁 Project Root: $PROJECT_ROOT"
echo "📁 Web Root: $WEB_ROOT"
echo "🔑 Database Password: $DB_PASSWORD"
echo ""
echo -e "${BLUE}Service Management:${NC}"
echo "• Start:   sudo systemctl start emergency-response"
echo "• Stop:    sudo systemctl stop emergency-response"
echo "• Restart: sudo systemctl restart emergency-response"
echo "• Status:  sudo systemctl status emergency-response"
echo "• Logs:    sudo journalctl -u emergency-response -f"
echo ""
echo -e "${BLUE}Database Management:${NC}"
echo "• PostgreSQL Service: sudo systemctl status $PG_SERVICE"
echo "• Connect to DB: sudo -u postgres psql -d palo_alto_emergency"
echo "• Test DB: psql -h localhost -d palo_alto_emergency -U emergency_user"
echo "• Backup Script: /usr/local/bin/emergency-backup.sh"
echo ""
echo -e "${BLUE}Configuration Files:${NC}"
echo "• Environment: $PROJECT_ROOT/.env"
echo "• Service: /etc/systemd/system/emergency-response.service"
echo "• Database Config: /etc/emergency-response.conf"
echo "• Backup Script: /usr/local/bin/emergency-backup.sh"
echo ""
echo -e "${BLUE}Troubleshooting:${NC}"
echo "• Service logs: sudo journalctl -u emergency-response -f"
echo "• Nginx logs: sudo tail -f /var/log/nginx/error.log"
echo "• Test API: curl http://localhost:3000/api/health"
echo "• Test Database: psql -h localhost -d palo_alto_emergency -U emergency_user -c 'SELECT 1;'"
echo ""

if systemctl is-active --quiet emergency-response && systemctl is-active --quiet nginx && systemctl is-active --quiet $PG_SERVICE; then
    echo -e "${GREEN}🚨 All services running - Emergency Response System Ready! 🚨${NC}"
else
    echo -e "${YELLOW}⚠️ Some services may need attention. Check the status above.${NC}"
    echo -e "${YELLOW}Run: sudo journalctl -u emergency-response -f${NC}"
fi
echo "=============================================="
EOF
chmod +x install.sh
echo -e "${GREEN}✅ Created: install.sh${NC}"

# Create GitHub workflow files
echo -e "${BLUE}Creating GitHub workflow files...${NC}"

cat > .github/workflows/ci.yml << 'EOF'
name: Emergency Response CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: timescale/timescaledb:latest-pg16
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_emergency
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Node.js 18
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: src/api/package-lock.json
    
    - name: Install API dependencies
      working-directory: src/api
      run: npm ci
    
    - name: Run API tests
      working-directory: src/api
      run: npm test
      env:
        NODE_ENV: test
        DB_HOST: localhost
        DB_PORT: 5432
        DB_NAME: test_emergency
        DB_USER: postgres
        DB_PASSWORD: postgres
    
    - name: Test API health endpoint
      run: |
        cd src/api
        npm start &
        sleep 10
        curl -f http://localhost:3000/api/health
        pkill -f "node server.js"
    
    - name: Test Docker build
      run: docker build -t emergency-api ./src/api

  security:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Run security audit
      working-directory: src/api
      run: npm audit --audit-level high

  docker:
    runs-on: ubuntu-latest
    needs: [test]
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Test Docker Compose
      run: |
        echo "DB_PASSWORD=test_password_123" > .env
        docker-compose -f docker-compose.yml config
        docker-compose up -d database
        sleep 30
        docker-compose down
EOF
echo -e "${GREEN}✅ Created: .github/workflows/ci.yml${NC}"

cat > .github/ISSUE_TEMPLATE/bug_report.md << 'EOF'
---
name: Bug report
about: Report a system issue
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description
A clear and concise description of what the bug is.

## Steps to Reproduce
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '...'
3. Scroll down to '...'
4. See error

## Expected Behavior
A clear and concise description of what you expected to happen.

## Screenshots
If applicable, add screenshots to help explain your problem.

## Environment Information
- OS: [e.g. Ubuntu 20.04]
- Browser: [e.g. Chrome 91]
- System Version: [e.g. 1.0.0]
- Database: [e.g. PostgreSQL 16]

## Additional Context
Add any other context about the problem here.

## Emergency Level
- [ ] Critical - System down
- [ ] High - Major functionality affected
- [ ] Medium - Minor functionality affected
- [ ] Low - Enhancement or minor issue
EOF
echo -e "${GREEN}✅ Created: .github/ISSUE_TEMPLATE/bug_report.md${NC}"

cat > .github/ISSUE_TEMPLATE/feature_request.md << 'EOF'
---
name: Feature request
about: Suggest an idea for the emergency response system
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

## Feature Description
A clear and concise description of the feature you'd like to see.

## Problem Statement
What problem would this feature solve? Is your feature request related to a problem?

## Proposed Solution
Describe the solution you'd like to see implemented.

## Alternative Solutions
Describe any alternative solutions or features you've considered.

## Emergency Response Context
How would this feature improve emergency response operations?

## Additional Context
Add any other context, mockups, or examples about the feature request here.

## Priority
- [ ] Critical - Needed for emergency operations
- [ ] High - Would significantly improve operations
- [ ] Medium - Nice to have improvement
- [ ] Low - Minor enhancement
EOF
echo -e "${GREEN}✅ Created: .github/ISSUE_TEMPLATE/feature_request.md${NC}"

# Create additional documentation
echo -e "${BLUE}Creating documentation...${NC}"

cat > docs/DEPLOYMENT.md << 'EOF'
# Deployment Guide

This guide covers different deployment methods for the Palo Alto Emergency Response System.

## Prerequisites

- PostgreSQL 16+ with PostGIS extension
- Node.js 18+
- Nginx (for production)
- Docker and Docker Compose (for containerized deployment)

## Quick Deployment Options

### 1. Docker Deployment (Recommended)

```bash
# Clone the repository
git clone <repository-url>
cd palo-alto-emergency-response

# Set environment variables
cp .env.example .env
# Edit .env with your configuration

# Start services
docker-compose up -d

# Access the application
open http://localhost
```

### 2. System Installation

```bash
# Run the automated installer
sudo ./install.sh
```

### 3. Manual Installation

#### Database Setup
```bash
# Install PostgreSQL and PostGIS
sudo apt install postgresql-16 postgresql-16-postgis-3

# Create database and user
sudo -u postgres createdb palo_alto_emergency
sudo -u postgres psql -c "CREATE USER emergency_user WITH PASSWORD 'your_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE palo_alto_emergency TO emergency_user;"

# Load schema
sudo -u postgres psql -d palo_alto_emergency -f database/schema.sql
```

#### API Setup
```bash
cd src/api
npm install --production
cp ../../.env.example ../../.env
# Edit .env with your database credentials
npm start
```

#### Web Server Setup
```bash
# Install and configure Nginx
sudo apt install nginx
sudo cp nginx.conf /etc/nginx/sites-available/emergency-response
sudo ln -s /etc/nginx/sites-available/emergency-response /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

## Production Configuration

### SSL/HTTPS Setup
1. Obtain SSL certificates (Let's Encrypt recommended)
2. Update nginx.conf with SSL configuration
3. Redirect HTTP to HTTPS

### Security Hardening
- Configure firewall (UFW/iptables)
- Set up fail2ban
- Regular security updates
- Database connection encryption
- API rate limiting (already configured)

### Monitoring
- Set up log aggregation
- Configure health check monitoring
- Database performance monitoring
- Application performance monitoring

### Backup Strategy
- Automated daily database backups (script included)
- Application file backups
- Configuration backups
- Test restore procedures

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Application environment | `production` |
| `PORT` | API server port | `3000` |
| `DB_HOST` | Database host | `localhost` |
| `DB_PORT` | Database port | `5432` |
| `DB_NAME` | Database name | `palo_alto_emergency` |
| `DB_USER` | Database user | `emergency_user` |
| `DB_PASSWORD` | Database password | - |
| `DB_SSL` | Enable SSL for database | `false` |

## Troubleshooting

### Common Issues

**Database Connection Failed**
- Check PostgreSQL service status
- Verify credentials in .env
- Check pg_hba.conf authentication

**API Server Won't Start**
- Check Node.js version (18+ required)
- Verify all dependencies installed
- Check port availability
- Review logs: `journalctl -u emergency-response -f`

**Nginx 502 Bad Gateway**
- Verify API server is running
- Check nginx configuration
- Verify proxy settings

### Log Locations
- API logs: `journalctl -u emergency-response`
- Nginx logs: `/var/log/nginx/error.log`
- PostgreSQL logs: `/var/log/postgresql/`

### Performance Tuning
- Adjust PostgreSQL settings for your hardware
- Configure connection pooling
- Enable nginx caching
- Optimize database indexes
EOF
echo -e "${GREEN}✅ Created: docs/DEPLOYMENT.md${NC}"

cat > docs/API.md << 'EOF'
# API Documentation

The Emergency Response System API provides RESTful endpoints for managing emergency incidents, personnel, and resources.

## Base URL
```
http://localhost:3000/api/v1
```

## Authentication
Currently, the API does not require authentication. In production, implement appropriate authentication mechanisms.

## Endpoints

### Health Check
Check the system status and database connectivity.

**GET** `/api/health`

Response:
```json
{
  "success": true,
  "status": "healthy",
  "timestamp": "2025-01-27T10:00:00.000Z",
  "services": {
    "api": "running",
    "database": "connected"
  },
  "uptime": 3600
}
```

### Incidents

#### Get Active Incidents
Retrieve all currently active emergency incidents.

**GET** `/api/v1/incidents/active`

Response:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "incident_number": "INC-2025-000001",
      "incident_type": "Structure Fire",
      "severity": "High",
      "status": "Active",
      "longitude": -122.1630,
      "latitude": 37.4419,
      "address": "450 University Ave",
      "title": "Commercial Building Fire",
      "description": "Heavy smoke showing from building",
      "reported_at": "2025-01-27T10:00:00.000Z"
    }
  ],
  "count": 1,
  "timestamp": "2025-01-27T10:00:00.000Z"
}
```

### Personnel

#### Get Personnel Status
Retrieve current status and locations of emergency personnel units.

**GET** `/api/v1/personnel/status`

Response:
```json
{
  "success": true,
  "data": [
    {
      "unit_id": "PAFD-E01",
      "call_sign": "Engine 1",
      "unit_type": "Fire Engine",
      "status": "Available",
      "longitude": -122.1576,
      "latitude": 37.4614,
      "last_update": "2025-01-27T10:00:00.000Z"
    }
  ],
  "count": 1,
  "timestamp": "2025-01-27T10:00:00.000Z"
}
```

### Shelters

#### Get Available Shelters
Retrieve information about emergency shelters and their capacity.

**GET** `/api/v1/shelters/available`

Response:
```json
{
  "success": true,
  "data": [
    {
      "id": "SHELTER-01",
      "facility_name": "Mitchell Park Community Center",
      "facility_type": "Community Center",
      "longitude": -122.1549,
      "latitude": 37.4282,
      "address": "3700 Middlefield Rd, Palo Alto, CA",
      "total_capacity": 150,
      "current_occupancy": 0,
      "available_capacity": 150,
      "operational_status": "Available",
      "has_kitchen": true,
      "has_medical": true,
      "wheelchair_accessible": true,
      "contact_phone": "(650) 463-4920"
    }
  ],
  "count": 1,
  "timestamp": "2025-01-27T10:00:00.000Z"
}
```

## WebSocket Events

Connect to `ws://localhost:3000/ws` for real-time updates.

### Connection Event
```json
{
  "type": "connection",
  "message": "Connected to Emergency Response System",
  "timestamp": "2025-01-27T10:00:00.000Z"
}
```

### Update Event
```json
{
  "type": "update",
  "data": {
    "incident_id": 1,
    "status": "In Progress"
  },
  "timestamp": "2025-01-27T10:00:00.000Z"
}
```

## Error Handling

All API endpoints return errors in a consistent format:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

### Common Error Codes
- `INTERNAL_ERROR` - Server error (500)
- `NOT_FOUND` - Endpoint not found (404)
- `RATE_LIMIT_EXCEEDED` - Too many requests (429)
- `VALIDATION_ERROR` - Invalid request data (400)

## Rate Limiting
- 1000 requests per hour per IP
- Headers included in responses:
  - `X-RateLimit-Limit`
  - `X-RateLimit-Remaining`
  - `X-RateLimit-Reset`

## CORS
Cross-origin requests are enabled for all origins in development. Configure appropriately for production.
EOF
echo -e "${GREEN}✅ Created: docs/API.md${NC}"

# Create a comprehensive README for the project
cat > INSTALL.md << 'EOF'
# Installation Instructions

This document provides step-by-step installation instructions for the Palo Alto Emergency Response System.

## System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04+ / CentOS 8+ / RHEL 8+
- **Memory**: 4GB RAM
- **Storage**: 20GB free space
- **CPU**: 2 cores

### Recommended Requirements
- **OS**: Ubuntu 22.04 LTS
- **Memory**: 8GB RAM
- **Storage**: 50GB free space (SSD preferred)
- **CPU**: 4 cores
- **Network**: Static IP address for production

## Installation Methods

### Method 1: Automated Installation (Recommended)

The automated installer handles all dependencies and configuration:

```bash
# Download the project
git clone <repository-url>
cd palo-alto-emergency-response

# Make installer executable
chmod +x install.sh

# Run installer as root
sudo ./install.sh
```

The installer will:
- Install PostgreSQL 16 with PostGIS
- Install Node.js and npm
- Install and configure Nginx
- Create database and user
- Load schema and sample data
- Configure systemd service
- Set up log rotation and backups

### Method 2: Docker Installation

For containerized deployment:

```bash
# Clone repository
git clone <repository-url>
cd palo-alto-emergency-response

# Copy environment file
cp .env.example .env

# Edit configuration
nano .env

# Start services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

### Method 3: Manual Installation

For custom installations or troubleshooting:

#### Step 1: Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y postgresql-16 postgresql-16-postgis-3 nodejs npm nginx git curl
```

**RHEL/CentOS:**
```bash
sudo dnf install -y postgresql16-server postgresql16-contrib nodejs npm nginx git curl
```

#### Step 2: Configure Database

```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database
sudo -u postgres createdb palo_alto_emergency

# Create user
sudo -u postgres psql -c "CREATE USER emergency_user WITH PASSWORD 'secure_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE palo_alto_emergency TO emergency_user;"

# Load schema
sudo -u postgres psql -d palo_alto_emergency -f database/schema.sql
```

#### Step 3: Configure Application

```bash
# Install API dependencies
cd src/api
npm install --production

# Create environment file
cp ../../.env.example ../../.env
# Edit .env with your database credentials

# Test API
npm start
```

#### Step 4: Configure Web Server

```bash
# Copy web files
sudo cp -r src/web/* /var/www/html/

# Configure Nginx
sudo cp nginx.conf /etc/nginx/sites-available/emergency-response
sudo ln -s /etc/nginx/sites-available/emergency-response /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Test and restart
sudo nginx -t
sudo systemctl restart nginx
```

## Post-Installation

### 1. Verify Installation

Check that all services are running:
```bash
sudo systemctl status emergency-response
sudo systemctl status postgresql
sudo systemctl status nginx
```

Test endpoints:
```bash
curl http://localhost/health
curl http://localhost:3000/api/health
curl http://localhost:3000/api/v1/incidents/active
```

### 2. Configure Firewall

```bash
# Allow HTTP and HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Allow PostgreSQL (if needed for external access)
sudo ufw allow 5432

# Enable firewall
sudo ufw enable
```

### 3. Set Up SSL (Production)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

### 4. Configure Monitoring

```bash
# View logs
sudo journalctl -u emergency-response -f
sudo tail -f /var/log/nginx