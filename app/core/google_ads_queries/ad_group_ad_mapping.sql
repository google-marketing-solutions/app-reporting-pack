SELECT customer.id AS account_id,
       customer.descriptive_name AS account_name,
       customer.currency_code AS currency,
       campaign.id AS campaign_id,
       campaign.name AS campaign_name,
       ad_group.id AS ad_group_id,
       ad_group.name AS ad_group_name,
       ad_group_ad.ad.id AS ad_id,
       ad_group_ad.ad.name AS ad_name
FROM ad_group_ad
WHERE
    campaign.advertising_channel_type = "VIDEO"