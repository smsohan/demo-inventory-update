const http = require('http');
const { Spanner } = require('@google-cloud/spanner');
const spanner = new Spanner({projectId: process.env.PROJECT_ID});

const instanceId = process.env.DB_INSTANCE;
const databaseId = process.env.DB_NAME;

const server = http.createServer(async(req, res) => {
    const instance = spanner.instance(instanceId);
    const database = instance.database(databaseId);

    const query = {
        sql: 'SELECT * FROM Products',
    };

    try {
        const results = await database.run(query);
        const rows = results[0].map(row => row.toJSON());
        rows.forEach(row => {
            res.write(
                `Id: ${row.Id}, ` +
                `Name: ${row.Name}, ` +
                `Quantity: ${row.Quantity}\n`
            );
        });
        res.end();
    } catch (err) {
        console.debug(`Error in reading data: ${err}`)
        res.send(`Error querying Spanner: ${err}`);
    }

});

const port = process.env.PORT || 8080; // Use environment variable or default to 8080

server.listen(port, () => {
    console.log(`Server is listening on port ${port}`);
});