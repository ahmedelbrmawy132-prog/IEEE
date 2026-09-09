-- ============================================================================
-- Task 5: PostgreSQL AI Schemas & Spatial Setup
-- Extensions: PostGIS 3.5 & pgvector 0.8+
-- ============================================================================

-- 1. Enable Required Extensions per SRS Specifications
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "vector";

-- ============================================================================
-- Table 1: users (Core Authentication & RBAC)
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'hiker',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ============================================================================
-- Table 2: trips (Trip Plans & Spatial Trajectories)
-- ============================================================================
CREATE TABLE IF NOT EXISTS trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'planned', -- planned, active, completed, cancelled
    route_geometry GEOMETRY(LineString, 4326),     -- Hiker trail path
    start_point GEOMETRY(Point, 4326) NOT NULL,
    destination_point GEOMETRY(Point, 4326) NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,
    ended_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Spatial Indexes for Geo-fencing and Dead-zone searches
CREATE INDEX IF NOT EXISTS idx_trips_route_gist ON trips USING GIST(route_geometry);
CREATE INDEX IF NOT EXISTS idx_trips_start_gist ON trips USING GIST(start_point);
CREATE INDEX IF NOT EXISTS idx_trips_user_status ON trips(user_id, status);

-- ============================================================================
-- Table 3: sos_alerts (Emergency Broadcasts & Live Tracking)
-- ============================================================================
CREATE TABLE IF NOT EXISTS sos_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    location GEOMETRY(Point, 4326) NOT NULL,
    battery_level INT,
    network_status VARCHAR(50),
    status VARCHAR(50) NOT NULL DEFAULT 'active', -- active, acknowledged, resolved
    payload JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE
);

-- Fast Spatial Index for Rescue Radius & Emergency Dispatch
CREATE INDEX IF NOT EXISTS idx_sos_location_gist ON sos_alerts USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_sos_status ON sos_alerts(status);

-- ============================================================================
-- Table 4: risk_assessments (DEM Elevation & AI Terrain Inferences)
-- ============================================================================
CREATE TABLE IF NOT EXISTS risk_assessments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    risk_score FLOAT NOT NULL,                    -- 0.0 to 1.0 (Critical threshold >= 0.7)
    slope_degrees FLOAT,
    flood_susceptibility FLOAT,
    cell_coverage_level VARCHAR(50),              -- full, partial, deadzone
    raw_telemetry JSONB,
    evaluated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_risk_trip_id ON risk_assessments(trip_id);
CREATE INDEX IF NOT EXISTS idx_risk_score ON risk_assessments(risk_score);

-- ============================================================================
-- Table 5: ai_audit_logs (Decision Auditing, Embeddings & Fallback Tracing)
-- ============================================================================
CREATE TABLE IF NOT EXISTS ai_audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    correlation_id VARCHAR(128) NOT NULL,         -- Links Go API request with Python ML
    model_name VARCHAR(100) NOT NULL,             -- e.g. gemini-flash, xgboost-fallback
    prompt_or_input TEXT,
    decision_output JSONB NOT NULL,
    latency_ms INT NOT NULL,
    is_fallback BOOLEAN DEFAULT FALSE,            -- Tracks whether fallback triggered
    embedding vector(768),                        -- 768-dim embeddings for similarity search
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Vector Index (HNSW) for Cosine Distance Semantic Auditing
CREATE INDEX IF NOT EXISTS idx_ai_audit_embedding ON ai_audit_logs 
USING hnsw (embedding vector_cosine_ops);

-- B-Tree Indexes for SLA & Latency queries
CREATE INDEX IF NOT EXISTS idx_ai_audit_correlation ON ai_audit_logs(correlation_id);
CREATE INDEX IF NOT EXISTS idx_ai_audit_latency ON ai_audit_logs(latency_ms);
CREATE INDEX IF NOT EXISTS idx_ai_audit_fallback ON ai_audit_logs(is_fallback);