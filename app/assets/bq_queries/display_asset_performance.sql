{% if incremental == "true" %}
CREATE OR REPLACE TABLE `{target_dataset}.display_asset_performance_{date_iso}`
{% else %}
CREATE OR REPLACE TABLE `{target_dataset}.display_asset_performance`
{% endif %}
AS (
       select
       DIS.date AS date,
       DIS.account_id AS account_id,
       DIS.account_name AS account_name,
       DIS.currency AS currency,
       O.ocid AS ocid,
       DIS.campaign_id AS campaign_id,
       DIS.campaign_name AS campaign_name,
       DIS.ad_group_id AS ad_group_id,
       DIS.ad_group_name AS ad_group_name,
       DIS.ad_id AS ad_id,
       DIS.ad_name AS ad_name,
       DIS.clicks AS clicks,
       DIS.impressions AS impressions,
       ROUND(IEEE_DIVIDE(CAST(DIS.cost AS FLOAT64), 1000000.0), 3) AS cost,
       DIS.video_trueview_views AS video_trueview_views,
       DIS.p25_views_rate * DIS.impressions AS p25_views,
       DIS.p50_views_rate * DIS.impressions AS p50_views,
       DIS.p75_views_rate * DIS.impressions AS p75_views,
       DIS.p100_views_rate * DIS.impressions AS p100_views
       from `{bq_dataset}.display_campaign_performance` DIS
       left join `{bq_dataset}.ocid_mapping` AS O
       on DIS.account_id = O.account_id
);