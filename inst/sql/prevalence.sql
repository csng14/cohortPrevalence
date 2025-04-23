DROP TABLE IF EXISTS #numerator;
CREATE TABLE #numerator AS
SELECT cohort_definition_id,
  YEAR(cohort_start_date) AS calendar_year,
	FLOOR((YEAR(cohort_start_date) - year_of_birth)) AS age,
	gender_concept_id,
  COUNT(DISTINCT subject_id) AS cohort_count
FROM (
  SELECT *
  FROM @work_database_schema.@cohort_table
  WHERE cohort_definition_id = @target_cohort_id
)
INNER JOIN @cdm_database_schema.person
	ON subject_id = person.person_id
INNER JOIN @cdm_database_schema.observation_period
	ON observation_period.person_id = person.person_id
		AND DATEADD(DAY, @washout_period, observation_period_start_date) <= cohort_start_date
		AND observation_period_end_date >= cohort_start_date
GROUP BY
  cohort_definition_id,
  YEAR(cohort_start_date),
	FLOOR((YEAR(cohort_start_date) - year_of_birth)),
	gender_concept_id;



DROP TABLE IF EXISTS #denominator;
CREATE TABLE #denominator AS
SELECT
  calendar_year,
  age,
  gender_concept_id,
	COUNT(person_id) AS num_person
FROM (
		SELECT person.person_id,
			calendar_year,
			FLOOR((calendar_year - year_of_birth)) AS age,
			gender_concept_id,
			CASE
				WHEN observation_period_start_date > DATEFROMPARTS(calendar_year, 1, 1) THEN observation_period_start_date
				ELSE DATEFROMPARTS(calendar_year, 1, 1)
			END AS start_date,
			CASE
				WHEN observation_period_end_date < DATEFROMPARTS(calendar_year + 1, 1, 1) THEN observation_period_end_date
				ELSE DATEFROMPARTS(calendar_year + 1, 1, 1)
			END AS end_date
		FROM (
			SELECT person_id,
				DATEADD(DAY, @washout_period, observation_period_start_date) AS observation_period_start_date,
				observation_period_end_date
			FROM @cdm_database_schema.observation_period
			WHERE DATEADD(DAY, @washout_period, observation_period_start_date) < observation_period_end_date
		) trunc_op
		INNER JOIN #year_interval
			ON YEAR(observation_period_start_date) <= calendar_year
				AND YEAR(observation_period_end_date) >= calendar_year
		INNER JOIN @cdm_database_schema.person
			ON trunc_op.person_id = person.person_id
	) time_spans_2
GROUP BY
  calendar_year,
  age,
  gender_concept_id
;

DROP TABLE IF EXISTS #prev_summary;
CREATE TABLE #prev_summary AS
SELECT denominator.calendar_year,
	denominator.age,
	concept_name AS gender,
	CASE
		WHEN numerator.cohort_count IS NOT NULL THEN CAST(numerator.cohort_count as FLOAT)
		ELSE CAST(0 AS FLOAT)
	END AS cohort_count,
	num_person
FROM #denominator denominator
INNER JOIN @vocabulary_database_schema.concept
	ON denominator.gender_concept_id = concept_id
LEFT JOIN #numerator numerator
	ON denominator.calendar_year = numerator.calendar_year
		AND denominator.age = numerator.age
		AND denominator.gender_concept_id = numerator.gender_concept_id;


/* Drop tables */
TRUNCATE TABLE #year_interval;
DROP TABLE #year_interval;

TRUNCATE TABLE #numerator;
DROP TABLE #numerator;

TRUNCATE TABLE #denominator;
DROP TABLE #denominator;
