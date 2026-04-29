CREATE EXTENSION IF NOT EXISTS timescaledb;


CREATE TABLE IF NOT EXISTS machine_condition_classification (
    machine_condition_id INT PRIMARY KEY,
    condition_class VARCHAR(30) NOT NULL,
    is_run BOOLEAN DEFAULT FALSE,
    is_failure BOOLEAN DEFAULT FALSE,
    is_planned_stop BOOLEAN DEFAULT FALSE,
    is_setup BOOLEAN DEFAULT FALSE,
    is_micro_stop BOOLEAN DEFAULT FALSE,
    is_waiting BOOLEAN DEFAULT FALSE,
    comment VARCHAR(255)
);

INSERT INTO machine_condition_classification (
    machine_condition_id, condition_class, is_run, is_failure, is_planned_stop,
    is_setup, is_micro_stop, is_waiting, comment
)
VALUES
(5,  'BREAKDOWN',    FALSE, TRUE,  FALSE, FALSE, FALSE, FALSE, 'Panne'),
(6,  'BREAKDOWN',    FALSE, TRUE,  FALSE, FALSE, FALSE, FALSE, 'Panne'),
(7,  'BREAKDOWN',    FALSE, TRUE,  FALSE, FALSE, FALSE, FALSE, 'Panne'),
(8,  'SETUP',        FALSE, FALSE, FALSE, TRUE,  FALSE, FALSE, 'Réglage / changement'),
(9,  'WAITING',      FALSE, FALSE, FALSE, FALSE, FALSE, TRUE,  'Attente'),
(10, 'MICRO_STOP',   FALSE, FALSE, FALSE, FALSE, TRUE,  FALSE, 'Micro-arrêt'),
(11, 'PLANNED_STOP', FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, 'Arrêt planifié'),
(12, 'MICRO_STOP',   FALSE, FALSE, FALSE, FALSE, TRUE,  FALSE, 'Micro-arrêt'),
(13, 'PLANNED_STOP', FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, 'Arrêt planifié'),
(14, 'PLANNED_STOP', FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, 'Arrêt planifié'),
(15, 'PLANNED_STOP', FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, 'Arrêt planifié'),
(16, 'PLANNED_STOP', FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, 'Arrêt planifié'),
(17, 'RUN', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Machine en fonctionnement')
ON CONFLICT (machine_condition_id) DO NOTHING;


CREATE TABLE IF NOT exists quality_data (
    quality_id SERIAL PRIMARY KEY,
    station_id INT,
    workorder_id INT,
    event_time TIMESTAMP,
    total_qty INT,
    scrap_qty INT,
    rework_qty INT
);

INSERT INTO quality_data (
    station_id,
    workorder_id,
    event_time,
    total_qty,
    scrap_qty,
    rework_qty
)
SELECT
    station_id,
    1,
    NOW() - (random() * interval '30 days'),
    (80 + floor(random()*40))::INT AS total_qty,
    floor(random()*3)::INT AS scrap_qty,
    floor(random()*2)::INT AS rework_qty
FROM generate_series(1,500),
     (SELECT DISTINCT station_id FROM stations) s;


CREATE TABLE IF NOT EXISTS station_nominal_rate (
    station_id INT PRIMARY KEY,
    nominal_rate_pph NUMERIC NOT NULL   
);

INSERT INTO station_nominal_rate (station_id, nominal_rate_pph)
VALUES
(1,100),(2,100),(3,100),(4,100),(5,100),(6,100),
(7,100),(8,100),(12,100),(17,100),(19,100),(20,100),(26,100)
ON CONFLICT (station_id) DO UPDATE
SET nominal_rate_pph = EXCLUDED.nominal_rate_pph;



//  KPI  TAUX DISPONIBILITE DES EQUIPEMENT

 /* 
* DISPONIBILITE + FIABILITE
* Availability Reliability (%) (maintenance KPI)
* AvailabilityOEE =  RunTime / PlannedProductionTime​ donne l’écart avec la disponibilité fiabilité
* Répond à : fiabilité + réparation (Industry 4.0)
* Si elle est basse : problème pannes / maintenance
*/


CREATE OR REPLACE VIEW kpi_availability_reliability AS
WITH base AS (
  SELECT
    mcd.station_id,
    mcd.machine_condition_id,
    c.condition_class,
    c.is_run,
    c.is_failure,
    c.is_planned_stop,
    c.is_setup,
    c.is_micro_stop,
    c.is_waiting,
    EXTRACT(EPOCH FROM (
      NULLIF(TRIM(mcd.date_to),'NULL')::timestamptz
      - NULLIF(TRIM(mcd.date_from),'NULL')::timestamptz
    )) AS duration_s
  FROM machine_condition_data mcd
  LEFT JOIN machine_condition_classification c
    ON mcd.machine_condition_id = c.machine_condition_id
  WHERE TRIM(mcd.date_from) <> 'NULL'
    AND TRIM(mcd.date_to) <> 'NULL'
),
agg AS (
  SELECT
    station_id,
    SUM(duration_s) FILTER (WHERE duration_s > 0) AS total_time_s,
    SUM(duration_s) FILTER (
      WHERE duration_s > 0 AND COALESCE(is_planned_stop, FALSE) = TRUE
    ) AS planned_stop_s,
    SUM(duration_s) FILTER (
      WHERE duration_s > 0 AND COALESCE(is_run, FALSE) = TRUE
    ) AS run_time_s,
    SUM(duration_s) FILTER (
      WHERE duration_s > 0 AND COALESCE(is_failure, FALSE) = TRUE
    ) AS breakdown_time_s,
    SUM(duration_s) FILTER (
      WHERE duration_s > 0 AND COALESCE(is_setup, FALSE) = TRUE
    ) AS setup_time_s,
    SUM(duration_s) FILTER (
      WHERE duration_s > 0 AND COALESCE(is_micro_stop, FALSE) = TRUE
    ) AS micro_stop_time_s,
    SUM(duration_s) FILTER (
      WHERE duration_s > 0 AND COALESCE(is_waiting, FALSE) = TRUE
    ) AS waiting_time_s,
    COUNT(*) FILTER (
      WHERE duration_s > 0 AND COALESCE(is_failure, FALSE) = TRUE
    ) AS failure_count
  FROM base
  WHERE duration_s > 0
  GROUP BY station_id
),
kpi AS (
  SELECT
    station_id,
    failure_count,
    total_time_s,
    COALESCE(planned_stop_s,0) AS planned_stop_s,
    COALESCE(run_time_s,0) AS run_time_s,
    COALESCE(breakdown_time_s,0) AS breakdown_time_s,
    COALESCE(setup_time_s,0) AS setup_time_s,
    COALESCE(micro_stop_time_s,0) AS micro_stop_time_s,
    COALESCE(waiting_time_s,0) AS waiting_time_s,
    (total_time_s - COALESCE(planned_stop_s,0)) AS planned_production_time_s,
    (COALESCE(run_time_s,0) / NULLIF(failure_count,0)) / 3600.0 AS mtbf_hours,
    (COALESCE(breakdown_time_s,0) / NULLIF(failure_count,0)) / 3600.0 AS mttr_hours
  FROM agg
)
SELECT
  station_id,
  failure_count,
  ROUND(planned_production_time_s / 3600.0, 2) AS planned_production_hours,
  ROUND(run_time_s / 3600.0, 2) AS run_hours,
  ROUND(breakdown_time_s / 3600.0, 2) AS breakdown_hours,
  ROUND(setup_time_s / 3600.0, 2) AS setup_hours,
  ROUND(micro_stop_time_s / 3600.0, 2) AS micro_stop_hours,
  ROUND(waiting_time_s / 3600.0, 2) AS waiting_hours,
  ROUND(
    100.0 * run_time_s / NULLIF(planned_production_time_s, 0)
  , 2) AS availability_oee_pct,
  ROUND(mtbf_hours, 2) AS mtbf_hours,
  ROUND(mttr_hours, 2) AS mttr_hours,
  ROUND(
    100.0 * mtbf_hours / NULLIF(mtbf_hours + mttr_hours, 0)
  , 2) AS availability_reliability_pct,
  ROUND(
    1.0 / NULLIF(mtbf_hours, 0)
  , 4) AS failure_rate_per_hour,
ROUND(
    (100.0 * run_time_s / NULLIF(planned_production_time_s, 0))
    -
    (100.0 * mtbf_hours / NULLIF(mtbf_hours + mttr_hours, 0))
  , 2) AS availability_gap_pct
FROM kpi;

/* SELECT * FROM kpi_availability_reliability ORDER BY availability_oee_pct DESC;*/

/* Si availability_gap_pct < 0 => Les pertes viennent surtout des pannes.
Si availability_gap_pct < 0 => La disponibilité OEE est plus faible que la disponibilité maintenance
*/ 


// Pareto le temps par état et par station 
// répartition des station par station et par classe d’état

CREATE OR REPLACE VIEW kpi_station_state_distribution AS
WITH base AS (
  SELECT
    mcd.station_id,
    c.condition_class,
    EXTRACT(EPOCH FROM (
      NULLIF(TRIM(mcd.date_to),'NULL')::timestamptz
      - NULLIF(TRIM(mcd.date_from),'NULL')::timestamptz
    )) / 3600.0 AS duration_h
  FROM machine_condition_data mcd
  LEFT JOIN machine_condition_classification c
    ON mcd.machine_condition_id = c.machine_condition_id
  WHERE TRIM(mcd.date_from) <> 'NULL'
    AND TRIM(mcd.date_to) <> 'NULL'
)
SELECT
  station_id,
  COALESCE(condition_class, 'UNCLASSIFIED') AS condition_class,
  ROUND(SUM(duration_h), 2) AS total_hours
FROM base
WHERE duration_h > 0
GROUP BY station_id, COALESCE(condition_class, 'UNCLASSIFIED');

/* SELECT * FROM kpi_station_state_distribution ORDER BY station_id, total_hours DESC;*/


// 3- taux de performance par station
// Performance= run / (Run + MicroStop)​

CREATE OR REPLACE VIEW kpi_performance AS
WITH base AS (
SELECT
    station_id,
    condition_class,
    EXTRACT(EPOCH FROM (
        NULLIF(TRIM(date_to),'NULL')::timestamptz -
        NULLIF(TRIM(date_from),'NULL')::timestamptz
    )) AS duration_s
FROM machine_condition_data mcd
LEFT JOIN machine_condition_classification c
ON mcd.machine_condition_id = c.machine_condition_id
WHERE TRIM(date_from) <> 'NULL'
AND TRIM(date_to) <> 'NULL'
),
agg AS (
SELECT
    station_id,
    SUM(duration_s) FILTER (
        WHERE condition_class = 'RUN'
    ) AS run_time_s,
    SUM(duration_s) FILTER (
        WHERE condition_class = 'MICRO_STOP'
    ) AS micro_stop_s
FROM base
GROUP BY station_id
)
SELECT
    station_id,
    ROUND(run_time_s/3600.0,2) AS run_hours,
    ROUND(micro_stop_s/3600.0,2) AS micro_stop_hours,
    ROUND(
        100.0 * run_time_s /
        NULLIF(run_time_s + micro_stop_s,0)
    ,2) AS performance_rate_pct
FROM agg;

/* select * from kpi_performance ORDER BY performance_rate_pct desc;*/

/* Le taux de performance obtenu est proche de 100 % pour l’ensemble des stations. 
 * Cette valeur élevée s’explique par le fait que le calcul repose uniquement sur les micro-arrêts identifiés dans les données. 
 * En l’absence d’informations sur la cadence réelle de production ou les quantités produites, 
 * les pertes de vitesse (slowdowns) ne peuvent pas être mesurées. 
 * Le taux de performance reflète donc principalement l’impact des micro-arrêts et non l’ensemble des pertes de cadence. */


// 3- taux de qualité

CREATE OR REPLACE VIEW kpi_quality AS
SELECT
station_id,
SUM(total_qty) AS total_production,
SUM(scrap_qty) AS scrap,
SUM(rework_qty) AS rework,
SUM(total_qty - scrap_qty - rework_qty) AS good_qty,
ROUND(
100.0 * SUM(total_qty - scrap_qty - rework_qty) /
NULLIF(SUM(total_qty),0)
,2) AS quality_rate_pct
FROM quality_data
GROUP BY station_id;

/* select * from kpi_quality */

//  qualité moyenn est environ = 98.48 % => signifie 1.5% de pertes qualité

/* 
Ton système montre machines très disponibles, très peu de pertes de vitesse et qualité stable
Les pertes principales viennent de breakdown (pannes) et scrap / rework
Mais leur impact reste limité.

L’analyse du taux de qualité montre une production globalement maîtrisée avec un taux moyen de conformité d’environ 98.5 %. 
Les pertes de qualité, principalement liées aux rebuts et aux retouches, représentent environ 1.5 % de la production totale. 
*/

// TRS

CREATE OR REPLACE VIEW kpi_trs_oee AS
WITH time_base AS (
  SELECT
    mcd.station_id,
    c.condition_class,
    c.is_run,
    c.is_failure,
    c.is_planned_stop,
    c.is_micro_stop,
    EXTRACT(EPOCH FROM (
      NULLIF(TRIM(mcd.date_to),'NULL')::timestamptz
      - NULLIF(TRIM(mcd.date_from),'NULL')::timestamptz
    )) AS duration_s
  FROM machine_condition_data mcd
  LEFT JOIN machine_condition_classification c
    ON mcd.machine_condition_id = c.machine_condition_id
  WHERE TRIM(mcd.date_from) <> 'NULL'
    AND TRIM(mcd.date_to) <> 'NULL'
),
time_agg AS (
  SELECT
    station_id,
    SUM(duration_s) FILTER (WHERE duration_s > 0) AS total_time_s,
    SUM(duration_s) FILTER (
      WHERE duration_s > 0 AND COALESCE(is_planned_stop, FALSE) = TRUE
    ) AS planned_stop_s,
    SUM(duration_s) FILTER (
      WHERE duration_s > 0 AND COALESCE(is_run, FALSE) = TRUE
    ) AS run_time_s,
    SUM(duration_s) FILTER (
      WHERE duration_s > 0 AND COALESCE(is_failure, FALSE) = TRUE
    ) AS breakdown_time_s,
    SUM(duration_s) FILTER (
      WHERE duration_s > 0 AND COALESCE(is_micro_stop, FALSE) = TRUE
    ) AS micro_stop_s
  FROM time_base
  WHERE duration_s > 0
  GROUP BY station_id
),
availability_performance AS (
  SELECT
    station_id,
    ROUND((total_time_s - COALESCE(planned_stop_s,0)) / 3600.0, 2) AS planned_production_hours,
    ROUND(COALESCE(run_time_s,0) / 3600.0, 2) AS run_hours,
    ROUND(COALESCE(breakdown_time_s,0) / 3600.0, 2) AS breakdown_hours,
    ROUND(COALESCE(micro_stop_s,0) / 3600.0, 2) AS micro_stop_hours,
    ROUND(
      100.0 * COALESCE(run_time_s,0)
      / NULLIF((total_time_s - COALESCE(planned_stop_s,0)), 0)
    , 2) AS availability_oee_pct,
    ROUND(
      100.0 * COALESCE(run_time_s,0)
      / NULLIF(COALESCE(run_time_s,0) + COALESCE(micro_stop_s,0), 0)
    , 2) AS performance_rate_pct
  FROM time_agg
),
quality AS (
  SELECT
    station_id,
    SUM(total_qty) AS total_production,
    SUM(scrap_qty) AS scrap_qty,
    SUM(rework_qty) AS rework_qty,
    SUM(total_qty) - SUM(scrap_qty) - SUM(rework_qty) AS good_qty,
    ROUND(
      100.0 *
      (SUM(total_qty) - SUM(scrap_qty) - SUM(rework_qty))
      / NULLIF(SUM(total_qty), 0)
    , 2) AS quality_rate_pct
  FROM quality_data
  GROUP BY station_id
)
SELECT
  ap.station_id,
  ap.planned_production_hours,
  ap.run_hours,
  ap.breakdown_hours,
  ap.micro_stop_hours,
  ap.availability_oee_pct,
  ap.performance_rate_pct,
  q.total_production,
  q.scrap_qty,
  q.rework_qty,
  q.good_qty,
  q.quality_rate_pct,
  ROUND(
    (ap.availability_oee_pct / 100.0) *
    (ap.performance_rate_pct / 100.0) *
    (q.quality_rate_pct / 100.0) * 100
  , 2) AS trs_oee_pct
FROM availability_performance ap
JOIN quality q
  ON ap.station_id = q.station_id;


/* select * from kpi_trs_oee kto */


/* ANALYS des PERTES:  même si le TRS est élevé, les pertes viennent surtout de
1- DISPONIBILITE: 96.85% -> 98.07% donc pertes = 2% principalement dues aux breakdownsalter 
2- QUALITE : 98.42% -> 98.53% donc pertes qualité = 1.5% ( scrap + rework )
3- PERFORMANCE : 99.47% -> 99.81% donc pertes très faibles donc les microstops sont faibles

=> STATIONS LES PLUS PERFORMANTES: 17 -19 - 20, ces stations ont peu de pannes,peu de micro stops, bonne qualité
=> STATIONS LES PLUS CRITIQUES: 1 - 26, mais breakdowns plus elevé et scrap un peu plus elevé

=> AVAILABILITY = 97.5% / PERFORMANCE = 99.6% / QUALITY = 98.5% 
=> TRS = 95.7%   DONC machines très disponibles, production rapide, qualité maitrisée
=> les pertes principales viennent de breakdowns


Les résultats obtenus montrent un niveau global de performance industrielle élevé. 
Le TRS moyen des stations est d’environ 95 %, ce qui correspond à un niveau d’excellence selon les standards industriels. 
L’analyse des composantes du TRS révèle que les pertes de performance sont très faibles, 
tandis que les principales pertes proviennent de la disponibilité des équipements, notamment en raison des pannes machines. 
Les pertes de qualité restent limitées, avec un taux de conformité supérieur à 98 %.

*/



// pareto global des pertes TRS en heures equivalents

/*
 * Contrairement au Pareto simple machine, cette requête combine :
 * PLANNED_STOP → perte de disponibilité
 * BREAKDOWN → perte de disponibilité
 * MICRO_STOP → perte de performance
 * SCRAP → perte de qualité convertie en heures
 * REWORK → perte de qualité convertie en heures
 Donc elle couvre les 3 composantes du TRS dans une seule analyse.
*/

// montre le pareto complet par station


CREATE OR REPLACE VIEW kpi_pareto_losses AS
WITH time_losses AS (
  SELECT
    c.condition_class AS loss_type,
    SUM(
      EXTRACT(EPOCH FROM (
        NULLIF(TRIM(mcd.date_to),'NULL')::timestamptz -
        NULLIF(TRIM(mcd.date_from),'NULL')::timestamptz
      ))
    ) / 3600.0 AS loss_hours
  FROM machine_condition_data mcd
  JOIN machine_condition_classification c
    ON mcd.machine_condition_id = c.machine_condition_id
  WHERE TRIM(mcd.date_from) <> 'NULL'
    AND TRIM(mcd.date_to) <> 'NULL'
    AND c.condition_class IN ('PLANNED_STOP','BREAKDOWN','MICRO_STOP')
  GROUP BY c.condition_class
),
quality_losses AS (
  SELECT
    'SCRAP' AS loss_type,
    SUM(q.scrap_qty / NULLIF(r.nominal_rate_pph,0)) AS loss_hours
  FROM quality_data q
  JOIN station_nominal_rate r
    ON q.station_id = r.station_id
  UNION ALL
  SELECT
    'REWORK' AS loss_type,
    SUM(q.rework_qty / NULLIF(r.nominal_rate_pph,0)) AS loss_hours
  FROM quality_data q
  JOIN station_nominal_rate r
    ON q.station_id = r.station_id
),
all_losses AS (
  SELECT * FROM time_losses
  UNION ALL
  SELECT * FROM quality_losses
)
SELECT
  loss_type,
  ROUND(loss_hours, 2) AS loss_hours,
  ROUND(
    100.0 * loss_hours / SUM(loss_hours) OVER()
  , 2) AS loss_pct,
  ROUND(
    100.0 * SUM(loss_hours) OVER (
      ORDER BY loss_hours DESC
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) / SUM(loss_hours) OVER()
  , 2) AS cumulative_pct
FROM all_losses;

/* SELECT * FROM kpi_pareto_losses ORDER BY loss_hours DESC;*/


/* 
 * PLANNED_STOP = 35.57% cest la premiere source de perte : correspond à maintenance planifié
 * changement de serie, nettoyage et areets programmes
 => la plus grande opportunité d’amélioration se trouve dans l’organisation de la production et l’optimisation des arrêts planifiés.
 
 * BREAKDOWN = 33.50% deuxieme source majeur de perte: 
 * MTBF modere et MTTR faible et AVAILABILITY tres bonne mais perfectible
 => la maintenance est réactive et efficace, mais les pannes restent trop fréquentes.
 
 * SCRAP = 16.77%  
 => la qualité est globalement bonne, mais les rebuts ont un impact non négligeable sur le TRS.
  
 * REWORK = 8.44% Impact moyen
 => Cela montre que les retouches existent mais restent secondaires par rapport aux rebuts et à la disponibilité.
 
 * MIRCO_STOP = 5.72 % Impact faible
 => confirme la performance machine est globalement maitrise
 * 
 * 
 => Ton système perd principalement du TRS à cause de :PLANNED_STOP, BREAKDOWN, SCRAP

=> Donc les priorités d’amélioration sont :optimiser les arrêts planifiés, améliorer la fiabilité machine, réduire les rebuts
 */

/* L’analyse Pareto globale des pertes du TRS montre que les arrêts planifiés (35.57 %)
 *  et les pannes machines (33.50 %) constituent les deux principales sources de dégradation de la performance globale, 
 * représentant ensemble plus de 69 % des pertes. 
 * En ajoutant les rebuts (16.77 %), ces trois catégories totalisent 85.84 % des pertes globales. 
 Les actions d’amélioration doivent donc se concentrer prioritairement sur l’optimisation des arrêts planifiés, 
 le renforcement de la fiabilité des équipements et la réduction des défauts de production.*/



// pareto des pertes TRS par station
// Quelle est la principale source de perte de TRS pour chaque station ?

CREATE OR REPLACE VIEW kpi_pareto_station_losses AS
WITH params AS (
    SELECT 100.0 AS nominal_rate_pph
),
time_base AS (
SELECT
    mcd.station_id,
    c.condition_class,
    EXTRACT(EPOCH FROM (
        NULLIF(TRIM(mcd.date_to),'NULL')::timestamptz -
        NULLIF(TRIM(mcd.date_from),'NULL')::timestamptz
    )) / 3600.0 AS duration_h
FROM machine_condition_data mcd
JOIN machine_condition_classification c
ON mcd.machine_condition_id = c.machine_condition_id
WHERE TRIM(mcd.date_from) <> 'NULL'
AND TRIM(mcd.date_to) <> 'NULL'
),
time_losses AS (
SELECT
    station_id,
    condition_class AS loss_type,
    SUM(duration_h) AS loss_hours
FROM time_base
WHERE condition_class IN ('PLANNED_STOP','BREAKDOWN','MICRO_STOP')
GROUP BY station_id, condition_class
),
quality_losses AS (
SELECT
    q.station_id,
    'SCRAP' AS loss_type,
    SUM(q.scrap_qty) / (SELECT nominal_rate_pph FROM params) AS loss_hours
FROM quality_data q
GROUP BY q.station_id
UNION ALL
SELECT
    q.station_id,
    'REWORK',
    SUM(q.rework_qty) / (SELECT nominal_rate_pph FROM params)
FROM quality_data q
GROUP BY q.station_id
),
all_losses AS (
SELECT * FROM time_losses
UNION ALL
SELECT * FROM quality_losses
)
SELECT
    station_id,
    loss_type,
    ROUND(loss_hours,2) AS loss_hours,
    ROUND(
        100 * loss_hours /
        SUM(loss_hours) OVER (PARTITION BY station_id)
    ,2) AS loss_pct
FROM all_losses;

/* SELECT * FROM kpi_pareto_station_losses ORDER BY station_id, loss_hours DESC;*/


/*
 * Station avec le plus fort poids des micro-arrêts 26 : 7.79 %  /  8 : 7.44 % /  2 : 7.67 %
=> Même si l’impact reste modéré, ces stations sont les plus sensibles aux micro-stops.
 * 
 * 
 *Station avec le plus fort poids du scrap 17 : 19.30 %
=> Cette station combine bon TRS mais poids qualité plus élevé que les autres, Elle mérite une vérification procédé / réglage.
*
*
*Stations les plus pénalisées par les arrêts planifiés  19 : 38.34 % /  20 : 38.08 % /  7 : 37.90 % / 17 : 37.41 % / 3 : 37.33 %
*
*Analyse station par station - Stations les plus pénalisées par les pannes
Celles où BREAKDOWN domine : 1 : 39.24 % /  4 : 38.09 % / 5 : 35.77 % /  2 : 35.04 %
=> Ces stations sont les meilleures candidates pour maintenance préventive, maintenance prédictive, analyse des causes racines (Root Cause Analysis)
*
*
 *  L’analyse Pareto des pertes par station met en évidence une structure de pertes relativement homogène entre les équipements. 
 * Les principales sources de dégradation du TRS sont les arrêts planifiés et les pannes machines, 
 * qui représentent la majorité des pertes sur la quasi-totalité des stations. Les rebuts constituent la troisième source de perte, 
 * tandis que les retouches et micro-arrêts restent secondaires. 
 * Cette analyse permet d’orienter les actions d’amélioration prioritairement vers l’optimisation des arrêts planifiés, 
 * l’amélioration de la fiabilité des équipements et la réduction des non-conformités. */ 




