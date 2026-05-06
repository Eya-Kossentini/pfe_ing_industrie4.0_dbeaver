-- ============================================================
-- 1. SCHEMAS
-- ============================================================
CREATE SCHEMA IF NOT EXISTS staging;

-- ============================================================
-- 2. TABLES STAGING (ordre respectant les FK)
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.clients (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.company_codes (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    client_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.sites (
    id BIGINT PRIMARY KEY,
    user_id INT,
    company_code_id INT,
    site_number VARCHAR,
    site_external_number VARCHAR,
    deletion_priority VARCHAR,
    geo_coordinates VARCHAR,
    description VARCHAR,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS staging.cells (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    site_id BIGINT NOT NULL REFERENCES staging.sites(id),
    user_id INT,
    info TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.machine_groups (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    user_id BIGINT NOT NULL,
    cell_id BIGINT,
    is_active BOOLEAN DEFAULT TRUE,
    failure BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.stations (
    id BIGINT PRIMARY KEY,
    machine_group_id BIGINT REFERENCES staging.machine_groups(id),
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    user_id BIGINT NOT NULL,
    info TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.lines (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    date TIMESTAMPTZ,
    user_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.line_stations (
    line_id BIGINT REFERENCES staging.lines(id) ON DELETE CASCADE,
    station_id BIGINT REFERENCES staging.stations(id),
    PRIMARY KEY (line_id, station_id)
);

CREATE TABLE IF NOT EXISTS staging.part_group_types (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.part_types (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    user_id BIGINT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS staging.part_groups (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    user_id BIGINT NOT NULL,
    part_type TEXT,
    part_group_type_id BIGINT REFERENCES staging.part_group_types(id),
    costs NUMERIC(12,2) DEFAULT 0,
    circulating_lot INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    state INT,
    automatic_emptying INT,
    master_workplan TEXT,
    comment TEXT,
    material_transfer BOOLEAN DEFAULT FALSE,
    created_on TIMESTAMPTZ,
    edited_on TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.part_master (
    id BIGINT PRIMARY KEY,
    part_number TEXT NOT NULL UNIQUE,
    description TEXT,
    part_status TEXT,
    parttype_id BIGINT REFERENCES staging.part_types(id),
    partgroup_id BIGINT REFERENCES staging.part_groups(id),
    case_type TEXT,
    product BOOLEAN DEFAULT FALSE,
    panel BOOLEAN DEFAULT FALSE,
    variant BOOLEAN DEFAULT FALSE,
    machine_group_id BIGINT REFERENCES staging.machine_groups(id),
    material_info TEXT,
    parts_index INT,
    edit_order_based_bom BOOLEAN DEFAULT FALSE,
    site_id BIGINT REFERENCES staging.sites(id),
    unit_id BIGINT,
    material_code TEXT,
    no_of_panels INT,
    customer_material_number TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.failure_group_types (
    id BIGINT PRIMARY KEY,
    failure_group_name TEXT NOT NULL,
    failure_group_desc TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.failure_types (
    failure_type_id BIGINT PRIMARY KEY,
    failure_type_code TEXT NOT NULL,
    failure_type_desc TEXT NOT NULL,
    site_id BIGINT REFERENCES staging.sites(id),
    failure_group_id BIGINT REFERENCES staging.failure_group_types(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.machine_condition_groups (
    id BIGINT PRIMARY KEY,
    group_name TEXT NOT NULL,
    group_description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.machine_conditions (
    id BIGINT PRIMARY KEY,
    group_id BIGINT NOT NULL REFERENCES staging.machine_condition_groups(id),
    condition_name TEXT NOT NULL,
    condition_description TEXT,
    color_rgb TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.erp_groups (
    id BIGINT PRIMARY KEY,
    state INT,
    erpgroup_no TEXT NOT NULL,
    erp_group_description TEXT,
    erpsystem TEXT,
    sequential BOOLEAN,
    separate_station BOOLEAN,
    fixed_layer BOOLEAN,
    created_on TIMESTAMPTZ,
    edited_on TIMESTAMPTZ,
    modified_by BIGINT,
    user_id BIGINT,
    cst_id BIGINT,
    valid BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS staging.assign_stations_to_erpgrp (
    station_id BIGINT REFERENCES staging.stations(id),
    erp_group_id BIGINT REFERENCES staging.erp_groups(id),
    station_type TEXT,
    user_id BIGINT,
    PRIMARY KEY (station_id, erp_group_id)
);

CREATE TABLE IF NOT EXISTS staging.workplans (
    id BIGINT PRIMARY KEY,
    version INT,
    is_current BOOLEAN,
    user_id BIGINT,
    site_id BIGINT REFERENCES staging.sites(id),
    client_id BIGINT REFERENCES staging.clients(id),
    company_id BIGINT REFERENCES staging.company_codes(id),
    source INT,
    status INT,
    product_vers_id BIGINT,
    workplan_status TEXT,
    part_no TEXT,
    part_desc TEXT,
    workplan_desc TEXT,
    workplan_type TEXT,
    workplan_version_erp TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.workplan_types (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.worksteps (
    id BIGINT PRIMARY KEY,
    workplan_id BIGINT REFERENCES staging.workplans(id),
    erp_group_id BIGINT REFERENCES staging.erp_groups(id),
    workstep_no INT,
    step INT,
    setup_time NUMERIC(10,2),
    te_person NUMERIC(10,2),
    te_machine NUMERIC(10,2),
    te_time_base NUMERIC(10,2),
    te_qty_base NUMERIC(10,2),
    transport_time NUMERIC(10,2),
    wait_time NUMERIC(10,2),
    status INT,
    panel_count INT,
    workstep_desc TEXT,
    erp_grp_no TEXT,
    erp_grp_desc TEXT,
    time_unit TEXT,
    setup_flag TEXT,
    workstep_version_erp TEXT,
    info TEXT,
    confirmation TEXT,
    sequentiell TEXT,
    workstep_type TEXT,
    traceflag TEXT,
    step_type TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    stamp TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS staging.bom_headers (
    id BIGINT PRIMARY KEY,
    description TEXT,
    valid_from TIMESTAMPTZ,
    valid_to TIMESTAMPTZ,
    part_master_id BIGINT REFERENCES staging.part_master(id),
    created_by TEXT,
    updated_by TEXT,
    state TEXT,
    version INT,
    is_current BOOLEAN,
    previous_version_id BIGINT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.bom_items (
    id BIGSERIAL PRIMARY KEY,
    bom_header_id BIGINT REFERENCES staging.bom_headers(id),
    part_master_id BIGINT REFERENCES staging.part_master(id),
    quantity NUMERIC(14,3),
    is_product BOOLEAN DEFAULT FALSE,
    component_name TEXT,
    layer INT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.work_orders (
    id BIGINT PRIMARY KEY,
    workorder_no TEXT NOT NULL,
    workorder_type TEXT NOT NULL,
    part_number TEXT NOT NULL,
    workorder_qty NUMERIC(14,3),
    startdate TIMESTAMPTZ,
    deliverydate TIMESTAMPTZ,
    unit TEXT,
    bom_version INT,
    workplan_type TEXT NOT NULL,
    backflush INT,
    source INT,
    workplan_version INT,
    workorder_desc TEXT NOT NULL,
    workplan_valid_from TIMESTAMPTZ,
    status TEXT NOT NULL,
    site_id BIGINT REFERENCES staging.sites(id),
    client_id INT NOT NULL,
    company_id BIGINT NOT NULL REFERENCES staging.company_codes(id),
    workorder_state TEXT,
    aps_planning_start_date TIMESTAMPTZ,
    aps_planning_stamp TIMESTAMPTZ,
    aps_planning_end_date TIMESTAMPTZ,
    aps_order_fixation INT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS staging.serial_numbers (
    id BIGINT PRIMARY KEY,
    serial_number TEXT NOT NULL,
    serial_number_pos INT,
    serial_number_ref_pos INT,
    serial_number_active CHAR(1),
    serial_number_ref TEXT,
    splitted BOOLEAN DEFAULT FALSE,
    workorder_id BIGINT NOT NULL REFERENCES staging.work_orders(id),
    part_id BIGINT NOT NULL REFERENCES staging.part_master(id),
    customer_part_number TEXT,
    workorder_type CHAR(1),
    serial_number_type CHAR(1),
    cluster_name TEXT,
    cluster_type CHAR(1),
    created_on TIMESTAMPTZ,
    created_by BIGINT,
    company_code_id BIGINT REFERENCES staging.company_codes(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.active_workorders (
    id BIGINT PRIMARY KEY,
    workorder_id BIGINT NOT NULL REFERENCES staging.work_orders(id),
    station_id BIGINT NOT NULL REFERENCES staging.stations(id),
    state INT NOT NULL,
    process_layer INT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.bookings (
    id BIGINT PRIMARY KEY,
    workorder_id BIGINT NOT NULL REFERENCES staging.work_orders(id),
    station_id BIGINT NOT NULL REFERENCES staging.stations(id),
    failed_id BIGINT NULL REFERENCES staging.failure_types(failure_type_id),
    serial_number_id BIGINT NULL REFERENCES staging.serial_numbers(id),
    process_layer INT,
    date_of_booking TIMESTAMPTZ NOT NULL,
    state TEXT NOT NULL,
    mesure_id BIGINT NULL,
    real_cycle_time NUMERIC(10,3),
    type TEXT,
    snr_booking BOOLEAN DEFAULT FALSE,
    booked_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.measurement_data (
    id BIGINT PRIMARY KEY,
    station_id BIGINT REFERENCES staging.stations(id),
    workorder_id BIGINT REFERENCES staging.work_orders(id),
    book_date TIMESTAMPTZ,
    measure_name TEXT,
    measure_value NUMERIC(14,4),
    lower_limit NUMERIC(14,4),
    upper_limit NUMERIC(14,4),
    nominal NUMERIC(14,4),
    tolerance NUMERIC(14,4),
    measure_fail_code INT,
    measure_type TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.machine_condition_data (
    id BIGINT PRIMARY KEY,
    date_from TIMESTAMPTZ NOT NULL,
    date_to TIMESTAMPTZ NOT NULL,
    station_id BIGINT NOT NULL REFERENCES staging.stations(id),
    condition_id BIGINT NOT NULL REFERENCES staging.machine_conditions(id),
    level TEXT,
    condition_stamp TIMESTAMPTZ,
    condition_type TEXT,
    color_rgb TEXT,
    condition_created TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.part_number_map (
    id INTEGER PRIMARY KEY,
    part_number TEXT,
    description TEXT,
    part_type_id INTEGER,
    part_group_id INTEGER,
    machine_group_id INTEGER,
    site_id INTEGER,
    unit_id INTEGER,
    customer_material_number TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 3. TABLES PUBLIC KPI
-- ============================================================

CREATE TABLE IF NOT EXISTS public.reliability_diagnostic_kpi (
    station_id INT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    mtbf_hours NUMERIC(10,2),
    top_loss_pct NUMERIC(10,2),
    criticality_level TEXT,
    PRIMARY KEY (station_id, timestamp)
);

CREATE TABLE IF NOT EXISTS public.defect_rate_kpi (
    station_id INT NOT NULL,
    station_name VARCHAR(255),
    total_bookings INT,
    good_count INT,
    fail_count INT,
    scrap_count INT,
    defect_count INT,
    defect_rate_pct NUMERIC(10,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (station_id, created_at)
);

-- ============================================================
-- 4. FONCTION REFRESH TIMESTAMPS (pour Grafana)
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_all_kpi_timestamps()
RETURNS void AS $$
BEGIN
    WITH ranked AS (
        SELECT ctid, ROW_NUMBER() OVER (ORDER BY station_id) AS rn
        FROM public.reliability_diagnostic_kpi
    )
    UPDATE public.reliability_diagnostic_kpi t
    SET timestamp = NOW() - (ranked.rn * INTERVAL '10 minutes')
    FROM ranked WHERE t.ctid = ranked.ctid;

    WITH ranked AS (
        SELECT ctid, ROW_NUMBER() OVER (ORDER BY station_id) AS rn
        FROM public.defect_rate_kpi
    )
    UPDATE public.defect_rate_kpi t
    SET created_at = NOW() - (ranked.rn * INTERVAL '10 minutes')
    FROM ranked WHERE t.ctid = ranked.ctid;

    RAISE NOTICE 'Timestamps rafraîchis à %', NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 5. REMPLIR station_name depuis staging.stations
-- ============================================================

UPDATE public.defect_rate_kpi d
SET station_name = s.name
FROM staging.stations s
WHERE d.station_id = s.id;

-- ============================================================
-- 6. LANCER LE REFRESH
-- ============================================================

SELECT public.refresh_all_kpi_timestamps();



SELECT AVG(oee_pct) AS "OEE Global"
FROM public.dashboard_overview;



ALTER TABLE reliability_diagnostic_kpi
ADD COLUMN station_name VARCHAR(255);

UPDATE reliability_diagnostic_kpi r
SET station_name = s.name
FROM staging.stations s
WHERE r.station_id = s.id;


ALTER TABLE reliability_diagnostic_kpi
ADD COLUMN production_day TIMESTAMP;

UPDATE reliability_diagnostic_kpi
SET production_day = timestamp 
    + (random() * interval '59 minutes')
    + (random() * interval '59 seconds');

SELECT *
FROM public.reliability_diagnostic_kpi rdk ;




ALTER TABLE mttr_kpi
ADD COLUMN station_name VARCHAR(255);

UPDATE mttr_kpi r
SET station_name = s.name
FROM staging.stations s
WHERE r.station_id = s.id;

ALTER TABLE mttr_kpi
ADD COLUMN production_day TIMESTAMP;


UPDATE mttr_kpi
SET production_day = timestamp 
    + (random() * interval '59 minutes')
    + (random() * interval '59 seconds');

SELECT production_day, COUNT(*) 
FROM mttr_kpi 
GROUP BY production_day 
ORDER BY production_day 
LIMIT 10;

WITH numbered AS (
  SELECT ctid, ROW_NUMBER() OVER () AS rn
  FROM mttr_kpi
)
UPDATE mttr_kpi m
SET production_day = '2025-06-01'::timestamp 
    + (n.rn || ' months')::interval
    + (random() * interval '28 days')
    + (random() * interval '24 hours')
FROM numbered n
WHERE m.ctid = n.ctid;


SELECT *
FROM public.mttr_kpi mk  ;


select * from quality_kpi;

SELECT MIN(oee_pct), MAX(oee_pct), AVG(oee_pct) 
FROM dashboard_overview;

SELECT MIN(availability_pct), MAX(availability_pct), AVG(availability_pct) 
FROM availability_kpi;

SELECT 
  COUNT(*) AS total,
  COUNT(CASE WHEN oee_pct = 0 THEN 1 END) AS zeros,
  COUNT(CASE WHEN oee_pct BETWEEN 0.01 AND 10 THEN 1 END) AS tres_bas,
  COUNT(CASE WHEN oee_pct BETWEEN 10 AND 50 THEN 1 END) AS bas,
  COUNT(CASE WHEN oee_pct BETWEEN 50 AND 85 THEN 1 END) AS normaux,
  COUNT(CASE WHEN oee_pct > 85 THEN 1 END) AS excellents
FROM dashboard_overview;


SELECT station_name, COUNT(*) AS nb_lignes, 
       MIN(oee_pct), MAX(oee_pct), AVG(oee_pct) AS oee_moyen
FROM dashboard_overview
GROUP BY station_name
ORDER BY oee_moyen DESC;


SELECT 'sites' AS tbl, COUNT(*) FROM staging.sites
UNION ALL SELECT 'lines', COUNT(*) FROM staging.lines
UNION ALL SELECT 'stations', COUNT(*) FROM staging.stations
UNION ALL SELECT 'machine_groups', COUNT(*) FROM staging.machine_groups
UNION ALL SELECT 'work_orders', COUNT(*) FROM staging.work_orders
UNION ALL SELECT 'active_workorders', COUNT(*) FROM staging.active_workorders
UNION ALL SELECT 'bookings', COUNT(*) FROM staging.bookings
UNION ALL SELECT 'serial_numbers', COUNT(*) FROM staging.serial_numbers
UNION ALL SELECT 'failure_types', COUNT(*) FROM staging.failure_types
UNION ALL SELECT 'machine_condition_data', COUNT(*) FROM staging.machine_condition_data
UNION ALL SELECT 'measurement_data', COUNT(*) FROM staging.measurement_data
ORDER BY tbl;


SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'staging' AND table_name = 'bookings'
ORDER BY ordinal_position;

SELECT * FROM staging.bookings LIMIT 5;


SELECT trigger_name, event_object_schema, event_object_table, action_timing, event_manipulation
FROM information_schema.triggers
WHERE event_object_schema IN ('staging', 'public');

SELECT routine_schema, routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema IN ('staging', 'public')
ORDER BY routine_schema, routine_name;

SELECT schemaname, matviewname FROM pg_matviews;

SELECT 
  DATE_TRUNC('month', created_at) AS mois,
  COUNT(*) AS nb_bookings
FROM staging.bookings
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY mois;


SELECT pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
  AND p.proname = 'refresh_all_kpi_timestamps';

SELECT public.refresh_all_kpi_timestamps();

SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'staging' AND table_name = 'machine_condition_data'
ORDER BY ordinal_position;


SELECT * FROM staging.machine_condition_data LIMIT 5;


SELECT 
  DATE_TRUNC('month', created_at) AS mois,
  COUNT(*) AS nb
FROM staging.machine_condition_data
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY mois;


SELECT * FROM timescaledb_information.jobs;

SELECT 
  mc.id,
  mc.condition_name,
  mc.condition_description,
  mc.group_id,
  mc.color_rgb
FROM staging.machine_conditions mc
ORDER BY mc.id;


SELECT mc.id, mc.condition_name, COUNT(mcd.id) AS nb_events
FROM staging.machine_conditions mc
LEFT JOIN staging.machine_condition_data mcd ON mcd.condition_id = mc.id
WHERE mc.id NOT BETWEEN 17 AND 26  -- on garde seulement la vague 2 (ALLOWED_CONDITIONS)
GROUP BY mc.id, mc.condition_name
ORDER BY mc.id;
