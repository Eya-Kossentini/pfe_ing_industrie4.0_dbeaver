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

// 6- kpi Quantités produites vs rebuts

CREATE OR REPLACE VIEW kpi_quality AS
SELECT
    station_id,
    SUM(total_qty) AS total_production,
    SUM(scrap_qty) AS scrap,
    SUM(rework_qty) AS rework,
    SUM(total_qty - scrap_qty - rework_qty) AS good_qty,
    ROUND(
        100.0 * SUM(total_qty - scrap_qty - rework_qty) / NULLIF(SUM(total_qty), 0),
        2
    ) AS quality_rate_pct,
    ROUND(
        100.0 * SUM(scrap_qty) / NULLIF(SUM(total_qty), 0),
        2
    ) AS scrap_rate_pct,
    ROUND(
        100.0 * SUM(rework_qty) / NULLIF(SUM(total_qty), 0),
        2
    ) AS rework_rate_pct
FROM quality_data
GROUP BY station_id;

/* quality_rate+scrap_rate+rework_rate=100%
 * 
 * 3 lectures qualité très claires :
 * quality_rate_pct → part de production bonne (Good Quality Rate)
 * scrap_rate_pct → part perdue définitivement (Scrap Rate)  ==> la non-qualité irréversible
 * rework_rate_pct → part nécessitant retouche (Rework Rate)  ==> la non-qualité récupérable
 * 
 * Stations avec le plus de rebuts : station 26 → 1.04 %  / station 4 → 1.04 % / station 7 → 1.02 %
 * Stations avec le moins de rebuts : station 3 → 0.98 % / station 8 → 0.98 % / station 19 → 0.98 %
 * Stations avec le plus de rework : station 6 → 0.52 % / station 8 → 0.52 % / station 19 → 0.52 %
 * Meilleure station en qualité globale: station 3 → 98.55 %
*/

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


// relier 2 tables active_workorder et workorder   

CREATE OR REPLACE VIEW workorder_station AS
SELECT
    w.workorder_id,
    w.workorder_no,
    w.workorder_qty,
    w.startdate,
    w.deliverydate,
    w.status,
    a.station_id
FROM work_orders w
JOIN active_workorders a
    ON a.workorder_id = w.workorder_id;


//  *************** Respect des ordres et du planning de production **************************

// 7- kpi respect du planning par station

CREATE OR REPLACE VIEW kpi_planning_respect AS
SELECT
    station_id,
    COUNT(workorder_id) AS total_orders,
    SUM(
        CASE
            WHEN deliverydate::date >= CURRENT_DATE THEN 1
            ELSE 0
        END
    ) AS orders_on_time,
    SUM(
        CASE
            WHEN deliverydate::date < CURRENT_DATE THEN 1
            ELSE 0
        END
    ) AS delayed_orders,
    ROUND(
        (
            100.0 *
            SUM(
                CASE
                    WHEN deliverydate::date >= CURRENT_DATE THEN 1
                    ELSE 0
                END
            ) / NULLIF(COUNT(workorder_id),0)
        )::numeric,
        2
    ) AS planning_respect_pct
FROM workorder_station
GROUP BY station_id;

/* Stations 17, 19, 20 → non-respect du planning
 * Toutes les autres stations → planning respecté
=> le KPI Respect des ordres et du planning de production est calculé en comparant 
la date de livraison prévue des ordres de fabrication avec la date actuelle.
*/

SELECT
    COUNT(*) AS total_orders,
    SUM(orders_on_time) AS total_on_time,
    SUM(delayed_orders) AS total_delayed,
    ROUND(100.0 * SUM(orders_on_time) / NULLIF(SUM(total_orders), 0), 2) AS global_planning_respect_pct
FROM kpi_planning_respect;

/* Total stations / ordres suivis = 11
À l’heure = 8   - En retard = 3  
==> respect des échéances des OF par station affectée */

//le statut planning de chaque ordre de fabrication (OF).

CREATE OR REPLACE VIEW workorder_planning_status AS
SELECT
    workorder_id,
    workorder_no,
    station_id,
    workorder_qty,
    startdate,
    deliverydate,
    status,
    CASE
        WHEN deliverydate::date >= CURRENT_DATE THEN 'ON_TIME'
        ELSE 'DELAYED'
    END AS planning_status,
    CASE
        WHEN deliverydate::date < CURRENT_DATE
        THEN CURRENT_DATE - deliverydate::date
        ELSE 0
    END AS delay_days
