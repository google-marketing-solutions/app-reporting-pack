#!/bin/bash
# Copyright 2026 Google LLC
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
set -o pipefail
cd "$(dirname "$0")"

# CONFIG_DIR is the mount path of the GCS config bucket (set as a job env var).
# Files live at gs://PROJECT/arp -> /config/arp because the whole bucket mounts at /config.
CONFIG_DIR="${CONFIG_DIR:-/config}"
APP_CONFIG_FILE="$(git config -f ./settings.ini config.config-file)"

# 1) run the workload; stdout/stderr flow straight to Cloud Logging.
./app/run-local.sh --quiet \
  --config "${CONFIG_DIR}/${APP_CONFIG_FILE}" \
  --google-ads-config "${CONFIG_DIR}/google-ads.yaml" \
  --legacy
exitcode=$?

# 2) on success, publish dashboard.json consumed by the public index.html.
if [[ $exitcode -eq 0 && -n "$GCS_BASE_PATH_PUBLIC" && -n "$CREATE_DASHBOARD_URL" ]]; then
  echo "{\"dashboardUrl\":\"${CREATE_DASHBOARD_URL}\"}" > /tmp/dashboard.json
  gcloud storage cp --content-type="application/json" --cache-control="no-store" \
    /tmp/dashboard.json "${GCS_BASE_PATH_PUBLIC}/dashboard.json"
fi

# non-zero -> Cloud Run marks the execution FAILED (real, alertable signal).
exit $exitcode
