CREATE EXTENSION IF NOT EXISTS timescaledb;


/*SELECT create_hypertable('availability_results', 'time');

SELECT * FROM public.kpi_results ORDER BY time DESC;*/


drop table availability_kpi, oee_kpi , performance_kpi, quality_kpi;

CREATE TABLE IF NOT EXISTS availability_kpi (
    id BIGSERIAL PRIMARY KEY,
    production_day DATE NOT NULL,
    station_id INT NOT NULL,
    run_time_hours NUMERIC(10,2),
    micro_stop_hours NUMERIC(10,2),
    breakdown_hours NUMERIC(10,2),
    planned_stop_hours NUMERIC(10,2),
    availability_pct NUMERIC(10,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


select count(*) from availability_kpi;

ALTER TABLE availability_kpi
ADD CONSTRAINT unique_availability_day_station
UNIQUE (production_day, station_id);

select * from availability_kpi;

CREATE TABLE IF NOT EXISTS performance_kpi (
    id BIGSERIAL PRIMARY KEY,
    production_day DATE NOT NULL,
    station_id INT NOT NULL,
    run_time_hours NUMERIC(10,2),
    micro_stop_hours NUMERIC(10,2),
    performance_pct NUMERIC(10,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE performance_kpi
ADD CONSTRAINT unique_performance_day_station
UNIQUE (production_day, station_id);


select * from performance_kpi;

CREATE TABLE IF NOT EXISTS oee_kpi (
    id BIGSERIAL PRIMARY KEY,
    production_day DATE NOT NULL,
    station_id INT NOT NULL,
    availability_pct NUMERIC(10,2),
    performance_pct NUMERIC(10,2),
    quality_pct NUMERIC(10,2),
    quality_missing BOOLEAN,
    oee_pct NUMERIC(10,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE oee_kpi
ADD CONSTRAINT unique_oee_day_station
UNIQUE (production_day, station_id);

select * from oee_kpi;

SELECT
    production_day,
    station_id,
    availability_pct,
    performance_pct,
    quality_pct,
    quality_missing,
    oee_pct
FROM oee_kpi
ORDER BY production_day, station_id;


CREATE TABLE IF NOT EXISTS quality_kpi (
    id BIGSERIAL PRIMARY KEY,
    production_day DATE NOT NULL,
    station_id INT NOT NULL,
    total_bookings INT,
    good_count INT,
    fail_count INT,
    scrap_count INT,
    quality_pct NUMERIC(10,2),
    defect_rate_pct NUMERIC(10,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE quality_kpi
ADD CONSTRAINT unique_quality_station
UNIQUE (production_day, station_id);

select * from quality_kpi;

save_scrap


CREATE TABLE IF NOT EXISTS scrap_by_day_kpi (
    id BIGSERIAL PRIMARY KEY,
    production_day DATE NOT NULL,
    station_id INT NOT NULL,
    total_bookings INT,
    scrap_count INT,
    scrap_rate_pct NUMERIC(10,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE scrap_by_day_kpi
ADD CONSTRAINT unique_scrap_station
UNIQUE (production_day, station_id);

select * from scrap_by_day_kpi;

SELECT *
FROM scrap_by_day_kpi
ORDER BY production_day, station_id;


CREATE TABLE IF NOT EXISTS defect_rate_kpi (
    station_id INT not null,
    total_bookings INT,
    good_count INT,
    fail_count INT,
    scrap_count INT,
    defect_count INT,
    defect_rate_pct NUMERIC(10,2),
    primary key (station_id, total_bookings),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

select * from defect_rate_kpi;

ALTER TABLE defect_rate_kpi
ADD CONSTRAINT unique_defect_rate
UNIQUE (station_id, total_bookings);


DROP TABLE IF EXISTS downtime_by_station_kpi;

CREATE TABLE downtime_by_station_kpi (
    station_id INT NOT NULL,
    production_day TIMESTAMP NOT NULL,
    downtime_type VARCHAR(100) NOT NULL,
    downtime_hours NUMERIC(10,2),
    downtime_minutes NUMERIC(10,2),
    downtime_events INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (station_id, production_day, downtime_type)
);

SELECT *
FROM downtime_by_station_kpi
ORDER BY production_day, station_id, downtime_type;


select * from downtime_by_station_kpi;


CREATE TABLE IF NOT EXISTS pareto_losses_kpi (
    station_id INT NOT NULL,
    production_day DATE NOT NULL,
    loss_type VARCHAR(100) NOT NULL,
    loss_hours NUMERIC(10,2),
    loss_pct NUMERIC(10,2),
    cumulative_pct NUMERIC(10,2),
    pareto_rank INT,
    is_critical BOOLEAN,
    PRIMARY KEY (station_id, production_day, loss_type),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

select * from pareto_losses_kpi;

SELECT DISTINCT station_id
FROM pareto_losses_kpi
ORDER BY station_id;

drop table mtbf_kpi;

CREATE TABLE IF NOT EXISTS mtbf_kpi (
    station_id INT not null,
    run_time_hours NUMERIC(10,2),
    failure_count INT,
    mtbf_hours NUMERIC(10,2),
    PRIMARY KEY (station_id, run_time_hours),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

select * from mtbf_kpi;
 
drop table mttr_kpi ;

CREATE TABLE IF NOT EXISTS mttr_kpi (
    station_id INT not null,
    repair_time_hours NUMERIC(10,2),
    repair_count INT,
    mttr_hours NUMERIC(10,2),
    PRIMARY KEY (station_id, repair_time_hours),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

/* ALTER TABLE failure_loss_diagnostic_kpi
ADD CONSTRAINT uq_failure_loss_station_pct
UNIQUE (station_id, top_failure_pct);
 
 */ 
select * from mtbf_kpi;

drop table reliability_diagnostic_kpi, failure_loss_diagnostic_kpi;

CREATE TABLE IF NOT EXISTS reliability_diagnostic_kpi (
    station_id INT PRIMARY KEY,
    mtbf_hours NUMERIC(10,2),
    top_loss_type VARCH4R(100),
    top_loss_pct NUMERIC(10,2),
    pareto_rank INT,
    criticality_level VARCHAR(50),
    diagnosis TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT *
FROM reliability_diagnostic_kpi where top_loss_type='REWORK'
ORDER BY station_id;

CREATE TABLE IF NOT EXISTS failure_loss_diagnostic_kpi (
    station_id INT not null,
    top_failure_group VARCHAR(100),
    top_failure_count INT,
    top_failure_pct NUMERIC(10,2),
    top_loss_type VARCHAR(100),
    top_loss_hours NUMERIC(10,2),
    top_loss_pct NUMERIC(10,2),
    criticality_level VARCHAR(50),
    diagnosis TEXT,
    PRIMARY KEY (station_id, top_failure_pct)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE failure_loss_diagnostic_kpi
ADD CONSTRAINT uq_failure_loss_station_pct
UNIQUE (station_id, top_failure_pct);

select * from failure_loss_diagnostic_kpi fldk ;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;



CREATE TABLE IF NOT EXISTS dashboard_overview (
    station_id INT not null,
    production_day DATE NOT NULL,
    oee_pct NUMERIC(10,2),
    availability_pct NUMERIC(10,2),
    performance_pct NUMERIC(10,2),
    quality_pct NUMERIC(10,2),
    mtbf_hours NUMERIC(10,2),
    mttr_hours NUMERIC(10,2),  
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (station_id, production_day)
);


select * from dashboard_overview;