FROM workorder_station;

/* WO_PCB_001 → livré dans les délais
 * WO_Automotive_Control_Unit_001 → livré dans les délais
 * WO001-Door-Hinge → en retard de 42 jours
 * Cet ordre est exécuté sur 3 stations : station 17 / station 19 /station 20
Donc ces stations héritent du retard.
*/


/* Quel ordre est en retard ? → WO001-Door-Hinge
 * Quelles stations sont impactées ? → 17, 19, 20
 * Quel est le respect global du planning ? → 72.73 % */


/* Le respect des ordres et du planning de production est évalué en comparant la date de livraison prévue des ordres de fabrication avec la date actuelle.
Un ordre est considéré comme respecté lorsque sa date de livraison n’est pas dépassée.
Dans le cas contraire, il est classé comme en retard.
L’analyse permet d’identifier les stations associées aux ordres en retard et d’évaluer le taux global de respect du planning. */



//    *********** Analyse de la production par machine, ligne, lot et période *******************************

//  Analyse par machine

CREATE OR REPLACE VIEW kpi_machine_analysis AS
SELECT
    station_id,
    planned_production_hours,
    run_hours,
    breakdown_hours,
    micro_stop_hours,
    setup_hours,
    waiting_hours,
    ROUND(
        (100.0 * run_hours / NULLIF(planned_production_hours, 0))::numeric,
        2
    ) AS machine_efficiency_pct
FROM kpi_availability_reliability;

/* Machines les plus performantes : station 17 → 98.07%  / station 19 → 97.85%
 * Machines les moins performantes: station 1 → 96.85%
 * Cela permet de détecter : les pannes récurrentes, les machines sous-performantes, les pertes de performance
 * 
 * => L’analyse de la production par machine permet d’évaluer l’efficience individuelle des équipements.
Le taux d’efficience machine est calculé en comparant le temps productif réel (temps de fonctionnement) au temps total disponible.
Cet indicateur permet d’identifier les machines sous-utilisées, les pertes de performance et les équipements présentant des arrêts fréquents.
*/ 

// analyse de production par ligne

CREATE OR REPLACE VIEW kpi_line_analysis AS
SELECT
    l.id AS line_id,
    l.name AS line_name,
    SUM(q.total_qty) AS total_production,
    SUM(q.scrap_qty) AS total_scrap,
    SUM(q.rework_qty) AS total_rework,
    SUM(q.total_qty - q.scrap_qty - q.rework_qty) AS good_qty,
    ROUND(
        (100.0 *
        SUM(q.total_qty - q.scrap_qty - q.rework_qty) /
        NULLIF(SUM(q.total_qty),0))::numeric,
        2
    ) AS line_quality_rate_pct,
    ROUND(
        (100.0 *
        SUM(q.scrap_qty) /
        NULLIF(SUM(q.total_qty),0))::numeric,
        2
    ) AS line_scrap_rate_pct
FROM quality_data q
JOIN line_station_association ls
    ON ls.station_id = q.station_id
JOIN lines l
    ON l.id = ls.line_id
GROUP BY l.id, l.name;

/* Cohérence du flux: On observe la production totale par ligne :FRA-SMT Line → 597 801 pièces / DH-ASM-LINE-01 → 298 692 pièces / SMT Line3 → 99 482 pièces
   =>Cela permet de voir quelle ligne produit le plus.

* Détection de goulets d’étranglement : SMT Line3 produit beaucoup moins → peut être une ligne plus petite ou plus lente.
* 
* => L’analyse par ligne de production consiste à agréger les performances des différentes stations composant une même ligne 
* afin d’évaluer la cohérence globale du flux de production. 
* Les indicateurs calculés incluent la production totale, les rebuts, les retouches et le taux de qualité. 
* Cette analyse permet d’identifier les lignes les plus productives, de détecter les déséquilibres 
* entre lignes et de mesurer l’impact des pertes de qualité sur la performance globale du système de production.
* 
*/

// analyse par lot - Ordre de fabrication (OF)


