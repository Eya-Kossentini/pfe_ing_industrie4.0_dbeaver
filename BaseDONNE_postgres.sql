CREATE SCHEMA IF NOT EXISTS raw;

CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS analytic;

CREATE SCHEMA IF NOT EXISTS ref;


CREATE TABLE IF NOT EXISTS ref.sites (
    id                      BIGINT PRIMARY key,
    user_id                 INT,
    company_code_id         INT,
    site_number             VARCHAR,
    site_external_number    VARCHAR,
    deletion_priority       VARCHAR,
    geo_coordinates         VARCHAR,
    description             VARCHAR ,
    
        CONSTRAINT fk_company_code
    FOREIGN KEY (company_code_id)
    REFERENCES ref.company_codes(id)
); 

INSERT INTO ref.sites (    
    id,
    user_id,
    company_code_id,
    site_number,
    site_external_number,
    deletion_priority,
    geo_coordinates,
    description
)
SELECT  
    id as site_id,
    user_id,
    company_code_id,
    site_number,
    site_external_number,
    deletion_priority,
    geo_coordinates,
    description
FROM public.sites; 

select * from ref.sites;


CREATE TABLE IF NOT EXISTS ref.cells (
    id                BIGINT PRIMARY KEY,
    name              TEXT NOT NULL,
    description       TEXT UNIQUE,
    site_id                 BIGINT NOT NULL REFERENCES ref.sites(id),
    user_id                 INT,
    info                    TEXT,
    is_active               BOOLEAN DEFAULT TRUE,
    created_at              TIMESTAMPTZ DEFAULT now(),
    updated_at              TIMESTAMPTZ DEFAULT now()
);


INSERT INTO ref.cells (
    id,
    name,
    description,
    site_id,
    user_id,
    info,
    is_active
)
SELECT
    id as cell_id,
    name,
    description,
    site_id,
    user_id,
    info,
    is_active
FROM public.cells;

select * from ref.cells;

select * from lines;

CREATE TABLE IF NOT EXISTS ref.lines (
    id                 BIGINT PRIMARY KEY,
    name               TEXT NOT NULL,
    description        TEXT NOT NULL,
    date                varchar,
    user_id                  BIGINT NOT NULL,
    created_at               TIMESTAMPTZ DEFAULT now(),
    updated_at               TIMESTAMPTZ DEFAULT now()
);

INSERT INTO ref.lines (
    id,
    name,
    description,
    date,
    user_id
)
SELECT
    id as line_id,
    name,
    description,
    date,
    user_id
FROM public.lines;

select * from ref.lines;

select * from machine_groups ;


CREATE TABLE IF NOT EXISTS ref.machine_groups (
    id           BIGINT PRIMARY KEY,
    name          TEXT NOT NULL,
    description   TEXT NOT NULL,
    is_active                   BOOLEAN DEFAULT TRUE,
    created_at                  TIMESTAMPTZ DEFAULT now(),
    updated_at                  TIMESTAMPTZ DEFAULT now()
);


INSERT INTO ref.machine_groups  (
    id,
    name,
    description
)
SELECT
    id,
    name,
    description
FROM public.machine_groups;

select * from ref.machine_groups;

--ref.machine_conditions = liste des types d’états

select * from machine_conditions mc ;

CREATE TABLE IF NOT EXISTS ref.machine_conditions (
    id                       BIGINT PRIMARY KEY,
    group_id                 BIGINT NOT NULL REFERENCES ref.machine_groups(id),
    condition_name           BIGINT NOT NULL,
    condition_description    TEXT,
    color_rgb                TEXT,
    is_active                BOOLEAN DEFAULT TRUE,
    created_at               TIMESTAMPTZ DEFAULT now(),
    updated_at               TIMESTAMPTZ DEFAULT now()
);


INSERT INTO ref.machine_conditions (
    id,
    group_id,
    condition_name,
    condition_description,
    color_rgb,
    is_active
)
select
    id,
    group_id,
    condition_name,
    condition_description,
    color_rgb,
    is_active
FROM public.machine_conditions ; 

select * from ref.machine_conditions;

select * from line_station_association lsa ;

CREATE TABLE IF NOT EXISTS ref.line_station_association (
    line_id                 BIGINT NOT NULL REFERENCES ref.lines(id),
    station_id               BIGINT NOT NULL REFERENCES ref.stations(id),
    created_at               TIMESTAMPTZ DEFAULT now(),
    updated_at               TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (line_id, station_id)
);


