#!/bin/bash
#
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ansi colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SETTING_FILE="./settings.ini"
SCRIPT_PATH=$(readlink -f "$0" | xargs dirname)
SETTING_FILE="${SCRIPT_PATH}/settings.ini"

trap _upload_install_log EXIT

# changing the cwd to the script's containing folder so all pathes inside can be local to it
# (important as the script can be called via absolute path and as a nested path)
pushd $SCRIPT_PATH >/dev/null

while :; do
    case $1 in
  -s|--settings)
      shift
      SETTING_FILE=$1
      ;;
  *)
      break
    esac
  shift
done

NAME=$(git config -f $SETTING_FILE config.name)
PROJECT_ID=$(gcloud config get-value project 2> /dev/null)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="csv(projectNumber)" | tail -n 1)
USER_EMAIL=$(gcloud config get-value account 2> /dev/null)

APP_CONFIG_FILE=$(eval echo $(git config -f $SETTING_FILE config.config-file))
REPOSITORY=$(eval echo $(git config -f $SETTING_FILE repository.name))
IMAGE_NAME=$(eval echo $(git config -f $SETTING_FILE repository.image))
REPOSITORY_LOCATION=$(git config -f $SETTING_FILE repository.location)

# New Cloud Run Job variables (replacing TOPIC)
JOB_NAME=$(eval echo $(git config -f $SETTING_FILE cloud-run.name))
JOB_REGION=$(git config -f $SETTING_FILE cloud-run.region)
JOB_CPU=$(git config -f $SETTING_FILE cloud-run.cpu)
JOB_MEMORY=$(git config -f $SETTING_FILE cloud-run.memory)
JOB_TIMEOUT=$(git config -f $SETTING_FILE cloud-run.task-timeout)
RUN_SA=$(eval echo $(git config -f $SETTING_FILE cloud-run.service-account))
RUN_SA=${RUN_SA:-$SERVICE_ACCOUNT}   # default to the compute SA

SERVICE_ACCOUNT=$PROJECT_NUMBER-compute@developer.gserviceaccount.com
GCS_BASE_PATH=gs://$PROJECT_ID/$NAME

check_billing() {
  BILLING_ENABLED=$(gcloud beta billing projects describe $PROJECT_ID --format="csv(billingEnabled)" | tail -n 1)
  if [[ "$BILLING_ENABLED" = 'False' ]]
  then
    echo -e "${RED}The project $PROJECT_ID does not have a billing enabled. Please activate billing${NC}"
    exit -1
  fi
}

copy_application_scripts() {
  echo "Copying application files to $GCS_BASE_PATH"
  gcloud storage rsync --recursive --exclude ".*/__pycache__/.*|[.].*" ./../app $GCS_BASE_PATH
}

copy_application_config() {
  echo "Copying configs to $GCS_BASE_PATH"
  gcloud storage cp ./../app/$APP_CONFIG_FILE $GCS_BASE_PATH/ --content-type="text/plain"
}

copy_googleads_config() {
  echo 'Copying google-ads.yaml to GCS'
  if [[ -f ./../google-ads.yaml ]]; then
    gcloud storage cp ./../google-ads.yaml $GCS_BASE_PATH/google-ads.yaml --content-type="text/plain"
  elif [[ -f $HOME/google-ads.yaml ]]; then
    gcloud storage cp $HOME/google-ads.yaml $GCS_BASE_PATH/google-ads.yaml --content-type="text/plain"
  else
    echo "Please upload google-ads.yaml"
  fi
}

deploy_files() {
  echo 'Deploying files to GCS'
  if ! gcloud storage ls gs://$PROJECT_ID > /dev/null 2> /dev/null; then
    echo "Creating GCS bucket gs://$PROJECT_ID"
    gcloud storage buckets create --uniform-bucket-level-access gs://$PROJECT_ID
  fi

  echo "Removing existing files at $GCS_BASE_PATH"
  gcloud storage rm --recursive $GCS_BASE_PATH/

  copy_application_scripts
  copy_application_config
  copy_googleads_config
}

