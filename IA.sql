-- Table résultats Isolation Forest
CREATE TABLE IF NOT EXISTS public.iforest_results (
    production_day   DATE,
    station_id       TEXT,
    station_name     TEXT,
    oee_pct          FLOAT,
    defect_rate_pct  FLOAT,
    downtime_minutes FLOAT,
    mtbf_hours       FLOAT,
    mttr_hours       FLOAT,
    anomaly_score    FLOAT,
    is_anomaly       BOOLEAN
);

-- Table résultats Forecasting
CREATE TABLE IF NOT EXISTS public.forecast_results (
    production_day   DATE,
    station_id       TEXT,
    station_name     TEXT,
    actual           FLOAT,
    predicted        FLOAT,
    mae              FLOAT,
    mape             FLOAT,
    model_name       TEXT
);

-- Table résultats Z-Score
CREATE TABLE IF NOT EXISTS public.zscore_results (
    production_day   DATE,
    station_id       TEXT,
    station_name     TEXT,
    kpi_name         TEXT,
    kpi_value        FLOAT,
    zscore           FLOAT,
    severity         TEXT   -- 'normal', 'warning', 'critical'
);

-- Table résultats IQR
CREATE TABLE IF NOT EXISTS public.iqr_results (
    production_day   DATE,
    station_id       TEXT,
    station_name     TEXT,
    kpi_name         TEXT,
    kpi_value        FLOAT,
    lower_bound      FLOAT,
    upper_bound      FLOAT,
    severity         TEXT
);

-- Table résultats Moving Average
CREATE TABLE IF NOT EXISTS public.ma_results (
    production_day   DATE,
    station_id       TEXT,
    station_name     TEXT,
    kpi_name         TEXT,
    kpi_value        FLOAT,
    ma_value         FLOAT,
    deviation_pct    FLOAT,
    severity         TEXT
);


select * from public.iforest_results ir ;
select * from public.forecast_results fr  ;
select * from public.iqr_results ir  ;
select * from public.ma_results mr  ;
select * from public.zscore_results zr  ;

SELECT * FROM public.forecast_results ;