INSERT INTO ref.line_station_association  (
    line_id,
    station_id
)
SELECT
    line_id,
    station_id
FROM public.line_station_association;


select * from stations;

CREATE TABLE IF NOT EXISTS ref.stations (
    id               BIGINT PRIMARY KEY,
    machine_group_id         BIGINT REFERENCES ref.machine_groups(id),
    name             TEXT NOT NULL,
    description      TEXT NOT NULL,
    is_active                BOOLEAN DEFAULT TRUE,
    user_id                  BIGINT NOT NULL,
    info                   TEXT,
    created_at               TIMESTAMPTZ DEFAULT now(),
    updated_at               TIMESTAMPTZ DEFAULT now()
);

INSERT INTO ref.stations (
    id,
    machine_group_id,
    name,
    description,
    is_active,
    user_id,
    info
)
SELECT
    id,
    machine_group_id,
    name,
    description,
    is_active,
    user_id,
    info
FROM public.stations;

select * from ref.stations;

select * from company_codes;

CREATE TABLE IF NOT EXISTS ref.company_codes (
    id              BIGINT PRIMARY KEY,
    user_id                 INT NOT NULL,
    client_id               INT NOT NULL,
    name            TEXT NOT NULL,
    description            TEXT NOT NULL,
    created_at              TIMESTAMPTZ DEFAULT now(),
    updated_at              TIMESTAMPTZ DEFAULT now()
);


INSERT INTO ref.company_codes  (
    id,
    user_id,
    client_id,
    name,
    description
)
SELECT
    id,
    user_id,
    client_id,
    name,
    description 
FROM public.company_codes;

select * from ref.company_codes;

select * from work_orders ;

CREATE TABLE IF NOT EXISTS ref.work_orders (
    id                 BIGINT PRIMARY KEY,
    workorder_no                 TEXT NOT NULL,
    workorder_type               TEXT NOT NULL,
    part_number                  TEXT NOT NULL,
    workorder_qty                NUMERIC(14,3),
    startdate                    TIMESTAMPTZ,
    deliverydate                 TIMESTAMPTZ,
    unit                         TEXT,
    bom_version                  INT,
    workplan_type                TEXT NOT NULL,
    backflush                    INT,
    source                       INT,
    workplan_version             INT,
    workorder_desc               TEXT NOT NULL,
    workplan_valid_from          TIMESTAMPTZ,
    status                       TEXT NOT NULL,
    site_id                      BIGINT REFERENCES ref.sites(id),
    client_id                    INT NOT NULL,
    company_id                   BIGINT NOT NULL REFERENCES ref.company_codes(id),
    workorder_state              TEXT,
    aps_planning_start_date      TIMESTAMPTZ,
    aps_planning_stamp           TIMESTAMPTZ,
    aps_planning_end_date        TIMESTAMPTZ,
    aps_order_fixation           INT,
    created_at                   TIMESTAMPTZ DEFAULT now(),
    updated_at                   TIMESTAMPTZ DEFAULT now()
);


INSERT INTO ref.work_orders (
    id,
    workorder_no,
    workorder_type,
    part_number,
    workorder_qty,
    startdate,
    deliverydate,
    unit,
    bom_version,
    workplan_type,
    backflush,
    source,
    workplan_version,
    workorder_desc,
    workplan_valid_from,
    status,
    site_id,
    client_id,
    company_id,
    workorder_state,
    aps_planning_start_date,
    aps_planning_stamp,
    aps_planning_end_date,
    aps_order_fixation
)
SELECT
    id,
    workorder_no,
    workorder_type,
    part_number,
    workorder_qty,
    startdate::timestamptz,
    deliverydate::timestamptz,
    unit,
    bom_version,
    workplan_type,
    backflush,
    source,
    workplan_version,
    workorder_desc,
    workplan_valid_from::timestamptz,
    status,
    NULLIF(NULLIF(site_id, ''), 'NULL')::bigint,
    client_id,
    company_id,
    workorder_state,
    aps_planning_start_date::timestamptz,
    aps_planning_stamp::timestamptz,
    aps_planning_end_date::timestamptz,
    aps_order_fixation
FROM public.work_orders
ON CONFLICT (id) DO NOTHING;

select * from ref.work_orders;

select * from active_workorders;