enable_apis() {
  echo "Enabling APIs"
  gcloud services enable bigquery.googleapis.com
  gcloud services enable compute.googleapis.com          # still used for the AR/Cloud Build base; safe to keep
  gcloud services enable containerregistry.googleapis.com
  gcloud services enable run.googleapis.com
  gcloud services enable cloudresourcemanager.googleapis.com
  gcloud services enable iamcredentials.googleapis.com
  gcloud services enable cloudbuild.googleapis.com
  gcloud services enable cloudscheduler.googleapis.com
  gcloud services enable googleads.googleapis.com
}

create_registry() {
  REPO_EXISTS=$(gcloud artifacts repositories list --location=$REPOSITORY_LOCATION --filter="REPOSITORY=projects/'$PROJECT_ID'/locations/'$REPOSITORY_LOCATION'/repositories/'"$REPOSITORY"'" --format="value(REPOSITORY)" 2>/dev/null)
  if [[ ! -n $REPO_EXISTS ]]; then
    echo "Creating a repository in Artifact Registry"
    # repo doesn't exist, creating
    gcloud artifacts repositories create ${REPOSITORY} \
        --repository-format=docker \
        --location=$REPOSITORY_LOCATION
    exitcode=$?
    if [ $exitcode -ne 0 ]; then
      echo -e "${RED}[ ! ] Please upgrade Cloud SDK to the latest version: gcloud components update"
    fi
  fi
}

build_docker_image() {
  echo "Building and pushing Docker image to Artifact Registry"
  gcloud builds submit --config=cloudbuild.yaml --substitutions=_REPOSITORY="docker",_IMAGE="$IMAGE_NAME",_REPOSITORY_LOCATION="$REPOSITORY_LOCATION" ./..
}

build_docker_image_gcr() {
  # NOTE: it's an alternative to build_docker_image if you want to use GCR instead of AR
  echo "Building and pushing Docker image to Container Registry"
  gcloud builds submit --config=cloudbuild-gcr.yaml --substitutions=_IMAGE="$IMAGE_NAME" ./..
}

set_iam_permissions() {
  # Reduced roles set (includes BigQuery access, drops legacy VM/Pub-Sub permissions)
  required_roles="bigquery.dataEditor bigquery.jobUser storage.objectAdmin artifactregistry.reader run.invoker iam.serviceAccountUser"
  echo "Setting up IAM permissions"
  for role in $required_roles; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member=serviceAccount:$SERVICE_ACCOUNT \
      --role=roles/$role \
      --condition=None \
      --no-user-output-enabled
  done
}

deploy_job() {
  echo "Deploying Cloud Run Job"
  local IMAGE="$REPOSITORY_LOCATION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME"
  local dashboard_url=$(./../app/scripts/create_dashboard.sh -L --config ./../app/$APP_CONFIG_FILE)

  local sa_flag=""
  if [[ -n "$RUN_SA" ]]; then
    sa_flag="--service-account=$RUN_SA"
  fi

  gcloud run jobs deploy $JOB_NAME \
    --image=$IMAGE \
    --region=$JOB_REGION \
    --cpu=$JOB_CPU --memory=$JOB_MEMORY \
    --task-timeout=$JOB_TIMEOUT --max-retries=1 --tasks=1 \
    $sa_flag \
    --add-volume=name=cfg,type=cloud-storage,bucket=$PROJECT_ID \
    --add-volume-mount=volume=cfg,mount-path=/config \
    --set-env-vars="CONFIG_DIR=/config/$NAME,GOOGLE_CLOUD_PROJECT=$PROJECT_ID,GCS_BASE_PATH_PUBLIC=gs://${PROJECT_ID}-public/$NAME,CREATE_DASHBOARD_URL=$dashboard_url"
}

