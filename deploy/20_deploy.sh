#!/usr/bin/env bash
# Build the image and deploy it to Cloud Run.
# The service is reachable from the internet; every /v1 route is protected by
# Firebase ID-token verification inside the app, and the rate limiter and
# --max-instances bound abuse.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require PROJECT_ID REGION SERVICE SQL_INSTANCE DB_NAME DB_USER DB_SECRET MAX_INSTANCES

TAG="$(git -C "$DEPLOY_DIR" rev-parse --short HEAD)"

gcloud builds submit "$DEPLOY_DIR/../backend" \
  --project="$PROJECT_ID" \
  --tag="${IMAGE}:${TAG}"

gcloud run deploy "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --image="${IMAGE}:${TAG}" \
  --service-account="$SERVICE_ACCOUNT" \
  --allow-unauthenticated \
  --min-instances=0 \
  --max-instances="$MAX_INSTANCES" \
  --concurrency=8 \
  --cpu=1 \
  --memory=1Gi \
  --timeout=120 \
  --add-cloudsql-instances="${PROJECT_ID}:${REGION}:${SQL_INSTANCE}" \
  --set-env-vars="FIREBASE_PROJECT_ID=${PROJECT_ID},GOOGLE_CLOUD_PROJECT=${PROJECT_ID},GOOGLE_CLOUD_LOCATION=${VERTEX_LOCATION:-global},GOOGLE_GENAI_USE_ENTERPRISE=true,GOOGLE_GENAI_USE_VERTEXAI=true,DB_HOST=/cloudsql/${PROJECT_ID}:${REGION}:${SQL_INSTANCE},DB_NAME=${DB_NAME},DB_USER=${DB_USER}" \
  --set-secrets="DB_PASSWORD=${DB_SECRET}:latest"

gcloud run services describe "$SERVICE" \
  --project="$PROJECT_ID" --region="$REGION" --format='value(status.url)'
