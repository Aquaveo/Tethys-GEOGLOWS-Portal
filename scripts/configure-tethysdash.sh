#!/usr/bin/env bash
set -euo pipefail
#
# configure-tethysdash.sh  - replaces salt/tethysdash.sls (salt-free).
#
# Links the PostGIS service to the tethysdash persistent store, ensures the store schema, and
# collects the tethysdash plugin static metadata. Idempotent (replaces the tethysdash_setup_complete
# marker guard).
#
# ⚠ OVERLAP WITH THE DB REPO: in the new design the store DB (tethysdash_primary_db) is created and
# its schema applied PRE-ECS by the DB-provisioning repo (provision.sh + migrate.sh, which runs the
# link + syncstores). If you keep that, this script's link/syncstores are idempotent no-ops here and
# you really only need step 3 (collect_plugin_static). Toggle with RUN_STORE_SETUP.
#   - syncstores is SAFE even though we banned its CREATE DATABASE: the DB already exists, so
#     create_persistent_store_database() skips CREATE DATABASE and runs only the alembic initializer.
#
# Required env:
#   POSTGIS_SERVICE_NAME     e.g. primary_postgis
# Optional:
#   RUN_STORE_SETUP=true|false   (default true) - do the link + syncstores here too

: "${POSTGIS_SERVICE_NAME:?}"
RUN_STORE_SETUP="${RUN_STORE_SETUP:-true}"

if [ "$RUN_STORE_SETUP" = "true" ]; then
  echo "==> link PostGIS service to tethysdash store"
  tethys link "persistent:${POSTGIS_SERVICE_NAME}" "tethysdash:ps_database:primary_db" \
    || echo "    (link may already exist - continuing)"

  echo "==> syncstores tethysdash (DB pre-exists -> initializer/alembic only)"
  tethys syncstores tethysdash
fi

# NOTE: tethysdash plugin static collection moved to publish-static.sh (it must run right before
# collectstatic, which is its own run-once step). This script now only does the store link + sync.

echo "tethysdash configured."
