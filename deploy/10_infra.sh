#!/usr/bin/env bash
# Create the project resources: APIs, service account, Artifact Registry,
# Cloud SQL (PostgreSQL) and the database password secret.
# Cloud SQL is the main fixed cost. Check current pricing for the tier below first.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require PROJECT_ID REGION SERVICE REPO SERVICE_ACCOUNT_NAME SQL_INSTANCE DB_NAME DB_USER DB_SECRET

gcloud config set project "$PROJECT_ID"

gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  aiplatform.googleapis.com

# Least-privilege runtime identity: model calls, Cloud SQL connections, and
# read access to the one secret it needs. Nothing else.
gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
  --display-name="NutriLens API runtime"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" --role="roles/aiplatform.user"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" --role="roles/cloudsql.client"

gcloud artifacts repositories create "$REPO" \
  --repository-format=docker --location="$REGION"

# Generate the database password locally, store it only in Secret Manager.
DB_PASSWORD="$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)"
printf '%s' "$DB_PASSWORD" | gcloud secrets create "$DB_SECRET" \
  --replication-policy=automatic --data-file=-
gcloud secrets add-iam-policy-binding "$DB_SECRET" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" --role="roles/secretmanager.secretAccessor"

gcloud sql instances create "$SQL_INSTANCE" \
  --database-version=POSTGRES_16 \
  --edition=enterprise \
  --tier=db-f1-micro \
  --region="$REGION" \
  --storage-size=10 \
  --availability-type=zonal \
  --deletion-protection
gcloud sql databases create "$DB_NAME" --instance="$SQL_INSTANCE"
gcloud sql users create "$DB_USER" --instance="$SQL_INSTANCE" --password="$DB_PASSWORD"
unset DB_PASSWORD

echo "Infrastructure created. Next: deploy/20_deploy.sh"
