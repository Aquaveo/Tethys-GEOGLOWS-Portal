#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./setup_thredds_conf_from_s3.sh
#   ./setup_thredds_conf_from_s3.sh my-bucket
#   ./setup_thredds_conf_from_s3.sh my-bucket my-prefix
#   ./setup_thredds_conf_from_s3.sh my-bucket my-prefix /some/dir
#
# Defaults:
#   S3_BUCKET_NAME = geoglows-dashboard-data
#   S3_PREFIX      = thredds
#   LOCAL_BASE_DIR = /var/lib/tethys_persist

S3_BUCKET_NAME="${1:-geoglows-dashboard-data}"
S3_PREFIX="${2:-thredds}"
LOCAL_BASE_DIR="${3:-/var/lib/tethys_persist}"

CONF_DIR="${LOCAL_BASE_DIR%/}/conf"
PUBLIC_DATA_DIR="${LOCAL_BASE_DIR%/}/data"

echo "Using:"
echo "  S3_BUCKET_NAME=${S3_BUCKET_NAME}"
echo "  S3_PREFIX=${S3_PREFIX}"
echo "  LOCAL_BASE_DIR=${LOCAL_BASE_DIR}"
echo

echo "Creating directories..."
mkdir -p "$CONF_DIR" "$PUBLIC_DATA_DIR"

# Ensure aws cli exists
command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found in container"; exit 1; }

# Helpful for debugging IAM issues (optional, but recommended)
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

# Verify (must exist and be non-empty)
for f in tomcat-users.xml catalog.xml threddsConfig.xml; do
  [[ -s "${CONF_DIR}/${f}" ]] || { echo "ERROR: ${CONF_DIR}/${f} missing or empty"; exit 1; }
done

# Permissions: only touch what we created/downloaded (avoid chmod -R on EFS)
chmod 777'*'
chmod 777 "$CONF_DIR/"*.xml

echo "Setup complete. Config files are at: ${CONF_DIR}"