CREATE TABLE IF NOT EXISTS ref.active_workorders (
    id      BIGINT PRIMARY KEY,
    workorder_id              BIGINT NOT NULL REFERENCES ref.work_orders(id),
    station_id                BIGINT NOT NULL REFERENCES ref.stations(id),
    state                     INT NOT NULL,
    created_at                TIMESTAMPTZ DEFAULT now(),
    updated_at                TIMESTAMPTZ DEFAULT now()
);

INSERT INTO ref.active_workorders (
    id,
    workorder_id,
    station_id,
    state
)
SELECT
    id,
    workorder_id::bigint,
    station_id::bigint,
    state::int
FROM public.active_workorders
WHERE workorder_id IN (
    SELECT id FROM ref.work_orders
)
AND station_id IN (
    SELECT id FROM ref.stations
)
ON CONFLICT (id) DO NOTHING;


SELECT * FROM ref.active_workorders aw ;

select * from failure_group_types fgt ;

CREATE TABLE IF NOT EXISTS ref.failure_group_types (
    id    BIGINT PRIMARY KEY,
    failure_group_name       TEXT NOT NULL,
    failure_group_desc       TEXT NOT NULL,
    created_at               TIMESTAMPTZ DEFAULT now(),
    updated_at               TIMESTAMPTZ DEFAULT now()
);

INSERT INTO ref.failure_group_types (
    id,
    failure_group_name,
    failure_group_desc
)
SELECT
    id,
    failure_group_name,
    failure_group_desc
FROM public.failure_group_types
ON CONFLICT (id) DO NOTHING;

select * from ref.failure_group_types ;


select * from failure_types;

CREATE TABLE IF NOT EXISTS ref.failure_types (
    failure_type_id          BIGINT PRIMARY KEY,
    failure_type_code        TEXT NOT NULL,
    failure_type_desc        TEXT NOT NULL,
    site_id                  BIGINT REFERENCES ref.sites(id),
    failure_group_id         BIGINT REFERENCES ref.failure_group_types(id),
    created_at               TIMESTAMPTZ DEFAULT now(),
    updated_at               TIMESTAMPTZ DEFAULT now()
);

INSERT INTO ref.failure_types (
    failure_type_id,
    failure_type_code,
    failure_type_desc,
    site_id,
    failure_group_id
)
SELECT
    f.failure_type_id,
    f.failure_type_code,
    f.failure_type_desc,
    NULLIF(NULLIF(f.site_id::text, ''), 'NULL')::bigint,
    f.failure_group_id
FROM public.failure_types f
WHERE (
    f.site_id IS NULL
    OR NULLIF(NULLIF(f.site_id::text, ''), 'NULL')::bigint IN (
        SELECT id FROM ref.sites
    )
)
AND f.failure_group_id IN (
    SELECT id FROM ref.failure_group_types
)
ON CONFLICT (failure_type_id) DO NOTHING;

select * from failure_types ft ;



/* -------------------------------------------- RAW ------------------------------------------------------------------*/


//raw.machine_condition_data = historique des événements d’états

select * from machine_condition_data mcd ;

drop table raw.machine_condition_data ;

CREATE TABLE IF NOT EXISTS raw.machine_condition_data (
    event_time         TIMESTAMPTZ NOT NULL,
    station_id         BIGINT NOT NULL REFERENCES ref.stations(id),
    condition_id       BIGINT NOT NULL REFERENCES ref.machine_conditions(id),
    end_time           TIMESTAMPTZ,
    duration_seconds   INTEGER,
    source_event_id    BIGINT,
    created_at         TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (event_time, station_id, condition_id)
);


WITH ordered AS (
    SELECT
        m.id::bigint AS source_event_id,
        m.station_id::bigint AS station_id,
        m.condition_id::bigint AS condition_id,
        NULLIF(m.date_from, 'NULL')::timestamptz AS date_from_ts,
        NULLIF(m.date_to, 'NULL')::timestamptz AS date_to_ts,
        LEAD(NULLIF(m.date_from, 'NULL')::timestamptz) OVER (
            PARTITION BY m.station_id
            ORDER BY NULLIF(m.date_from, 'NULL')::timestamptz
        ) AS next_date_from_ts
    FROM public.machine_condition_data m
    WHERE m.date_from IS NOT NULL
      AND m.station_id IS NOT NULL
      AND m.condition_id IS NOT NULL
      AND m.station_id::bigint IN (SELECT id FROM ref.stations)
      AND m.condition_id::bigint IN (SELECT id FROM ref.machine_conditions)
)
INSERT INTO raw.machine_condition_data (
    event_time,
    station_id,
    condition_id,
    end_time,
    duration_seconds,
    source_event_id
)
SELECT
    o.date_from_ts AS event_time,
    o.station_id,
    o.condition_id,
    COALESCE(o.date_to_ts, o.next_date_from_ts, o.date_from_ts) AS end_time,
    GREATEST(
        EXTRACT(
            EPOCH FROM (
                COALESCE(o.date_to_ts, o.next_date_from_ts, o.date_from_ts) - o.date_from_ts
            )
        )::integer,
        0
    ) AS duration_seconds,
    o.source_event_id
