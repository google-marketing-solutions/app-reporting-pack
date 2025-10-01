## Prerequisites

1. [A Google Ads Developer token](https://developers.google.com/google-ads/api/docs/first-call/dev-token#:~:text=A%20developer%20token%20from%20Google,SETTINGS%20%3E%20SETUP%20%3E%20API%20Center.)

1. A GCP project with billing account attached; a person responsible for deployment of App Reporting Pack should have **OWNER** or **ADMIN** permissions to the project.

1. Credentials for Google Ads API access - `google-ads.yaml`.
   See details [here](https://github.com/google/ads-api-report-fetcher/blob/main/docs/how-to-authenticate-ads-api.md)

## Installation

1. Clone repo in Cloud Shell or on your local machine (we assume Linux with `gcloud` CLI installed):
```bash
git clone https://github.com/google-marketing-solutions/app-reporting-pack
```

1. Go to the repo folder: `cd app-reporting-pack/`

1. Optionally put your `google-ads.yaml` there or be ready to provide all Ads API credentials

1. Optionally adjust settings in `gcp/settings.ini`

1. Run installation:

```
./gcp/install.sh
```

## Updating

To update the existing version of App Reporting Pack

1. Clone repo in Cloud Shell or on your local machine (we assume Linux with `gcloud` CLI installed):
```bash
git clone https://github.com/google-marketing-solutions/app-reporting-pack
```
!!!note

    If you already have `app-reporting-pack` repository clone, run the following

    ```bash
    git stash
    git pull
    ```

1. Go to the repo folder: `cd app-reporting-pack/`

1. Run installation:

```
./gcp/upgrade.sh
```

## Troubleshooting

The most important thing to understand - you should use Cloud Logging to diagnose and track execution progress of ARP VMs. In the end of execution VMs are deleted. If you see an existing VM left from execution it's a signal of something wrong happened.

### No public IP

By default virtual machines created by the Cloud Function have no public IP address associated. It's done to work around possible issues with policies in GCP projects forbid assigning public IPs for VMs.

It's managed by the `no-public-ip` option in the `settings.ini` in `[compute]` section. By default it's `true` so VMs created without public IPs. As they still need to get access to the Artifact Repository for downloading the Docker image, the option 'Private Google Access' is enabled for the default subnetwork. It's done by `setup.sh`. But VMs created by the CF get into another subnetwork in your environment them you have to enable the option manually.

To enable the option follow these steps:

- open GCE virtual machines
- choose a ARP VM, it will have name like arp-vm-xxxxxxxxxxxxx
- click on its network interface (next to its internal IP - usually "nic0")
- in the first list "Network interface details" click on "default" subnetwork for the interface
- click Edit and enable 'Private Google Access' option, save

### Docker image failed to build

If you're getting an error at the creating Docker repository step:

```
ERROR: (gcloud.artifacts.repositories.create) INVALID_ARGUMENT: Maven config is not supported for format "DOCKER"
- '@type': type.googleapis.com/google.rpc.DebugInfo
  detail: '[ORIGINAL ERROR] generic::invalid_argument: Maven config is not supported
    for format "DOCKER" [google.rpc.error_details_ext] { code: 3 message: "Maven config
    is not supported for format \"DOCKER\"" }'
```

Please update your Cloud SDK CLI by running `gcloud components update`

### No Google Cloud Storage public access

If your GCP project has a policy to prevent public access to GCS then during installation `setup.sh` won't be able to deploy a webpage (index.html) for waiting for the completion from which you could clone the dashboard. In that case you will have to replicate the dashboard manually - see [Dashboard Replication](../dashboard/replication.md).

### VM ran but did nothing and was not deleted

Normally the Cloud Function `create-vm` creates a VM which runs ARP as Docker container. Though for this to work the VM should download an ARP image from Artifact Repository. If your GCP project forbids for GCE VMs to have public IPs then by default they don't have access to any Google Cloud services. To work around this issue you need to enable 'Private Google Access' option for the default subnetwork. It should be enabled automatically by default but worth checking - go to your VM's settings and check whcih subnetwork it got into and then check the setting 'Private Google Access' is enabled for that subnetwork.

Please see [No public IP](#no-public-ip) for details.

You can safely delete all ARP virtual machines and rerun Scheduler job manually. On a next run a VM should properly start with Google network access and download ARP image. In the end the VM will be removed.

