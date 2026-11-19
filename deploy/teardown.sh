#!/usr/bin/env bash
# Delete everything 10_infra.sh and 20_deploy.sh created. Destructive.
# You must type the project id to confirm. The budget is left in place.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require PROJECT_ID REGION SERVICE REPO SQL_INSTANCE DB_SECRET SERVICE_ACCOUNT_NAME

read -r -p "This deletes the Cloud Run service, Cloud SQL instance (and its data), secret, registry and service account in ${PROJECT_ID}. Type the project id to continue: " answer
if [[ "$answer" != "$PROJECT_ID" ]]; then
  echo "Aborted." >&2
  exit 1
fi

gcloud run services delete "$SERVICE" --project="$PROJECT_ID" --region="$REGION" --quiet || true
gcloud sql instances patch "$SQL_INSTANCE" --project="$PROJECT_ID" --no-deletion-protection --quiet || true
gcloud sql instances delete "$SQL_INSTANCE" --project="$PROJECT_ID" --quiet || true
gcloud secrets delete "$DB_SECRET" --project="$PROJECT_ID" --quiet || true
gcloud artifacts repositories delete "$REPO" --project="$PROJECT_ID" --location="$REGION" --quiet || true
gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" --role="roles/aiplatform.user" --quiet || true
gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" --role="roles/cloudsql.client" --quiet || true
gcloud iam service-accounts delete "$SERVICE_ACCOUNT" --project="$PROJECT_ID" --quiet || true

echo "Teardown commands issued. Confirm in the console that nothing is left running."
