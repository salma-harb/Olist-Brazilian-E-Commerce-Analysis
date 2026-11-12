
-- But : créer la base olist, les 3 schémas et les tables raw
create database olist;

use olist;
go
create schema raw;
go
CREATE SCHEMA clean;
GO
CREATE SCHEMA analytics;
GO
use olist;
go
SELECT name FROM sys.schemas WHERE name IN ('raw', 'clean', 'analytics');

-- 3. Créer les 9 tables raw (une par CSV)
-- Tout en NVARCHAR : les vrais types viendront dans clean
USE olist;
GO

DROP TABLE IF EXISTS raw.customers;
CREATE TABLE raw.customers (
    customer_id                NVARCHAR(50),
    customer_unique_id         NVARCHAR(50),
    customer_zip_code_prefix   NVARCHAR(10),
    customer_city              NVARCHAR(100),
    customer_state             NVARCHAR(10)
);

DROP TABLE IF EXISTS raw.geolocation;
CREATE TABLE raw.geolocation (
    geolocation_zip_code_prefix NVARCHAR(10),
    geolocation_lat             NVARCHAR(50),
    geolocation_lng             NVARCHAR(50),
    geolocation_city            NVARCHAR(100),
    geolocation_state           NVARCHAR(10)
);

DROP TABLE IF EXISTS raw.order_items;
CREATE TABLE raw.order_items (
    order_id             NVARCHAR(50),
    order_item_id        NVARCHAR(10),
    product_id           NVARCHAR(50),
    seller_id            NVARCHAR(50),
    shipping_limit_date  NVARCHAR(50),
    price                NVARCHAR(50),
    freight_value        NVARCHAR(50)
);

DROP TABLE IF EXISTS raw.order_payments;
CREATE TABLE raw.order_payments (
    order_id              NVARCHAR(50),
    payment_sequential    NVARCHAR(10),
    payment_type          NVARCHAR(50),
    payment_installments  NVARCHAR(10),
    payment_value         NVARCHAR(50)
);

DROP TABLE IF EXISTS raw.order_reviews;
CREATE TABLE raw.order_reviews (
    review_id                NVARCHAR(50),
    order_id                 NVARCHAR(50),
    review_score             NVARCHAR(10),
    review_comment_title     NVARCHAR(500),
    review_comment_message   NVARCHAR(MAX),
    review_creation_date     NVARCHAR(50),
    review_answer_timestamp  NVARCHAR(50)
);

DROP TABLE IF EXISTS raw.orders;
CREATE TABLE raw.orders (
    order_id                       NVARCHAR(50),
    customer_id                    NVARCHAR(50),
    order_status                   NVARCHAR(50),
    order_purchase_timestamp       NVARCHAR(50),
    order_approved_at              NVARCHAR(50),
    order_delivered_carrier_date   NVARCHAR(50),
    order_delivered_customer_date  NVARCHAR(50),
    order_estimated_delivery_date  NVARCHAR(50)
);

DROP TABLE IF EXISTS raw.products;
CREATE TABLE raw.products (
    product_id                  NVARCHAR(50),
    product_category_name       NVARCHAR(100),
    product_name_lenght         NVARCHAR(10),
    product_description_lenght  NVARCHAR(10),
    product_photos_qty          NVARCHAR(10),
    product_weight_g            NVARCHAR(20),
    product_length_cm           NVARCHAR(20),
    product_height_cm           NVARCHAR(20),
    product_width_cm            NVARCHAR(20)
);

DROP TABLE IF EXISTS raw.sellers;
CREATE TABLE raw.sellers (
    seller_id                NVARCHAR(50),
    seller_zip_code_prefix   NVARCHAR(10),
    seller_city              NVARCHAR(100),
    seller_state             NVARCHAR(10)
);

DROP TABLE IF EXISTS raw.product_category_translation;
CREATE TABLE raw.product_category_translation (
    product_category_name          NVARCHAR(100),
    product_category_name_english  NVARCHAR(100)
);
GO

SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'raw';










