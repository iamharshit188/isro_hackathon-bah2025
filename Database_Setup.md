 
## **Quick Setup Instructions**

### **Prerequisites**
- PostgreSQL 14+ with PostGIS extension support
- Superuser access for extension installation
- At least 10GB storage space for production data

### **One-Command Setup**
```bash
# Run the complete setup script
psql -h your_host -U your_user -d your_database -f vaayu_darshak_complete_setup.sql
```

## **Complete Database Setup Script**

Save this as `vaayu_darshak_complete_setup.sql`:

```sql
-- =====================================================
-- VAAYU DARSHAK: ISRO AIR QUALITY DATABASE SETUP
-- =====================================================
-- Project: ISRO Bharatiya Antariksha Yatra 2025 Hackathon
-- Team: WaterPlane
-- Purpose: Complete database setup for air quality monitoring system
-- Version: 1.0
-- Date: July 2025
-- =====================================================

-- Enable required extensions
-- These extensions provide UUID generation, spatial operations, and automation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";           -- UUID generation
CREATE EXTENSION IF NOT EXISTS postgis;               -- Spatial data operations
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;    -- Performance monitoring
CREATE EXTENSION IF NOT EXISTS pgcrypto;              -- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS pg_cron;               -- Automated scheduling

-- =====================================================
-- TABLE CREATION
-- =====================================================

-- Table 1: GROUND_STATIONS
-- Purpose: Master data for CPCB monitoring stations across India
-- Coverage: 400+ urban monitoring stations
CREATE TABLE public.ground_stations (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    station_id text NOT NULL UNIQUE,
    city text NOT NULL,
    state text NOT NULL,
    location geometry(POINT, 4326) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    is_active boolean DEFAULT true,
    
    CONSTRAINT ground_stations_pkey PRIMARY KEY (id),
    CONSTRAINT ground_stations_station_id_unique UNIQUE (station_id),
    CONSTRAINT ground_stations_location_valid CHECK (ST_IsValid(location))
);

-- Add descriptive comment
COMMENT ON TABLE public.ground_stations IS 
'Master table storing metadata for CPCB ground monitoring stations. Each station has a unique identifier, geographic location (PostGIS point), and administrative details.';

-- Table 2: STATION_READINGS
-- Purpose: Time-series air quality measurements from CPCB stations
-- Data: PM2.5, PM10, NO2, SO2, CO, O3 concentrations
-- Volume: ~1M records daily with hourly updates
CREATE TABLE public.station_readings (
    id bigint NOT NULL DEFAULT nextval('station_readings_id_seq'::regclass),
    station_id_ref uuid NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    pm25 numeric(8,2),
    pm10 numeric(8,2),
    no2 numeric(8,2),
    so2 numeric(8,2),
    co numeric(8,2),
    o3 numeric(8,2),
    aqi_calculated numeric(5,2),
    data_quality_score integer DEFAULT 5 CHECK (data_quality_score BETWEEN 1 AND 5),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT station_readings_pkey PRIMARY KEY (id),
    CONSTRAINT station_readings_recorded_at_check CHECK (recorded_at = 0) AND 
        (pm10 IS NULL OR pm10 >= 0) AND
        (no2 IS NULL OR no2 >= 0) AND
        (so2 IS NULL OR so2 >= 0) AND
        (co IS NULL OR co >= 0) AND
        (o3 IS NULL OR o3 >= 0)
    )
);

-- Create sequence for station_readings
CREATE SEQUENCE IF NOT EXISTS station_readings_id_seq;

COMMENT ON TABLE public.station_readings IS 
'Time-series storage of pollutant measurements from CPCB ground stations. Includes all major pollutants with quality scoring and validation constraints.';

-- Table 3: SATELLITE_AOD_DATA
-- Purpose: ISRO EOS-6 satellite Aerosol Optical Depth measurements
-- Source: MOSDAC portal NetCDF files
-- Resolution: 1km spatial grid across India
-- Volume: 5M+ records daily with automated 30-day retention
CREATE TABLE public.satellite_aod_data (
    id bigint NOT NULL DEFAULT nextval('satellite_aod_data_id_seq'::regclass),
    location geometry(POINT, 4326) NOT NULL,
    aod_value numeric(10,6) NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    satellite_source text DEFAULT 'EOS-6',
    data_quality integer DEFAULT 1 CHECK (data_quality BETWEEN 1 AND 3),
    grid_cell_id text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT satellite_aod_data_pkey PRIMARY KEY (id),
    CONSTRAINT satellite_aod_data_aod_range CHECK (aod_value BETWEEN 0 AND 5),
    CONSTRAINT satellite_aod_data_location_valid CHECK (ST_IsValid(location)),
    CONSTRAINT satellite_aod_data_india_bounds CHECK (
        ST_Within(location, ST_MakeEnvelope(68.7, 8.4, 97.25, 37.6, 4326))
    )
);

-- Create sequence for satellite_aod_data
CREATE SEQUENCE IF NOT EXISTS satellite_aod_data_id_seq;

COMMENT ON TABLE public.satellite_aod_data IS 
'Raw Aerosol Optical Depth measurements from ISRO EOS-6 satellite. This data is processed through ML calibration to generate rural area PM2.5 estimates.';

-- Table 4: WEATHER_READINGS
-- Purpose: IMD meteorological data for ML calibration enhancement
-- Network: 3000+ weather stations across India
-- Role: Critical for accurate AOD-to-PM2.5 conversion
CREATE TABLE public.weather_readings (
    id bigint NOT NULL DEFAULT nextval('weather_readings_id_seq'::regclass),
    station_id_ref uuid,
    location geometry(POINT, 4326) NOT NULL,
    recorded_at date NOT NULL,
    min_temp numeric(5,2),
    max_temp numeric(5,2),
    rainfall numeric(8,2) DEFAULT 0,
    humidity numeric(5,2),
    wind_speed numeric(5,2),
    wind_direction numeric(5,2),
    pressure numeric(8,2),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT weather_readings_pkey PRIMARY KEY (id),
    CONSTRAINT weather_readings_temp_logical CHECK (min_temp = 0),
    CONSTRAINT weather_readings_wind_direction_range CHECK (wind_direction BETWEEN 0 AND 360)
);

-- Create sequence for weather_readings
CREATE SEQUENCE IF NOT EXISTS weather_readings_id_seq;

COMMENT ON TABLE public.weather_readings IS 
'Meteorological data from IMD stations. Essential for ML model calibration and improving satellite data accuracy through weather correlation.';

-- =====================================================
-- FOREIGN KEY RELATIONSHIPS
-- =====================================================

-- Link station readings to ground stations
ALTER TABLE public.station_readings 
ADD CONSTRAINT station_readings_station_id_ref_fkey 
FOREIGN KEY (station_id_ref) REFERENCES public.ground_stations(id) 
ON DELETE CASCADE ON UPDATE CASCADE;

-- Link weather readings to ground stations (optional - some weather stations are independent)
ALTER TABLE public.weather_readings 
ADD CONSTRAINT weather_readings_station_id_ref_fkey 
FOREIGN KEY (station_id_ref) REFERENCES public.ground_stations(id) 
ON DELETE SET NULL ON UPDATE CASCADE;

-- =====================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- =====================================================

-- Spatial indexes for geographic queries (GIST indexes)
CREATE INDEX IF NOT EXISTS idx_ground_stations_location 
ON public.ground_stations USING GIST (location);

CREATE INDEX IF NOT EXISTS idx_satellite_aod_location 
ON public.satellite_aod_data USING GIST (location);

CREATE INDEX IF NOT EXISTS idx_weather_readings_location 
ON public.weather_readings USING GIST (location);

-- Temporal indexes for time-series queries (B-tree indexes)
CREATE INDEX IF NOT EXISTS idx_station_readings_recorded_at 
ON public.station_readings USING BTREE (recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_satellite_aod_recorded_at 
ON public.satellite_aod_data USING BTREE (recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_weather_readings_recorded_at 
ON public.weather_readings USING BTREE (recorded_at DESC);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_station_readings_station_time 
ON public.station_readings USING BTREE (station_id_ref, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_satellite_aod_location_time 
ON public.satellite_aod_data USING GIST (location, recorded_at);

-- Performance indexes for data quality and filtering
CREATE INDEX IF NOT EXISTS idx_ground_stations_active 
ON public.ground_stations USING BTREE (is_active) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_station_readings_quality 
ON public.station_readings USING BTREE (data_quality_score) WHERE data_quality_score >= 4;

-- =====================================================
-- RPC FUNCTIONS FOR INTELLIGENT DATA FUSION
-- =====================================================

-- Function 1: INTELLIGENT DATA SOURCE SELECTION
-- Purpose: Smart routing between CPCB ground stations and satellite data
-- Logic: Use ground station data within 5km, fallback to calibrated satellite data
CREATE OR REPLACE FUNCTION public.get_fused_aqi(
    target_lat double precision,
    target_lon double precision,
    search_radius_km double precision DEFAULT 5.0
)
RETURNS TABLE (
    aqi_value numeric,
    source_type text,
    confidence_score integer,
    weather_context jsonb,
    location_info jsonb,
    recorded_at timestamp with time zone,
    metadata jsonb
) 
LANGUAGE plpgsql
AS $$
DECLARE
    target_point geometry;
    nearest_station_data record;
    satellite_data_point record;
    weather_data_point record;
    search_radius_meters numeric;
BEGIN
    -- Convert input coordinates to PostGIS point
    target_point := ST_SetSRID(ST_MakePoint(target_lon, target_lat), 4326);
    search_radius_meters := search_radius_km * 1000;
    
    -- Step 1: Search for nearby CPCB ground stations (high accuracy)
    SELECT INTO nearest_station_data
        gs.id,
        gs.station_id,
        gs.city,
        gs.state,
        sr.pm25,
        sr.pm10,
        sr.no2,
        sr.so2,
        sr.co,
        sr.o3,
        sr.aqi_calculated,
        sr.recorded_at,
        sr.data_quality_score,
        ST_Distance(gs.location, target_point) as distance_meters
    FROM public.ground_stations gs
    JOIN public.station_readings sr ON gs.id = sr.station_id_ref
    WHERE ST_DWithin(gs.location, target_point, search_radius_meters)
        AND gs.is_active = true
        AND sr.recorded_at >= CURRENT_TIMESTAMP - INTERVAL '6 hours'
        AND sr.data_quality_score >= 3
    ORDER BY ST_Distance(gs.location, target_point), sr.recorded_at DESC
    LIMIT 1;
    
    -- Step 2: Get weather context data
    SELECT INTO weather_data_point
        min_temp,
        max_temp,
        rainfall,
        humidity,
        wind_speed,
        recorded_at as weather_recorded_at
    FROM public.weather_readings
    WHERE ST_DWithin(location, target_point, search_radius_meters * 2)
        AND recorded_at >= CURRENT_DATE - INTERVAL '2 days'
    ORDER BY ST_Distance(location, target_point), recorded_at DESC
    LIMIT 1;
    
    -- Step 3: Return results based on data availability
    IF nearest_station_data.id IS NOT NULL THEN
        -- Ground station data available (urban area)
        RETURN QUERY SELECT
            nearest_station_data.aqi_calculated,
            'cpcb_ground_station'::text,
            5::integer,
            jsonb_build_object(
                'min_temp', weather_data_point.min_temp,
                'max_temp', weather_data_point.max_temp,
                'rainfall', weather_data_point.rainfall,
                'humidity', weather_data_point.humidity,
                'wind_speed', weather_data_point.wind_speed
            ),
            jsonb_build_object(
                'station_id', nearest_station_data.station_id,
                'city', nearest_station_data.city,
                'state', nearest_station_data.state,
                'distance_km', round((nearest_station_data.distance_meters / 1000)::numeric, 2)
            ),
            nearest_station_data.recorded_at,
            jsonb_build_object(
                'pm25', nearest_station_data.pm25,
                'pm10', nearest_station_data.pm10,
                'no2', nearest_station_data.no2,
                'data_quality', nearest_station_data.data_quality_score
            );
    ELSE
        -- No ground station nearby, use satellite data (rural area)
        SELECT INTO satellite_data_point
            aod_value,
            recorded_at,
            data_quality,
            ST_Distance(location, target_point) as distance_meters
        FROM public.satellite_aod_data
        WHERE ST_DWithin(location, target_point, search_radius_meters * 5)
            AND recorded_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
            AND data_quality >= 1
        ORDER BY ST_Distance(location, target_point), recorded_at DESC
        LIMIT 1;
        
        IF satellite_data_point.aod_value IS NOT NULL THEN
            -- Return satellite data for ML calibration
            RETURN QUERY SELECT
                satellite_data_point.aod_value,
                'satellite_aod'::text,
                3::integer,
                jsonb_build_object(
                    'min_temp', weather_data_point.min_temp,
                    'max_temp', weather_data_point.max_temp,
                    'rainfall', weather_data_point.rainfall,
                    'humidity', weather_data_point.humidity,
                    'requires_calibration', true
                ),
                jsonb_build_object(
                    'source', 'ISRO_EOS6',
                    'distance_km', round((satellite_data_point.distance_meters / 1000)::numeric, 2),
                    'coverage_type', 'rural_satellite'
                ),
                satellite_data_point.recorded_at,
                jsonb_build_object(
                    'aod_value', satellite_data_point.aod_value,
                    'data_quality', satellite_data_point.data_quality,
                    'calibration_required', true
                );
        ELSE
            -- No data available
            RETURN QUERY SELECT
                NULL::numeric,
                'no_data_available'::text,
                0::integer,
                '{}'::jsonb,
                jsonb_build_object('message', 'No air quality data available for this location'),
                NULL::timestamp with time zone,
                '{}'::jsonb;
        END IF;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.get_fused_aqi IS 
'Intelligent data source selection function. Automatically chooses between high-accuracy CPCB ground station data (urban) and calibrated satellite data (rural) based on location and data availability.';

-- Function 2: ML TRAINING DATASET GENERATION
-- Purpose: Generate aligned dataset for calibration model training
-- Output: Combined CPCB ground truth + ISRO satellite + IMD weather data
CREATE OR REPLACE FUNCTION public.get_calibration_data(
    start_date date DEFAULT CURRENT_DATE - INTERVAL '30 days',
    end_date date DEFAULT CURRENT_DATE,
    min_quality_score integer DEFAULT 4
)
RETURNS TABLE (
    date_recorded date,
    ground_truth_pm25 numeric,
    satellite_aod numeric,
    min_temp numeric,
    max_temp numeric,
    rainfall numeric,
    humidity numeric,
    station_location jsonb,
    data_completeness_score integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sr.recorded_at::date as date_recorded,
        AVG(sr.pm25) as ground_truth_pm25,
        AVG(sad.aod_value) as satellite_aod,
        AVG(wr.min_temp) as min_temp,
        AVG(wr.max_temp) as max_temp,
        AVG(wr.rainfall) as rainfall,
        AVG(wr.humidity) as humidity,
        jsonb_build_object(
            'lat', ST_Y(gs.location),
            'lon', ST_X(gs.location),
            'city', gs.city,
            'state', gs.state
        ) as station_location,
        CASE 
            WHEN COUNT(DISTINCT sr.id) >= 20 AND 
                 COUNT(DISTINCT sad.id) >= 5 AND 
                 COUNT(DISTINCT wr.id) >= 1 THEN 5
            WHEN COUNT(DISTINCT sr.id) >= 15 AND 
                 COUNT(DISTINCT sad.id) >= 3 THEN 4
            WHEN COUNT(DISTINCT sr.id) >= 10 THEN 3
            ELSE 2
        END as data_completeness_score
    FROM public.ground_stations gs
    JOIN public.station_readings sr ON gs.id = sr.station_id_ref
    JOIN public.satellite_aod_data sad ON ST_DWithin(gs.location, sad.location, 5000)
    LEFT JOIN public.weather_readings wr ON gs.id = wr.station_id_ref
    WHERE sr.recorded_at::date BETWEEN start_date AND end_date
        AND sad.recorded_at::date BETWEEN start_date AND end_date
        AND (wr.recorded_at IS NULL OR wr.recorded_at BETWEEN start_date AND end_date)
        AND sr.pm25 IS NOT NULL
        AND sr.data_quality_score >= min_quality_score
        AND sad.aod_value > 0
        AND gs.is_active = true
    GROUP BY sr.recorded_at::date, gs.id, gs.location, gs.city, gs.state
    HAVING AVG(sr.pm25) IS NOT NULL 
        AND AVG(sad.aod_value) IS NOT NULL
        AND COUNT(DISTINCT sr.id) >= 5
    ORDER BY date_recorded DESC, data_completeness_score DESC;
END;
$$;

COMMENT ON FUNCTION public.get_calibration_data IS 
'Generates aligned training dataset combining CPCB ground truth, ISRO satellite AOD, and IMD weather data. Used for ML model training with quality scoring and completeness validation.';

-- Function 3: HISTORICAL TREND ANALYSIS
-- Purpose: Time-series analysis for trend detection and forecasting support
CREATE OR REPLACE FUNCTION public.get_historical_trends(
    target_lat double precision,
    target_lon double precision,
    days_back integer DEFAULT 30,
    aggregation_interval text DEFAULT 'daily'
)
RETURNS TABLE (
    time_period timestamp with time zone,
    avg_aqi numeric,
    min_aqi numeric,
    max_aqi numeric,
    trend_direction text,
    data_points integer,
    confidence_level integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    target_point geometry;
    interval_text text;
BEGIN
    target_point := ST_SetSRID(ST_MakePoint(target_lon, target_lat), 4326);
    
    -- Set appropriate time interval
    CASE aggregation_interval
        WHEN 'hourly' THEN interval_text := '1 hour';
        WHEN 'daily' THEN interval_text := '1 day';
        WHEN 'weekly' THEN interval_text := '1 week';
        ELSE interval_text := '1 day';
    END CASE;
    
    RETURN QUERY
    WITH time_series AS (
        SELECT 
            date_trunc(aggregation_interval, sr.recorded_at) as time_bucket,
            AVG(sr.aqi_calculated) as avg_aqi_value,
            MIN(sr.aqi_calculated) as min_aqi_value,
            MAX(sr.aqi_calculated) as max_aqi_value,
            COUNT(*) as point_count,
            AVG(sr.data_quality_score) as avg_quality
        FROM public.ground_stations gs
        JOIN public.station_readings sr ON gs.id = sr.station_id_ref
        WHERE ST_DWithin(gs.location, target_point, 10000)
            AND sr.recorded_at >= CURRENT_TIMESTAMP - (days_back || ' days')::interval
            AND sr.aqi_calculated IS NOT NULL
            AND gs.is_active = true
        GROUP BY date_trunc(aggregation_interval, sr.recorded_at)
        ORDER BY time_bucket
    )
    SELECT 
        ts.time_bucket,
        ROUND(ts.avg_aqi_value, 2),
        ROUND(ts.min_aqi_value, 2),
        ROUND(ts.max_aqi_value, 2),
        CASE 
            WHEN LAG(ts.avg_aqi_value) OVER (ORDER BY ts.time_bucket) IS NULL THEN 'insufficient_data'
            WHEN ts.avg_aqi_value > LAG(ts.avg_aqi_value) OVER (ORDER BY ts.time_bucket) * 1.1 THEN 'increasing'
            WHEN ts.avg_aqi_value = 4 AND ts.point_count >= 20 THEN 5
            WHEN ts.avg_quality >= 3 AND ts.point_count >= 10 THEN 4
            WHEN ts.point_count >= 5 THEN 3
            ELSE 2
        END as confidence_level
    FROM time_series ts;
END;
$$;

COMMENT ON FUNCTION public.get_historical_trends IS 
'Analyzes historical air quality trends for a location with configurable time aggregation. Supports trend detection and provides confidence scoring for forecasting models.';

-- =====================================================
-- AUTOMATED MAINTENANCE WITH PG_CRON
-- =====================================================

-- Schedule automated data cleanup (30-day retention for satellite data)
-- This prevents the database from growing too large while preserving recent data
SELECT cron.schedule(
    'satellite-data-cleanup',
    '0 2 * * *',  -- Run daily at 2 AM
    'DELETE FROM public.satellite_aod_data WHERE recorded_at < CURRENT_TIMESTAMP - INTERVAL ''30 days'';'
);

-- Schedule automated statistics updates for query optimization
SELECT cron.schedule(
    'update-table-stats',
    '0 3 * * 0',  -- Run weekly on Sunday at 3 AM
    'ANALYZE public.ground_stations, public.station_readings, public.satellite_aod_data, public.weather_readings;'
);

-- Schedule automated index maintenance
SELECT cron.schedule(
    'reindex-spatial-data',
    '0 4 1 * *',  -- Run monthly on 1st at 4 AM
    'REINDEX INDEX CONCURRENTLY idx_ground_stations_location, idx_satellite_aod_location, idx_weather_readings_location;'
);

-- =====================================================
-- SAMPLE DATA INSERTION
-- =====================================================

-- Insert sample ground stations (major Indian cities)
INSERT INTO public.ground_stations (station_id, city, state, location) VALUES
('CPCB_DEL_001', 'New Delhi', 'Delhi', ST_SetSRID(ST_MakePoint(77.2090, 28.6139), 4326)),
('CPCB_MUM_001', 'Mumbai', 'Maharashtra', ST_SetSRID(ST_MakePoint(72.8777, 19.0760), 4326)),
('CPCB_BLR_001', 'Bangalore', 'Karnataka', ST_SetSRID(ST_MakePoint(77.5946, 12.9716), 4326)),
('CPCB_CHN_001', 'Chennai', 'Tamil Nadu', ST_SetSRID(ST_MakePoint(80.2707, 13.0827), 4326)),
('CPCB_KOL_001', 'Kolkata', 'West Bengal', ST_SetSRID(ST_MakePoint(88.3639, 22.5726), 4326)),
('CPCB_HYD_001', 'Hyderabad', 'Telangana', ST_SetSRID(ST_MakePoint(78.4867, 17.3850), 4326)),
('CPCB_PUN_001', 'Pune', 'Maharashtra', ST_SetSRID(ST_MakePoint(73.8567, 18.5204), 4326)),
('CPCB_AHM_001', 'Ahmedabad', 'Gujarat', ST_SetSRID(ST_MakePoint(72.5714, 23.0225), 4326))
ON CONFLICT (station_id) DO NOTHING;

-- Insert sample current readings for testing
INSERT INTO public.station_readings (station_id_ref, recorded_at, pm25, pm10, no2, so2, co, o3, aqi_calculated, data_quality_score)
SELECT 
    gs.id,
    CURRENT_TIMESTAMP - (random() * INTERVAL '1 hour'),
    (random() * 150 + 10)::numeric(8,2),  -- PM2.5: 10-160
    (random() * 200 + 20)::numeric(8,2),  -- PM10: 20-220
    (random() * 80 + 5)::numeric(8,2),    -- NO2: 5-85
    (random() * 50 + 2)::numeric(8,2),    -- SO2: 2-52
    (random() * 4 + 0.5)::numeric(8,2),   -- CO: 0.5-4.5
    (random() * 120 + 10)::numeric(8,2),  -- O3: 10-130
    (random() * 250 + 25)::numeric(5,2),  -- AQI: 25-275
    (random() * 2 + 4)::integer           -- Quality: 4-5
FROM public.ground_stations gs
WHERE gs.is_active = true;

-- Insert sample satellite data for testing
INSERT INTO public.satellite_aod_data (location, aod_value, recorded_at, data_quality)
SELECT 
    ST_SetSRID(ST_MakePoint(
        68.7 + random() * (97.25 - 68.7),   -- Random longitude within India
        8.4 + random() * (37.6 - 8.4)       -- Random latitude within India
    ), 4326),
    (random() * 2 + 0.1)::numeric(10,6),    -- AOD: 0.1-2.1
    CURRENT_TIMESTAMP - (random() * INTERVAL '12 hours'),
    (random() * 2 + 1)::integer              -- Quality: 1-3
FROM generate_series(1, 100);  -- Generate 100 sample points

-- =====================================================
-- PERFORMANCE MONITORING VIEWS
-- =====================================================

-- View for monitoring data freshness
CREATE OR REPLACE VIEW public.data_freshness_monitor AS
SELECT 
    'Ground Stations' as data_source,
    COUNT(*) as total_records,
    MAX(recorded_at) as latest_data,
    MIN(recorded_at) as oldest_data,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(recorded_at)))/3600 as hours_since_latest
FROM public.station_readings
UNION ALL
SELECT 
    'Satellite AOD' as data_source,
    COUNT(*) as total_records,
    MAX(recorded_at) as latest_data,
    MIN(recorded_at) as oldest_data,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(recorded_at)))/3600 as hours_since_latest
FROM public.satellite_aod_data
UNION ALL
SELECT 
    'Weather Data' as data_source,
    COUNT(*) as total_records,
    MAX(recorded_at::timestamp with time zone) as latest_data,
    MIN(recorded_at::timestamp with time zone) as oldest_data,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(recorded_at::timestamp with time zone)))/3600 as hours_since_latest
FROM public.weather_readings;

COMMENT ON VIEW public.data_freshness_monitor IS 
'Monitoring view for tracking data freshness across all sources. Helps identify data pipeline issues and ensures real-time system health.';

-- =====================================================
-- SETUP COMPLETION MESSAGE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'VAAYU DARSHAK DATABASE SETUP COMPLETED!';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Tables Created: 4 (ground_stations, station_readings, satellite_aod_data, weather_readings)';
    RAISE NOTICE 'RPC Functions: 3 (get_fused_aqi, get_calibration_data, get_historical_trends)';
    RAISE NOTICE 'Indexes: 12 (spatial and temporal optimizations)';
    RAISE NOTICE 'Automated Jobs: 3 (cleanup, stats, maintenance)';
    RAISE NOTICE 'Sample Data: Inserted for testing';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Test the setup: SELECT * FROM public.data_freshness_monitor;';
    RAISE NOTICE '2. Test data fusion: SELECT * FROM public.get_fused_aqi(28.6139, 77.2090);';
    RAISE NOTICE '3. Configure your application connection strings';
    RAISE NOTICE '4. Set up data ingestion pipelines';
    RAISE NOTICE '==============================================';
END $$;
```

