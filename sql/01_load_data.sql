/* =====================================================================
   01_load_data.sql
   Loads the 9 Kaggle CSV files. Run from the REPOSITORY ROOT so the
   relative paths to data/ resolve:
       psql -d olist -f sql/01_load_data.sql
   \copy runs client-side, so no superuser rights are needed.
   Load order matters: parent tables before child tables (foreign keys).
   ===================================================================== */

\echo 'Loading customers...'
\copy customers FROM 'data/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading geolocation (~1M rows, takes a moment)...'
\copy geolocation (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state) FROM 'data/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading sellers...'
\copy sellers FROM 'data/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading category translations...'
\copy product_category_translation FROM 'data/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading products...'
\copy products FROM 'data/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading orders...'
\copy orders FROM 'data/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading order items...'
\copy order_items FROM 'data/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading payments...'
\copy order_payments FROM 'data/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading reviews...'
\copy order_reviews (review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp) FROM 'data/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true)

-- Two categories used in products have no English translation in the source file.
INSERT INTO product_category_translation VALUES
    ('pc_gamer', 'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_food_preparers')
ON CONFLICT (product_category_name) DO NOTHING;

ANALYZE;
\echo 'Load complete.'
