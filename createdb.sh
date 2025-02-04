set +x

export SPANNER_EMULATOR_HOST=localhost:9010
gcloud config configurations activate emulator
INSTANCE=test-instance
PROJECT_ID=sohansm-project
DATABASE=inventory

gcloud config configurations create emulator
gcloud config set auth/disable_credentials true
gcloud config set project $PROJECT_ID
gcloud config set api_endpoint_overrides/spanner http://localhost:9020/
gcloud spanner instances create $INSTANCE\
  --config=emulator-config --description="Test Instance" --nodes=1
gcloud spanner databases create $DATABASE \
    --instance=$INSTANCE\
    --project=$PROJECT_ID
gcloud spanner databases ddl update $DATABASE \
    --instance=$INSTANCE\
    --project=$PROJECT_ID \
    --ddl="CREATE TABLE Products (
        Id INT64 NOT NULL,
        Name STRING(MAX) NOT NULL,
        Quantity INT64 NOT NULL,
    ) PRIMARY KEY(Id)"

for i in {1..5}; do  # Loop from 1 to 5
  NAME="Product $i"
  QUANTITY=$(( $i * 10 )) # Example: Quantity will be 10, 20, 30, etc.

  gcloud spanner rows insert \
      --instance="$INSTANCE" \
      --database="$DATABASE" \
      --table=Products \
      --project="$PROJECT_ID" \
      --data="Id=$i,Name=$NAME,Quantity=$QUANTITY"
done

gcloud spanner databases execute-sql $DATABASE \
    --instance=$INSTANCE \
    --project=$PROJECT_ID \
    --sql="SELECT * FROM Products"

gcloud config configurations activate default