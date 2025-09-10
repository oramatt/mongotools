# MongoDB Migration and Profiling Utilities

This repository contains two Bash scripts to assist with MongoDB data migration and profiling analysis. These scripts enable exporting/importing data between MongoDB and Oracle Database API for MongoDB, as well as reviewing MongoDB profiling data.

## Scripts Overview
| Script | Purpose |
|--------|---------|
| [`mongoDump.sh`](https://github.com/oramatt/mongotools/blob/main/mongoDump.sh) | Bulk export/import of MongoDB data for migration. |
| [`mongoProfileExport.sh`](https://github.com/oramatt/mongotools/blob/main/mongoProfileExport.sh) | Enables profiling, exports, and analyzes MongoDB performance. |

---

## `mongoDump.sh` - Data Migration
### Features
- Export MongoDB data into BSON format using `mongodump`.
- Import BSON data into Oracle Database API for MongoDB using `mongorestore`.
- Appends data to existing collections instead of overwriting.
- Allows user to select the source and target MongoDB details.
- Handles missing BSON files gracefully and logs all actions.
- **Supports Authentication** (username, password, auth DB).
- **Supports TLS/SSL** (CA file, client certs, and `--tlsInsecure`).
- **Supports Parallelism**:
  - Export: `--numParallelCollections`
  - Import: `--numInsertionWorkersPerCollection`, `--numParallelCollections`

### Prerequisites
- Install MongoDB Tools (`mongodump`, `mongorestore`).
- Ensure the script has execution permissions:
  ```bash
  chmod +x mongoDump.sh
  ```

### Usage
Run the script and choose an operation:
```bash
./mongoDump.sh
```
You’ll be presented with a menu:
```
################################################
#          1 ==   Export MongoDB data          #
#          2 ==   Import MongoDB data          #
#          3 ==   Both Export & Import         #
#          4 ==   Exit                         #
################################################
```

---

#### Export Data from MongoDB
- This will dump data from MongoDB into a specified local directory.
- Example run:
  ```
  Please enter your choice: 1
  Enter the endpoint information for your MongoDB database (source): 
  Example (localhost:27017/dbname): localhost:27017/sampledb

  Enter MongoDB auth information (leave blank if not required):
  Auth database name: admin
  Username: appuser
  Password: ********

  Use SSL/TLS connection? (yes/no): yes
  Enter the path to the CA certificate file (leave blank if not required):
  CA File (e.g., /etc/mongodb/ssl/mongodb-cert.crt): /etc/ssl/ca.pem
  Enter the path to the client certificate key file (leave blank if not required):
  Client Certificate File (optional):

  Enter the collection name to export from (source) or leave blank to export all collections:
  Example (registrations):            ← (press Enter to export all)

  Specify number of parallel collections for export (leave blank for default): 8

  Enter the local storage location for the export file:
  Example (/tmp): /tmp/exportDir
  ```

- The exported BSON files will be stored in:
  ```
  /tmp/exportDir/sampledb/
  ```

- Behind the scenes, the script issues a `mongodump` command shaped like one of these:

  **All collections**
  ```bash
  mongodump --uri="mongodb://<host:port/db>?ssl=true" <authArgs> <sslArgs>     --tlsInsecure --gzip --out="<dir>"     --numParallelCollections 8
  ```

  **Single collection**
  ```bash
  mongodump --uri="mongodb://<host:port/db>?ssl=true" --collection="<name>" <authArgs> <sslArgs>     --tlsInsecure --gzip --out="<dir>"     --numParallelCollections 8
  ```

---

#### Import Data into Oracle Database API for MongoDB
- This will import BSON files into a MongoDB-compatible Oracle Database (Oracle Database API for MongoDB).
- Example run:
  ```
  Please enter your choice: 2
  Username: matt
  Password: ********
  Hostname (e.g., localhost): localhost
  Oracle schema (target database): matt

  Specify number of insertion workers per collection (leave blank for default): 128
  Specify number of collections to restore in parallel (leave blank for default): 64

  Enter the base directory where BSON files are stored (e.g., /tmp/exportDir/): /tmp/exportDir
  ```

- All collections found in `/tmp/exportDir/` will be imported into the `matt` schema.

- Behind the scenes, the script issues a `mongorestore` command per collection, shaped like:

  ```bash
  mongorestore     --uri="mongodb://matt:********@localhost:27017/matt?authMechanism=PLAIN&authSource=%24external&tls=true&retryWrites=false&loadBalanced=true"     --db matt     --gzip     --collection <collectionName>     --nsInclude "matt.<collectionName>"     --tlsInsecure     --numInsertionWorkersPerCollection 128     --numParallelCollections 64     /tmp/exportDir/matt/<collectionName>.bson.gz
  ```

### Notes  
- Both parallelism options are **optional**, if you press ```enter``` at the prompts, the script will omit them.  
- `--numInsertionWorkersPerCollection` controls how many concurrent worker threads insert into each collection.  
- `--numParallelCollections` controls how many collections are restored at the same time.
- `tlsInsecure` should only be used in lab or dev environmnets.

---

#### Both Export & Import
- Runs export and import back-to-back, preserving the same auth/TLS/parallel prompts for each phase.

#### Logging
- Logs all actions into a timestamped log file (`mongoMover.log`), including which parallel flags were applied (when provided).

---

## `mongoProfileExport.sh` - Database Profiling
### Features
- Enable profiling at level 2 (captures all queries).
- Disable profiling when done.
- Purge profiling data if needed.
- Export profiling data for further analysis.

### Prerequisites
- Install `mongosh` and `mongoexport`.
- Ensure script is executable:
  ```bash
  chmod +x mongoProfileExport.sh
  ```

### Usage
Run:
```bash
./mongoProfileExport.sh
```

You'll be prompted for MongoDB connection details:
```
Enter MongoDB host (default: localhost): localhost
Enter MongoDB port (default: 27017): 27017
Enter MongoDB database name (default: test): myDB
```

Then, select an action:
```
==================== MENU ====================
1. Enable Profiling (Level 2)
2. Disable Profiling
3. Purge Profiling Data
4. Export Profiling Data
5. Exit
=============================================
```

#### Enable Profiling
- Enables full query capture (`setProfilingLevel(2)`).

#### Disable Profiling
- Stops profiling to reduce database overhead.

#### Purge Profiling Data
- Deletes profiling logs to free up storage.

#### Export Profiling Data
- Saves profiling logs as a JSON file for review.

#### Logging
- Logs all actions into a timestamped log file (`mongoProfiling.log`).

---

## Author
Matt DeMarco  
[matthew.demarco@oracle.com](mailto:matthew.demarco@oracle.com)  

---

## Contributing
Feel free to submit issues and pull requests for enhancements.

---

## License
The Universal Permissive License (UPL), Version 1.0  
See LICENSE file.
