#!/usr/bin/env bash
set -euo pipefail

# Render the portal config for this pod.
#
# The portal config is now declarative: it comes from the mounted tethys-portal-config
# This script only:
#   1. copies that file into TETHYS_HOME, and
#   2. injects the values that must NOT live in a ConfigMap - secrets, plus the
#      environment-specific DB host (the init Job sets TETHYS_DB_HOST=tethys-postgres-rw
#      to bypass the transaction-mode pooler for migrations).
#
# => Changing any Django/portal setting is just an edit to portal_config.yml + re-apply.
#    No image rebuild, because this script never enumerates settings.

export TETHYS_HOME="${TETHYS_HOME:-/home/tethys/portal}"
export TETHYS_PERSIST="${TETHYS_PERSIST:-/home/tethys/persist}"
export STATIC_ROOT="${STATIC_ROOT:-/home/tethys/persist/static}"
export MEDIA_ROOT="${MEDIA_ROOT:-/home/tethys/persist/media}"
export TETHYS_WORKSPACES_ROOT="${TETHYS_WORKSPACES_ROOT:-/home/tethys/persist/workspaces}"

# Where the ConfigMap is mounted (see the configure initContainer volumeMount).
PORTAL_CONFIG_SRC="${PORTAL_CONFIG_SRC:-/config/portal_config.yml}"

mkdir -p "$TETHYS_HOME" 

echo "Applying portal config from $PORTAL_CONFIG_SRC"
cp "$PORTAL_CONFIG_SRC" "$TETHYS_HOME/portal_config.yml"


set_args=(
  --set SECRET_KEY "${TETHYS_SECRET_KEY:?TETHYS_SECRET_KEY is required (from tethys-secret)}"
  --set DATABASES.default.PASSWORD "${TETHYS_DB_PASSWORD:?TETHYS_DB_PASSWORD is required (from tethys-db-app)}"
)
if [ -n "${TETHYS_DB_HOST:-}" ]; then
  set_args+=(--set DATABASES.default.HOST "$TETHYS_DB_HOST")
fi
# Supabase pooler (Supavisor) identifies the tenant from the username suffix: USER must be
# "<role>.<project_ref>" (e.g. tethys_default.xxxx) or you get "no tenant identifier provided".
if [ -n "${TETHYS_DB_USERNAME:-}" ]; then
  set_args+=(--set DATABASES.default.USER "$TETHYS_DB_USERNAME")
fi
if [ -n "${TETHYS_DB_PORT:-}" ]; then
  set_args+=(--set DATABASES.default.PORT "$TETHYS_DB_PORT")
fi
if [ -n "${TETHYS_DB_NAME:-}" ]; then
  set_args+=(--set DATABASES.default.NAME "$TETHYS_DB_NAME")
fi

tethys settings "${set_args[@]}"

# S3 static via django-storages (only when configured -- no-op for the local/workshop path).
# collectstatic (in publish-static.sh) uploads to S3; the web tier emits CloudFront URLs.
# Per-release prefix = INIT_VERSION (the image tag) for immutable, atomic releases.
if [ -n "${STATIC_S3_BUCKET:-}" ]; then
  loc="${INIT_VERSION:-static}"
  s3_args=(
    --set STORAGES.default.BACKEND "django.core.files.storage.FileSystemStorage"
    --set STORAGES.staticfiles.BACKEND "storages.backends.s3.S3Storage"
    --set STORAGES.staticfiles.OPTIONS.bucket_name "$STATIC_S3_BUCKET"
    --set STORAGES.staticfiles.OPTIONS.region_name "${AWS_REGION:-us-east-1}"
    --set STORAGES.staticfiles.OPTIONS.location "$loc"
    --set STORAGES.staticfiles.OPTIONS.querystring_auth false
  )
  if [ -n "${STATIC_CLOUDFRONT_DOMAIN:-}" ]; then
    s3_args+=( --set STORAGES.staticfiles.OPTIONS.custom_domain "$STATIC_CLOUDFRONT_DOMAIN" )
    s3_args+=( --set STATIC_URL "https://${STATIC_CLOUDFRONT_DOMAIN}/${loc}/" )
  fi
  tethys settings "${s3_args[@]}"
  echo "S3 static configured: bucket=$STATIC_S3_BUCKET location=$loc domain=${STATIC_CLOUDFRONT_DOMAIN:-<none>}"
fi

echo "Tethys portal config applied."