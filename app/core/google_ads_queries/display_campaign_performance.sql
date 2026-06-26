SELECT segments.date AS date,
    segments.ad_network_type AS network,
    customer.id AS account_id,
    customer.descriptive_name AS account_name,
    customer.currency_code AS currency,
    campaign.id AS campaign_id,
    campaign.name AS campaign_name,
    ad_group.id AS ad_group_id,
    ad_group.name AS ad_group_name,
    ad_group_ad.ad.id AS ad_id,
    ad_group_ad.ad.name AS ad_name,
    metrics.clicks AS clicks,
    metrics.cost_micros AS cost,
    metrics.impressions AS impressions,
    metrics.video_trueview_views AS video_trueview_views,
    metrics.video_quartile_p25_rate AS p25_views_rate,
    metrics.video_quartile_p50_rate AS p50_views_rate,
    metrics.video_quartile_p75_rate AS p75_views_rate,
    metrics.video_quartile_p100_rate AS p100_views_rate
FROM ad_group_ad
WHERE campaign.advertising_channel_type = 'DISPLAY'
  AND segments.date >= "{start_date}"
  AND segments.date <= "{end_date}"