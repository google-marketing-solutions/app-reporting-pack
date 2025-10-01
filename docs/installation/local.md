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

## Installation

In order to run App Reporting Pack locally please follow the steps outlined below:

1. clone this repository
  ```bash
  git clone https://github.com/google-marketing-solutions/app-reporting-pack
  cd app-reporting-pack
  ```
1. (Recommended) configure virtual environment if you starting testing the solution:
  ```bash
  python -m venv app-reporting-pack
  source app-reporting-pack/bin/activate
  ```
1. install dependencies:
  `pip install -r --require-hashes app/requirements.txt`

1. Run `run-local.sh` script in a terminal to generate all necessary tables for App Reporting Pack:

  ```bash
  ./app/run-local.sh
  ```

It will guide you through a series of questions to get all necessary parameters to run the scripts:

- `account_id` - id of Google Ads MCC account (no dashes, 111111111 format)
- `BigQuery project_id` - id of BigQuery project where script will store the data (i.e. `my_project`)
- `BigQuery dataset` - id of BigQuery dataset where script will store the data (i.e. `my_dataset`)
- `Reporting window` - Number of days (i.e. `90`) for performance data fetching.
- `end date` - last date from which you want to get performance data (i.e., `2022-12-31`). Relative dates are supported [see more](https://github.com/google/ads-api-report-fetcher#dynamic-dates).
- `Ads config` - path to `google-ads.yaml` file.
After the initial run of `run-local.sh` command it will generate `app_reporting_pack.yaml` config file with all necessary information to be used for future runs.
When you run `./run-local.sh` next time it will automatically pick up the created configuration.

## Schedule running `run-local.sh` as a cronjob

When running `run-local.sh` scripts you can specify two options which are useful when running queries periodically (i.e. as a cron job):

- `-c <config>`- path to `app_reporting_pack.yaml` config file. Comes handy when you have multiple config files or the configuration is located outside of current folder.
- `-q` - skips all confirmation prompts and starts running scripts based on config file.

> `run-local.sh` support `--legacy` command line flag which is used to generate dashboard in the format compatible with existing dashboard.
> If you're migrating existing datasources `--legacy` option might be extremely handy.

If you installed all requirements in a virtual environment you can use the trick below to run the proper cronjob:

```bash
* 1 * * * /usr/bin/env bash -c "source /path/to/your/venv/bin/activate \
  && bash /path/to/app-reporting-pack/app/run-local.sh \
  -c /path/to/app_reporting_pack.yaml -g /path/to/google-ads.yaml -q"
```

This command will execute App Reporting Pack queries every day at 1 AM.