FROM ordered o
ON CONFLICT (event_time, station_id, condition_id) DO NOTHING;



CREATE TABLE IF NOT EXISTS raw.bookings (
like public.bookings including all,
primary key(id)
);


INSERT INTO raw.bookings 
select * 
FROM public.bookings 
WHERE date_of_booking IS NOT NULL
  AND station_id IS NOT NULL
ON CONFLICT (id) DO NOTHING;



/* ---------------------- Convert the main raw to hypertables ---------------------- */ 

SELECT create_hypertable('raw.machine_condition_data', 'event_time', if_not_exists => TRUE);

SELECT create_hypertable('raw.bookings', 'booking_time', if_not_exists => TRUE);


/* -------------------------------------------- MART ------------------------------------------------------------------*/

-- basée si real_cycle_time est fiable.

CREATE OR REPLACE VIEW mart.kpi_cycle_time_by_station AS
SELECT
    station_id,
    COUNT(*) AS total_bookings,
    COUNT(*) FILTER (
        WHERE real_cycle_time IS NOT NULL
          AND real_cycle_time > 0
    ) AS measured_bookings,
    ROUND(
        AVG(real_cycle_time) FILTER (
            WHERE real_cycle_time IS NOT NULL
              AND real_cycle_time > 0
        )::numeric,
        2
    ) AS avg_real_cycle_time,
    ROUND(
        MIN(real_cycle_time) FILTER (
            WHERE real_cycle_time IS NOT NULL
              AND real_cycle_time > 0
        )::numeric,
        2
    ) AS min_real_cycle_time,
    ROUND(
        MAX(real_cycle_time) FILTER (
            WHERE real_cycle_time IS NOT NULL
              AND real_cycle_time > 0
        )::numeric,
        2
    ) AS max_real_cycle_time
FROM raw.bookings
GROUP BY station_id
ORDER BY station_id;



-- Vue résumé KPI par station

drop view mart.kpi_station_summary ;

CREATE VIEW mart.kpi_station_summary AS
WITH defect AS (
    SELECT
        station_id,
        COUNT(*) AS total_bookings,
        COUNT(*) FILTER (WHERE LOWER(TRIM(state))='pass') AS good_count,
        COUNT(*) FILTER (WHERE LOWER(TRIM(state)) = 'fail') AS fail_count,
        COUNT(*) FILTER (WHERE LOWER(TRIM(state)) = 'scrap') AS scrap_count,
        COUNT(*) FILTER (WHERE LOWER(TRIM(state)) IN ('fail', 'scrap')) AS defect_count,
        COUNT(*) FILTER (WHERE LOWER(TRIM(state)) NOT IN ('pass', 'fail', 'scrap')) AS unknown_state_count,
        ROUND(
            (
                100.0 * COUNT(*) FILTER (WHERE LOWER(TRIM(state)) IN ('fail', 'scrap'))
                / NULLIF(COUNT(*), 0)
            )::numeric,
            2
        ) AS defect_rate_pct
    FROM raw.bookings
    GROUP BY station_id
),
cycle AS (
    SELECT
        station_id,
        COUNT(*) FILTER (
            WHERE real_cycle_time IS NOT NULL
              AND real_cycle_time > 0
        ) AS measured_bookings,
        ROUND(
            (AVG(real_cycle_time) FILTER (
                WHERE real_cycle_time IS NOT NULL
                  AND real_cycle_time > 0
            ))::numeric,
            2
        ) AS avg_real_cycle_time
    FROM raw.bookings
    GROUP BY station_id
)
SELECT
    d.station_id,
    d.total_bookings,
    d.good_count,
    d.fail_count,
    d.scrap_count,
    d.defect_count,
    d.unknown_state_count,
    d.defect_rate_pct,
    ROUND(
    (100.0 * good_count / NULLIF(total_bookings, 0))::numeric,
    2) AS yield_pct,
    c.measured_bookings,
    c.avg_real_cycle_time,
    ROUND(
    (100.0 * c.measured_bookings / NULLIF(d.total_bookings, 0))::numeric,
    2
) AS cycle_data_coverage_pct
FROM defect d
LEFT JOIN cycle c
    ON d.station_id = c.station_id