deploy_public_index() {
  echo 'Deploying index.html to GCS'

  if ! gcloud storage ls gs://$PROJECT_ID-public > /dev/null 2> /dev/null; then
    gcloud storage buckets create --uniform-bucket-level-access gs://$PROJECT_ID-public
  fi

  gcloud storage buckets add-iam-policy-binding gs://${PROJECT_ID}-public --member=allUsers --role=roles/storage.objectViewer 2> /dev/null
  exitcode=$?
  if [ $exitcode -ne 0 ]; then
    echo -e "${RED}[ ! ] Could not add public access to public cloud bucket${NC}"
  else
    GCS_BASE_PATH_PUBLIC=gs://${PROJECT_ID}-public/$NAME
    gcloud storage cp "${SCRIPT_PATH}/index.html" $GCS_BASE_PATH_PUBLIC/index.html --content-type="text/html" --cache-control="no-store"
    if gcloud storage ls $GCS_BASE_PATH_PUBLIC/dashboard.json >/dev/null 2> /dev/null; then
      gcloud storage rm $GCS_BASE_PATH_PUBLIC/dashboard.json
    fi
  fi
}

start() {
  dashboard_url=$(./../app/scripts/create_dashboard.sh -L --config ./../app/$APP_CONFIG_FILE)

  echo 'Executing Cloud Run Job '$JOB_NAME
  # async: don't block install on a large first run; user watches check_logs.sh.
  gcloud run jobs execute $JOB_NAME --region=$JOB_REGION

  # Check if there is a public bucket and index.html and echo the url
  local PUBLIC_URL=$(print_public_gcs_url)/index.html
  local ARP_GOOGLE_GROUP="https://groups.google.com/g/app-reporting-pack-readers-external"
  echo -e "${CYAN}[ * ] Please join Google group to get access to the dashboard - ${GREEN}${ARP_GOOGLE_GROUP}${NC}"
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" $PUBLIC_URL)

  if [[ $STATUS_CODE -eq 200 ]]; then
    echo -e "${CYAN}[ * ] To access your new dashboard, click this link - ${GREEN}${PUBLIC_URL}${NC}"
  else
    echo -e "${CYAN}[ * ] Your GCP project does not allow public access.${NC}"
    if [[ -f ./../app/$APP_CONFIG_FILE ]]; then
      echo -e "${CYAN}[ * ] To create your dashboard, click the following link once the installation process completes and all the relevant tables have been created in the DB:"
      echo -e "${GREEN}$dashboard_url${NC}"
    else
      echo -e "${CYAN}[ * ] To create your dashboard, please run the ${GREEN}./scripts/create_dashboard.sh -c $APP_CONFIG_FILE -L${CYAN} shell script once the installation process completes and all the relevant tables have been created in the DB.${NC}"
    fi
  fi
}

print_public_gcs_url() {
  INDEX_PATH="${PROJECT_ID}-public/$NAME"
  PUBLIC_URL="https://storage.googleapis.com/${INDEX_PATH}"
  echo $PUBLIC_URL
}

schedule_run() {
  local SCHED_NAME=$(eval echo $(git config -f $SETTING_FILE scheduler.name))
  local REGION=$(git config -f $SETTING_FILE scheduler.region)
  local SCHEDULE=$(git config -f $SETTING_FILE scheduler.schedule)
  SCHEDULE=${SCHEDULE:-"0 0 * * *"}
  local SCHEDULE_TZ=$(git config -f $SETTING_FILE scheduler.schedule-timezone)
  SCHEDULE_TZ=${SCHEDULE_TZ:-"Etc/UTC"}

  delete_schedule   # existing existence-checked delete, reused unchanged

  echo 'Scheduling HTTP job to run Cloud Run Job '$JOB_NAME
  gcloud scheduler jobs create http $SCHED_NAME \
    --location=$REGION \
    --schedule="$SCHEDULE" \
    --time-zone=$SCHEDULE_TZ \
    --uri="https://run.googleapis.com/v2/projects/${PROJECT_ID}/locations/${JOB_REGION}/jobs/${JOB_NAME}:run" \
    --http-method=POST \
    --oauth-service-account-email=${RUN_SA}
}

delete_schedule() {
  JOB_NAME=$(eval echo $(git config -f $SETTING_FILE scheduler.name))
  REGION=$(git config -f $SETTING_FILE scheduler.region)

  JOB_EXISTS=$(gcloud scheduler jobs list --location=$REGION --format="value(ID)" --filter="ID=projects/'$PROJECT_ID'/locations/'$REGION'/jobs/'$JOB_NAME'" 2>/dev/null)
  if [[ -n $JOB_EXISTS ]]; then
    echo 'Deleting Cloud Scheduler job '$JOB_NAME
    gcloud scheduler jobs delete $JOB_NAME --location $REGION --quiet
  fi
}

