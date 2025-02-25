#!/bin/bash

# Script purpose - Execution
# 
# Author: Matt DeMarco (matthew.demarco@oracle.com)
# 
# Example script for the Execution phase of a migration focused on data migration from source to target
# This script can do the following:
# 1. Bulk data export -- single operation exporting data in bulk from MongoDB source to file system location
# 2. Bulk data import -- single operation importing data into Oracle Database API for MongoDB
# 3. BOTH data export and data import -- combined operation for exporting data in bulk and importing to Oracle Database API for MongoDB
#


# Utility functions
# UX menu selection options
function startUp()
{
    clear
    echo "############################################################"
    echo "# This will export or import data for your MongoDB system  #"
    echo "############################################################"

    echo
    echo "################################################"
    echo "#                                              #"
    echo "#    What would you like to do ?               #"
    echo "#                                              #"
    echo "#          1 ==   Export MongoDB data          #"
    echo "#          2 ==   Import MongoDB data          #"
    echo "#          3 ==   Both Export & Import         #"
    echo "#          4 ==   Exit                         #"
    echo "#                                              #"
    echo "################################################"
    echo
    read -p "Please enter your choice: " doWhat
}

function doNothing()
{
    echo "Exiting..."
    exit 0
}

function badChoice()
{
    # Increment the invalid choice counter
    ((INVALID_COUNT++))
    # Set maximum allowed invalid attempts
    MAX_INVALID=3

    echo "Invalid choice, please try again..."
    echo "Attempt $INVALID_COUNT of $MAX_INVALID."

    # Check if invalid attempts exceed the max allowed
    if [ "$INVALID_COUNT" -ge "$MAX_INVALID" ]
    then
        echo "Too many invalid attempts. Exiting the script..."
        exit 1  # Exit the script
    fi

    sleep 2
}

# Function to check if a command exists in PATH
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate inputs
validate_input() 
{
    if [[ -z "$1" ]]; then
        echo "Error: $2 cannot be empty."
        exit 1
    fi
}

# Generate runtime-based log file name
RUNTIME=$(date +%m_%d_%y_%H%M%S)
LOG_FILE="${RUNTIME}_mongoMover.log"

# Logging function
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}


# Check for required MongoDB dump tool
chkMongodump()
{
    if check_command "mongodump"; then
        mongodump_path=$(command -v mongodump)
    else
        echo "mongodump not found in PATH."
        read -p "Please enter the full path to the mongodump binary: " mongodump_path
        validate_input "$mongodump_path" "mongodump binary path"
        
        # Ensure valid binary path
        if [[ ! -x "$mongodump_path" ]]; then
            echo "Error: Invalid mongodump path. Ensure it's an executable."
            exit 1
        fi
        
        export PATH="$(dirname "$mongodump_path"):$PATH"
    fi
}


# Check for required MongoDB restore tool
chkMongorestore()
{
    if ! check_command "mongorestore"; then
        echo "mongorestore not found in PATH."
        read -p "Please enter the full path to the mongorestore binary: " mongorestore_path
        validate_input "$mongorestore_path" "mongorestore binary path"
        export PATH="$mongorestore_path:$PATH"
    else
        mongorestore_path="mongorestore"
    fi
}


# Use mongodump to export data and indexes from MongoDB source
# Menu item 1
exportSrc()
{
    chkMongodump  # Ensure mongodump_path is set

    log_action "Starting MongoDB export process."

    echo "################################################"
    echo "Enter the endpoint information for your MongoDB database (source): "
    read -p "Example (localhost:27017/dbname): " srcMongo
    validate_input "$srcMongo" "Source MongoDB URI"

    log_action "User provided MongoDB URI: mongodb://$srcMongo"

    # Add username/password for authentication
    read -p "Enter MongoDB username (leave blank if not required): " MONGO_USER
    read -s -p "Enter MongoDB password (leave blank if not required): " MONGO_PASS
    echo ""

    echo "Enter the collection name to export from (source) or leave blank to export all collections: "
    read -p "Example (registrations): " srcCol

    read -p "Specify number of parallel collections for export (leave blank for default): " numParallelCollections

    parallelArg=""
    if [[ -n "$numParallelCollections" ]]; then
        parallelArg="--numParallelCollections=$numParallelCollections"
    fi

    echo "Enter the local storage location for the export file: "
    read -p "Example (/tmp): " jsonLoc
    validate_input "$jsonLoc" "Export file location"

    log_action "Export directory specified: $jsonLoc"

    echo "################################################"

    jsonLoc=$(echo "$jsonLoc" | sed 's:/*$::')

    if [[ ! -d "$jsonLoc" ]]; then
        mkdir -p "$jsonLoc"
        echo "Created directory: $jsonLoc"
        log_action "Created export directory: $jsonLoc"
    fi

    authArgs=""
    if [[ -n "$MONGO_USER" && -n "$MONGO_PASS" ]]; then
        authArgs="--username=\"$MONGO_USER\" --password=\"$MONGO_PASS\" --authenticationDatabase=admin"
    fi

    if [[ -z "$srcCol" ]]; then
        echo "Exporting all collections from source MongoDB..."
        dumpCommand="$mongodump_path --uri=\"mongodb://$srcMongo\" $authArgs $parallelArg --out=\"$jsonLoc\""
        log_action "Exporting all collections from: mongodb://$srcMongo"
    else
        echo "Exporting data from source MongoDB collection: $srcCol"
        dumpCommand="$mongodump_path --uri=\"mongodb://$srcMongo\" --collection=\"$srcCol\" $authArgs $parallelArg --out=\"$jsonLoc\""
        log_action "Exporting collection: $srcCol from: mongodb://$srcMongo"
    fi

    echo "Running: $dumpCommand"
    log_action "Executing command: $dumpCommand"

    eval "$dumpCommand"
    if [[ $? -ne 0 ]]; then
        echo "Error: mongodump failed. Check source MongoDB details."
        log_action "Error: mongodump failed."
        exit 1
    fi

    log_action "MongoDB export completed successfully. Data saved to: $jsonLoc"

    echo "################################################"
    echo "        Export saved to: $jsonLoc               "
    echo "################################################"

    sleep 5
}




