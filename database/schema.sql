-- Situational Awareness Database Schema for Palo Alto
-- PostgreSQL 16 with PostGIS and TimescaleDB extensions

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Incident Types
CREATE TABLE IF NOT EXISTS incident_types (
    id SERIAL PRIMARY KEY,
    type_code TEXT UNIQUE NOT NULL,
    type_name TEXT NOT NULL,
    default_severity TEXT DEFAULT 'Medium',
    color_code TEXT DEFAULT '#e74c3c',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tracked Asset Types  
CREATE TABLE IF NOT EXISTS tracked_asset_types (
    id SERIAL UNIQUE NOT NULL,
    type_code TEXT PRIMARY KEY,
    type_name TEXT NOT NULL,
    organization TEXT NOT NULL,
    icon TEXT DEFAULT 'default.png',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Incidents Table
CREATE TABLE IF NOT EXISTS incidents (
    id SERIAL PRIMARY KEY,
    incident_id TEXT UNIQUE NOT NULL,
    incident_type_id INTEGER NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('Low', 'Medium', 'High', 'Critical')),
    priority INTEGER NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    status TEXT NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'In Progress', 'Resolved', 'Cancelled')),
    location GEOMETRY(POINT, 4326) NOT NULL,
    address TEXT,
    title TEXT NOT NULL,
    description TEXT,
    reported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    dispatched_at TIMESTAMPTZ,
    created_by TEXT NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT fk_incidents_type FOREIGN KEY (incident_type_id) REFERENCES incident_types(id)
);

-- Add incident_id generation function
CREATE OR REPLACE FUNCTION generate_incident_id() RETURNS TEXT AS $$
BEGIN
    RETURN 'INC-' || extract(year from now()) || '-' || lpad((SELECT COALESCE(MAX(CAST(SUBSTRING(incident_id FROM 10) AS INTEGER)), 0) + 1 FROM incidents WHERE incident_id LIKE 'INC-' || extract(year from now()) || '-%')::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- Set default for incident_id
ALTER TABLE incidents ALTER COLUMN incident_id SET DEFAULT generate_incident_id();

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

-- Tracked Assets Table
CREATE TABLE IF NOT EXISTS tracked_assets (
    id SERIAL,
    asset_id TEXT PRIMARY KEY,
    type_code TEXT NOT NULL,
    tactical_call TEXT NOT NULL,
    description TEXT NOT NULL,
    activity TEXT DEFAULT NULL,
    location GEOMETRY(POINT, 4326) NOT NULL,
    status TEXT NOT NULL DEFAULT 'Available' CHECK (
        status IN ('Available', 'Dispatched', 'En Route', 'Fixed', 'On Scene', 'Out of Service')
    ),
    url TEXT DEFAULT NULL,
    condition_type TEXT DEFAULT NULL,
    condition_severity TEXT DEFAULT 'None' CHECK (condition_severity IN ('None', 'Unknown', 'Low', 'Medium', 'High', 'Critical')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_tracked_assets_type_code FOREIGN KEY (type_code) REFERENCES tracked_asset_types(type_code)
);

-- Tracked Asset Location Tracking
CREATE TABLE IF NOT EXISTS tracked_asset_locations (
    id SERIAL,
    asset_id TEXT NOT NULL,
    activity TEXT DEFAULT NULL,
    location GEOMETRY(POINT, 4326) NOT NULL,
    status TEXT NOT NULL DEFAULT 'Available' CHECK (
        status IN ('Available', 'Dispatched', 'En Route', 'Fixed', 'On Scene', 'Out of Service')
    ),
    condition_type TEXT DEFAULT NULL,
    condition_severity TEXT DEFAULT 'None' CHECK (condition_severity IN ('None', 'Unknown', 'Low', 'Medium', 'High', 'Critical')),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (asset_id, timestamp),
    CONSTRAINT fk_tracked_asset_locations_asset_id FOREIGN KEY (asset_id) REFERENCES tracked_assets(asset_id)
);

-- Convert tracked_asset_locations to hypertable (with error handling)
DO $$
BEGIN
    BEGIN
        PERFORM create_hypertable('tracked_asset_locations', 'timestamp', if_not_exists => TRUE);
        RAISE NOTICE 'Created TimescaleDB hypertable for tracked_asset_locations';
    EXCEPTION 
        WHEN OTHERS THEN
            RAISE NOTICE 'TimescaleDB not available or hypertable already exists for tracked_asset_locations: %', SQLERRM;
    END;
END $$;


-- Service boundaries table for Palo Alto
CREATE TABLE IF NOT EXISTS service_boundaries (
    id SERIAL PRIMARY KEY,
    boundary_name TEXT NOT NULL,
    boundary_type TEXT NOT NULL,
    jurisdiction TEXT NOT NULL,
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

CREATE INDEX IF NOT EXISTS idx_tracked_asset_locations_location ON tracked_asset_locations USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_tracked_asset_locations_timestamp ON tracked_asset_locations USING BTREE (timestamp);
CREATE INDEX IF NOT EXISTS idx_tracked_asset_locations_asset_id ON tracked_asset_locations USING BTREE (asset_id);

CREATE INDEX IF NOT EXISTS idx_tracked_assets_status ON tracked_assets USING BTREE (status);

CREATE INDEX IF NOT EXISTS idx_service_boundaries_geometry ON service_boundaries USING GIST (boundary_geometry);

-- Functions
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
    DROP TRIGGER IF EXISTS update_tracked_assets_updated_at ON tracked_assets;
    
    CREATE TRIGGER update_incidents_updated_at 
        BEFORE UPDATE ON incidents 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
        
    CREATE TRIGGER update_tracked_assets_updated_at 
        BEFORE UPDATE ON tracked_assets 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
        
END $$;

-- Views
CREATE OR REPLACE VIEW active_incidents_view AS
SELECT 
    i.id,
    i.incident_id,
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

-- Create completion notification
DO $$
BEGIN
    RAISE NOTICE '=======================================================';
    RAISE NOTICE 'Situational Awareness Database schema setup complete';
    RAISE NOTICE '=======================================================';
END $$;