check_owners() {
  local project_admins=$(gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings" \
    --filter="bindings.role=roles/owner OR bindings.role=roles/admin" \
    --format="value(bindings.members[])"
  )
  if [[ ! $project_admins =~ $USER_EMAIL ]]; then
      echo "User $USER_EMAIL does not have admin / owner rights to project $PROJECT_ID"
      exit
  fi
}

deploy_all() {
  check_owners
  check_billing
  enable_apis
  set_iam_permissions
  deploy_files
  create_registry
  build_docker_image
  deploy_job
  schedule_run
}

migrate_to_cloud_run() {
  echo "Migrating legacy Cloud Function + Pub/Sub + VM stack to Cloud Run Jobs"
  local CF_NAME="create-${NAME}-vm"
  local OLD_TOPIC="run-${NAME}"
  local CF_REGION="europe-west1"
  local SCHED_NAME=$(eval echo $(git config -f $SETTING_FILE scheduler.name))
  local SCHED_REGION=$(git config -f $SETTING_FILE scheduler.region)

  # 1) delete the legacy pubsub-type scheduler job ONLY (http = already migrated)
  if gcloud scheduler jobs describe "$SCHED_NAME" --location="$SCHED_REGION" >/dev/null 2>&1; then
    local TARGET=$(gcloud scheduler jobs describe "$SCHED_NAME" --location="$SCHED_REGION" \
      --format='value(pubsubTarget.topicName)')
    if [[ -n "$TARGET" ]]; then
      gcloud scheduler jobs delete "$SCHED_NAME" --location="$SCHED_REGION" --quiet
    fi
  fi

  # 2) delete the legacy Cloud Function
  if [[ -n "$CF_NAME" ]] && \
     gcloud functions describe "$CF_NAME" --region="$CF_REGION" --gen2 >/dev/null 2>&1; then
    gcloud functions delete "$CF_NAME" --region="$CF_REGION" --gen2 --quiet
  fi

  # 3) delete the legacy Pub/Sub topic
  if [[ -n "$OLD_TOPIC" ]] && gcloud pubsub topics describe "$OLD_TOPIC" >/dev/null 2>&1; then
    gcloud pubsub topics delete "$OLD_TOPIC" --quiet
  fi

  # 4) stand up the new stack (idempotent: deploy_job / schedule_run create-or-update)
  set_iam_permissions
  build_docker_image
  deploy_job
  schedule_run
  echo "Migration to Cloud Run Jobs complete. Old roles (compute.admin, pubsub.*) can be"
  echo "revoked with: ./gcp/setup.sh tighten_iam"
}

# OPT-IN, never called automatically: revoke roles the old model needed.
tighten_iam() {
  for role in compute.admin pubsub.publisher monitoring.editor logging.logWriter; do
    gcloud projects remove-iam-policy-binding $PROJECT_ID \
      --member=serviceAccount:$SERVICE_ACCOUNT \
      --role=roles/$role --condition=None --no-user-output-enabled 2>/dev/null || true
  done
}

_upload_install_log() {
  if [[ -f "/tmp/${NAME}_installer.log" ]]; then
    gcloud storage cp /tmp/${NAME}_installer.log gs://$PROJECT_ID/$NAME/
    rm "/tmp/${NAME}_installer.log"
  fi
}

_list_functions() {
  # list all functions in this file not starting with "_"
  declare -F | awk '{print $3}' | grep -v "^_"
}

if [[ $# -eq 0 ]]; then
  _list_functions
else
  for i in "$@"; do
    if declare -F "$i" > /dev/null; then
      "$i" 2>&1 | tee -a /tmp/${NAME}_installer.log
      exitcode=$?
      if [ $exitcode -ne 0 ]; then
        echo "Breaking script as command '$i' failed"
        exit $exitcode
      fi
    else
      echo -e "\033[0;31mFunction '$i' does not exist.\033[0m"
    fi
  done
fi

popd > /dev/null
