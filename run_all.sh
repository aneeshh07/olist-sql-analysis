#!/usr/bin/env bash
# Builds the database and runs every analysis, saving outputs to results/.
# Usage (from repo root):  bash run_all.sh            (database name defaults to "olist")
#                          DB=mydb bash run_all.sh
set -e
DB="${DB:-olist}"
PSQL="psql -d $DB -v ON_ERROR_STOP=1 -q"

echo "1/4 Creating schema..."            ; $PSQL -f sql/00_schema.sql
echo "2/4 Loading CSVs..."               ; $PSQL -f sql/01_load_data.sql
echo "3/4 Creating views & functions..." ; $PSQL -f sql/03_views_functions.sql

echo "4/4 Running data quality checks and analysis..."
mkdir -p results
$PSQL -f sql/02_data_quality.sql > results/02_data_quality.txt
for f in sql/analysis/*.sql; do
  name=$(basename "$f" .sql)
  echo "   -> $name"
  $PSQL -f "$f" > "results/${name}.txt"
done
echo "Done. Outputs are in results/"
