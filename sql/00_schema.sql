/* =====================================================================
   00_schema.sql
   Creates the Olist e-commerce schema in PostgreSQL.
   - Primary keys and foreign keys enforce data integrity.
   - Indexes speed up the joins and date filters used in the analysis.
   Run:  psql -d olist -f sql/00_schema.sql
   ===================================================================== */

DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders,
                     products, product_category_translation, sellers,
                     customers, geolocation CASCADE;

-- One row per (customer, order). The same person can have several
-- customer_id values; customer_unique_id identifies the real person.
CREATE TABLE customers (
    customer_id              VARCHAR(32) PRIMARY KEY,
    customer_unique_id       VARCHAR(32) NOT NULL,
    customer_zip_code_prefix VARCHAR(10),
    customer_city            TEXT,
    customer_state           CHAR(2)
);

-- No natural key: zip prefixes repeat with many lat/lng points.
CREATE TABLE geolocation (
    geolocation_id              SERIAL PRIMARY KEY,
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat             NUMERIC(18,14),
    geolocation_lng             NUMERIC(18,14),
    geolocation_city            TEXT,
    geolocation_state           CHAR(2)
);

CREATE TABLE sellers (
    seller_id              VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city            TEXT,
    seller_state           CHAR(2)
);

CREATE TABLE product_category_translation (
    product_category_name         TEXT PRIMARY KEY,
    product_category_name_english TEXT
);

-- Column names fix the dataset's original "lenght" misspelling.
-- NUMERIC is used because the raw CSV can contain values such as "40.0".
CREATE TABLE products (
    product_id                 VARCHAR(32) PRIMARY KEY,
    product_category_name      TEXT,
    product_name_length        NUMERIC,
    product_description_length NUMERIC,
    product_photos_qty         NUMERIC,
    product_weight_g           NUMERIC,
    product_length_cm          NUMERIC,
    product_height_cm          NUMERIC,
    product_width_cm           NUMERIC
);

CREATE TABLE orders (
    order_id                      VARCHAR(32) PRIMARY KEY,
    customer_id                   VARCHAR(32) NOT NULL REFERENCES customers(customer_id),
    order_status                  VARCHAR(20) NOT NULL,
    order_purchase_timestamp      TIMESTAMP   NOT NULL,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

-- One row per item in an order (an order with 3 items has 3 rows).
CREATE TABLE order_items (
    order_id            VARCHAR(32) NOT NULL REFERENCES orders(order_id),
    order_item_id       INT         NOT NULL,
    product_id          VARCHAR(32) NOT NULL REFERENCES products(product_id),
    seller_id           VARCHAR(32) NOT NULL REFERENCES sellers(seller_id),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    freight_value       NUMERIC(10,2) NOT NULL CHECK (freight_value >= 0),
    PRIMARY KEY (order_id, order_item_id)
);

-- An order can be paid with several methods (e.g. card + voucher).
CREATE TABLE order_payments (
    order_id             VARCHAR(32) NOT NULL REFERENCES orders(order_id),
    payment_sequential   INT         NOT NULL,
    payment_type         VARCHAR(20) NOT NULL,
    payment_installments INT,
    payment_value        NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);

-- review_id is NOT unique in the raw data, so a surrogate key is used.
CREATE TABLE order_reviews (
    review_pk               SERIAL PRIMARY KEY,
    review_id               VARCHAR(32) NOT NULL,
    order_id                VARCHAR(32) NOT NULL REFERENCES orders(order_id),
    review_score            SMALLINT    CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- Indexes on the columns used most in joins and filters
CREATE INDEX idx_customers_unique   ON customers (customer_unique_id);
CREATE INDEX idx_orders_customer    ON orders (customer_id);
CREATE INDEX idx_orders_purchase_ts ON orders (order_purchase_timestamp);
CREATE INDEX idx_orders_status      ON orders (order_status);
CREATE INDEX idx_items_product      ON order_items (product_id);
CREATE INDEX idx_items_seller       ON order_items (seller_id);
CREATE INDEX idx_reviews_order      ON order_reviews (order_id);
CREATE INDEX idx_geo_zip            ON geolocation (geolocation_zip_code_prefix);
