#!/bin/bash

APP_CONFIG_FILE=$(git config -f "./settings.ini" config.config-file)

# Google Ads API client reads only local key files, not gs:// paths, so fetch the key from GCS first.
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
ADS_SA_KEY_GCS="gs://${PROJECT_ID}/credentials/google-ads-sa-komoe.json"
gcloud storage cp "$ADS_SA_KEY_GCS" /app/google-ads-sa-komoe.json || {
  echo "Failed to download Ads service account key from $ADS_SA_KEY_GCS" >&2
  exit 1
}

# TODO: --backfill?
chmod +x ./run-local.sh
./run-local.sh --quiet --config $APP_CONFIG_FILE --google-ads-config google-ads.yaml --legacy