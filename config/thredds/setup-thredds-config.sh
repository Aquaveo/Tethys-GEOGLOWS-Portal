#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <S3_BUCKET_NAME> <S3_PREFIX> <LOCAL_BASE_DIR>" >&2
  exit 1
}

[[ $# -eq 3 ]] || usage

S3_BUCKET_NAME="$1"
S3_PREFIX="$2"
LOCAL_BASE_DIR="$3"

CONF_DIR="${LOCAL_BASE_DIR%/}/conf"
PUBLIC_DATA_DIR="${LOCAL_BASE_DIR%/}/data"

echo "Creating directories..."
mkdir -p "$CONF_DIR" "$PUBLIC_DATA_DIR"

# Ensure aws cli exists
command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found in container"; exit 1; }

# (Optional) sanity check identity (helps debugging IAM issues)
echo "Checking AWS identity..."
aws sts get-caller-identity >/dev/null

download() {
  local key="$1"
  local dest="$2"
  echo "Downloading s3://${S3_BUCKET_NAME}/${key} -> ${dest}"
  aws s3 cp "s3://${S3_BUCKET_NAME}/${key}" "${dest}"
}

download "${S3_PREFIX%/}/tomcat-users.xml"   "${CONF_DIR}/tomcat-users.xml"
download "${S3_PREFIX%/}/catalog.xml"       "${CONF_DIR}/catalog.xml"
download "${S3_PREFIX%/}/threddsConfig.xml" "${CONF_DIR}/threddsConfig.xml"

# Verify
for f in tomcat-users.xml catalog.xml threddsConfig.xml; do
  [[ -s "${CONF_DIR}/${f}" ]] || { echo "ERROR: ${CONF_DIR}/${f} missing or empty"; exit 1; }
done

# Permissions: only touch what you created/downloaded
chmod 777 "$CONF_DIR"
chmod 777 "$CONF_DIR/"*.xml

echo "Setup complete. Config files are at: ${CONF_DIR}"
