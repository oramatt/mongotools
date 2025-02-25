# MongoDB Migration and Profiling Utilities

This repository contains two Bash scripts to assist with MongoDB data migration and profiling analysis. These scripts enable exporting/importing data between MongoDB and Oracle Database API for MongoDB, as well as reviewing MongoDB profiling data.

## Scripts Overview
| Script | Purpose |
|--------|---------|
| [`mongoDump.sh`](#mongodumpsh-data-migration) | Bulk export/import of MongoDB data for migration. |
| [`mongoProfileExport.sh`](#mongoprofileexportsh-database-profiling) | Enables profiling, exports, and analyzes MongoDB performance. |

---

## `mongoDump.sh` - Data Migration
### Features
- Export MongoDB data into BSON format using `mongodump`.
- Import BSON data into Oracle Database API for MongoDB using `mongorestore`.
- Appends data to existing collections instead of overwriting.
- Allows user to select the source and target MongoDB details.
- Handles missing BSON files gracefully and logs all actions.

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
You'll be presented with a menu:
```
################################################
#          1 ==   Export MongoDB data          #
#          2 ==   Import MongoDB data          #
#          3 ==   Both Export & Import         #
#          4 ==   Exit                         #
################################################
```

#### Export Data from MongoDB
- This will dump data from MongoDB into a specified local directory.
- Example run:
  ```
  Please enter your choice: 1
  Enter MongoDB connection (example: localhost:27017/myDB): localhost:27017/myDB
  Enter export directory (example: /tmp/exportDir/): /tmp/exportDir/
  ```
- The exported BSON files will be stored in:
  ```
  /tmp/exportDir/myDB/
  ```

#### Import Data into Oracle Database API for MongoDB
- This will import BSON files into a MongoDB-compatible Oracle DB.
- Example:
  ```
  Please enter your choice: 2
  Enter target MongoDB schema: oracleSchema
  Enter BSON file directory: /tmp/exportDir/
  ```
- All collections found in `/tmp/exportDir/` will be imported into `oracleSchema`.

#### Both Export & Import
- Runs export and import back-to-back.

#### Logging
- Logs all actions into a timestamped log file (`mongoMover.log`).

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