CREATE VIEW kpi_workorder_analysis AS
WITH last_quality AS (
    SELECT DISTINCT ON (q.workorder_id)
        q.workorder_id,
        q.total_qty,
        q.scrap_qty,
        q.rework_qty,
        q.event_time
    FROM quality_data q
    ORDER BY q.workorder_id, q.event_time DESC
)
SELECT
    w.workorder_id,
    w.workorder_no,
    w.workorder_qty AS planned_qty,
    lq.total_qty AS actual_production,
    lq.scrap_qty AS total_scrap,
    lq.rework_qty AS total_rework,
    (lq.total_qty - lq.scrap_qty - lq.rework_qty) AS good_qty,
    ROUND(
        (
            100.0 * (lq.total_qty - lq.scrap_qty - lq.rework_qty)
            / NULLIF(lq.total_qty, 0)
        )::numeric,
        2
    ) AS quality_rate_pct,
    ROUND(
        (
            100.0 * lq.total_qty
            / NULLIF(w.workorder_qty, 0)
        )::numeric,
        2
    ) AS production_adherence_pct
FROM workorder_station ws
JOIN work_orders w
    ON w.workorder_id = ws.workorder_id
JOIN last_quality lq
    ON lq.workorder_id = w.workorder_id
GROUP BY
    w.workorder_id,
    w.workorder_no,
    w.workorder_qty,
    lq.total_qty,
    lq.scrap_qty,
    lq.rework_qty;


/* Pour l’OF WO_PCB_001 : 
 * Quantité planifiée : 1000 / Production réelle : 88 / Quantité conforme : 86 / Taux de qualité : 97.73 % / Respect quantitatif du plan : 8.80 %
=> la qualité du lot est bonne mais la quantité produite reste très inférieure à la quantité planifiée
 * Donc l’OF est probablement en cours, pas encore terminé, ou partiellement exécuté.

=> L’analyse par lot (ordre de fabrication) permet de suivre individuellement chaque OF en comparant la quantité planifiée
 à la quantité réellement produite, ainsi que les pertes de qualité associées. Les indicateurs calculés incluent la production réelle,
  les rebuts, les retouches, la quantité conforme, le taux de qualité et le taux de respect quantitatif du plan. 
  Cette analyse facilite la comparaison entre ordres de fabrication et met en évidence les écarts entre planification et exécution.
*/


// analyse par periode (jour)

CREATE OR REPLACE VIEW kpi_production_by_day AS
SELECT
    DATE(event_time) AS production_day,
    SUM(total_qty) AS total_production,
    SUM(scrap_qty) AS total_scrap,
    SUM(rework_qty) AS total_rework,
    SUM(total_qty - scrap_qty - rework_qty) AS good_qty,
    ROUND(
        (
            100.0 * SUM(total_qty - scrap_qty - rework_qty)
            / NULLIF(SUM(total_qty), 0)
        )::numeric,
        2
    ) AS quality_rate_pct,
    ROUND(
        (
            100.0 * SUM(scrap_qty)
            / NULLIF(SUM(total_qty), 0)
        )::numeric,
        2
    ) AS scrap_rate_pct
FROM quality_data
GROUP BY DATE(event_time)
ORDER BY production_day;

/* production moyenne ≈ 40 000 à 45 000 unités / jour
 * qualité très stable ≈ 98.4 % – 98.6 % 
 * 
 * deux anomalies pour 09/03/2026 = 30574 production 
 * et 10/03/2026 production 8234  
 * ca indique arret machine ou maintenance ou manque de amtiere ou production partielle */ 
// analyse par periode (semaine)

CREATE OR REPLACE VIEW kpi_production_by_week AS
SELECT
    DATE_TRUNC('week', event_time) AS production_week,
    SUM(total_qty) AS total_production,
    SUM(scrap_qty) AS total_scrap,
    SUM(rework_qty) AS total_rework,
    SUM(total_qty - scrap_qty - rework_qty) AS good_qty,
    ROUND(
        (
            100.0 * SUM(total_qty - scrap_qty - rework_qty)
            / NULLIF(SUM(total_qty), 0)
        )::numeric,
        2
    ) AS quality_rate_pct,
    ROUND(
        (
            100.0 * SUM(scrap_qty)
            / NULLIF(SUM(total_qty), 0)
        )::numeric,
        2
    ) AS scrap_rate_pct
