## Prerequisites

- Google Ads API access and [google-ads.yaml](https://github.com/google/ads-api-report-fetcher/blob/main/docs/how-to-authenticate-ads-api.md#setting-up-using-google-adsyaml) file - follow documentation on [API authentication](https://github.com/google/ads-api-report-fetcher/blob/main/docs/how-to-authenticate-ads-api.md).
- Python 3.9+
- [Service account](https://cloud.google.com/iam/docs/creating-managing-service-accounts#creating) created and [service account key](https://cloud.google.com/iam/docs/creating-managing-service-account-keys#creating) downloaded in order to write data to BigQuery.

  - Once you downloaded service account key export it as an environmental variable

    ```
    export GOOGLE_APPLICATION_CREDENTIALS=path/to/service_account.json
    ```

  - If authenticating via service account is not possible you can authenticate with the following command:
    ```
    gcloud auth application-default login
    ```
## Running in Docker

You can run App Reporting Pack queries inside a Docker container.

```bash
docker run \
    -v /path/to/google-ads.yaml:/google-ads.yaml \
    -v /path/to/service_account.json:/app/service_account.json \
    -v /path/to/app_reporting_pack.yaml:/app_reporting_pack.yaml \
    ghcr.io/google-marketing-solutions/app-reporting-pack \
    -g google-ads.yaml -c app_reporting_pack.yaml --legacy --backfill
```

!!!important
    Don't forget to change /path/to/google-ads.yaml and /path/to/service_account.json with valid paths.

You can provide configs as remote (for example Google Cloud Storage).
In that case you don't need to mount `google-ads.yaml` and `app_reporting_pack.yaml`
configs into the container:

```bash
docker run \
    -v /path/to/service_account.json:/app/service_account.json \
    ghcr.io/google-marketing-solutions/app-reporting-pack \
    -g gs://project_name/google-ads.yaml \
    -c gs://project_name/app_reporting_pack.yaml \
    --legacy --backfill
```

