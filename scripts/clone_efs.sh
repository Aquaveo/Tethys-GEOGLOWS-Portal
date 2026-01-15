#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-1"
SOURCE_FS="fs-09d128d330673bf43"
ENVS="enee,marn,imhpa,ineter,mrn-belize,insivumeh"
FORCE_ONE_ZONE="true"
DRY_RUN="false"

usage() {
  cat >&2 <<EOF
Usage: $0 [--region us-east-1] --source-fs fs-... [--envs "a,b,c"] [--force-one-zone true|false] [--dry-run]

Defaults:
  --region $REGION
  --envs   $ENVS
  --force-one-zone $FORCE_ONE_ZONE
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) REGION="$2"; shift 2 ;;
    --source-fs) SOURCE_FS="$2"; shift 2 ;;
    --envs) ENVS="$2"; shift 2 ;;
    --force-one-zone) FORCE_ONE_ZONE="$2"; shift 2 ;;
    --dry-run) DRY_RUN="true"; shift 1 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

command -v aws >/dev/null || { echo "aws not found" >&2; exit 1; }

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run] %q' "$1"
    shift
    for a in "$@"; do printf ' %q' "$a"; done
    printf '\n'
  else
    "$@"
  fi
}

IFS=',' read -r -a ENV_ARR <<< "$ENVS"

echo "REGION=$REGION"
echo "SOURCE_FS=$SOURCE_FS"
echo "ENVS=${ENV_ARR[*]}"
echo "FORCE_ONE_ZONE=$FORCE_ONE_ZONE"
echo "DRY_RUN=$DRY_RUN"
echo

# Pull source subnets + SGs from the source FS (ice)
mapfile -t SUBNET_IDS < <(aws efs describe-mount-targets --region "$REGION" --file-system-id "$SOURCE_FS" \
  --query 'MountTargets[].SubnetId' --output text | tr '\t' '\n')

FIRST_MT="$(aws efs describe-mount-targets --region "$REGION" --file-system-id "$SOURCE_FS" --query 'MountTargets[0].MountTargetId' --output text)"
mapfile -t SG_IDS < <(aws efs describe-mount-target-security-groups --region "$REGION" --mount-target-id "$FIRST_MT" \
  --query 'SecurityGroups[]' --output text | tr '\t' '\n')

# If forcing One Zone, infer AZ from first subnet and filter subnets to that AZ
AZ_NAME=""
if [[ "$FORCE_ONE_ZONE" == "true" ]]; then
  AZ_NAME="$(aws ec2 describe-subnets --region "$REGION" --subnet-ids "${SUBNET_IDS[0]}" --query 'Subnets[0].AvailabilityZone' --output text)"
  mapfile -t SUBNET_IDS < <(aws ec2 describe-subnets --region "$REGION" --subnet-ids "${SUBNET_IDS[@]}" \
    --query "Subnets[?AvailabilityZone=='$AZ_NAME'].SubnetId" --output text | tr '\t' '\n')
fi

echo "Using subnets: ${SUBNET_IDS[*]}"
echo "Using SGs:     ${SG_IDS[*]}"
echo "AZ_NAME:       ${AZ_NAME:-<regional>}"
echo

OUT="efs_env_map.csv"
echo "env,fileSystemId,apName,apPath,accessPointId" > "$OUT"

wait_for_efs_available() {
  local fs_id="$1"
  local timeout_sec="${2:-600}"   # 10 min default
  local sleep_sec="${3:-5}"

  local deadline=$((SECONDS + timeout_sec))
  while true; do
    local state
    state="$(aws efs describe-file-systems \
      --region "$REGION" \
      --file-system-id "$fs_id" \
      --query 'FileSystems[0].LifeCycleState' \
      --output text)"

    if [[ "$state" == "available" ]]; then
      return 0
    fi

    if (( SECONDS >= deadline )); then
      echo "ERROR: Timed out waiting for EFS $fs_id to become available (state=$state)" >&2
      return 1
    fi

    sleep "$sleep_sec"
  done
}

wait_for_mount_targets() {
  local fs_id="$1"
  local timeout_sec="${2:-600}"
  local sleep_sec="${3:-5}"
  local deadline=$((SECONDS + timeout_sec))

  while true; do
    local bad
    bad="$(aws efs describe-mount-targets --region "$REGION" --file-system-id "$fs_id" \
      --query 'MountTargets[?LifeCycleState!=`available`].[MountTargetId,LifeCycleState]' --output text)"

    if [[ -z "$bad" ]]; then
      return 0
    fi

    if (( SECONDS >= deadline )); then
      echo "ERROR: Timed out waiting for mount targets on $fs_id. Still not available:" >&2
      echo "$bad" >&2
      return 1
    fi
    sleep "$sleep_sec"
  done
}