# Use mongorestore to import data and attempt to restore indexes into Oracle Database API for MongoDB
# Menu item 2
importTgt()
{
    chkMongorestore  # Ensure mongorestore_path is set

    log_action "Starting MongoDB import process."

    echo "################################################"
    echo "Enter the connection details for your Oracle Database API for MongoDB (target):"
    read -p "Username: " tgtUser
    validate_input "$tgtUser" "Username"

    read -sp "Password: " tgtPass
    echo
    validate_input "$tgtPass" "Password"

    read -p "Hostname (e.g., localhost): " tgtHost
    validate_input "$tgtHost" "Hostname"

    read -p "MongoDB API enabled Oracle schema name (target database name): " tgtDb
    validate_input "$tgtDb" "Oracle schema"

    log_action "Target database set to: $tgtDb"

    encode_url() {
        echo -n "$1" | jq -sRr @uri
    }
    encoded_pass=$(encode_url "$tgtPass")

    tgtMongo="${tgtUser}:${encoded_pass}@${tgtHost}:27017/${tgtDb}?authMechanism=PLAIN&authSource=%24external&tls=true&retryWrites=false&loadBalanced=true"
    echo "Constructed Target MongoDB URI: mongodb://${tgtMongo}"

    log_action "MongoDB import target URI: mongodb://${tgtMongo}"

    echo "################################################"

    read -p "Enter the base directory where BSON files are stored (e.g., /tmp/exportDir/): " bsonBaseDir
    validate_input "$bsonBaseDir" "BSON export directory"

    log_action "User provided BSON export directory: $bsonBaseDir"

    if [[ ! -d "$bsonBaseDir" ]]; then
        echo "Error: The specified directory does not exist: $bsonBaseDir"
        log_action "Error: BSON directory not found: $bsonBaseDir"
        exit 1
    fi

    log_action "Scanning for BSON files in: $bsonBaseDir"

    bsonFiles=($(find "$bsonBaseDir" -type f -name "*.bson"))

    if [[ ${#bsonFiles[@]} -eq 0 ]]; then
        echo "Error: No BSON files found in the specified directory: $bsonBaseDir"
        log_action "Error: No BSON files found in: $bsonBaseDir"
        exit 1
    fi

    for bsonFile in "${bsonFiles[@]}"; do
        collectionName=$(basename "$bsonFile" .bson)
        dbName=$(basename "$(dirname "$bsonFile")")

        echo "Importing collection: $collectionName from $bsonFile into target database: $tgtDb"
        log_action "Importing collection: $collectionName from file: $bsonFile into $tgtDb"

        $mongorestore_path --uri="mongodb://$tgtMongo" --db="$tgtDb" --tlsInsecure --collection="$collectionName" --nsInclude="$tgtDb.$collectionName" "$bsonFile"

        if [[ $? -ne 0 ]]; then
            echo "Error: mongorestore failed for collection: $collectionName"
            log_action "Error: mongorestore failed for collection: $collectionName"
            exit 1
        fi
    done

    log_action "MongoDB import completed successfully. Data imported into: $tgtDb"

    echo "################################################"
    echo "       Restore complete! All data has been imported into: $tgtDb"
    echo "################################################"

    sleep 5
}


# Do both export and import in one pass
# Menu item 3
doBoth()
{
    exportSrc
    importTgt

}



# Main script
# Initialize the invalid attempt counter to escape the while loop
INVALID_COUNT=0 
while true
do
    startUp
    case $doWhat in
        1) exportSrc ;;
        2) importTgt ;;
        3) doBoth ;;
        4) doNothing ;;
        *) badChoice ;;
    esac
done













