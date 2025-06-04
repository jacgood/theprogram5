#!/bin/bash
set -e

# PostgreSQL initialization script for imported MySQL databases
echo "Initializing PostgreSQL databases from MySQL migration..."

# Create databases that will be imported
databases=(
    "aue"
    "aueoriginal" 
    "domains"
    "dotmed"
    "ebay"
    "goodinc_wrdp1"
    "goodval"
    "goodvaluation"
    "goodvaluation2"
    "goodvaluation3"
    "goodvaluationtest"
    "gvi"
    "gvitest"
    "ids"
    "please_read_me_xmg"
    "test"
    "testing"
    "wordpress"
)

# Create each database
for db in "${databases[@]}"; do
    echo "Creating database: $db"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE DATABASE "$db" WITH ENCODING='UTF8' LC_COLLATE='C' LC_CTYPE='C';
        GRANT ALL PRIVILEGES ON DATABASE "$db" TO $POSTGRES_USER;
EOSQL
done

echo "Database initialization completed!"