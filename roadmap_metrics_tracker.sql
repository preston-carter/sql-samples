
/* Union exposure and snippet model data sets post Q3 2019 */

WITH t1 AS (
  SELECT created_at, feature_name, value
  FROM main_ratingprofilemodel
  WHERE feature_name  IN (SELECT attr_name FROM  [mldt_models_roadmap_csv])
    AND created_at > '11/01/2019'

  UNION ALL

  SELECT created_at, feature_name, value
  FROM main_ratingsnippetmodel
  WHERE feature_name  IN (SELECT attr_name FROM [mldt_models_roadmap_csv])
    AND created_at > '11/01/2019'
),

/* Count all ratings by model */

q4_ratings_count AS(
  SELECT feature_name, COUNT(value)
  FROM t1 GROUP BY feature_name
),

/* Group and count all ratings by bins 1-5 */

bin_1_count AS (
  SELECT feature_name, COUNT(value)
  FROM t1 WHERE value = 1 GROUP BY feature_name
),

bin_2_count AS (
  SELECT feature_name, COUNT(value)
  FROM t1 WHERE value = 2 GROUP BY feature_name
),

bin_3_count AS (
  SELECT feature_name, COUNT(value)
  FROM t1 WHERE value = 3 GROUP BY feature_name
),

bin_4_count AS (
  SELECT feature_name, COUNT(value)
  FROM t1 WHERE value = 4 GROUP BY feature_name
),

bin_5_count AS (
  SELECT feature_name, COUNT(value)
  FROM t1 WHERE value = 5 GROUP BY feature_name
),

/* Compile rating stats + links and combine on test_set_type */

t2 AS (
  SELECT attr_name, models.test_set_type, bin_1, bin_2, bin_3, bin_4, bin_5, concat('https://app.sourceress.com/rating/attribute_overview/',attr_name,'/') as attr_link, rubric_link, target_dist_queue_link, model_diff_queue_link, rating_status, rating_priority
  FROM [mldt_models_roadmap_csv AS models], [mldt_test_sets_csv AS tests]
  WHERE models.test_set_type = tests.test_set_type
),

/* Compile individual model stats, pulling most current data */

t3 AS (
  SELECT x.spearman_coefficient, x.num_ratings_seen, x.ontology_name, date_trunc('second', x.deploy_date) as trained_date
  FROM main_modelrecipesmodel x
  INNER JOIN (
    SELECT ontology_name, max(deploy_date) latest_date
    FROM main_modelrecipesmodel
    GROUP BY ontology_name) y
  ON x.ontology_name = y.ontology_name and x.deploy_date = y.latest_date
)

/* Select all fields to display and create cases for prioritization */

SELECT '[' || t2.attr_name || '](' || t2.attr_link || ')' AS attr_name_with_link, INITCAP(t2.rating_status) AS rating_status, '[Rubric](' || t2.rubric_link || ')' AS rubric_link, '[Target Dist Queue](' || t2.target_dist_queue_link || ')' AS target_dist_queues, '[Model Diff Queue](' || t2.model_diff_queue_link || ')' AS model_diff_queues, COALESCE(t3.spearman_coefficient, 0) AS spearman, t3.num_ratings_seen AS ratings_seen_by_model, q4_ratings_count.count AS q4_ratings_count,
CASE
  WHEN t3.spearman_coefficient > 0.9 AND t3.num_ratings_seen > 3000 THEN 'Ready!'
  ELSE 'Add ratings'
END AS spearman_status,
t2.test_set_type,
CASE
  WHEN coalesce(bin_1_count.COUNT, 0) < t2.bin_1 THEN t2.bin_1 - coalesce(bin_1_count.COUNT, 0)
  ELSE 0
END AS bin_1_needed,
CASE
  WHEN coalesce(bin_2_count.COUNT, 0) < t2.bin_2 THEN t2.bin_2 - coalesce(bin_2_count.COUNT, 0)
  ELSE 0
END AS bin_2_needed,
CASE
  WHEN coalesce(bin_3_count.COUNT, 0) < t2.bin_3 THEN t2.bin_3 - coalesce(bin_3_count.COUNT, 0)
  ELSE 0
END AS bin_3_needed,
CASE
  WHEN coalesce(bin_4_count.COUNT, 0) < t2.bin_4 THEN t2.bin_4 - coalesce(bin_4_count.COUNT, 0)
  ELSE 0
END AS bin_4_needed,
CASE
  WHEN coalesce(bin_5_count.COUNT, 0) < t2.bin_5 THEN t2.bin_5 - coalesce(bin_5_count.COUNT, 0)
  ELSE 0
END AS bin_5_needed,
CASE
  WHEN bin_1_count.COUNT >= t2.bin_1 AND bin_2_count.COUNT >= t2.bin_2 AND
  bin_3_count.COUNT >= t2.bin_3 AND bin_4_count.COUNT >= t2.bin_4 AND bin_5_count.COUNT >= t2.bin_5
  THEN 'Ready!'
  ELSE 'Add ratings'
END AS test_status,
t2.rating_priority

FROM t2

LEFT JOIN t3 ON t2.attr_name = t3.ontology_name
LEFT JOIN q4_ratings_count ON t2.attr_name = q4_ratings_count.feature_name
LEFT JOIN bin_1_count ON t2.attr_name = bin_1_count.feature_name
LEFT JOIN bin_2_count ON t2.attr_name = bin_2_count.feature_name
LEFT JOIN bin_3_count ON t2.attr_name = bin_3_count.feature_name
LEFT JOIN bin_4_count ON t2.attr_name = bin_4_count.feature_name
LEFT JOIN bin_5_count ON t2.attr_name = bin_5_count.feature_name

GROUP BY t2.attr_name, t2.attr_link, t2.rubric_link, t2.target_dist_queue_link, t2.model_diff_queue_link, t2.rating_status, t3.spearman_coefficient, t3.num_ratings_seen, q4_ratings_count.count, t2.test_set_type, bin_1_count.count, bin_2_count.count, bin_3_count.count, bin_4_count.count, bin_5_count.count, t2.bin_1, t2.bin_2, t2.bin_3, t2.bin_4, t2.bin_5, t2.rating_priority

ORDER BY
  /*CASE
    WHEN t2.rating_status = 'active' THEN 1
    WHEN t2.rating_status = 'paused' THEN 2
    WHEN t2.rating_status = 'inactive' THEN 3
  END,
  coalesce(t3.spearman_coefficient, 0) DESC,
  q4_ratings_count DESC*/
  rating_priority ASC
