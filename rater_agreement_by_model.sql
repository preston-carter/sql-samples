SELECT feature_name,
       DATE(updated_at),
       unbalanced_num_ratings AS number_of_ratings,
       unbalanced_correlation AS correlation,
       unbalanced_mean_squared_error AS MSE,
'https://app.sourceress.com/custom_rating_queue/queues/verify_previous_single_attribute_ratings/VerifyPreviousSingleAttributeRatingsQueueView/' || feature_name ||'/__/' AS even_queue_verification_link

FROM main_ratercorrelationmodel

/* Ignore new, pessimistic, and optimistic models */
WHERE unbalanced_num_ratings >= 20 AND feature_name NOT LIKE '%pessimistic' AND feature_name NOT LIKE '%optimistic'

ORDER BY unbalanced_mean_squared_error DESC
