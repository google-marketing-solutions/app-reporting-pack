SELECT segments.date AS date,
       segments.conversion_action AS conversion_action,
       segments.conversion_action_name AS conversion_action_name,
       segments.conversion_lag_bucket AS conversion_lag_bucket,
       customer.id AS account_id,
       customer.descriptive_name AS account_name,
       customer.currency_code AS currency,
       campaign.id AS campaign_id,
       campaign.name AS campaign_name,
       ad_group.id AS ag_group_id,
       ad_group.name AS ad_group_name,
       metrics.conversions AS conversions,
       metrics.conversions_value AS conversions_value
FROM ad_group
WHERE segments.date >= "{start_date}"
  AND segments.date <= "{end_date}"