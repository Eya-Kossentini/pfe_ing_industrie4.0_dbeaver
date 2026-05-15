-- ============================================================
-- FICHIER SQL ORGANISÉ - STAGING + KPI PUBLIC
-- Projet : Dashboard industriel / Grafana
-- Objectif : créer les tables staging, alimenter les KPI publics,
--            puis préparer les données pour les dashboards.
-- ============================================================

-- ============================================================
-- 0. RECOMMANDATIONS D'EXÉCUTION
-- ============================================================
-- 1) Exécuter d'abord les tables staging.
-- 2) Charger les données staging.
-- 3) Créer / corriger les tables KPI public.
-- 4) Créer les index uniques nécessaires aux UPSERT.
-- 5) Lancer les INSERT INTO ... ON CONFLICT.
-- 6) Vérifier avec les requêtes de contrôle à la fin.


-- ============================================================
-- 1. SCHÉMA STAGING
-- ============================================================

CREATE SCHEMA IF NOT EXISTS staging;


-- ============================================================
-- 2. TABLES STAGING - RÉFÉRENTIELS
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
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.cells (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    site_id BIGINT NOT NULL REFERENCES staging.sites(id),
    user_id INT,
    info TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
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


-- ============================================================
-- 3. TABLES STAGING - PARTS / BOM / WORKPLAN
-- ============================================================

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


-- ============================================================
-- 4. TABLES STAGING - QUALITÉ / PRODUCTION / CONDITIONS MACHINE
-- ============================================================

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
    created_at TIMESTAMPTZ DEFAULT now()
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


-- ============================================================
-- 5. TABLES KPI PUBLIC - STRUCTURE MINIMALE
-- ============================================================
-- Certaines tables existent déjà dans ton script mais ne sont pas créées ici
-- avant d'être utilisées : oee_kpi, quality_kpi, mtbf_kpi, mttr_kpi,
-- scrap_by_day_kpi, dashboard_overview, downtime_by_station_kpi,
-- pareto_losses_kpi, failure_loss_diagnostic_kpi.
-- Vérifie qu'elles existent bien avant les INSERT.

CREATE TABLE IF NOT EXISTS public.defect_rate_kpi (
    id SERIAL PRIMARY KEY,
    production_day DATE NOT NULL,
    station_id BIGINT NOT NULL,
    station_name VARCHAR(255),
    total_bookings INT,
    good_count INT,
    fail_count INT,
    scrap_count INT,
    defect_count INT,
    defect_rate_pct NUMERIC(10,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    timestamp TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_defect_rate_kpi_day_station
ON public.defect_rate_kpi(production_day, station_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_quality_kpi_day_station
ON public.quality_kpi(production_day, station_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_oee_day_station
ON public.oee_kpi(production_day, station_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_scrap_day_station
ON public.scrap_by_day_kpi(production_day, station_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_downtime_day_station_type
ON public.downtime_by_station_kpi(production_day, station_id, downtime_type);

CREATE UNIQUE INDEX IF NOT EXISTS idx_pareto_unique
ON public.pareto_losses_kpi(station_id, production_day, loss_type);

CREATE UNIQUE INDEX IF NOT EXISTS uq_failure_loss_station
ON public.failure_loss_diagnostic_kpi(station_id);


-- ============================================================
-- 6. FONCTION - REFRESH TIMESTAMPS POUR GRAFANA
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_all_kpi_timestamps()
RETURNS void AS $$
BEGIN
    WITH ranked AS (
        SELECT ctid, ROW_NUMBER() OVER (ORDER BY station_id) AS rn
        FROM public.reliability_diagnostic_kpi
    )
    UPDATE public.reliability_diagnostic_kpi t
    SET timestamp = now() - (ranked.rn * INTERVAL '10 minutes')
    FROM ranked
    WHERE t.ctid = ranked.ctid;

    WITH ranked AS (
        SELECT ctid, ROW_NUMBER() OVER (ORDER BY station_id) AS rn
        FROM public.defect_rate_kpi
    )
    UPDATE public.defect_rate_kpi t
    SET created_at = now() - (ranked.rn * INTERVAL '10 minutes')
    FROM ranked
    WHERE t.ctid = ranked.ctid;

    RAISE NOTICE 'Timestamps rafraîchis à %', now();
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 7. NORMALISATION DES CONDITIONS MACHINE
-- ============================================================

UPDATE staging.machine_conditions
SET condition_description = CASE condition_name
    WHEN '106'  THEN 'Idle'
    WHEN '1000' THEN 'Running'
    WHEN '1001' THEN 'Waiting'
    WHEN '1002' THEN 'Cooling phase during molding'
    WHEN '1003' THEN 'Micro Stop'
    WHEN '1012' THEN 'Repair'
    WHEN '2000' THEN 'Breakdown'
    WHEN '2002' THEN 'Calibration'
    WHEN '3001' THEN 'Material Check'
    WHEN '5001' THEN 'Cleaning'
    WHEN '6001' THEN 'Setup'
    WHEN '7001' THEN 'Meeting'
    ELSE condition_description
END,
updated_at = now()
WHERE condition_name IN (
    '106', '1000', '1001', '1002', '1003', '1012',
    '2000', '2002', '3001', '5001', '6001', '7001'
);

UPDATE staging.machine_conditions
SET group_id = CASE
    WHEN condition_name IN ('1000', '1001', '1002', '1200', '1003')
        THEN 6
    WHEN condition_name IN ('1012', '2000', '2100')
        THEN 4
    WHEN condition_name IN ('2002', '3000', '3001', '3002', '3100', '3003', '3005', '6001', '5001', '3004')
        THEN 5
    ELSE group_id
END,
updated_at = now();

UPDATE staging.machine_condition_groups
SET
    group_name = CASE
        WHEN id = 4 THEN 'Unplanned Downtime'
        WHEN id = 5 THEN 'Planned Downtime'
        WHEN id = 6 THEN 'Operational'
        ELSE group_name
    END,
    group_description = CASE
        WHEN id = 4 THEN 'Breakdowns, repairs, part shortage'
        WHEN id = 5 THEN 'Setup, cleaning, calibration, preventive maintenance, trial runs, material checks, inventory checks, meetings, breaks'
        WHEN id = 6 THEN 'Running, waiting, micro stop, rate deviation, cooling phase during molding'
        ELSE group_description
    END,
    updated_at = now()
WHERE id IN (4, 5, 6);


-- ============================================================
-- 8. ALIMENTATION KPI - QUALITY
-- ============================================================

INSERT INTO public.quality_kpi (
    production_day,
    station_id,
    total_bookings,
    good_count,
    fail_count,
    scrap_count,
    quality_pct,
    defect_rate_pct,
    station_name
)
SELECT
    DATE(b.date_of_booking) AS production_day,
    b.station_id,
    COUNT(*) AS total_bookings,
    COUNT(*) FILTER (WHERE b.state = 'pass') AS good_count,
    COUNT(*) FILTER (WHERE b.state = 'fail') AS fail_count,
    COUNT(*) FILTER (WHERE b.state = 'scrap') AS scrap_count,
    ROUND(COUNT(*) FILTER (WHERE b.state = 'pass') * 100.0 / NULLIF(COUNT(*), 0), 2) AS quality_pct,
    ROUND(COUNT(*) FILTER (WHERE b.state IN ('fail', 'scrap')) * 100.0 / NULLIF(COUNT(*), 0), 2) AS defect_rate_pct,
    COALESCE(s.name, CONCAT('Station ', b.station_id)) AS station_name
FROM staging.bookings b
LEFT JOIN staging.stations s ON s.id = b.station_id
GROUP BY DATE(b.date_of_booking), b.station_id, s.name
ON CONFLICT (production_day, station_id) DO UPDATE SET
    total_bookings  = EXCLUDED.total_bookings,
    good_count      = EXCLUDED.good_count,
    fail_count      = EXCLUDED.fail_count,
    scrap_count     = EXCLUDED.scrap_count,
    quality_pct     = EXCLUDED.quality_pct,
    defect_rate_pct = EXCLUDED.defect_rate_pct,
    station_name    = EXCLUDED.station_name,
    created_at      = now();


-- ============================================================
-- 9. ALIMENTATION KPI - DEFECT RATE
-- ============================================================

INSERT INTO public.defect_rate_kpi (
    production_day,
    station_id,
    total_bookings,
    good_count,
    fail_count,
    scrap_count,
    defect_count,
    defect_rate_pct,
    station_name,
    created_at,
    timestamp
)
SELECT
    DATE(b.date_of_booking) AS production_day,
    b.station_id,
    COUNT(*) AS total_bookings,
    COUNT(*) FILTER (WHERE b.state = 'pass') AS good_count,
    COUNT(*) FILTER (WHERE b.state = 'fail') AS fail_count,
    COUNT(*) FILTER (WHERE b.state = 'scrap') AS scrap_count,
    COUNT(*) FILTER (WHERE b.state IN ('fail', 'scrap')) AS defect_count,
    ROUND(COUNT(*) FILTER (WHERE b.state IN ('fail', 'scrap')) * 100.0 / NULLIF(COUNT(*), 0), 2) AS defect_rate_pct,
    COALESCE(s.name, CONCAT('Station ', b.station_id)) AS station_name,
    now() AS created_at,
    now() AS timestamp
FROM staging.bookings b
LEFT JOIN staging.stations s ON s.id = b.station_id
GROUP BY DATE(b.date_of_booking), b.station_id, s.name
ON CONFLICT (production_day, station_id) DO UPDATE SET
    total_bookings  = EXCLUDED.total_bookings,
    good_count      = EXCLUDED.good_count,
    fail_count      = EXCLUDED.fail_count,
    scrap_count     = EXCLUDED.scrap_count,
    defect_count    = EXCLUDED.defect_count,
    defect_rate_pct = EXCLUDED.defect_rate_pct,
    station_name    = EXCLUDED.station_name,
    created_at      = now(),
    timestamp       = now();


-- ============================================================
-- 10. ALIMENTATION KPI - SCRAP BY DAY
-- ============================================================

INSERT INTO public.scrap_by_day_kpi (
    production_day,
    station_id,
    total_bookings,
    scrap_count,
    scrap_rate_pct,
    created_at,
    station_name
)
SELECT
    DATE(b.date_of_booking) AS production_day,
    b.station_id,
    COUNT(*) AS total_bookings,
    COUNT(*) FILTER (WHERE b.state = 'scrap') AS scrap_count,
    ROUND(COUNT(*) FILTER (WHERE b.state = 'scrap') * 100.0 / NULLIF(COUNT(*), 0), 2) AS scrap_rate_pct,
    now() AS created_at,
    COALESCE(s.name, CONCAT('Station ', b.station_id)) AS station_name
FROM staging.bookings b
LEFT JOIN staging.stations s ON s.id = b.station_id
GROUP BY DATE(b.date_of_booking), b.station_id, s.name
ON CONFLICT (production_day, station_id) DO UPDATE SET
    total_bookings = EXCLUDED.total_bookings,
    scrap_count    = EXCLUDED.scrap_count,
    scrap_rate_pct = EXCLUDED.scrap_rate_pct,
    created_at     = now(),
    station_name   = EXCLUDED.station_name;


-- ============================================================
-- 11. ALIMENTATION KPI - OEE
-- ============================================================

INSERT INTO public.oee_kpi (
    production_day,
    station_id,
    availability_pct,
    performance_pct,
    quality_pct,
    oee_pct,
    station_name
)
WITH quality_agg AS (
    SELECT
        DATE(date_of_booking) AS production_day,
        station_id,
        COUNT(*) AS total_bookings,
        COUNT(*) FILTER (WHERE state = 'pass') AS good_count
    FROM staging.bookings
    GROUP BY DATE(date_of_booking), station_id
),
machine_agg AS (
    SELECT
        DATE(date_from) AS production_day,
        station_id,
        SUM(EXTRACT(EPOCH FROM (date_to - date_from))) AS total_seconds,
        SUM(EXTRACT(EPOCH FROM (date_to - date_from))) FILTER (
            WHERE condition_type IN ('Running', 'Micro Stop')
        ) AS productive_seconds,
        SUM(EXTRACT(EPOCH FROM (date_to - date_from))) FILTER (
            WHERE condition_type IN (
                'Cleaning', 'Setup', 'Preventive Maintenance',
                'Inventory Check', 'Meeting', 'Material Check',
                'Trial & Pilot Run', 'Calibration', 'Fire Drills',
                'No Production & Break'
            )
        ) AS planned_stop_seconds
    FROM staging.machine_condition_data
    GROUP BY DATE(date_from), station_id
)
SELECT
    COALESCE(q.production_day, m.production_day) AS production_day,
    COALESCE(q.station_id, m.station_id) AS station_id,
    ROUND(LEAST(100.0 * m.productive_seconds / NULLIF(m.total_seconds - COALESCE(m.planned_stop_seconds, 0), 0), 100.0)::numeric, 2) AS availability_pct,
    ROUND(LEAST(100.0 * q.total_bookings / NULLIF(m.productive_seconds / 30.0, 0), 100.0)::numeric, 2) AS performance_pct,
    ROUND(100.0 * q.good_count / NULLIF(q.total_bookings, 0)::numeric, 2) AS quality_pct,
    ROUND(
        (
            LEAST(100.0 * m.productive_seconds / NULLIF(m.total_seconds - COALESCE(m.planned_stop_seconds, 0), 0), 100.0)
            * LEAST(100.0 * q.total_bookings / NULLIF(m.productive_seconds / 30.0, 0), 100.0)
            * (100.0 * q.good_count / NULLIF(q.total_bookings, 0))
        )::numeric / 10000.0,
        2
    ) AS oee_pct,
    COALESCE(s.name, CONCAT('Station ', COALESCE(q.station_id, m.station_id))) AS station_name
FROM quality_agg q
FULL OUTER JOIN machine_agg m
    ON q.production_day = m.production_day
   AND q.station_id = m.station_id
LEFT JOIN staging.stations s
    ON s.id = COALESCE(q.station_id, m.station_id)
ON CONFLICT (production_day, station_id) DO UPDATE SET
    availability_pct = EXCLUDED.availability_pct,
    performance_pct  = EXCLUDED.performance_pct,
    quality_pct      = EXCLUDED.quality_pct,
    oee_pct          = EXCLUDED.oee_pct,
    station_name     = EXCLUDED.station_name,
    created_at       = now();


-- ============================================================
-- 12. ALIMENTATION KPI - DOWNTIME BY STATION
-- ============================================================

INSERT INTO public.downtime_by_station_kpi (
    production_day,
    station_id,
    downtime_type,
    downtime_hours,
    downtime_minutes,
    downtime_events,
    station_name,
    created_at
)
SELECT
    DATE(m.date_from) AS production_day,
    m.station_id,
    m.condition_type AS downtime_type,
    ROUND(SUM(EXTRACT(EPOCH FROM (m.date_to - m.date_from)) / 3600.0)::numeric, 2) AS downtime_hours,
    ROUND(SUM(EXTRACT(EPOCH FROM (m.date_to - m.date_from)) / 60.0)::numeric, 2) AS downtime_minutes,
    COUNT(*) AS downtime_events,
    COALESCE(s.name, CONCAT('Station ', m.station_id)) AS station_name,
    now() AS created_at
FROM staging.machine_condition_data m
LEFT JOIN staging.stations s ON s.id = m.station_id
WHERE m.condition_type NOT IN (
    'Running', 'Micro Stop', 'Waiting',
    'Cooling phase during molding', 'Rate Deviation & Others'
)
GROUP BY DATE(m.date_from), m.station_id, m.condition_type, s.name
ON CONFLICT (production_day, station_id, downtime_type) DO UPDATE SET
    downtime_hours   = EXCLUDED.downtime_hours,
    downtime_minutes = EXCLUDED.downtime_minutes,
    downtime_events  = EXCLUDED.downtime_events,
    station_name     = EXCLUDED.station_name,
    created_at       = now();


-- ============================================================
-- 13. ALIMENTATION KPI - PARETO LOSSES
-- ============================================================

INSERT INTO public.pareto_losses_kpi (
    station_id,
    production_day,
    loss_type,
    loss_hours,
    loss_pct,
    cumulative_pct,
    pareto_rank,
    is_critical,
    created_at,
    station_name
)
WITH base AS (
    SELECT
        m.station_id,
        DATE(m.date_from) AS production_day,
        m.condition_type AS loss_type,
        SUM(EXTRACT(EPOCH FROM (m.date_to - m.date_from))) / 3600.0 AS loss_hours
    FROM staging.machine_condition_data m
    GROUP BY m.station_id, DATE(m.date_from), m.condition_type
),
calc_pct AS (
    SELECT
        station_id,
        production_day,
        loss_type,
        ROUND(loss_hours::numeric, 2) AS loss_hours,
        ROUND(
            loss_hours * 100.0 / NULLIF(SUM(loss_hours) OVER (PARTITION BY station_id, production_day), 0),
            2
        ) AS loss_pct
    FROM base
),
ranked AS (
    SELECT
        station_id,
        production_day,
        loss_type,
        loss_hours,
        loss_pct,
        ROW_NUMBER() OVER (
            PARTITION BY station_id, production_day
            ORDER BY loss_hours DESC
        ) AS pareto_rank,
        ROUND(
            SUM(loss_pct) OVER (
                PARTITION BY station_id, production_day
                ORDER BY loss_hours DESC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ),
            2
        ) AS cumulative_pct
    FROM calc_pct
)
SELECT
    r.station_id,
    r.production_day,
    r.loss_type,
    r.loss_hours,
    r.loss_pct,
    r.cumulative_pct,
    r.pareto_rank,
    CASE WHEN r.cumulative_pct <= 80 THEN TRUE ELSE FALSE END AS is_critical,
    now() AS created_at,
    COALESCE(s.name, CONCAT('Station ', r.station_id)) AS station_name
FROM ranked r
LEFT JOIN staging.stations s ON s.id = r.station_id
ON CONFLICT (station_id, production_day, loss_type) DO UPDATE SET
    loss_hours     = EXCLUDED.loss_hours,
    loss_pct       = EXCLUDED.loss_pct,
    cumulative_pct = EXCLUDED.cumulative_pct,
    pareto_rank    = EXCLUDED.pareto_rank,
    is_critical    = EXCLUDED.is_critical,
    created_at     = now(),
    station_name   = EXCLUDED.station_name;


-- ============================================================
-- 14. ALIMENTATION KPI - DASHBOARD OVERVIEW
-- ============================================================

INSERT INTO public.dashboard_overview (
    production_day,
    station_id,
    oee_pct,
    availability_pct,
    performance_pct,
    quality_pct,
    mtbf_hours,
    mttr_hours,
    station_name,
    created_at
)
SELECT
    o.production_day,
    o.station_id,
    o.oee_pct,
    o.availability_pct,
    o.performance_pct,
    o.quality_pct,
    mtbf.mtbf_hours,
    mttr.mttr_hours,
    COALESCE(o.station_name, mtbf.station_name, s.name, CONCAT('Station ', o.station_id)) AS station_name,
    now() AS created_at
FROM public.oee_kpi o
LEFT JOIN public.mtbf_kpi mtbf ON o.station_id = mtbf.station_id
LEFT JOIN public.mttr_kpi mttr ON o.station_id = mttr.station_id
LEFT JOIN staging.stations s ON s.id = o.station_id
ON CONFLICT (production_day, station_id) DO UPDATE SET
    oee_pct          = EXCLUDED.oee_pct,
    availability_pct = EXCLUDED.availability_pct,
    performance_pct  = EXCLUDED.performance_pct,
    quality_pct      = EXCLUDED.quality_pct,
    mtbf_hours       = EXCLUDED.mtbf_hours,
    mttr_hours       = EXCLUDED.mttr_hours,
    station_name     = EXCLUDED.station_name,
    created_at       = now();


-- ============================================================
-- 15. ALIMENTATION KPI - FAILURE / LOSS DIAGNOSTIC
-- ============================================================

TRUNCATE TABLE public.failure_loss_diagnostic_kpi RESTART IDENTITY;

INSERT INTO public.failure_loss_diagnostic_kpi (
    station_id,
    top_failure_group,
    top_failure_count,
    top_failure_pct,
    top_loss_type,
    top_loss_hours,
    top_loss_pct,
    criticality_level,
    diagnosis,
    station_name,
    created_at
)
WITH failures_per_station_group AS (
    SELECT
        b.station_id,
        fgt.failure_group_name AS failure_group,
        COUNT(*) AS nb_failures
    FROM staging.bookings b
    JOIN staging.failure_types ft ON ft.failure_type_id = b.failed_id
    JOIN staging.failure_group_types fgt ON fgt.id = ft.failure_group_id
    WHERE b.failed_id IS NOT NULL
      AND b.state IN ('fail', 'scrap')
    GROUP BY b.station_id, fgt.failure_group_name
),
total_failures_per_station AS (
    SELECT station_id, SUM(nb_failures) AS total_failures
    FROM failures_per_station_group
    GROUP BY station_id
),
top_failure_per_station AS (
    SELECT DISTINCT ON (f.station_id)
        f.station_id,
        f.failure_group AS top_failure_group,
        f.nb_failures AS top_failure_count,
        ROUND(100.0 * f.nb_failures / NULLIF(t.total_failures, 0), 2) AS top_failure_pct
    FROM failures_per_station_group f
    JOIN total_failures_per_station t ON t.station_id = f.station_id
    ORDER BY f.station_id, f.nb_failures DESC
),
losses_per_station_type AS (
    SELECT
        station_id,
        condition_type AS loss_type,
        SUM(EXTRACT(EPOCH FROM (date_to - date_from)) / 3600.0) AS loss_hours
    FROM staging.machine_condition_data
    WHERE condition_type NOT IN ('Running', 'Micro Stop')
    GROUP BY station_id, condition_type
),
total_losses_per_station AS (
    SELECT station_id, SUM(loss_hours) AS total_losses_hours
    FROM losses_per_station_type
    GROUP BY station_id
),
top_loss_per_station AS (
    SELECT DISTINCT ON (l.station_id)
        l.station_id,
        l.loss_type AS top_loss_type,
        ROUND(l.loss_hours::numeric, 2) AS top_loss_hours,
        ROUND(100.0 * l.loss_hours / NULLIF(t.total_losses_hours, 0), 2) AS top_loss_pct
    FROM losses_per_station_type l
    JOIN total_losses_per_station t ON t.station_id = l.station_id
    ORDER BY l.station_id, l.loss_hours DESC
),
avg_oee_per_station AS (
    SELECT station_id, AVG(oee_pct) AS avg_oee
    FROM public.oee_kpi
    GROUP BY station_id
)
SELECT
    COALESCE(f.station_id, l.station_id, o.station_id) AS station_id,
    f.top_failure_group,
    f.top_failure_count,
    f.top_failure_pct,
    l.top_loss_type,
    l.top_loss_hours,
    l.top_loss_pct,
    CASE
        WHEN o.avg_oee >= 75 THEN 'Low'
        WHEN o.avg_oee >= 60 THEN 'Medium'
        WHEN o.avg_oee >= 40 THEN 'High'
        ELSE 'Critical'
    END AS criticality_level,
    CONCAT(
        'OEE moyen ', COALESCE(ROUND(o.avg_oee::numeric, 1)::text, 'N/A'), '%. ',
        'Cause #1 défauts : ', COALESCE(f.top_failure_group, 'aucune'),
        ' (', COALESCE(f.top_failure_pct::text, '0'), '%). ',
        'Cause #1 arrêt : ', COALESCE(l.top_loss_type, 'aucune'),
        ' (', COALESCE(ROUND(l.top_loss_hours::numeric, 1)::text, '0'), 'h, ',
        COALESCE(l.top_loss_pct::text, '0'), '%).'
    ) AS diagnosis,
    COALESCE(s.name, CONCAT('Station ', COALESCE(f.station_id, l.station_id, o.station_id))) AS station_name,
    now() AS created_at
FROM top_failure_per_station f
FULL OUTER JOIN top_loss_per_station l ON f.station_id = l.station_id
FULL OUTER JOIN avg_oee_per_station o ON COALESCE(f.station_id, l.station_id) = o.station_id
LEFT JOIN staging.stations s ON s.id = COALESCE(f.station_id, l.station_id, o.station_id)
ON CONFLICT (station_id) DO UPDATE SET
    top_failure_group = EXCLUDED.top_failure_group,
    top_failure_count = EXCLUDED.top_failure_count,
    top_failure_pct   = EXCLUDED.top_failure_pct,
    top_loss_type     = EXCLUDED.top_loss_type,
    top_loss_hours    = EXCLUDED.top_loss_hours,
    top_loss_pct      = EXCLUDED.top_loss_pct,
    criticality_level = EXCLUDED.criticality_level,
    diagnosis         = EXCLUDED.diagnosis,
    station_name      = EXCLUDED.station_name,
    created_at        = now();

UPDATE public.failure_loss_diagnostic_kpi
SET criticality_level = CASE
    -- Critical : OEE faible OU perte enorme OU defauts eleves
    WHEN (SELECT AVG(oee_pct) FROM public.oee_kpi o WHERE o.station_id = failure_loss_diagnostic_kpi.station_id) < 66 
         OR top_loss_pct >= 24  THEN 'Critical'
    -- High : situations qui demandent attention
    WHEN (SELECT AVG(oee_pct) FROM public.oee_kpi o WHERE o.station_id = failure_loss_diagnostic_kpi.station_id) < 68 
         OR top_loss_pct >= 23 THEN 'High'
    -- Medium : a surveiller (gros du parc)
    WHEN (SELECT AVG(oee_pct) FROM public.oee_kpi o WHERE o.station_id = failure_loss_diagnostic_kpi.station_id) < 69 
         OR top_loss_pct >= 21 THEN 'Medium'
    -- Low : situation saine
    ELSE 'Low'
END;

select * from public.failure_loss_diagnostic_kpi fldk ;

-- Ajouter la colonne action si pas encore fait

ALTER TABLE public.failure_loss_diagnostic_kpi 
    ADD COLUMN IF NOT EXISTS recommended_action TEXT;


-- Update avec regles metier riches et adaptees a TES donnees reelles
UPDATE public.failure_loss_diagnostic_kpi
SET recommended_action = CASE
    -- ===== CRITICAL + WAITING =====
    WHEN criticality_level = 'Critical' AND top_loss_type = 'Waiting' THEN
        '🚨 URGENT: Audit flux de production. Les temps d''attente representent ' 
        || top_loss_pct || '% des arrets. Action: revoir ordonnancement, equilibrage charge operateurs, et flux matiere amont.'
    -- ===== HIGH + WAITING =====
    WHEN criticality_level = 'High' AND top_loss_type = 'Waiting' THEN
        '⚠️ Optimiser flux de production. Mettre en place Kanban et 5S pour reduire les attentes (' || top_loss_pct || '%).'
    -- ===== RATE DEVIATION =====
    WHEN top_loss_type = 'Rate Deviation & Others' THEN
        '📊 Performance instable. Action: Audit cycle time + formation operateurs. Verifier reglages machine (' || top_loss_pct || '% d''ecart cadence).'
    -- ===== BREAKDOWN =====
    WHEN top_loss_type = 'Breakdown' THEN
        '🔧 Pannes critiques (' || top_loss_pct || '%). Action: Maintenance preventive intensifiee, audit machine sous 48h.'
    -- ===== PART SHORTAGE =====
    WHEN top_loss_type = 'Part Shortage' THEN
        '📦 Chaine logistique deficiente. Action: revoir stock minimum, auditer fournisseurs, alertes stock automatiques.'
    -- ===== DEFAUTS QUALITE - SOLDER FILLET =====
    WHEN top_failure_group = 'Solder Fillet' AND criticality_level IN ('Critical', 'High') THEN
        '🔥 Defauts Solder Fillet eleves (' || top_failure_pct || '%). Action: Calibrer four soudure, verifier temperature pate, formation operateurs reflow.'
    -- ===== DEFAUTS - BRIDGING =====
    WHEN top_failure_group = 'Bridging' THEN
        '⚡ Pontage soudure detecte (' || top_failure_pct || '%). Action: Verifier stencil, parametres pasting, alignement composants.'
    -- ===== DEFAUTS - UPSIDE DOWN =====
    WHEN top_failure_group = 'Upside Down' THEN
        '🔄 Composants montes a l''envers (' || top_failure_pct || '%). Action: Verifier feeders SMT, programmation pick-and-place, polarisation.'
    -- ===== SETUP =====
    WHEN top_loss_type = 'Setup' THEN
        '⏱️ Temps changement de serie eleve. Action: Implementer SMED, standardiser setups.'
    -- ===== CLEANING =====
    WHEN top_loss_type = 'Cleaning' THEN
        '🧹 Cycles nettoyage trop longs. Action: Optimiser frequence, evaluer automatisation.'
    -- ===== LOW (situation saine) =====
    WHEN criticality_level = 'Low' THEN
        '✅ Performance satisfaisante. Maintenir bonnes pratiques. Identifier comme reference pour standardiser sur autres stations.'
    ELSE
        '🟡 Situation stable mais ameliorable. Surveiller indicateurs et engager actions d''amelioration continue.'
END;


SELECT 
    station_name, 
    criticality_level, 
    top_failure_group,
    top_loss_type,
    recommended_action
FROM public.failure_loss_diagnostic_kpi
ORDER BY 
    CASE criticality_level
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        ELSE 4
    END,
    top_loss_pct DESC;
-- ============================================================
-- 16. REFRESH FINAL POUR GRAFANA
-- ============================================================

SELECT public.refresh_all_kpi_timestamps();


-- ============================================================
-- 17. CONTRÔLES RAPIDES
-- ============================================================

-- Volumétrie staging
SELECT 'sites' AS table_name, COUNT(*) AS nb_rows FROM staging.sites
UNION ALL SELECT 'lines', COUNT(*) FROM staging.lines
UNION ALL SELECT 'stations', COUNT(*) FROM staging.stations
UNION ALL SELECT 'machine_groups', COUNT(*) FROM staging.machine_groups
UNION ALL SELECT 'work_orders', COUNT(*) FROM staging.work_orders
UNION ALL SELECT 'bookings', COUNT(*) FROM staging.bookings
UNION ALL SELECT 'serial_numbers', COUNT(*) FROM staging.serial_numbers
UNION ALL SELECT 'failure_types', COUNT(*) FROM staging.failure_types
UNION ALL SELECT 'machine_condition_data', COUNT(*) FROM staging.machine_condition_data
UNION ALL SELECT 'measurement_data', COUNT(*) FROM staging.measurement_data
ORDER BY table_name;

-- Qualité des données OEE
SELECT
    COUNT(*) AS total,
    COUNT(*) FILTER (
        WHERE oee_pct > 0
          AND availability_pct > 0
          AND performance_pct > 0
          AND quality_pct > 0
    ) AS lignes_completes,
    COUNT(DISTINCT station_name) AS stations,
    COUNT(DISTINCT production_day) AS jours,
    MIN(production_day) AS premier_jour,
    MAX(production_day) AS dernier_jour
FROM public.oee_kpi;

-- Distribution OEE dashboard
SELECT
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE oee_pct = 0) AS zeros,
    COUNT(*) FILTER (WHERE oee_pct BETWEEN 0.01 AND 10) AS tres_bas,
    COUNT(*) FILTER (WHERE oee_pct BETWEEN 10 AND 50) AS bas,
    COUNT(*) FILTER (WHERE oee_pct BETWEEN 50 AND 85) AS normaux,
    COUNT(*) FILTER (WHERE oee_pct > 85) AS excellents
FROM public.dashboard_overview;

-- OEE moyen par station
SELECT
    station_name,
    COUNT(*) AS nb_lignes,
    MIN(oee_pct) AS min_oee,
    MAX(oee_pct) AS max_oee,
    AVG(oee_pct) AS oee_moyen
FROM public.dashboard_overview
GROUP BY station_name
ORDER BY oee_moyen DESC;

-- Couverture bookings vs machine condition data
SELECT
    (SELECT COUNT(*) FROM staging.machine_condition_data) AS mcd_count,
    (SELECT COUNT(DISTINCT station_id) FROM staging.machine_condition_data) AS mcd_stations,
    (SELECT COUNT(*) FROM staging.bookings) AS bookings_count,
    (SELECT COUNT(DISTINCT station_id) FROM staging.bookings) AS bookings_stations,
    (SELECT COUNT(*) FROM staging.measurement_data) AS measurements_count;

-- Stations présentes dans bookings mais absentes de machine_condition_data
SELECT COUNT(DISTINCT b.station_id) AS stations_a_couvrir
FROM staging.bookings b
WHERE NOT EXISTS (
    SELECT 1
    FROM staging.machine_condition_data mcd
    WHERE mcd.station_id = b.station_id
);


-- ============================================================
-- 18. REQUÊTES DE DEBUG À GARDER À PART
-- ============================================================

-- SELECT * FROM staging.bookings LIMIT 5;
-- SELECT * FROM staging.machine_condition_data LIMIT 5;
-- SELECT * FROM public.quality_kpi ORDER BY production_day DESC LIMIT 20;
-- SELECT * FROM public.oee_kpi ORDER BY production_day DESC LIMIT 20;
-- SELECT * FROM public.defect_rate_kpi ORDER BY production_day DESC LIMIT 20;
-- SELECT * FROM public.scrap_by_day_kpi ORDER BY production_day DESC LIMIT 20;
-- SELECT * FROM public.dashboard_overview ORDER BY production_day DESC LIMIT 20;
-- SELECT * FROM public.pareto_losses_kpi ORDER BY production_day DESC, station_id, pareto_rank LIMIT 50;
 SELECT * FROM public.failure_loss_diagnostic_kpi ORDER BY criticality_level, station_id;

SELECT criticality_level, COUNT(*) AS nb_stations
FROM public.failure_loss_diagnostic_kpi
GROUP BY criticality_level
ORDER BY 
    CASE criticality_level
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        ELSE 4
    END;



CREATE OR REPLACE VIEW public.v_ai_diagnostic_snapshot AS
WITH ranked AS (
    SELECT 
        station_name,
        top_loss_type,
        top_loss_pct,
        top_failure_group,
        top_failure_pct,
        criticality_level,
        recommended_action,
        ROW_NUMBER() OVER (
            ORDER BY 
                CASE criticality_level
                    WHEN 'Critical' THEN 1
                    WHEN 'High' THEN 2
                    WHEN 'Medium' THEN 3
                    ELSE 4
                END,
                top_loss_pct DESC
        ) AS rank
    FROM public.failure_loss_diagnostic_kpi
)
SELECT 
    (SELECT station_name FROM ranked WHERE rank = 1) AS critical_station,
    (SELECT top_loss_type FROM ranked WHERE rank = 1) AS main_loss,
    (SELECT top_loss_pct FROM ranked WHERE rank = 1) AS main_loss_pct,
    (SELECT top_failure_group FROM ranked WHERE rank = 1) AS main_failure_group,
    (SELECT top_failure_pct FROM ranked WHERE rank = 1) AS main_failure_pct,
    (SELECT criticality_level FROM ranked WHERE rank = 1) AS criticality,
    (SELECT recommended_action FROM ranked WHERE rank = 1) AS recommended_action,
    (SELECT COUNT(*) FROM public.failure_loss_diagnostic_kpi WHERE criticality_level = 'Critical') AS nb_critical,
    (SELECT COUNT(*) FROM public.failure_loss_diagnostic_kpi WHERE criticality_level = 'High') AS nb_high,
    (SELECT COUNT(*) FROM public.failure_loss_diagnostic_kpi WHERE criticality_level = 'Medium') AS nb_medium,
    (SELECT COUNT(*) FROM public.failure_loss_diagnostic_kpi WHERE criticality_level = 'Low') AS nb_low;

SELECT * FROM public.v_ai_diagnostic_snapshot ;

WITH ranked AS (
    SELECT
        downtime_type,
        SUM(downtime_hours) AS total_hours
    FROM public.downtime_by_station_kpi
    WHERE downtime_type NOT IN ('Running', 'Micro Stop')
    GROUP BY downtime_type
    ORDER BY total_hours DESC
    LIMIT 1
)
SELECT
    CONCAT('🚨 Main issue: ', downtime_type, ' — ', ROUND(total_hours::numeric * 60, 0), ' min') AS alert
FROM ranked;