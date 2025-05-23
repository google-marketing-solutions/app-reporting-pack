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
  video.id AS video_id,
  metrics.video_views AS video_views,
  metrics.video_quartile_p100_rate AS p100_view,
  metrics.video_quartile_p25_rate AS p25_view,
  metrics.video_quartile_p50_rate AS p50_view,
  metrics.video_quartile_p75_rate AS p75_view
FROM video
