-- ==============================================================================
-- PROJET : OLIST E-COMMERCE
-- PHASE 4 : NETTOYAGE ET TRANSFORMATION DES DONNÉES (DATA CLEANING)
-- FICHIER : 02_data_cleaning_olist.sql
-- DESCRIPTION : Cast des types, suppression des guillemets parasites, 
--               et traitement des anomalies détectées lors du profiling.
-- ==============================================================================

USE olist;
GO
-- ==============================================================================
-- 1. NETTOYAGE ET TRANSFORMATION : clean.orders
-- ==============================================================================

-- demande à SQL Server : « Donnes-moi le numéro ID de la table utilisateur clean.orders si elle existe.

IF OBJECT_ID('clean.orders', 'U') IS NOT NULL 
    DROP TABLE clean.orders;

SELECT 
    -- Nettoyage de l'identifiant (Suppression des guillemets)
    REPLACE(order_id, '"', '') AS order_id,
    REPLACE(customer_id, '"', '') AS customer_id,
    
    -- Normalisation du statut
    TRIM(order_status) AS order_status,
    
    -- Conversion de type : NVARCHAR -> DATETIME2
    TRY_CONVERT(DATETIME2, order_purchase_timestamp) AS order_purchase_timestamp,
    TRY_CONVERT(DATETIME2, order_approved_at) AS order_approved_at,
    TRY_CONVERT(DATETIME2, order_delivered_carrier_date) AS order_delivered_carrier_date,
    TRY_CONVERT(DATETIME2, order_delivered_customer_date) AS order_delivered_customer_date,
    TRY_CONVERT(DATETIME2, order_estimated_delivery_date) AS order_estimated_delivery_date

INTO clean.orders
FROM raw.orders;

select * from clean.orders;
select * from raw.customers;

-- 2. NETTOYAGE ET TRANSFORMATION : clean.customers

IF OBJECT_ID('clean.customers', 'U') IS NOT NULL 
    DROP TABLE clean.customers;
select 

trim(replace(customer_id,'"','')) as cleaned_customer_id,
trim(replace(customer_unique_id,'"','')) as cleaned_customer_unique_id,

try_convert(int,customer_zip_code_prefix) as cleaned_customer_zip_code_prefix,
trim(lower(customer_city)) as cleaned_customer_city,
UPPER(TRIM(customer_state)) as cleaned_customer_state

INTO clean.customers
FROM raw.customers;

select * from clean.customers;




-- ==============================================================================
-- 3. NETTOYAGE ET TRANSFORMATION : clean.geolocation
-- ==============================================================================
select * from raw.geolocation;
select distinct geolocation_state from raw.geolocation;

IF OBJECT_ID('clean.geolocation', 'U') IS NOT NULL 
    DROP TABLE clean.geolocation;

SELECT 
    -- Nettoyage et conversion du code postal
    TRY_CONVERT(INT, REPLACE(geolocation_zip_code_prefix, '"', '')) AS geolocation_zip_code_prefix,
    
    -- Conversion des coordonnées géographiques en FLOAT
    TRY_CONVERT(FLOAT, geolocation_lat) AS geolocation_lat,
    TRY_CONVERT(FLOAT, geolocation_lng) AS geolocation_lng,
    
    -- Normalisation de la ville et de l'état
    TRIM(LOWER(geolocation_city)) AS geolocation_city,
    UPPER(TRIM(geolocation_state)) AS geolocation_state

INTO clean.geolocation
FROM raw.geolocation;

-- Vérification
SELECT TOP 10 * FROM clean.geolocation;


-- ==============================================================================
-- 4. NETTOYAGE ET TRANSFORMATION : clean.order_items
-- ==============================================================================
select * from raw.order_items;

IF OBJECT_ID('clean.order_items', 'U') IS NOT NULL 
    DROP TABLE clean.order_items;

SELECT 
    -- Nettoyage des clés (Suppression des guillemets)
    TRIM(REPLACE(order_id, '"', '')) AS order_id,
    TRY_CONVERT(INT, order_item_id) AS order_item_id,
    TRIM(REPLACE(product_id, '"', '')) AS product_id,
    TRIM(REPLACE(seller_id, '"', '')) AS seller_id,
    
    -- Conversion de la date limite d'expédition
    TRY_CONVERT(DATETIME2, shipping_limit_date) AS shipping_limit_date,
    
    -- Conversion des montants financiers
    TRY_CONVERT(DECIMAL(10,2), price) AS price,
    TRY_CONVERT(DECIMAL(10,2), freight_value) AS freight_value

INTO clean.order_items
FROM raw.order_items;

-- Vérification
SELECT TOP 10 * FROM clean.order_items;




-- ==============================================================================
-- 5. NETTOYAGE ET TRANSFORMATION : clean.order_payments
-- ==============================================================================

select * from raw.order_payments;


IF OBJECT_ID('clean.order_payments', 'U') IS NOT NULL 
    DROP TABLE clean.order_payments;

