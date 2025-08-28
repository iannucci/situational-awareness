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
