# Tethys-GEOGLOWS-Portal
This is a portal that can be deployed using ECS on AWS.

**Architecture:** uvx-based (salt-free) Tethys image · **Supabase** Postgres · static on **S3 + CloudFront**
(django-storages) · **THREDDS** as a separate ECS service · deployed on **ECS**.
Full design: `docs/superpowers/specs/2026-06-23-enee-ecs-supabase-portal-design.md`.

## Deployment steps

> Auth for all AWS steps: `aws sso login --sso-session geoglows`
> (profile `AWSAdministratorAccess-401506828094`, region `us-east-1`).

**1. Provision the Supabase database** (one-time) — repo `enee-geoglows-portal-db`: ✅
```bash
cp .env.example .env            # SUPABASE_ADMIN_URL + TETHYS_DEFAULT_PASSWORD
set -a; . ./.env; set +a
scripts/provision.sh            # roles + tethys_platform + tethysdash_primary_db + grants + postgis
```

**2. Create the static bucket + CloudFront** (one-time) — `aws/cloudformation/static-cdn.yaml`: ✅
```bash
aws cloudformation deploy --template-file aws/cloudformation/static-cdn.yaml \
  --stack-name enee-portal-static --parameter-overrides BucketName=enee-portal-static \
  --capabilities CAPABILITY_NAMED_IAM --region us-east-1 --profile AWSAdministratorAccess-401506828094
# outputs -> STATIC_S3_BUCKET=enee-portal-static, STATIC_CLOUDFRONT_DOMAIN=d38ru6meoupfl7.cloudfront.net
```

**3. Build & push the image** (the React build + uv geo stack run at build time): ✅ builds
```bash
docker build -t <ecr-repo>:<tag> .      # CI: .github/workflows/build_ecr_aws_dev.yml
docker push <ecr-repo>:<tag>
```

**4. Configure the portal env** (`.env` / SSM) — ⏳
Supabase pooler URLs, THREDDS (Cloud Map), ggst, static (`STATIC_S3_BUCKET`/`STATIC_CLOUDFRONT_DOMAIN`),
and `INIT_VERSION=<image tag>`. See `.env.example`.

**5. Deploy / run** — ⏳ the init container runs `scripts/init-tethys.sh` (see "Init & guards") **before**
the web tier; `collectstatic` uploads static to S3. Local: `docker compose`; AWS: ECS.

**6. ECS infrastructure** (Phase 5) — ⏳ task def (`awsvpc`) + ALB + Cloud Map (`enee.local`/`thredds`)
+ security groups + task role (**S3 write** for collectstatic) + SSM secrets. Templates go in
`aws/cloudformation/` (see its README).

## Init & guards

The init container runs `scripts/init-tethys.sh` **before** the web (uvicorn) tier, every time a
task starts. Roles + databases are provisioned earlier by the `enee-geoglows-portal-db` repo.

- **Every deploy (idempotent):** `wait-for-role` → `portal-config` → `db-migrations` →
  `portal-bootstrap`, then the web tier is flipped to the transaction pooler.
- **Once per image version (guarded):** `configure-services`, `configure-ggst`,
  `configure-tethysdash` — wrapped in `scripts/run-once.sh`, which records a marker row in the
  **database** (`enee_init_markers` in `tethys_platform`), so "once" survives ECS task/instance
  replacement (a file marker would reset every boot).

### Controls
- **`INIT_VERSION`** — set it to the image tag. The guard key becomes `<step>@<INIT_VERSION>`, so a
  **new image runs the guarded steps once** (applying new services/store migrations), then **skips**
  on restarts of the same version. Unset = run-once-ever.
- **`INIT_FORCE=true`** — ignore markers and re-run the guarded steps once (e.g. to re-apply changed
  `ggst` settings without cutting a new image). Re-records on success.

Manual reset: `DELETE FROM enee_init_markers WHERE name LIKE 'ggst%';` (then redeploy).