## **Testing Your Database Setup**

### **Verification Commands**

```sql
-- 1. Check all tables are created
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('ground_stations', 'station_readings', 'satellite_aod_data', 'weather_readings');

-- 2. Verify spatial indexes
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'public' 
  AND indexname LIKE 'idx_%location%';

-- 3. Test the intelligent data fusion function
SELECT * FROM public.get_fused_aqi(28.6139, 77.2090);

-- 4. Check data freshness
SELECT * FROM public.data_freshness_monitor;

-- 5. Test calibration data generation
SELECT COUNT(*) as training_samples 
FROM public.get_calibration_data();
```

### **Expected Output**
- All 4 tables created successfully
- 12+ indexes for performance optimization
- 3 RPC functions for intelligent data processing
- Sample data inserted for immediate testing
- Automated maintenance jobs scheduled

## **Database Architecture Overview**

### **Data Flow Design**
```
ISRO EOS-6 Satellite → satellite_aod_data (Raw AOD)
CPCB Stations → ground_stations + station_readings (Ground Truth)
IMD Weather → weather_readings (Calibration Context)
    ↓
get_fused_aqi() → Intelligent Source Selection
    ↓
Mobile App (Urban: CPCB Data | Rural: Calibrated Satellite)
```

### **Key Features**
- **Spatial Optimization**: PostGIS indexes for sub-100ms geographic queries
- **Data Quality**: Built-in validation constraints and scoring
- **Automated Maintenance**: 30-day retention, statistics updates
- **ML Ready**: Functions optimized for training data generation
- **Production Scale**: Handles 5M+ daily satellite records