ORDER BY d.station_id;


select * from mart.kpi_station_summary kss ;


-- KPI taux de défaut par station


CREATE VIEW mart.kpi_defect_rate_by_station AS
SELECT
    station_id,
    COUNT(*) AS total_bookings,
    COUNT(*) FILTER (WHERE LOWER(state) = 'pass') AS good_count,
    COUNT(*) FILTER (WHERE LOWER(state) = 'fail') AS fail_count,
    COUNT(*) FILTER (WHERE LOWER(state) = 'scrap') AS scrap_count,
    COUNT(*) FILTER (WHERE LOWER(state) IN ('fail', 'scrap')) AS defect_count,
    ROUND(
        (
            100.0 * COUNT(*) FILTER (WHERE LOWER(state) IN ('fail', 'scrap'))
            / NULLIF(COUNT(*), 0)
        )::numeric,
        2
    ) AS defect_rate_pct
FROM raw.bookings
GROUP BY station_id
ORDER BY station_id;


CREATE VIEW mart.line_production_quality AS
SELECT
    DATE(b.date_of_booking) AS production_day,
    l.id AS line_id,
    l.name AS line_name,
    COUNT(*)::integer AS total_production,
    COUNT(*) FILTER (
        WHERE LOWER(b.state) = 'scrap'
    )::integer AS total_scrap,
    COUNT(*) FILTER (
        WHERE LOWER(b.state) = 'fail'
    )::integer AS total_rework,
    (
        COUNT(*)
        - COUNT(*) FILTER (WHERE LOWER(b.state) = 'scrap')
        - COUNT(*) FILTER (WHERE LOWER(b.state) = 'fail')
    )::integer AS good_qty,
    ROUND(
        (
            100.0 * (
                COUNT(*)
                - COUNT(*) FILTER (WHERE LOWER(b.state) = 'scrap')
                - COUNT(*) FILTER (WHERE LOWER(b.state) = 'fail')
            )
            / NULLIF(COUNT(*), 0)
        )::numeric,
        2
    ) AS line_quality_rate_pct,
    ROUND(
        (
            100.0 * COUNT(*) FILTER (WHERE LOWER(b.state) = 'scrap')
            / NULLIF(COUNT(*), 0)
        )::numeric,
        2
    ) AS line_scrap_rate_pct
FROM raw.bookings b
INNER JOIN ref.line_station_association lsa
    ON b.station_id = lsa.station_id
INNER JOIN ref.lines l
    ON lsa.line_id = l.id
WHERE b.date_of_booking IS NOT NULL
GROUP BY
    DATE(b.date_of_booking),
    l.id,
    l.name
ORDER BY
    production_day,
    line_id;


UPDATE machine_condition_data
SET date_to = NULL
WHERE date_to = 'NULL';

UPDATE machine_condition_data
SET date_from = NULL
WHERE date_from = 'NULL';


CREATE TABLE mart.kpi_availability (
    production_day DATE,
    station_id BIGINT,
    operating_time NUMERIC(10,2),
    planned_time NUMERIC(10,2),
    availability_rate NUMERIC(5,4),
    PRIMARY KEY (production_day, station_id)
);

truncate table mart.kpi_availability;

INSERT INTO mart.kpi_availability
SELECT
    DATE(event_time) AS production_day,
    station_id,
    ROUND(
        SUM(CASE 
            WHEN condition_id NOT IN (8,12,16)
            THEN duration_seconds / 3600.0
            ELSE 0 
        END)
    ,2) AS operating_time,
    ROUND(SUM(duration_seconds) / 3600.0,2) AS planned_time,
    ROUND(
        COALESCE(
            SUM(CASE 
                WHEN condition_id NOT IN (8,12,16)
                THEN duration_seconds / 3600.0
                ELSE 0 
            END)
            /
            NULLIF(SUM(duration_seconds) / 3600.0, 0),
        0)
    ,4) AS availability_rate
FROM raw.machine_condition_data
GROUP BY DATE(event_time), station_id
HAVING SUM(duration_seconds) > 0;

SELECT * from mart.kpi_availability ka ;




