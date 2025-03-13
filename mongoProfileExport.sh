#!/bin/bash

# Script Purpose - Planning
#
# Author: Matt DeMarco (matthew.demarco@oracle.com)
#
# Example script for the Planning phase of a migration focused on reviewing MongoDB operations relative to 23ai support
# This script can do the following:
# 1. Enable profiling for a MongoDB database at level 2
# 2. Disable profiling for a MongoDB database
# 3. Purge profiling data for a MongoDB database
# 4. Export MongoDB profiling data to a user-specified location
#

# Clear screen for readability
clear

# Generate runtime-based log file name
RUNTIME=$(date +%m_%d_%y_%H%M%S)
LOG_FILE="${RUNTIME}_mongoProfiling.log"

# Logging function
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Disclaimers and user confirmation
echo "###################################################################################################"
echo "WARNING: Enabling profiling on a MongoDB database may impact the performance of production systems."
echo "Additionally, exporting profile data could expose sensitive information."
echo "###################################################################################################"
read -p "Do you accept these caveats and wish to proceed? (yes/no): " ACCEPT

if [[ "$ACCEPT" != "yes" ]]; then
    log_action "User denied the disclaimers and aborted the script."
    echo "Operation aborted by user."
    exit 1
fi

log_action "User accepted the disclaimers and proceeded with the script."

# Validate mongosh availability
validate_mongosh() {
    if ! command -v mongosh &>/dev/null; then
        echo "mongosh is not found in your PATH."
        read -p "Please provide the full path to the mongosh binary: " MONGOSH_PATH
        if [[ ! -x "$MONGOSH_PATH" ]]; then
            echo "Invalid path to mongosh binary. Please ensure the file exists and is executable."
            log_action "Failed: mongosh not found or invalid path."
            exit 1
        fi
        MONGOSH="$MONGOSH_PATH"
    else
        MONGOSH=$(command -v mongosh)
    fi
}

# Prompt user for MongoDB connection details
mongo_connection() {
    echo "Prompting for MongoDB connection details..."
    read -p "Enter MongoDB host (default: localhost): " MONGO_HOST
    MONGO_HOST=${MONGO_HOST:-localhost}

    read -p "Enter MongoDB port (default: 27017): " MONGO_PORT
    MONGO_PORT=${MONGO_PORT:-27017}

    read -p "Enter MongoDB database name (default: test): " DATABASE
    DATABASE=${DATABASE:-test}

    read -p "Enter MongoDB username (leave blank if not required): " MONGO_USER
    read -s -p "Enter MongoDB password (leave blank if not required): " MONGO_PASS
    echo
}

# Validate MongoDB connection
validate_connection() {
    echo "Validating connection to MongoDB..."
    CONNECTION_STRING="mongodb://$MONGO_HOST:$MONGO_PORT"
    if [[ -n "$MONGO_USER" && -n "$MONGO_PASS" ]]; then
        CONNECTION_STRING="mongodb://$MONGO_USER:$MONGO_PASS@$MONGO_HOST:$MONGO_PORT"
    fi
    $MONGOSH --eval "db.stats()" "$CONNECTION_STRING/$DATABASE" &>/dev/null
    if [ $? -ne 0 ]; then
        log_action "Failed to connect to MongoDB with the provided connection details."
        echo "Failed to connect to MongoDB. Please check your connection details."
        exit 1
    fi
    log_action "Connection to MongoDB validated successfully."
    echo "Connection successful."
}

# Check current profiling state
check_profiling_state() {
    echo "Checking current profiling state..."
    PROFILING_LEVEL=$($MONGOSH --quiet --eval "db.getProfilingStatus().was" "$CONNECTION_STRING/$DATABASE")
    if [[ "$PROFILING_LEVEL" -eq 0 ]]; then
        echo "Profiling is currently DISABLED for the database $DATABASE."
        log_action "Profiling is currently DISABLED for the database $DATABASE."
    elif [[ "$PROFILING_LEVEL" -eq 1 ]]; then
        echo "Profiling is currently ENABLED at level 1 (slow operations only) for the database $DATABASE."
        log_action "Profiling is currently ENABLED at level 1 for the database $DATABASE."
    elif [[ "$PROFILING_LEVEL" -eq 2 ]]; then
        echo "Profiling is currently ENABLED at level 2 (all operations) for the database $DATABASE."
        log_action "Profiling is currently ENABLED at level 2 for the database $DATABASE."
    else
        echo "Unable to determine the profiling state."
        log_action "Unable to determine the profiling state for the database $DATABASE."
    fi
}

# Enable profiling
enable_profiling() {
    $MONGOSH --eval "db.setProfilingLevel(2); print('Profiling enabled at level 2 for database $DATABASE');" "$CONNECTION_STRING/$DATABASE"
    log_action "Enabled profiling at level 2 for database $DATABASE"
}

# Disable profiling
disable_profiling() {
    $MONGOSH --eval "db.setProfilingLevel(0); print('Profiling disabled for database $DATABASE');" "$CONNECTION_STRING/$DATABASE"
    log_action "Disabled profiling for database $DATABASE"
}

# Purge profiling data
purge_profiling_data() {
    $MONGOSH --eval "db.system.profile.drop(); print('Profiling data purged for database $DATABASE');" "$CONNECTION_STRING/$DATABASE"
    log_action "Purged profiling data for database $DATABASE"
}

# Export profiling data
export_profiling_data() {
    read -p "Enter export file path (e.g., /path/to/profiling_data.json): " EXPORT_PATH
    if [ -z "$EXPORT_PATH" ]; then
        echo "Invalid file path. Please try again."
        log_action "Failed export: Invalid file path."
        return
    fi
    mongoexport --uri="$CONNECTION_STRING" --db="$DATABASE" --collection="system.profile" --out="$EXPORT_PATH"
    if [ $? -eq 0 ]; then
        echo "Profiling data exported to $EXPORT_PATH"
        log_action "Exported profiling data to $EXPORT_PATH for database $DATABASE"
    else
        echo "Failed to export profiling data. Ensure the path is writable and you have permissions."
        log_action "Failed to export profiling data for database $DATABASE"
    fi
}

# Validate mongosh
validate_mongosh

# Prompt and validate connection
mongo_connection
validate_connection

# Check profiling state
check_profiling_state

# Main Menu
INVALID_COUNT=0
MAX_INVALID=3

while true; do
    echo "==================== MENU ===================="
    echo "1. Enable Profiling (Level 2)"
    echo "2. Disable Profiling"
    echo "3. Purge Profiling Data"
    echo "4. Export Profiling Data"
    echo "5. Exit"
    echo "============================================="
    read -p "Enter your choice: " CHOICE

    case $CHOICE in
        1) enable_profiling ;;
        2) disable_profiling ;;
        3) purge_profiling_data ;;
        4) export_profiling_data ;;
        5) 
            log_action "User exited the script."
            echo "Exiting..."
            exit 0 
            ;;
        *) 
            echo "Invalid choice. Please try again."
            ((INVALID_COUNT++))
            if [ "$INVALID_COUNT" -ge "$MAX_INVALID" ]; then
                log_action "Script exited due to too many invalid attempts."
                echo "Too many invalid attempts. Exiting."
                exit 1
            fi
            ;;
    esac
done
