const http = require('http');
const { Spanner } = require('@google-cloud/spanner');
const { Storage } = require('@google-cloud/storage');
const { Readable } = require('stream');
const client = require('prom-client');
const fs = require('fs')

const register = new client.Registry();
const rowsUpsertedCounter = new client.Counter({
  name: 'rows_upserted',
  help: 'Total rows upserted'
});
register.registerMetric(rowsUpsertedCounter);

const spanner = new Spanner({ projectId: process.env.PROJECT_ID });
const instanceId = process.env.DB_INSTANCE;
const databaseId = process.env.DB_NAME;

const storage = new Storage();

const csv = require('csv-parser');

const upsertProducts = async (products) => {
    const instance = spanner.instance(instanceId);
    const database = instance.database(databaseId);
    const productsTable = database.table("Products")

    try {
        await productsTable.upsert(products)
        console.log('Data inserted successfully.');
        rowsUpsertedCounter.inc(products.lenth)
    } catch (err) {
        console.error('ERROR inserting data:', err);
    } finally {
        await database.close();
    }
}

const processCSVData = async (inventoryCSV) => {
    const readableStream = new Readable({
        read() { }
    });

    readableStream.push(inventoryCSV);
    readableStream.push(null);
    const products = [];
    readableStream
        .pipe(csv())
        .on('data', ({ Id, Name, Quantity }) => {
            console.log(`Id: ${Id}, Name: ${Name}`)
            products.push({ Id, Name, Quantity })
        }).on('end', async () => {
            console.log('finished reading data');
            await upsertProducts(products);
            console.log('finished inserting data');
        })
        .on('error', (error) => {
            console.error('Error parsing CSV:', error);
        });
}

const processGCSFile = async (req, res) => {
    let body = '';

    req.on('data', chunk => {
        body += chunk;
    });

    req.on('end', async () => {
        const { name, bucket } = JSON.parse(body);
        const gcsBucket = storage.bucket(bucket);

        const file = gcsBucket.file(name);
        const fileContents = await file.download();
        const inventoryCSV = fileContents.toString('utf8');
        await processCSVData(inventoryCSV);
        res.write("Inserted data");
    })

}
const processDirect = async (req, res) => {
    let body = '';
    req.on('data', chunk => {
        console.log("chunk = " + chunk);
        body += chunk;
    });

    req.on('end', async () => {
        console.log("body = " + body);
        const inventoryCSV = body.toString('utf8');
        await processCSVData(inventoryCSV);
        res.write("Inserted data");
    });
}

const server = http.createServer(async (req, res) => {
    // This is for the otel collector
    if (req.url === '/metrics'){
        res.appendHeader('Content-Type', register.contentType)
        res.statusCode = 200
        res.end(await register.metrics());
        return
    }

    if (req.method == 'POST') {
        if (req.url === '/direct') {
            await processDirect(req, res)
        } else {
            await processGCSFile(req, res)
        }

        res.statusCode = 200;
        res.end()
        return
    }

    res.statusCode = 200
    res.write("Call with POST, /direct to upload a CSV file directly, or trigger using GCS on cloud on /")
    res.end()
});

const port = process.env.PORT || 8080;

server.listen(port, () => {
    console.log(`Server is listening on port ${port}`);
});