create_access_points() {
  local env="$1"
  local fs_id="$2"

  # Match ICE settings:
  # THREDDS / GEOSERVER: posix 1000:1000, owner 1000:1000, perms 0777
  # TETHYS:             posix 0:0,       owner 0:0,       perms 0777
  local thredds_path="/${env}-thredds-data"
  local geoserver_path="/${env}-geoserver-data"
  local tethys_path="/${env}-tethys-persist"

  local ap_id

  # THREDDS
  ap_id="$(run aws efs create-access-point --region "$REGION" --file-system-id "$fs_id" \
    --posix-user "Uid=1000,Gid=1000" \
    --root-directory "Path=${thredds_path},CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=0777}" \
    --tags Key=Name,Value="fsap-THREDDS" Key=environment,Value="$env" Key=project,Value="geoglows" \
    --query 'AccessPointId' --output text)"
  [[ "$DRY_RUN" == "true" ]] && ap_id="<NEW_AP_ID>"
  echo "${env},${fs_id},THREDDS,${thredds_path},${ap_id}" >> "$OUT"

  # GEOSERVER
  ap_id="$(run aws efs create-access-point --region "$REGION" --file-system-id "$fs_id" \
    --posix-user "Uid=1000,Gid=1000" \
    --root-directory "Path=${geoserver_path},CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=0777}" \
    --tags Key=Name,Value="fsap-GEOSERVER" Key=environment,Value="$env" Key=project,Value="geoglows" \
    --query 'AccessPointId' --output text)"
  [[ "$DRY_RUN" == "true" ]] && ap_id="<NEW_AP_ID>"
  echo "${env},${fs_id},GEOSERVER,${geoserver_path},${ap_id}" >> "$OUT"

  # TETHYS
  ap_id="$(run aws efs create-access-point --region "$REGION" --file-system-id "$fs_id" \
    --posix-user "Uid=0,Gid=0" \
    --root-directory "Path=${tethys_path},CreationInfo={OwnerUid=0,OwnerGid=0,Permissions=0777}" \
    --tags Key=Name,Value="fsap-TETHYS" Key=environment,Value="$env" Key=project,Value="geoglows" \
    --query 'AccessPointId' --output text)"
  [[ "$DRY_RUN" == "true" ]] && ap_id="<NEW_AP_ID>"
  echo "${env},${fs_id},TETHYS,${tethys_path},${ap_id}" >> "$OUT"
}

for env in "${ENV_ARR[@]}"; do
  echo "=== ENV: $env ==="

  # Create EFS
  CREATE_FS_CMD=(aws efs create-file-system --region "$REGION" --encrypted
    --tags Key=Name,Value="${env}-efs" Key=environment,Value="$env" Key=project,Value="geoglows")

  if [[ "$FORCE_ONE_ZONE" == "true" ]]; then
    CREATE_FS_CMD+=(--availability-zone-name "$AZ_NAME")
  fi

  fs_id="$(run "${CREATE_FS_CMD[@]}" --query 'FileSystemId' --output text)"
  [[ "$DRY_RUN" == "true" ]] && fs_id="<NEW_FS_ID>"

  echo "FS_ID=$fs_id"

  if [[ "$DRY_RUN" != "true" ]]; then
    wait_for_efs_available "$fs_id"
  else
    echo "[dry-run] wait_for_efs_available <NEW_FS_ID>"
  fi

  # Mount targets
  for subnet in "${SUBNET_IDS[@]}"; do
    run aws efs create-mount-target --region "$REGION" --file-system-id "$fs_id" --subnet-id "$subnet" --security-groups "${SG_IDS[@]}" >/dev/null || true
  done

  if [[ "$DRY_RUN" != "true" ]]; then
    wait_for_mount_targets "$fs_id"
  else
    echo "[dry-run] wait_for_mount_targets <NEW_FS_ID>"
  fi

  # Access points
  create_access_points "$env" "$fs_id"

  echo
done

echo "Done."
echo "Wrote: $OUT"
[[ "$DRY_RUN" == "true" ]] && echo "NOTE: dry-run uses placeholders for new IDs."
