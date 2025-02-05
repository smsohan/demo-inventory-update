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

Make sure you have Terraform installed. Then run the following:

```bash
$ cd terraform
$ cp dev.tfvars.example dev.tfvars
```

Then edit the dev.tfvars file and update the values. Then run the following:

```bash
$ terraform init
$ terraform apply --var-file="dev.tfvars"
```

Once it suceeds you'll see a few output, note the GCS bucket url, since it has a suffix to make it globally unique.
Then, you can trigger the app using the following:

```bash
$ cd .. # go from the terraform dir to the parent
$ gsutil cp inventory.csv "gs://<bucket-url>"
```

If everything worked, this should now upsert the data in your Spanner table. You can verify on the Console.