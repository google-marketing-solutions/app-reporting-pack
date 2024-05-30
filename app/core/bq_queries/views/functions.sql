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


-- Get number of elements in first non-emtpy array.
CREATE OR REPLACE FUNCTION `{bq_dataset}.GetNumberOfElements` (first_element STRING, second_element STRING, third_element STRING)
RETURNS INT64
AS (
    ARRAY_LENGTH(SPLIT(
        IFNULL(
            IFNULL(first_element, second_element),
            third_element), "|")
        ) - 1
    );

-- Convert millis to human-readable values
CREATE OR REPLACE FUNCTION `{bq_dataset}.NormalizeMillis` (value INT64)
RETURNS FLOAT64
AS (ROUND(value / 1e6, 2)
);

-- Convert  network enums
CREATE OR REPLACE FUNCTION `{bq_dataset}.ConvertAdNetwork` (name STRING)
RETURNS STRING
AS (
    CASE
        WHEN name = "CONTENT" THEN "Display"
        WHEN name = "SEARCH" THEN "Search"
        WHEN name = "SEARCH_PARTNERS" THEN "Search Partners"
        WHEN name = "YOUTUBE_SEARCH" THEN "YouTube Search"
        WHEN name = "YOUTUBE_WATCH" THEN "YouTube Videos"
        WHEN name = "YOUTUBE" THEN "YouTube"
        WHEN name = "GOOGLE_TV" THEN "Google TV"
        ELSE name END
);

-- Convert asset field types
CREATE OR REPLACE FUNCTION `{bq_dataset}.ConvertAssetFieldType` (name STRING)
RETURNS STRING
AS (
    CASE
        WHEN name = "DESCRIPTION" THEN "Description"
        WHEN name = "HEADLINE" THEN "Headline"
        WHEN name = "MARKETING_IMAGE" THEN "Image"
        WHEN name = "MEDIA_BUNDLE" THEN "Html5"
        WHEN name = "YOUTUBE_VIDEO" THEN "Video"
        ELSE "Unknown" END
);

-- Put text length into bins
CREATE OR REPLACE FUNCTION `{bq_dataset}.BinText` (type STRING, text_length INT64)
RETURNS STRING
AS (
    CASE
        WHEN type = "HEADLINE" AND text_length < 20 THEN "0-20 symbols"
        WHEN type = "HEADLINE" AND text_length >= 20 THEN "20+ symbols"
        WHEN type = "DESCRIPTION" AND text_length < 30 THEN "0-30 symbols"
        WHEN type = "DESCRIPTION" AND text_length < 60 THEN "31-60 symbols"
        WHEN type = "DESCRIPTION" AND text_length >= 60 THEN "60+ symbols"
        ELSE "Unknown (Text)" END
);

-- Put images and HTML5 into bins
CREATE OR REPLACE FUNCTION `{bq_dataset}.BinBanners` (width INT64, height INT64)
RETURNS STRING
AS (
    CASE
        WHEN ROUND(SAFE_DIVIDE(width, height), 2) = 1.0 THEN "1:1 (Square)"
        WHEN ROUND(SAFE_DIVIDE(width, height), 2) = 1.91 THEN "1.91:1 (Landscsape)"
        WHEN ROUND(SAFE_DIVIDE(width, height), 2) = 0.8 THEN "4:5 (Portrait)"
        ELSE "Unknown (Image)" END
);


CREATE OR REPLACE FUNCTION `{bq_dataset}.equalsArr` (x ARRAY<STRING>, y ARRAY<STRING>)
RETURNS INT64
LANGUAGE js AS r"""
var count = (x.length >= y.length ? x : y).reduce((count, element) => count + (!x.includes(element) ? 1 : 0), 0);
return count;
""";
