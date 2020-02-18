#!/usr/bin/env bash

# Fetch a list of existing repos from AWS.
EXISTING_REPOS="$(aws ecr describe-repositories --output=json | \
jq -r '.repositories[].repositoryName')"

APIM_REPOS=(apim
k8s-init
client-downloads-server
ui
ldap
lur
cassandra
cassandra-operator
juhu
busybox
analytics-proxy
migration
cassandra-health-check)

APIM_ANALYTICS_REPOS=(busybox
openresty
analytics-cronjobs
analytics-ingestion
analytics-storage
analytics-client
nginx-openresty
analytics-mq-kafka
analytics-mq-zookeeper
analytics-operator)

APIM_PORTAL_REPOS=(portal-db
portal-exec-job
portal-dbproxy
portal-admin
portal-web
nginx-openresty
portal-job-alpine)

DATAPOWER_REPOS=(k8s-datapower-monitor
datapower)

# Create all missing repos to enable successful usage of "apicup registry-upload"
for repo in ${APIM_REPOS[*]} ${APIM_ANALYTICS_REPOS[*]} ${APIM_PORTAL_REPOS[*]} ${DATAPOWER_REPOS[*]}; do
  if [[ -z "$(echo "$EXISTING_REPOS" | grep -E "^$repo$" || true)" ]]; then
  	echo "Preparing to create repo '$repo'."
  	aws ecr create-repository --repository-name "$repo"
  	#aws ecr delete-repository --repository-name "$repo" --force
  else
    echo "Repo '$repo' already exists, don't have to create it."
  fi
done
echo ""

echo "Docker login for ECR..."
docker_login_cmd="$(aws ecr get-login --no-include-email)"
bash -c "${docker_login_cmd}"
echo ""

. ./scripts/envfile
echo "Prepared to upload docker images to registry '$REGISTRY'."

if [[ ! -d "$APIC_IMAGES_PATH" ]]; then
  echo "ERROR: APIC images directory on path '$APIC_IMAGES_PATH' not found."
  exit 2
fi

management_tgz="$(find "$APIC_IMAGES_PATH" -name "management-*.tgz")"
analytics_tgz="$(find "$APIC_IMAGES_PATH" -name "analytics-*.tgz")"
portal_tgz="$(find "$APIC_IMAGES_PATH" -name "portal-*.tgz")"

dpm_tgz="$(find "$APIC_IMAGES_PATH" -name "dpm*.tar.gz")"
idg_tgz="$(find "$APIC_IMAGES_PATH" -name "idg_*.nonprod.tar.gz")"

if [[ -z "$management_tgz" || -z "$analytics_tgz" || -z "$portal_tgz" || \
      -z "$dpm_tgz" || -z "$idg_tgz" ]]; then
  echo "All 5 docker image archives have to be present for this installation:"
  echo "- management ($management_tgz)"
  echo "- analytics ($analytics_tgz)"
  echo "- portal ($portal_tgz)"
  echo "- dpm ($dpm_tgz)"
  echo "- idg nonprod ($idg_tgz)"
  echo "Please check APIC images directory path: '$APIC_IMAGES_PATH'."
  exit 3
fi

echo "Loading docker images (management, analytics & portal) to AWS using apicup..."
echo "Loading docker images from archive '$management_tgz'..."
apicup registry-upload management "$management_tgz" "$REGISTRY"
echo "Loading docker images from archive '$analytics_tgz'..."
apicup registry-upload analytics "$analytics_tgz" "$REGISTRY"
echo "Loading docker images from archive '$portal_tgz'..."
apicup registry-upload portal "$portal_tgz" "$REGISTRY"
echo ""

# For DataPower Monitor and DataPower we use docker command because it seems
# that for both archives we got error using apicup registry-upload command.
function upload_docker_image_to_aws() {
  image_path="$1"
  tag_env_var_name="$2"
  echo "Loading docker images from archive '$image_path'..."

  docker_load_res="$(docker load -i "$image_path")"
  # Skip lines with "loading layer [==...=>]" and parse line with loaded image:
  # Loaded image: ibmcom/k8s-datapower-monitor:2018.4.1.9
  docker_image="$(echo "$docker_load_res" \
    | grep "Loaded image:" \
    | sed 's/Loaded image: *//')"
  docker_repo_name="$(echo "$docker_image" | sed 's|.*/||; s|:.*||')"
  docker_tag="$(echo "$docker_image" | sed 's/.*://')"
  if [[ -z "$docker_repo_name" || -z "$docker_tag" ]]; then
    echo "ERROR getting repo name & version, docker load result:"
    echo "$docker_load_res"
    exit 4
  fi

  echo "Setting variable '$tag_env_var_name' in ./scripts/envfile to '$docker_tag'."
  sed -i -r "s/export $tag_env_var_name=.*/export $tag_env_var_name=$docker_tag/" ./scripts/envfile

  echo "Uploading '$docker_image' to AWS registry '$REGISTRY'"
  docker tag "$docker_image" "$REGISTRY/$docker_repo_name:$docker_tag"
  docker push "$REGISTRY/$docker_repo_name:$docker_tag"
  echo ""
}

echo "Loading docker images (dpm & idg) to AWS using docker command..."
upload_docker_image_to_aws "$dpm_tgz" "apic_dpm_tag"
upload_docker_image_to_aws "$idg_tgz" "apic_idg_tag"