SELECT 
    -- Nettoyage de la clé (Suppression des guillemets)
    TRIM(REPLACE(order_id, '"', '')) AS order_id,
    
    -- Conversion des entiers et normalisation du texte
    TRY_CONVERT(INT, payment_sequential) AS payment_sequential,
    TRIM(LOWER(payment_type)) AS payment_type,
    TRY_CONVERT(INT, payment_installments) AS payment_installments,
    
    -- Conversion du montant financier
    TRY_CONVERT(DECIMAL(10,2), payment_value) AS payment_value

INTO clean.order_payments
FROM raw.order_payments
-- Exclusion des 11 anomalies métiers détectées en Phase 3
WHERE TRY_CONVERT(DECIMAL(10,2), payment_value) > 0 
  AND TRY_CONVERT(INT, payment_installments) >= 1;

-- Vérification
SELECT TOP 10 * FROM clean.order_payments;





-- ==============================================================================
-- 6. NETTOYAGE ET TRANSFORMATION : clean.order_reviews
-- ==============================================================================
select * from raw.order_reviews;

IF OBJECT_ID('clean.order_reviews', 'U') IS NOT NULL 
    DROP TABLE clean.order_reviews;

SELECT 
    -- Nettoyage préventif des identifiants (Guillemets + Espaces)
    TRIM(REPLACE(review_id, '"', '')) AS review_id,
    TRIM(REPLACE(order_id, '"', '')) AS order_id,
    
    -- Conversion du score d'évaluation en entier
    TRY_CONVERT(INT, review_score) AS review_score,
    
    -- Nettoyage des espaces sur le texte (les NULL restent NULL)
    TRIM(review_comment_title) AS review_comment_title,
    TRIM(review_comment_message) AS review_comment_message,
    
    -- Conversion des horodatages en DATETIME2
    TRY_CONVERT(DATETIME2, review_creation_date) AS review_creation_date,
    TRY_CONVERT(DATETIME2, review_answer_timestamp) AS review_answer_timestamp

INTO clean.order_reviews
FROM raw.order_reviews;

-- Vérification
SELECT TOP 10 * FROM clean.order_reviews;


-- ==============================================================================
-- 7. NETTOYAGE ET TRANSFORMATION : clean.products
-- ==============================================================================

IF OBJECT_ID('clean.products', 'U') IS NOT NULL 
    DROP TABLE clean.products;

SELECT 
    -- Nettoyage de l'identifiant
    TRIM(REPLACE(product_id, '"', '')) AS product_id,
    
    -- Normalisation du nom de catégorie
    TRIM(LOWER(product_category_name)) AS product_category_name,
    
    -- Conversion des caractéristiques textuelles
    TRY_CONVERT(INT, product_name_lenght) AS product_name_lenght,
    TRY_CONVERT(INT, product_description_lenght) AS product_description_lenght,
    TRY_CONVERT(INT, product_photos_qty) AS product_photos_qty,
    
    -- Conversion des dimensions physiques
    TRY_CONVERT(FLOAT, product_weight_g) AS product_weight_g,
    TRY_CONVERT(FLOAT, product_length_cm) AS product_length_cm,
    TRY_CONVERT(FLOAT, product_height_cm) AS product_height_cm,
    TRY_CONVERT(FLOAT, product_width_cm) AS product_width_cm

INTO clean.products
FROM raw.products
-- Exclusion des 4 anomalies physiques (poids ou dimensions <= 0)
WHERE (TRY_CONVERT(FLOAT, product_weight_g) > 0 OR product_weight_g IS NULL)
  AND (TRY_CONVERT(FLOAT, product_length_cm) > 0 OR product_length_cm IS NULL)
  AND (TRY_CONVERT(FLOAT, product_height_cm) > 0 OR product_height_cm IS NULL)
  AND (TRY_CONVERT(FLOAT, product_width_cm) > 0 OR product_width_cm IS NULL);

-- Vérification
SELECT TOP 10 * FROM clean.products;



-- ==============================================================================
-- 8. NETTOYAGE ET TRANSFORMATION : clean.sellers
-- ==============================================================================

IF OBJECT_ID('clean.sellers', 'U') IS NOT NULL 
    DROP TABLE clean.sellers;

SELECT 
    -- Nettoyage de l'identifiant
    TRIM(REPLACE(seller_id, '"', '')) AS seller_id,
    
    -- Conversion du code postal
    TRY_CONVERT(INT, seller_zip_code_prefix) AS seller_zip_code_prefix,
    
    -- Normalisation de la ville et de l'état
    TRIM(LOWER(seller_city)) AS seller_city,
    UPPER(TRIM(seller_state)) AS seller_state

INTO clean.sellers
FROM raw.sellers;

-- Vérification
SELECT TOP 10 * FROM clean.sellers;

-- ==============================================================================
-- 9. NETTOYAGE ET TRANSFORMATION : clean.product_category_translation
-- ==============================================================================

IF OBJECT_ID('clean.product_category_translation', 'U') IS NOT NULL 
    DROP TABLE clean.product_category_translation;

SELECT 
    TRIM(LOWER(product_category_name)) AS product_category_name,
    TRIM(LOWER(product_category_name_english)) AS product_category_name_english

INTO clean.product_category_translation
FROM raw.product_category_translation;

-- Vérification
SELECT TOP 10 * FROM clean.product_category_translation;