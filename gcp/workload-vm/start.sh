#!/bin/bash

APP_CONFIG_FILE=$(git config -f "./settings.ini" config.config-file)
ADS_CONFIG=google-ads.yaml

# Ads API client reads only local key files, not gs:// paths; fetch the key named in json_key_file_path from GCS.
SA_KEY_LINE=$(grep -E '^[[:space:]]*json_key_file_path:' "$ADS_CONFIG" | head -1)
SA_KEY_PATH=${SA_KEY_LINE#*:}
SA_KEY_PATH=${SA_KEY_PATH//[\"\' ]/}
if [[ -n "$SA_KEY_PATH" ]]; then
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
  SA_KEY_FOLDER=$(git config -f "./settings.ini" google-ads.credentials-gcs-folder 2>/dev/null || echo credentials)
  SA_KEY_GCS="gs://${PROJECT_ID}/${SA_KEY_FOLDER}/$(basename "$SA_KEY_PATH")"
  gcloud storage cp "$SA_KEY_GCS" "$SA_KEY_PATH" || {
    echo "Failed to download Ads service account key from $SA_KEY_GCS" >&2
    exit 1
  }
fi

# TODO: --backfill?
chmod +x ./run-local.sh
./run-local.sh --quiet --config $APP_CONFIG_FILE --google-ads-config google-ads.yaml --legacy