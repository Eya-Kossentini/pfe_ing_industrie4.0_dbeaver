CREATE EXTENSION IF NOT EXISTS timescaledb;


drop table kpi_results;

CREATE TABLE IF NOT EXISTS kpi_results (
    time         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    kpi_name     TEXT NOT NULL,
    station_id   INTEGER,
    production_day DATE,
    valeur        FLOAT NOT NULL,
    metric        TEXT
);


SELECT create_hypertable('availability_results', 'time');

SELECT * FROM public.kpi_results ORDER BY time DESC;

SELECT *
FROM public.kpi_results
ORDER BY time DESC
LIMIT 20;


CREATE TABLE IF NOT EXISTS public.availability_results (
    id BIGSERIAL PRIMARY KEY,
    production_day DATE NOT NULL,
    station_id INTEGER NOT NULL,
    run_time_hours DOUBLE PRECISION NOT NULL,
    micro_stop_hours DOUBLE PRECISION NOT NULL,
    breakdown_hours DOUBLE PRECISION NOT NULL,
    planned_stop_hours DOUBLE PRECISION NOT NULL,
    availability_pct DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.availability_results
ADD CONSTRAINT unique_availability_day_station
UNIQUE (production_day, station_id);


select * from public.availability_results;
