{% if incremental == "true" %}
CREATE OR REPLACE TABLE `{target_dataset}.video_campaign_asset_performance_{date_iso}`
{% else %}
CREATE OR REPLACE TABLE `{target_dataset}.video_campaign_asset_performance`
{% endif %}
AS (
      WITH
      MappingTable AS (
      SELECT
        ad_id,
        ANY_VALUE(M.ad_name) AS ad_name,
        ANY_VALUE(ad_group_id) AS ad_group_id,
        ANY_VALUE(M.ad_group_name) AS ad_group_name,
        ANY_VALUE(M.campaign_id) AS campaign_id,
        ANY_VALUE(M.campaign_name) AS campaign_name,
        ANY_VALUE(M.account_id) AS account_id,
        ANY_VALUE(M.account_name) AS account_name,
        ANY_VALUE(O.ocid) AS ocid,
        ANY_VALUE(M.currency) AS currency,
      FROM `{bq_dataset}.ad_group_ad_mapping` AS M
      LEFT JOIN `{bq_dataset}.ocid_mapping` AS O
        USING (account_id)
      GROUP BY 1
    )
       select
       VD.date AS date,
       AD.account_id AS account_id,
       AD.account_name AS account_name,
       AD.currency AS currency,
       AD.ocid AS ocid,
       AD.campaign_id AS campaign_id,
       AD.campaign_name AS campaign_name,
       AD.ad_group_id AS ad_group_id,
       AD.ad_group_name AS ad_group_name,
       AD.ad_id AS ad_id,
       AD.ad_name AS ad_name,
       VD.video_id AS video_id,
       VD.video_title AS video_title,
       VD.clicks AS clicks,
       VD.impressions AS impressions,
       ROUND(IEEE_DIVIDE(CAST(VD.cost AS FLOAT64), 1000000.0), 3) AS cost,
       VD.conversions AS conversions,
       VD.view_through_conversions AS view_through_conversions,
       VD.conversions_value AS conversions_value,
       VD.video_trueview_views AS video_trueview_views,
       VD.p100_views_rate * VD.impressions AS p100_views,
       VD.p25_views_rate * VD.impressions AS p25_views,
       VD.p50_views_rate * VD.impressions AS p50_views,
       VD.p75_views_rate * VD.impressions AS p75_views
       from `{bq_dataset}.video` VD
       left join `MappingTable` AD
       on AD.ad_id = VD.ad_id
);