CREATE OR REPLACE VIEW mart.kpi_pareto_losses AS
WITH losses AS (
    -- 1. Breakdown depuis machine_condition_data
    SELECT
        m.station_id,
        DATE(m.event_time) AS production_day,
        'BREAKDOWN' AS loss_type,
        SUM(m.duration_seconds) / 3600.0 AS loss_hours
    FROM raw.machine_condition_data m
    WHERE m.condition_id IN (8,12,16)
    GROUP BY m.station_id, DATE(m.event_time)
    UNION ALL
    -- 2. Micro stop
    SELECT
        m.station_id,
        DATE(m.event_time) AS production_day,
        'MICRO_STOP' AS loss_type,
        SUM(m.duration_seconds) / 3600.0 AS loss_hours
    FROM raw.machine_condition_data m
    WHERE m.condition_id IN (5,6)
    GROUP BY m.station_id, DATE(m.event_time)
    UNION ALL
    -- 3. Scrap depuis bookings
    SELECT
        b.station_id,
        DATE(b.date_of_booking) AS production_day,
        'SCRAP' AS loss_type,
        COUNT(*) * 1.0 AS loss_hours
    FROM raw.bookings b
    WHERE LOWER(b.state) = 'scrap'
    GROUP BY b.station_id, DATE(b.date_of_booking)
    UNION ALL
    -- 4. Rework depuis bookings
    SELECT
        b.station_id,
        DATE(b.date_of_booking) AS production_day,
        'REWORK' AS loss_type,
        COUNT(*) * 1.0 AS loss_hours
    FROM raw.bookings b
    WHERE LOWER(b.state) = 'fail'
    GROUP BY b.station_id, DATE(b.date_of_booking)
),
agg AS (
    SELECT
        station_id,
        production_day,
        loss_type,
        ROUND(SUM(loss_hours), 2) AS loss_hours
    FROM losses
    GROUP BY station_id, production_day, loss_type
)
SELECT
    station_id,
    production_day,
    loss_type,
    loss_hours,
    ROUND(
        100.0 * loss_hours / NULLIF(SUM(loss_hours) OVER (PARTITION BY station_id, production_day), 0),
        2
    ) AS loss_pct,
    ROUND(
        100.0 * SUM(loss_hours) OVER (
            PARTITION BY station_id, production_day
            ORDER BY loss_hours DESC, loss_type
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / NULLIF(SUM(loss_hours) OVER (PARTITION BY station_id, production_day), 0),
        2
    ) AS cumulative_pct,
    ROW_NUMBER() OVER (
        PARTITION BY station_id, production_day
        ORDER BY loss_hours DESC, loss_type
    ) AS pareto_rank
FROM agg;


select * from ref.machine_conditions;


CREATE OR REPLACE VIEW mart.kpi_mtbf_by_station AS
WITH run_time AS (
    SELECT
        station_id,
        ROUND(SUM(duration_seconds) / 3600.0, 2) AS run_time_hours
    FROM raw.machine_condition_data
    WHERE condition_id = 17
    GROUP BY station_id
),
failures AS (
    SELECT
        station_id,
        COUNT(*) AS failure_count
    FROM raw.machine_condition_data
    WHERE condition_id = 10
    GROUP BY station_id
)
SELECT
    COALESCE(r.station_id, f.station_id) AS station_id,
    COALESCE(r.run_time_hours, 0) AS run_time_hours,
    COALESCE(f.failure_count, 0) AS failure_count,
    ROUND(
        COALESCE(r.run_time_hours, 0) / NULLIF(COALESCE(f.failure_count, 0), 0),
        2
    ) AS mtbf_hours
FROM run_time r
FULL OUTER JOIN failures f
    ON r.station_id = f.station_id
ORDER BY station_id;


CREATE OR REPLACE VIEW mart.kpi_mttr_by_station AS
WITH breakdowns AS (
    SELECT
        station_id,
        ROUND(SUM(duration_seconds) / 3600.0, 2) AS breakdown_time_hours,
        COUNT(*) AS failure_count
    FROM raw.machine_condition_data
    WHERE condition_id = 10
    GROUP BY station_id
)
SELECT
    station_id,
    breakdown_time_hours,
    failure_count,
    ROUND(
        breakdown_time_hours / NULLIF(failure_count, 0),
        2
    ) AS mttr_hours
FROM breakdowns
ORDER BY station_id;


CREATE OR REPLACE VIEW mart.kpi_downtime_by_station AS
SELECT
    station_id,
    DATE(event_time) AS production_day,
    CASE
        WHEN condition_id = 10 THEN 'BREAKDOWN'
        WHEN condition_id = 5 THEN 'MICRO_STOP'
        WHEN condition_id = 8 THEN 'SETUP'
        WHEN condition_id = 11 THEN 'PLANNED_MAINTENANCE'
        WHEN condition_id = 16 THEN 'NO_PRODUCTION_BREAK'
        WHEN condition_id = 9 THEN 'PART_SHORTAGE'
        WHEN condition_id = 6 THEN 'CLEANING'
        WHEN condition_id = 7 THEN 'RATE_DEVIATION'
        ELSE 'OTHER_STOP'
    END AS downtime_type,
    ROUND(SUM(duration_seconds) / 3600.0, 2) AS downtime_hours,
    ROUND(SUM(duration_seconds) / 60.0, 2) AS downtime_minutes,
    COUNT(*) AS downtime_events
FROM raw.machine_condition_data
WHERE condition_id <> 17
GROUP BY
    station_id,
    DATE(event_time),
    CASE
        WHEN condition_id = 10 THEN 'BREAKDOWN'
        WHEN condition_id = 5 THEN 'MICRO_STOP'
        WHEN condition_id = 8 THEN 'SETUP'
        WHEN condition_id = 11 THEN 'PLANNED_MAINTENANCE'
        WHEN condition_id = 16 THEN 'NO_PRODUCTION_BREAK'
        WHEN condition_id = 9 THEN 'PART_SHORTAGE'
        WHEN condition_id = 6 THEN 'CLEANING'
        WHEN condition_id = 7 THEN 'RATE_DEVIATION'
        ELSE 'OTHER_STOP'
    END
ORDER BY production_day, station_id, downtime_hours DESC;

CREATE OR REPLACE VIEW mart.kpi_failure_top AS
WITH failure_counts AS (
    SELECT
        b.station_id,
        TRIM(b.failed_id) AS failure_group_id,
        COUNT(*) AS failure_count
    FROM raw.bookings b
    WHERE b.failed_id IS NOT NULL
      AND TRIM(b.failed_id) <> ''
    GROUP BY b.station_id, TRIM(b.failed_id)
)
SELECT
    fc.station_id,
    fc.failure_group_id,
    fgt.failure_group_name,
    fgt.failure_group_desc,
    fc.failure_count,
    ROUND(
        100.0 * fc.failure_count
        / NULLIF(SUM(fc.failure_count) OVER (PARTITION BY fc.station_id), 0),
        2
    ) AS failure_pct,
    ROW_NUMBER() OVER (
        PARTITION BY fc.station_id
        ORDER BY fc.failure_count DESC, fc.failure_group_id
    ) AS rank_in_station
FROM failure_counts fc
LEFT JOIN ref.failure_group_types fgt
    ON fc.failure_group_id = fgt.id::text;


CREATE OR REPLACE VIEW mart.kpi_scrap_by_day AS
SELECT
    DATE(date_of_booking) AS production_day,
    station_id,
    COUNT(*) AS total_bookings,
    COUNT(*) FILTER (WHERE LOWER(state) = 'scrap') AS scrap_count,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE LOWER(state) = 'scrap')
        / NULLIF(COUNT(*), 0),
        2
    ) AS scrap_rate_pct