FROM quality_data
GROUP BY DATE_TRUNC('week', event_time)
ORDER BY production_week;

/* production est tres stable autour de 300 000 pieces par semaine
 * qualite presque 98.5% montre un processus industriel stable, peu de variation de qualité*/ 
// analyse par periode (mois)

CREATE OR REPLACE VIEW kpi_production_by_month AS
SELECT
    DATE_TRUNC('month', event_time) AS production_month,
    SUM(total_qty) AS total_production,
    SUM(scrap_qty) AS total_scrap,
    SUM(rework_qty) AS total_rework,
    SUM(total_qty - scrap_qty - rework_qty) AS good_qty,
    ROUND(
        (
            100.0 * SUM(total_qty - scrap_qty - rework_qty)
            / NULLIF(SUM(total_qty), 0)
        )::numeric,
        2
    ) AS quality_rate_pct,
    ROUND(
        (
            100.0 * SUM(scrap_qty)
            / NULLIF(SUM(total_qty), 0)
        )::numeric,
        2
    ) AS scrap_rate_pct
FROM quality_data
GROUP BY DATE_TRUNC('month', event_time)
ORDER BY production_month;

/* Fevrier production 910 751 scrap rate 1.00%
 * Mars production 3838 235 scrap rat 1.01%
 * MARS est plus faible car la période s'arrete au 10 mars 
 * qualite reste stable 98.5 % */


// Cadence de production par période

CREATE OR REPLACE VIEW kpi_daily_production_rate AS
SELECT
    DATE(event_time) AS production_day,
    SUM(total_qty) AS total_production,
    ROUND(
        (SUM(total_qty) / 24.0)::numeric,
        2
    ) AS units_per_hour
FROM quality_data
GROUP BY DATE(event_time)
ORDER BY production_day;

/* cadence normale entre 1700 - 1900 pieces par heure 
 * baisse brutale le 10/03/2026 cadence 343 unites/heures donc cette journee doit etre analysee 
 */

/* => L’analyse temporelle de la production permet d’observer l’évolution de la performance industrielle sur différentes périodes 
 * (jour, semaine, mois). Les indicateurs calculés incluent la production totale, les rebuts, la quantité conforme,
 *  le taux de qualité et la cadence de production. Cette analyse met en évidence les variations de performance dans le temps et 
 * permet d’identifier les périodes de baisse de production, souvent liées à des arrêts machines, des opérations de maintenance 
 * ou des contraintes d’approvisionnement.
 */ 

// Detection anomalie de production journalière avec Z-Score

// Avec la règle classique du Z-score, une anomalie est détectée si : ∣𝑍∣ > 3

CREATE OR REPLACE VIEW anomaly_production_zscore AS
SELECT
    production_day,
    total_production,
    AVG(total_production) OVER() AS avg_production,
    STDDEV(total_production) OVER() AS std_production,
    ROUND(
        (
            (total_production - AVG(total_production) OVER())
            /
            NULLIF(STDDEV(total_production) OVER(),0)
        )::numeric,
        2
    ) AS z_score,
    CASE
        WHEN ABS(
            (total_production - AVG(total_production) OVER())
            /
            NULLIF(STDDEV(total_production) OVER(),0)
        ) > 3
        THEN 'ANOMALY'
        ELSE 'NORMAL'
    END AS anomaly_flag
FROM kpi_production_by_day;

/* 2026-02-07 : production = 12 353 moyenne = 40 437 écart très fort à la baisse
➡️ journée de sous-production anormale

2026-03-10  : production = 8 234 , encore plus bas que la moyenne z_score = -3.77
➡️ anomalie encore plus marquée, probablement liée à : arrêt machine, maintenance, manque matière, OF non lancé,problème de ligne.  */ 


// Détection avec IQR (Interquartile Range)
// Méthode très utilisée en industrie.
// Formule : 𝐼𝑄𝑅 = 𝑄3 − 𝑄1
// Anomalie si : X < Q1 − 1.5IQR
// ou X > Q3 + 1.5IQR
// anomalie si PRODUCTION < 35770  ou PRODUCTION > 49572

