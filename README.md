# App Reporting Pack

**A centralized platform and dashboard for Google Ads App campaign data.**

## Table of Contents

1. [Introduction](#introduction)
1. [Deliverables](#deliverables)
1. [Prerequisites](#prerequisites)
1. [Installation](#installation)
   - [Primary Installation Method](#primary-installation-method)
   - [Manual installation in Google Cloud](#manual-installation-in-google-cloud)
   - [Alternative Installation Methods](#alternative-installation-methods)
     - [Prerequisites for alternative installation methods](#prerequisites-1)
     - [Running Queries Locally](#running-queries-locally)
     - [Running in a Docker Container](#running-in-a-docker-container)
     - [Running in Compute Engine with Docker](#running-in-compute-engine-with-docker)
1. [Dashboard Replication](#dashboard-replication)
1. [Disclaimer](#disclaimer)

## Introduction

Crucial information on App campaigns is scattered across various places in Google Ads UI which makes it harder to get insights into how campaign and assets perform.
App Reporting Pack fetches all necessary data from Ads API and creates a centralized [dashboard](https://lookerstudio.google.com/c/u/0/reporting/3f042b13-f767-4195-b092-35b94e0b430c/page/0hcO) showing different aspects of App campaign's performance and settings. All data is stored in BigQuery tables that can be used for any other need the client might have.

## Deliverables

1. A centralized [dashboard](https://lookerstudio.google.com/c/u/0/reporting/3f042b13-f767-4195-b092-35b94e0b430c/page/0hcO) with deep app campaign and assets performance views
2. The following data tables in BigQuery that can be used independently:

- `asset_performance`
- `creative_excellence`
- `approval_statuses`
- `change_history`
- `performance_grouping_history`
- `ad_group_network_split`
- `geo_performance`
- `cannibalization`

## Prerequisites

1. [A Google Ads Developer token](https://developers.google.com/google-ads/api/docs/first-call/dev-token#:~:text=A%20developer%20token%20from%20Google,SETTINGS%20%3E%20SETUP%20%3E%20API%20Center.)

1. A GCP project with billing account attached

1. Membership in `app-reporting-pack-readers-external` Google group (join [here](https://groups.google.com/g/app-reporting-pack-readers-external)) to get access to the [dashboard template](https://lookerstudio.google.com/c/u/0/reporting/3f042b13-f767-4195-b092-35b94e0b430c/page/0hcO).

1. Credentials for Google Ads API access - `google-ads.yaml`.
   See details here - https://github.com/google/ads-api-report-fetcher/blob/main/docs/how-to-authenticate-ads-api.md
   Normally you need OAuth2 credentials (Client ID, Client Secret), a Google Ads developer token and a refresh token.

## Installation

There are several ways to run the application. A recommended way is to run it
in the Google Cloud but it's not a requirement. You can run ARP locally or
in your own infrastructure. In either way you need two things:

- Google Ads API credentials (in `google-ads.yaml` or separately)
- ARP configuration (in `app_reporting_pack.yaml`) - it can be generated via running `run-local.sh`.

### Primary Installation Method

The primary installation method deploys ARP into Google Cloud by using Cloud Run Button.
The procedure automates generating ARP configuration and deploying all required components to the Cloud.

This approach is the simplest one because it clones the repo and starts install scripts for you. But sometimes you might need some customization.
The majority infrastructure settings can be changed in `gcp/settings.ini` file (regions, service names, etc).
If it's a case for you please use the [Manual installation in Google Cloud](#manual-installation-in-google-cloud) below.

To install the solution, follow these steps:

1. Click "Run on Google Cloud":
   [![Run on Google Cloud](https://deploy.cloud.run/button.svg)](https://deploy.cloud.run?dir=gcp/cloud-run-button)

1. Select your GCP project and choose any region.

1. When prompted, upload your google-ads.yaml (alternately you can paste in your client ID, client secret, refresh token, developer token and MCC ID later).

1. The install script will generate ARP configuration by asking some interactive questions and then deploy all cloud components in the current project

1. At the end you will be given a link to a webpage on Cloud Storage where you can track the progress.

1. This webpage will inform you once the BigQuery datasets have been populated and you can create a dashboard.
   When the button is enabled, click "Open Dashboard" to clone the dashboard template.
   Click the "Save" button on the top right to save your new dashboard.

1. Change your dashboard's name and save it's URL or bookmark it.

It's important to note that a Cloud Run service that is being built and deployed during installation isn't actually needed (it'll be removed at the end).
All ARP installation happens in a pre-build script.

### Manual installation in Google Cloud

1. First you need to clone the repo in Cloud Shell or on your local machine (we assume Linux with gcloud CLI installed):

```
git clone https://github.com/google/app-reporting-pack
```

1. Go to the repo folder: `cd app-reporting-pack/`

1. Optionally put your `google-ads.yaml` there or be ready to provide all Ads API credentials

1. Optionally adjust settings in `gcp/settings.ini`

1. Run installation:

```
./gcp/install.sh
```

Or if you already have ARP configuration (`app_reporting_pack.yaml`) then you can directly deploy all components via running:

```
./gcp/setup.sh deploy_public_index deploy_all start
```

It runs threee tasks ('deploy_public_index', 'deploy_all' and 'start') described below.

> TIP: when you install via clicking Cloud Run Button basically you run the same `install.sh` but in an automatically created Shell.

The setup script with 'deploy_all' task does the followings:

- enable APIs
- grant required IAM permissions
- create a Docker repository in Artifact Repository
- build a Docker image (using `gcp/workload-vm/Dockerfile` file)
- publish the image into the repository
- deploy Cloud Function `create-vm` (from gcp/cloud-functions/create-vm/) (using environment variables in env.yaml file)
- deploy files to GCS (queries, scripts and config `app_reporting_pack.yaml` and `google-ads.yaml`) (to a bucket with a name of current GCP project id and 'arp' subfolder)
- create a Scheduler job for calling the `create-vm` Cloud Function

The setup script with 'deploy_public_index' task uploads the `index.html` webpage on a GCS public bucket,
the page that you can use to track installation progress, and create a dashboard at the end.

The task 'start' for `setup.sh` does the last part - publishes a PubSub message which essentially includes the following:

- the Cloud Function 'create-vm' gets a message with arguments and create a virtual machine based on a Docker container from the Docker image built during the installation
- the VM on startup parses the arguments from the CF (via VM's attributes) and executes ARP code in quite the same way as it executes locally (using `run-local.sh`).
  Additionally the VM's entrypoint script deletes the virtual machine upon completion of the `run-local.sh`.

#### No public IP

By default virtual machines created by the Cloud Function have no public IP address associated. It's done to work around possible issues with policies in GCP projects forbid assigning public IPs for VMs.

It's managed by the `no-public-ip` option in the `settings.ini` in `[compute]` section. By default it's `true` so VMs created without public IPs. As they still need to get access to the Artifact Repository for downloading the Docker image, the option 'Private Google Access' is enabled for the default subnetwork. It's done by `setup.sh`. But VMs created by the CF get into another subnetwork in your environment them you have to enable the option manually.

To enable the option follow these steps:

- open GCE virtual machines
- choose a ARP VM, it will have name like arp-vm-xxxxxxxxxxxxx
- click on its network interface (next to its internal IP - usually "nic0")
- in the first list "Network interface details" click on "default" subnetwork for the interface
- click Edit and enable 'Private Google Access' option, save

### Troubleshooting

The most important thing to understand - you should use Cloud Logging to diagnose and track execution progress of ARP VMs. In the end of execution VMs are deleted. If you see an existing VM left from execution it's a signal of something wrong happened.

#### Docker image failed to build

If you're getting an error at the creating Docker repository step:

```
ERROR: (gcloud.artifacts.repositories.create) INVALID_ARGUMENT: Maven config is not supported for format "DOCKER"
- '@type': type.googleapis.com/google.rpc.DebugInfo
  detail: '[ORIGINAL ERROR] generic::invalid_argument: Maven config is not supported
    for format "DOCKER" [google.rpc.error_details_ext] { code: 3 message: "Maven config
    is not supported for format \"DOCKER\"" }'
```

Please update your Cloud SDK CLI by running `gcloud components update`

#### No Google Cloud Storage public access

If your GCP project has a policy to prevent public access to GCS then during installation `setup.sh` won't be able to deploy a webpage (index.html) for waiting for the completion from which you could clone the dashboard. In that case you will have to replicate the dashboard manually - see [Dashboard Replication](#dashboard-replication).

#### VM ran but did nothing and was not deleted

Normally the Cloud Function `create-vm` creates a VM which runs ARP as Docker container. Though for this to work the VM should download an ARP image from Artifact Repository. If your GCP project forbids for GCE VMs to have public IPs then by default they don't have access to any Google Cloud services. To work around this issue you need to enable 'Private Google Access' option for the default subnetwork. It should be enabled automatically by default but worth checking - go to your VM's settings and check whcih subnetwork it got into and then check the setting 'Private Google Access' is enabled for that subnetwork.

Please see [No public IP](#no-public-ip) for details.

You can safely delete all ARP virtual machines and rerun Scheduler job manually. On a next run a VM should properly start with Google network access and downlaod ARP image. In the end the VM will be removed.

### Alternative Installation Methods

#### Prerequisites

- Google Ads API access and [google-ads.yaml](https://github.com/google/ads-api-report-fetcher/blob/main/docs/how-to-authenticate-ads-api.md#setting-up-using-google-adsyaml) file - follow documentation on [API authentication](https://github.com/google/ads-api-report-fetcher/blob/main/docs/how-to-authenticate-ads-api.md).
- Python 3.8+
- [Service account](https://cloud.google.com/iam/docs/creating-managing-service-accounts#creating) created and [service account key](https://cloud.google.com/iam/docs/creating-managing-service-account-keys#creating) downloaded in order to write data to BigQuery.

  - Once you downloaded service account key export it as an environmental variable

    ```
    export GOOGLE_APPLICATION_CREDENTIALS=path/to/service_account.json
    ```

  - If authenticating via service account is not possible you can authenticate with the following command:
    ```
    gcloud auth application-default login
    ```

#### Running queries locally

In order to run App Reporting Pack locally please follow the steps outlined below:

- clone this repository
  ```
  git clone https://github.com/google/app-reporting-pack
  cd app-reporting-pack
  ```
- (Recommended) configure virtual environment if you starting testing the solution:
  ```
  sudo apt-get install python3-venv
  python3 -m venv app-reporting-pack
  source app-reporting-pack/bin/activate
  ```
- Make sure that that pip is updated to the latest version:
  ```
  pip install --upgrade pip
  ```
- install dependencies:
  `pip install -r app/requirements.in`
  Please run `run-local.sh` script in a terminal to generate all necessary tables for App Reporting Pack:

  ```shell
  bash ./app/run-local.sh
  ```

It will guide you through a series of questions to get all necessary parameters to run the scripts:

- `account_id` - id of Google Ads MCC account (no dashes, 111111111 format)
- `BigQuery project_id` - id of BigQuery project where script will store the data (i.e. `my_project`)
- `BigQuery dataset` - id of BigQuery dataset where script will store the data (i.e. `my_dataset`)
- `Reporting window` - Number of days (i.e. `90`) for performance data fetching.
- `end date` - last date from which you want to get performance data (i.e., `2022-12-31`). Relative dates are supported [see more](https://github.com/google/ads-api-report-fetcher#dynamic-dates).
- `Ads config` - path to `google-ads.yaml` file.
- `Parse video dimensions` - how to get video orientation for video assets - from YouTube (`youtube` mode, [learn more about using the YouTube Data API](docs/how-to-get-video-orientation-for-assets.md#get-video-orientation-from-youtube-data-api)), from asset name (`regex` mode) or use placeholders (`placeholders` mode).
After the initial run of `run-local.sh` command it will generate `app_reporting_pack.yaml` config file with all necessary information to be used for future runs.
When you run `bash run-local.sh` next time it will automatically pick up the created configuration.

##### Schedule running `run-local.sh` as a cronjob

When running `run-local.sh` scripts you can specify two options which are useful when running queries periodically (i.e. as a cron job):

- `-c <config>`- path to `app_reporting_pack.yaml` config file. Comes handy when you have multiple config files or the configuration is located outside of current folder.
- `-q` - skips all confirmation prompts and starts running scripts based on config file.

> `run-local.sh` support `--legacy` command line flag which is used to generate dashboard in the format compatible with existing dashboard.
> If you're migrating existing datasources `--legacy` option might be extremely handy.

If you installed all requirements in a virtual environment you can use the trick below to run the proper cronjob:

```
* 1 * * * /usr/bin/env bash -c "source /path/to/your/venv/bin/activate && bash /path/to/app-reporting-pack/app/run-local.sh -c /path/to/app_reporting_pack.yaml -g /path/to/google-ads.yaml -q"
```

This command will execute App Reporting Pack queries every day at 1 AM.

#### Running in a Docker container

You can run App Reporting Pack queries inside a Docker container.

```
sudo docker run \
    -v /path/to/google-ads.yaml:/google-ads.yaml \
    -v /path/to/service_account.json:/app/service_account.json \
    -v /path/to/app_reporting_pack.yaml:/app_reporting_pack.yaml \
    ghcr.io/google/app-reporting-pack \
    -g google-ads.yaml -c app_reporting_pack.yaml --legacy --backfill
```

> Don't forget to change /path/to/google-ads.yaml and /path/to/service_account.json with valid paths.

You can provide configs as remote (for example Google Cloud Storage).
In that case you don't need to mount `google-ads.yaml` and `app_reporting_pack.yaml`
configs into the container:

```
sudo docker run \
    -v /path/to/service_account.json:/app/service_account.json \
    ghcr.io/google/app-reporting-pack \
    -g gs://project_name/google-ads.yaml \
    -c gs://project_name/app_reporting_pack.yaml \
    --legacy --backfill
```

### Dashboard Replication

If you install ARP via Cloud Run Button (see [Primary Installation Method](#primary-installation-method)) then in most cases you don't need the following procedure. Otherwise use the following command to clone the ARP dashboard.

Once queries ran successfully you can proceed with dashboard replication.\
Run the following command in the terminal to get a link for cloning the dashboard:

```
bash ./app/scripts/create_dashboard.sh -c app/app_reporting_pack.yaml -L
```

If you're running on a local machine you can omit `-L` flag and then the link will be opened in the browser.

For more details on dashboard please refer to [how-to-replicate-app-reporting-pack](docs/how-to-replicate-app-reporting-pack.md) document.

> **_IMPORTANT:_** After the dashboard is created you need to enable image previews, read details on how it can be done [here](docs/how-to-replicate-dashboard.md#enable-image-previews).


## Disclaimer

This is not an officially supported Google product.
