# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Get video information on each youtube video
SELECT
  segments.date as date,
  campaign.id as campaign_id,
  campaign.advertising_channel_type as campaign_type,
  ad_group.id as ad_group_id,
  ad_group_ad.ad.id as ad_id,
  video.id AS video_id,
  video.title AS video_title,
  metrics.clicks AS clicks,
  metrics.impressions AS impressions,
  metrics.cost_micros AS cost,
  metrics.conversions AS conversions,
  metrics.view_through_conversions AS view_through_conversions,
  metrics.conversions_value AS conversions_value,
  metrics.video_trueview_views AS video_trueview_views,
  metrics.video_quartile_p100_rate AS p100_views_rate,
  metrics.video_quartile_p25_rate AS p25_views_rate,
  metrics.video_quartile_p50_rate AS p50_views_rate,
  metrics.video_quartile_p75_rate AS p75_views_rate
FROM video
WHERE
    campaign.advertising_channel_type in ("VIDEO", "DISPLAY")
    AND segments.date >= "{start_date}"
    AND segments.date <= "{end_date}"