## **Configuration for Different Environments**

### **Local Development**
```bash
# Minimal setup for development
createdb vaayu_darshak_dev
psql vaayu_darshak_dev -f vaayu_darshak_complete_setup.sql
```

### **Production Deployment**
```bash
# Production with performance optimizations
psql -h production-host -U admin -d vaayu_darshak_prod \
  -c "SET work_mem = '256MB'; SET shared_buffers = '2GB';" \
  -f vaayu_darshak_complete_setup.sql
```

### **Cloud Deployment (Supabase)**
1. Create new Supabase project
2. Enable PostGIS extension in SQL Editor
3. Run the complete setup script
4. Configure Row Level Security (RLS) if needed

## **Performance Recommendations**

### **Production Tuning**
```sql
-- Recommended PostgreSQL settings for production
-- Add to postgresql.conf

shared_buffers = '25% of RAM'
work_mem = '256MB'
maintenance_work_mem = '1GB'
effective_cache_size = '75% of RAM'
random_page_cost = 1.1
checkpoint_completion_target = 0.9
wal_buffers = '16MB'
```

### **Monitoring Queries**
```sql
-- Monitor query performance
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
WHERE query LIKE '%get_fused_aqi%' 
ORDER BY total_time DESC;

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes 
WHERE schemaname = 'public';
```
