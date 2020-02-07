WITH t1 AS (

   SELECT DISTINCT ON (original_primary_role_id, original_user_id)
      original_primary_role_id,
      original_user_id,
      SUM(CASE WHEN review_is_accepted = false OR review_is_accepted = true THEN 1 ELSE 0 END) AS number_reviewed,
      SUM(CASE WHEN review_is_accepted = false OR review_is_bad_role = true THEN 1 ELSE 0 END) AS mistakes,
      1 - SUM(CASE WHEN review_is_accepted = false OR review_is_bad_role = true THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS accuracy

  FROM
      main_profileratingoutcomeephemeral outcome
      LEFT JOIN [user_table AS user1] on user1.id = outcome.original_user_id
      LEFT JOIN [customer_role_details_table AS cr_details] on cr_details.role_id = outcome.original_primary_role_id
  WHERE
      [user1.full_name=user_name_filter] AND
      [review_created_at=daterange] AND
      [cr_details.customer_name=Customer_Filter] AND
      [cr_details.role_name=Role_Filter] AND
      original_user_id != review_user_id AND
      original_is_accepted = true AND
      original_is_excused = false AND
      original_is_qc_requested = false AND
      review_is_after_heuristic_change = false AND
      review_is_generated_in_qc_queue = true AND
      days_between_ratings <= 14

  GROUP BY original_primary_role_id, original_user_id

),

t2 AS (

SELECT
cr_details.customer_name || ' - ' || cr_details.role_name AS customer_role,
rating.pr_rater_name AS name,
COUNT(person_id) AS ratings,
SUM(profile_seconds_taken) / 3600 AS hours,
COUNT(person_id) * 3600 / SUM(profile_seconds_taken) AS speed,
SUM(CASE WHEN profile_qualified = true THEN 1 ELSE 0 END) AS accepted,
SUM(CASE WHEN profile_qualified = false THEN 1 ELSE 0 END) AS rejected,
SUM(CASE WHEN profile_qualified = true THEN 1 ELSE 0 END) * 1.0 / COUNT(person_id) AS accept_percent,
SUM(CASE WHEN profile_qualified = true and profile_score >= rating.acceptance_probability_threshold THEN 1 ELSE 0 END) AS taken,
SUM(CASE WHEN profile_qualified = true and profile_score >= rating.acceptance_probability_threshold THEN 1 ELSE 0 END) * (1.0 / COUNT(person_id)) AS taken_percent,
SUM(CASE WHEN profile_qc_requested = true THEN 1 ELSE 0 END) AS questions,
SUM(CASE WHEN profile_qc_requested = true THEN 1 ELSE 0 END) * 1.0 / COUNT(person_id) AS question_percent,
qc_stats.number_reviewed,
qc_stats.mistakes,
qc_stats.accuracy,
levels.int_value,

CASE
  WHEN levels.int_value >= 90 THEN 'Done'
  WHEN qc_stats.number_reviewed ISNULL OR qc_stats.number_reviewed < 10 THEN 'QC review needed'
  WHEN COUNT(person_id) > 50 AND (COUNT(person_id) * 3600 / SUM(profile_seconds_taken)) >= 40 AND qc_stats.accuracy > 0.85 THEN 'Ready'
  WHEN COUNT(person_id) < 50 AND (COUNT(person_id) * 3600 / SUM(profile_seconds_taken)) < 40 AND qc_stats.accuracy < 0.85 THEN 'Improve all metrics'
  WHEN COUNT(person_id) > 50 AND (COUNT(person_id) * 3600 / SUM(profile_seconds_taken)) < 40 AND qc_stats.accuracy < 0.85 THEN 'Increase speed and accuracy'
  WHEN COUNT(person_id) < 50 AND (COUNT(person_id) * 3600 / SUM(profile_seconds_taken)) >= 40 AND qc_stats.accuracy < 0.85 THEN 'Increase ratings and accuracy'
  WHEN COUNT(person_id) < 50 AND (COUNT(person_id) * 3600 / SUM(profile_seconds_taken)) < 40 AND qc_stats.accuracy > 0.85 THEN 'Increase ratings and speed'
  WHEN COUNT(person_id) < 50 AND (COUNT(person_id) * 3600 / SUM(profile_seconds_taken)) >= 40 AND qc_stats.accuracy > 0.85 THEN 'Increase ratings'
  WHEN COUNT(person_id) > 50 AND (COUNT(person_id) * 3600 / SUM(profile_seconds_taken)) < 40 AND qc_stats.accuracy > 0.85 THEN 'Increase speed'
  WHEN COUNT(person_id) > 50 AND (COUNT(person_id) * 3600 / SUM(profile_seconds_taken)) >= 40 AND qc_stats.accuracy < 0.85 THEN 'Increase accuracy'
  ELSE ''
END AS level_up

FROM [temp_rot AS rating]

LEFT JOIN t1 AS qc_stats ON qc_stats.original_user_id = rating.pr_rater AND qc_stats.original_primary_role_id = rating.role_id

LEFT JOIN main_seekerroleexperiencestatemodel AS levels ON levels.user_id = rating.pr_rater AND levels.role_id = rating.role_id

LEFT JOIN [customer_role_details_table AS cr_details] on cr_details.role_id = rating.role_id

WHERE
[rating.pr_rater_name=user_name_filter] AND
[DATE(rating.profile_pst)=daterange] AND
[cr_details.customer_name=Customer_Filter] AND
[cr_details.role_name=Role_Filter]

GROUP BY customer_role, name, levels.int_value, qc_stats.number_reviewed, qc_stats.mistakes, qc_stats.accuracy

ORDER BY customer_role, name, levels.int_value DESC

),

t3 AS (

SELECT DISTINCT ON (customer_role, name)
customer_role, name, ratings, hours, speed, accepted, rejected, accept_percent, taken, taken_percent, number_reviewed, mistakes, accuracy, level_up

FROM t2

)

SELECT *
FROM t3

ORDER BY
    CASE
      WHEN level_up = 'Ready' THEN 1
      WHEN level_up = 'Increase ratings' THEN 2
      WHEN level_up = 'Increase speed' THEN 3
      WHEN level_up = 'Increase accuracy' THEN 4
      WHEN level_up = 'Increase ratings and speed' THEN 5
      WHEN level_up = 'Increase ratings and accuracy' THEN 6
      WHEN level_up = 'Increase speed and accuracy' THEN 7
      WHEN level_up = 'Improve all metrics' THEN 8
      WHEN level_up = 'QC review needed' THEN 9
      WHEN level_up = 'Done' THEN 10
      ELSE 11
    END,
  customer_role, name
