PROJECT_ID=sohansm-project
DB_INSTANCE=test-instance
DB_NAME=inventory

gcloud run deploy nodejs-inventory-update --source . --region us-central1 \
--set-env-vars DB_INSTANCE=$DB_INSTANCE \
--set-env-vars DB_NAME=$DB_NAME \
--set-env-vars PROJECT_ID=$PROJECT_ID \
--no-allow-unauthenticated

# $ gcloud builds submit --pack image=us-central1-docker.pkg.dev/$PROJECT_ID/cloud-run-source-deploy/inventory-app