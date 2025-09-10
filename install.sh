#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚨 Palo Alto Situational Awareness System Installer 🚨${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    exit 1
fi

# FIXED: Get the absolute path of the project directory
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
echo -e "${BLUE}Project root: $PROJECT_ROOT${NC}"

# FIXED: Verify we're in the correct directory and all files exist
if [[ ! -f "$PROJECT_ROOT/database/schema.sql" ]]; then
    echo -e "${RED}Error: database/schema.sql not found at $PROJECT_ROOT/database/schema.sql${NC}"
    echo -e "${YELLOW}This usually means:${NC}"
    echo -e "${YELLOW}1. The project generator didn't complete successfully${NC}"
    echo -e "${YELLOW}2. You're running install.sh from the wrong directory${NC}"
    echo -e "${YELLOW}3. Some files were accidentally deleted${NC}"
    echo ""
    echo -e "${BLUE}Current directory structure:${NC}"
    ls -la "$PROJECT_ROOT/" 2>/dev/null || echo "Cannot access $PROJECT_ROOT"
    echo ""
    echo -e "${BLUE}Checking for key files:${NC}"
    echo -n "database/ directory: "
    [[ -d "$PROJECT_ROOT/database" ]] && echo -e "${GREEN}EXISTS${NC}" || echo -e "${RED}MISSING${NC}"
    echo -n "src/api/ directory: "
    [[ -d "$PROJECT_ROOT/src/api" ]] && echo -e "${GREEN}EXISTS${NC}" || echo -e "${RED}MISSING${NC}"
    echo -n "src/web/ directory: "
    [[ -d "$PROJECT_ROOT/src/web" ]] && echo -e "${GREEN}EXISTS${NC}" || echo -e "${RED}MISSING${NC}"
    echo ""
    echo -e "${YELLOW}To fix this issue:${NC}"
    echo -e "${YELLOW}1. Re-run the project generator: ./generate-project.sh${NC}"
    echo -e "${YELLOW}2. Or create the missing schema file manually (see below)${NC}"
    echo -e "${YELLOW}3. Make sure you're in the project root directory${NC}"
    
    # Offer to create the missing schema file
    echo ""
    echo -e "${BLUE}Would you like me to create the missing database schema file? (y/N):${NC}"
    read -r create_schema
    if [[ $create_schema =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Creating missing database directory and schema file...${NC}"
        mkdir -p "$PROJECT_ROOT/database"
        
        cat > "$PROJECT_ROOT/database/schema.sql" << 'SCHEMA_EOF'
-- Situational Awareness Database Schema for Palo Alto
-- PostgreSQL 16 with PostGIS and TimescaleDB extensions

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
CREATE OR REPLACE FUNCTION generate_incident_number() RETURNS TEXT AS $
BEGIN
    RETURN 'INC-' || extract(year from now()) || '-' || lpad((SELECT COALESCE(MAX(CAST(SUBSTRING(incident_number FROM 10) AS INTEGER)), 0) + 1 FROM incidents WHERE incident_number LIKE 'INC-' || extract(year from now()) || '-%')::TEXT, 6, '0');
END;
$ LANGUAGE plpgsql;

-- Set default for incident_number
ALTER TABLE incidents ALTER COLUMN incident_number SET DEFAULT generate_incident_number();

-- Convert to TimescaleDB hypertable (with error handling)
DO $
BEGIN
    -- Try to create hypertable, ignore if already exists or TimescaleDB not available
    BEGIN
        PERFORM create_hypertable('incidents', 'reported_at', if_not_exists => TRUE);
        RAISE NOTICE 'Created TimescaleDB hypertable for incidents';
    EXCEPTION 
        WHEN OTHERS THEN
            RAISE NOTICE 'TimescaleDB not available or hypertable already exists for incidents: %', SQLERRM;
    END;
END $;

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
DO $
BEGIN
    BEGIN
        PERFORM create_hypertable('unit_locations', 'timestamp', if_not_exists => TRUE);
        RAISE NOTICE 'Created TimescaleDB hypertable for unit_locations';
    EXCEPTION 
        WHEN OTHERS THEN
            RAISE NOTICE 'TimescaleDB not available or hypertable already exists for unit_locations: %', SQLERRM;
    END;
END $;

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

-- Indexes for performance
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

-- Functions
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$ LANGUAGE plpgsql;

-- Triggers
DO $
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
END $;

-- Views
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

-- Create completion notification
DO $
BEGIN
    RAISE NOTICE '=======================================================';
    RAISE NOTICE 'Situational Awareness Database Schema Setup Complete!';
    RAISE NOTICE 'Database: Palo Alto Situational Awareness System';
    RAISE NOTICE 'Ready for Situational Awareness operations!';
    RAISE NOTICE '=======================================================';
END $;
SCHEMA_EOF

        echo -e "${GREEN}✅ Created missing database schema file${NC}"
        
        # Also create any other missing directories
        mkdir -p "$PROJECT_ROOT/database/migrations"
        mkdir -p "$PROJECT_ROOT/database/seeds" 
        mkdir -p "$PROJECT_ROOT/database/backups"
        touch "$PROJECT_ROOT/database/backups/.gitkeep"
        
        echo -e "${GREEN}✅ Created missing database directories${NC}"
    else
        echo -e "${RED}Please re-run the project generator to create all missing files${NC}"
        exit 1
    fi
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
sudo -u postgres createdb palo_alto_situational_awareness || echo -e "${YELLOW}Database may already exist${NC}"
sudo -u postgres psql -c "DROP USER IF EXISTS situational_awareness_user;" || true
sudo -u postgres psql -c "CREATE USER situational_awareness_user WITH PASSWORD '$DB_PASSWORD';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE palo_alto_situational_awareness TO situational_awareness_user;" || true
sudo -u postgres psql -c "ALTER USER situational_awareness_user CREATEDB;" || true

# Grant schema permissions
echo -e "${BLUE}Setting up database permissions...${NC}"
sudo -u postgres psql -d palo_alto_situational_awareness -c "GRANT ALL ON SCHEMA public TO situational_awareness_user;" || true
sudo -u postgres psql -d palo_alto_situational_awareness -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO situational_awareness_user;" || true
sudo -u postgres psql -d palo_alto_situational_awareness -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO situational_awareness_user;" || true
sudo -u postgres psql -d palo_alto_situational_awareness -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO situational_awareness_user;" || true
sudo -u postgres psql -d palo_alto_situational_awareness -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO situational_awareness_user;" || true

# FIXED: Load database schema with absolute path
echo -e "${BLUE}Loading database schema from $PROJECT_ROOT/database/schema.sql...${NC}"
if [[ -f "$PROJECT_ROOT/database/schema.sql" ]]; then
    sudo -u postgres psql -d palo_alto_situational_awareness -f "$PROJECT_ROOT/database/schema.sql" || echo -e "${YELLOW}Schema loading completed with warnings${NC}"
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

# FIXED: Create environment file
cat > "$PROJECT_ROOT/.env" << ENVFILE
NODE_ENV=production
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=palo_alto_situational_awareness
DB_USER=situational_awareness_user
DB_PASSWORD=$DB_PASSWORD
DB_SSL=false
DB_CONNECTION_TIMEOUT=30000
ENVFILE

chmod 600 "$PROJECT_ROOT/.env"

# Create systemd service file with proper environment handling
cat > /etc/systemd/system/situational-awareness.service << SERVICEFILE
[Unit]
Description=Palo Alto Situational Awareness System
Documentation=https://github.com/iannucci/situational-awareness
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
SyslogIdentifier=situational-awareness

# FIXED: Environment file
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
systemctl enable situational-awareness

echo -e "${BLUE}Configuring Nginx...${NC}"
WEB_DIR="$PROJECT_ROOT/src/web"

if [[ ! -d "$WEB_DIR" ]]; then
    echo -e "${RED}Error: Web directory not found at $WEB_DIR${NC}"
    exit 1
fi

# Copy web files to standard location
WEB_ROOT="/var/www/situational-awareness"
echo -e "${BLUE}Setting up web root at $WEB_ROOT...${NC}"
mkdir -p "$WEB_ROOT"
cp -r "$WEB_DIR/"* "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT" 2>/dev/null || chown -R nginx:nginx "$WEB_ROOT" 2>/dev/null || true
chmod -R 644 "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;

# Create nginx configuration specifically for system installation
echo -e "${BLUE}Creating nginx configuration for system installation...${NC}"

# Create nginx config for system installation (different from Docker version)
cat > /tmp/situational-awareness-nginx.conf << 'NGINXCONF'
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Main application - serve static files
    location / {
        root /var/www/situational-awareness;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            add_header Vary "Accept-Encoding";
        }
    }
    
    # API endpoints (System installation - uses localhost)
    location /api {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        
        # CORS headers for API
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;
        
        # Handle OPTIONS requests for CORS
        if ($request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin * always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;
            add_header Access-Control-Max-Age 1728000 always;
            add_header Content-Length 0;
            add_header Content-Type "text/plain; charset=UTF-8";
            return 204;
        }
    }
    
    # WebSocket support for real-time updates
    location /ws {
        proxy_pass http://127.0.0.1:3000;
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
NGINXCONF

# Configure nginx based on system type
if [[ -d /etc/nginx/sites-available ]]; then
    # Ubuntu/Debian style
    cp /tmp/situational-awareness-nginx.conf /etc/nginx/sites-available/situational-awareness
    
    # Enable site and disable default
    ln -sf /etc/nginx/sites-available/situational-awareness /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    echo -e "${GREEN}✅ Configured nginx (Ubuntu/Debian style)${NC}"
else
    # RHEL/CentOS style
    cp /tmp/situational-awareness-nginx.conf /etc/nginx/conf.d/situational-awareness.conf
    
    # Disable default server block in main config if it exists
    if [[ -f /etc/nginx/nginx.conf ]]; then
        # Comment out any existing server blocks in main config
        sed -i '/^[[:space:]]*server[[:space:]]*{/,/^[[:space:]]*}/s/^/#/' /etc/nginx/nginx.conf 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Configured nginx (RHEL/CentOS style)${NC}"
fi

# Clean up temporary file
rm -f /tmp/situational-awareness-nginx.conf

# Test nginx configuration
echo -e "${BLUE}Testing nginx configuration...${NC}"
if ! nginx -t; then
    echo -e "${RED}Nginx configuration test failed${NC}"
    echo -e "${YELLOW}Checking nginx configuration...${NC}"
    
    # Show the configuration we created
    if [[ -f /etc/nginx/sites-available/situational-awareness ]]; then
        echo -e "${BLUE}Configuration file: /etc/nginx/sites-available/situational-awareness${NC}"
        head -20 /etc/nginx/sites-available/situational-awareness
    elif [[ -f /etc/nginx/conf.d/situational-awareness.conf ]]; then
        echo -e "${BLUE}Configuration file: /etc/nginx/conf.d/situational-awareness.conf${NC}"
        head -20 /etc/nginx/conf.d/situational-awareness.conf
    fi
    
    # Show nginx error
    echo -e "${BLUE}Nginx test output:${NC}"
    nginx -t 2>&1 || true
    
    exit 1
fi

echo -e "${GREEN}✅ Nginx configuration test passed${NC}"

# Start services
echo -e "${BLUE}Starting services...${NC}"
systemctl start situational-awareness
nginx -t && systemctl restart nginx && systemctl enable nginx

# Save configuration
echo "DB_PASSWORD=$DB_PASSWORD" > /etc/situational-awareness.conf
echo "PROJECT_ROOT=$PROJECT_ROOT" >> /etc/situational-awareness.conf
echo "POSTGRES_VERSION=$PG_VERSION" >> /etc/situational-awareness.conf
chmod 600 /etc/situational-awareness.conf

# Create backup script
cat > /usr/local/bin/emergency-backup.sh << 'BACKUPEOF'
#!/bin/bash
BACKUP_DIR="/var/backups/situational-awareness"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="palo_alto_situational_awareness"
DB_USER="situational_awareness_user"

# Load configuration
if [[ -f /etc/situational-awareness.conf ]]; then
    source /etc/situational-awareness.conf
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

if systemctl is-active --quiet situational-awareness; then
    echo -e "${GREEN}✅ Situational Awareness System is running${NC}"
else
    echo -e "${RED}❌ Situational Awareness System failed to start${NC}"
    echo "Checking service status:"
    systemctl status situational-awareness --no-pager || true
    echo "Checking logs:"
    journalctl -u situational-awareness -n 20 --no-pager || true
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
echo "• Start:   sudo systemctl start situational-awareness"
echo "• Stop:    sudo systemctl stop situational-awareness"
echo "• Restart: sudo systemctl restart situational-awareness"
echo "• Status:  sudo systemctl status situational-awareness"
echo "• Logs:    sudo journalctl -u situational-awareness -f"
echo ""
echo -e "${BLUE}Troubleshooting:${NC}"
echo "• Service logs: sudo journalctl -u situational-awareness -f"
echo "• Nginx logs: sudo tail -f /var/log/nginx/error.log"
echo "• Test API: curl http://localhost:3000/api/health"
echo "• Test Database: psql -h localhost -d palo_alto_situational_awareness -U situational_awareness_user -c 'SELECT 1;'"
echo ""

if systemctl is-active --quiet situational-awareness && systemctl is-active --quiet nginx && systemctl is-active --quiet $PG_SERVICE; then
    echo -e "${GREEN}🚨 All services running - Situational Awareness System Ready! 🚨${NC}"
else
    echo -e "${YELLOW}⚠️ Some services may need attention. Check the status above.${NC}"
    echo -e "${YELLOW}Run: sudo journalctl -u situational-awareness -f${NC}"
fi
echo "=============================================="