FROM raw.bookings
GROUP BY DATE(date_of_booking), station_id
ORDER BY production_day, station_id;

CREATE OR REPLACE VIEW mart.kpi_yield_by_day AS
SELECT
    DATE(date_of_booking) AS production_day,
    station_id,
    COUNT(*) AS total_bookings,
    COUNT(*) FILTER (WHERE LOWER(TRIM(state)) = 'pass') AS good_count,
    COUNT(*) FILTER (WHERE LOWER(TRIM(state)) = 'fail') AS fail_count,
    COUNT(*) FILTER (WHERE LOWER(TRIM(state)) = 'scrap') AS scrap_count,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE LOWER(TRIM(state)) = 'pass')
        / NULLIF(COUNT(*), 0),
        2
    ) AS yield_pct,
    CASE
        WHEN COUNT(*) < 10 THEN 'LOW_VOLUME'
        ELSE 'NORMAL'
    END AS volume_flag
FROM raw.bookings
GROUP BY DATE(date_of_booking), station_id
ORDER BY production_day, station_id;

CREATE OR REPLACE VIEW mart.kpi_oee_daily_trend AS
WITH expanded_events AS (
    SELECT
        m.station_id,
        m.condition_id,
        gs.day_start::date AS production_day,
        EXTRACT(
            EPOCH FROM (
                LEAST(m.end_time, gs.day_start + INTERVAL '1 day')
                - GREATEST(m.event_time, gs.day_start)
            )
        ) AS duration_seconds
    FROM raw.machine_condition_data m
    CROSS JOIN LATERAL generate_series(
        date_trunc('day', m.event_time),
        date_trunc('day', m.end_time),
        interval '1 day'
    ) AS gs(day_start)
    WHERE m.event_time IS NOT NULL
      AND m.end_time IS NOT NULL
      AND m.end_time > m.event_time
),
machine_time AS (
    SELECT
        production_day,
        station_id,
        COALESCE(SUM(duration_seconds), 0) AS total_time_s,
        COALESCE(SUM(CASE WHEN condition_id = 17 THEN duration_seconds ELSE 0 END), 0) AS run_time_s,
        COALESCE(SUM(CASE WHEN condition_id = 5 THEN duration_seconds ELSE 0 END), 0) AS micro_stop_s,
        COALESCE(SUM(CASE WHEN condition_id IN (8, 11, 16) THEN duration_seconds ELSE 0 END), 0) AS planned_stop_s,
        COALESCE(SUM(CASE WHEN condition_id = 10 THEN duration_seconds ELSE 0 END), 0) AS breakdown_s
    FROM expanded_events
    WHERE duration_seconds > 0
    GROUP BY production_day, station_id
),
quality_data AS (
    SELECT
        DATE(date_of_booking) AS production_day,
        station_id,
        COUNT(*) AS total_bookings,
        COUNT(*) FILTER (WHERE LOWER(TRIM(state)) = 'pass') AS good_count
    FROM raw.bookings
    GROUP BY DATE(date_of_booking), station_id
)
SELECT
    mt.production_day,
    mt.station_id,
    ROUND(mt.total_time_s / 3600.0, 2) AS total_time_hours,
    ROUND(mt.run_time_s / 3600.0, 2) AS run_time_hours,
    ROUND(mt.micro_stop_s / 3600.0, 2) AS micro_stop_hours,
    ROUND(mt.planned_stop_s / 3600.0, 2) AS planned_stop_hours,
    ROUND(mt.breakdown_s / 3600.0, 2) AS breakdown_hours,
    COALESCE(q.total_bookings, 0) AS total_bookings,
    COALESCE(q.good_count, 0) AS good_count,
    ROUND(
        COALESCE(
            100.0 * mt.run_time_s::numeric
            / NULLIF((mt.total_time_s - mt.planned_stop_s)::numeric, 0),
            0
        ),
        2
    ) AS availability_pct,
    ROUND(
        COALESCE(
            100.0 * mt.run_time_s::numeric
            / NULLIF((mt.run_time_s + mt.micro_stop_s)::numeric, 0),
            0
        ),
        2
    ) AS performance_pct,
    ROUND(
        COALESCE(
            100.0 * COALESCE(q.good_count, 0)::numeric
            / NULLIF(COALESCE(q.total_bookings, 0)::numeric, 0),
            0
        ),
        2
    ) AS quality_pct,
    ROUND(
        (
            COALESCE(
                mt.run_time_s::numeric
                / NULLIF((mt.total_time_s - mt.planned_stop_s)::numeric, 0),
                0
            )
            *
            COALESCE(
                mt.run_time_s::numeric
                / NULLIF((mt.run_time_s + mt.micro_stop_s)::numeric, 0),
                0
            )
            *
            COALESCE(
                COALESCE(q.good_count, 0)::numeric
                / NULLIF(COALESCE(q.total_bookings, 0)::numeric, 0),
                0
            )
        ) * 100,
        2
    ) AS oee_pct
FROM machine_time mt
LEFT JOIN quality_data q
    ON mt.production_day = q.production_day
   AND mt.station_id = q.station_id
ORDER BY mt.production_day, mt.station_id;


SELECT
    station_id,
    DATE(event_time) AS production_day,
    COUNT(*) AS nb_rows,
    SUM(duration_seconds) AS total_seconds,
    ROUND(SUM(duration_seconds)/3600.0, 2) AS total_hours,
    MAX(duration_seconds) AS max_duration_s
FROM raw.machine_condition_data
WHERE station_id = 1
  AND DATE(event_time) = '2026-01-19'
GROUP BY station_id, DATE(event_time);
