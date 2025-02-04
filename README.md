# Introduction

This is a demo app for triggering `GCS > Cloud Run > Spanner`

## Local dev
Start two containers, one for the App and one for a Spanner emulator.

```bash
$ docker compose up
```

Then, on a separate terminal, create the database and seed data. Please note that your
data will be lost if you restart the Spanner Emulator container. Please update the
variables in [createdb.sh](./createdb.sh) and then run the following command:

```bash
$ sh createdb.sh
# Test that you have some seed data
$ gcloud config configurations activate emulator
$ gcloud spanner databases execute-sql <DB_NAME> --sql "select * from products" --instance=<DB_INSTANCE>
# Upload a file locally to see that it's updating data
$ curl http://localhost:8080/direct --data-binary @inventory.csv -H 'Content-Type: text/csv'
# Verify that you have new data
$ gcloud spanner databases execute-sql <DB_NAME> --sql "select * from products" --instance=<DB_INSTANCE>
```

If you modify app code / add npm packages,
then you need to exit the `docker compose up` by hitting `ctrl-c` and run the following.
This is not optimized and can be made better.
```bash
$ docker compose build && docker compose up
$ sh createdb.sh
```

## Deploy to GCP

You need to create a `spanner` instance. Then you can run the same `createdb.sh` script to create the
test database, but use the `default` configuration to target real spanner instead of the emulator
and update the variables accordingly. You'll also need to give Spanner Database User role to the Cloud Run
app's service account. Once your Spanner database is created, you can deploy the Cloud Run app.
Update the variables in [deploy.sh](./deploy.sh) and run the following:

```bash
$ sh deploy.sh
```
Then setup GCS trigger for this service for a specific BUCKET and run the following to trigger the service:

```bash
$ gsutil cp inventory.csv gs://<BUCKET>/
```

If you check the logs for the Cloud Run service, you can see that the data was successfully procssed. Also, you can
use the Spanner UI on GCP console or the following command to see the updated data:

```bash
$ gcloud config configurations activate default
$ gcloud spanner databases execute-sql <DB_NAME> --sql "select * from products" --instance=<DB_INSTANCE>
```
Try changing the file a few times, the app should `upsert` the database to insert new rows and update existing rows.