CREATE OR REPLACE VIEW anomaly_production_iqr AS
WITH stats AS (
    SELECT
        percentile_cont(0.25) WITHIN GROUP (ORDER BY total_production) AS q1,
        percentile_cont(0.75) WITHIN GROUP (ORDER BY total_production) AS q3
    FROM kpi_production_by_day
)
SELECT
    p.production_day,
    p.total_production,
    s.q1,
    s.q3,
    (s.q3 - s.q1) AS iqr,
    CASE
        WHEN p.total_production < s.q1 - 1.5*(s.q3-s.q1)
        OR p.total_production > s.q3 + 1.5*(s.q3-s.q1)
        THEN 'ANOMALY'
        ELSE 'NORMAL'
    END AS anomaly_flag
FROM kpi_production_by_day p
CROSS JOIN stats s;

/* La détection des anomalies a été réalisée à l’aide de la méthode statistique IQR (Interquartile Range). 
 * Cette approche identifie les valeurs situées en dehors de l’intervalle [Q1−1.5×IQR,Q3+1.5×IQR]. 
 * Les résultats montrent plusieurs journées de sous-production anormale, notamment les 7 et 8 février
 *  ainsi que les 9 et 10 mars 2026. Ces anomalies peuvent être liées à des arrêts machines, 
 * des opérations de maintenance ou des perturbations dans le flux de production. */ 

// Detection par moyenne mobile (7 jours)  : Comparer une valeur à la moyenne des derniers jours.

CREATE OR REPLACE VIEW anomaly_production_moving_avg AS
SELECT
    production_day,
    total_production,
    AVG(total_production) OVER(
        ORDER BY production_day
        ROWS BETWEEN 7 PRECEDING AND CURRENT ROW
    ) AS moving_avg,
    ROUND(
        (
            total_production -
            AVG(total_production) OVER(
                ORDER BY production_day
                ROWS BETWEEN 7 PRECEDING AND CURRENT ROW
            )
        )::numeric,
        2
    ) AS deviation,
    CASE
        WHEN ABS(
            total_production -
            AVG(total_production) OVER(
                ORDER BY production_day
                ROWS BETWEEN 7 PRECEDING AND CURRENT ROW
            )
        ) > 10000
        THEN 'ANOMALY'
        ELSE 'NORMAL'
    END AS anomaly_flag
FROM kpi_production_by_day;

/* Une analyse de séries temporelles basée sur une moyenne mobile a été réalisée afin d’identifier les dérives de production. 
 * Cette méthode compare la production quotidienne à la tendance moyenne observée sur les jours précédents. 
 * Les résultats mettent en évidence plusieurs anomalies, notamment les 9 et 10 mars 2026, 
 * caractérisées par une chute significative de la production par rapport à la tendance moyenne. 
 * Ces anomalies peuvent être associées à des arrêts machines, des perturbations du flux de production 
 * ou des opérations de maintenance. */ 

// scrap_rate_par_jour
// Scrap Rate=Scrap Qty /​ Total Production×100

CREATE OR REPLACE VIEW daily_scrap_rate AS
SELECT
    DATE(event_time) AS production_day,
    SUM(total_qty) AS total_production,
    SUM(scrap_qty) AS total_scrap,
    ROUND(
        (SUM(scrap_qty)::numeric / NULLIF(SUM(total_qty),0)) * 100,
        2
    ) AS scrap_rate_pct
FROM quality_data
GROUP BY DATE(event_time)
ORDER BY production_day;

// moyenne mobile prediction
// PredictionJ+1​=moyenne(scrap_rateJ​,scrap_rateJ−1​,scrap_rateJ−2​)
// + detection aleret dérive qualité , machine mal réglée , défaut matière

CREATE OR REPLACE VIEW kpi_scrap_prediction AS
SELECT
    production_day,
    total_production,
    total_scrap,
    scrap_rate_pct,
    ROUND(
        AVG(scrap_rate_pct) OVER(
            ORDER BY production_day
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS predicted_scrap_rate_j1,
    ROUND(
        scrap_rate_pct -
        AVG(scrap_rate_pct) OVER(
            ORDER BY production_day
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS deviation,
    CASE
        WHEN scrap_rate_pct >
        AVG(scrap_rate_pct) OVER(
            ORDER BY production_day
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) * 1.20
        THEN 'SCRAP_ALERT'
        ELSE 'NORMAL'
    END AS alert_flag
FROM daily_scrap_rate;