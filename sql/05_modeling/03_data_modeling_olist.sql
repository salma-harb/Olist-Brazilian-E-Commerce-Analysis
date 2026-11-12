-- ==============================================================================
-- SCRIPT : 03_data_modeling_olist.sql
-- OBJECTIF : Construction du Schéma en Étoile (Star Schema)
-- ==============================================================================

USE olist;
GO

-- 1. CRÉATION DE LA DIMENSION : analytics.dim_customers
IF OBJECT_ID('analytics.dim_customers', 'U') IS NOT NULL 
    DROP TABLE analytics.dim_customers;

-- Création de la structure de la table avec la clé primaire
CREATE TABLE analytics.dim_customers (
    customer_key BIGINT IDENTITY(1,1) NOT NULL,
    customer_id NVARCHAR(4000) NULL,
    customer_unique_id NVARCHAR(4000) NULL,
    customer_zip_code_prefix INT NULL,
    customer_city NVARCHAR(100) NULL,
    customer_state NVARCHAR(10) NULL,
    CONSTRAINT PK_dim_customers PRIMARY KEY (customer_key)
);

-- Insertion des données nettoyées
INSERT INTO analytics.dim_customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT 
    cleaned_customer_id,
    cleaned_customer_unique_id,
    cleaned_customer_zip_code_prefix,
    cleaned_customer_city,
    cleaned_customer_state
FROM clean.customers;

-- Vérification
SELECT TOP 10 * FROM analytics.dim_customers;


-- ==============================================================================
-- 2. CRÉATION DE LA DIMENSION : analytics.dim_products
-- ==============================================================================

USE olist;
GO

IF OBJECT_ID('analytics.dim_products', 'U') IS NOT NULL 
    DROP TABLE analytics.dim_products;

-- Création du moule / structure de la table
CREATE TABLE analytics.dim_products (
    product_key BIGINT IDENTITY(1,1) NOT NULL,
    product_id NVARCHAR(4000) NULL,
    product_category_name NVARCHAR(100) NULL,
    product_category_name_english NVARCHAR(100) NULL,
    product_name_lenght INT NULL,
    product_description_lenght INT NULL,
    product_photos_qty INT NULL,
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL,
    CONSTRAINT PK_dim_products PRIMARY KEY (product_key)
);

-- Insertion des données avec jointure pour la traduction
INSERT INTO analytics.dim_products (
    product_id,
    product_category_name,
    product_category_name_english,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT 
    p.product_id,
    p.product_category_name,
    ISNULL(t.product_category_name_english, 'unassigned') AS product_category_name_english,
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM clean.products p
LEFT JOIN clean.product_category_translation t 
    ON p.product_category_name = t.product_category_name;

-- Vérification
SELECT TOP 10 * FROM analytics.dim_products;





-- ==============================================================================
-- 3. CRÉATION DE LA DIMENSION : analytics.dim_sellers
-- ==============================================================================

USE olist;
GO

IF OBJECT_ID('analytics.dim_sellers', 'U') IS NOT NULL 
    DROP TABLE analytics.dim_sellers;

-- Création de la structure de la table
CREATE TABLE analytics.dim_sellers (
    seller_key BIGINT IDENTITY(1,1) NOT NULL,
    seller_id NVARCHAR(4000) NULL,
    seller_zip_code_prefix INT NULL,
    seller_city NVARCHAR(100) NULL,
    seller_state NVARCHAR(10) NULL,
    CONSTRAINT PK_dim_sellers PRIMARY KEY (seller_key)
);

-- Insertion des données nettoyées
INSERT INTO analytics.dim_sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT 
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM clean.sellers;

-- Vérification
SELECT TOP 10 * FROM analytics.dim_sellers;



-- ==============================================================================
-- 4. CRÉATION DE LA DIMENSION : analytics.dim_date
-- ==============================================================================

USE olist;
GO

IF OBJECT_ID('analytics.dim_date', 'U') IS NOT NULL 
    DROP TABLE analytics.dim_date;

-- Création de la structure de la table Calendrier
CREATE TABLE analytics.dim_date (
    date_key INT NOT NULL,              -- Format AAAAMMJJ (ex: 20170902)
    full_date DATE NOT NULL,            -- Format Date standard (2017-09-02)
    year_number INT NOT NULL,           -- Année (2017)
    quarter_number INT NOT NULL,        -- Trimestre (1, 2, 3, 4)
    quarter_name VARCHAR(10) NOT NULL,  -- Trimestre lisible ('Q1', 'Q2'...)
    month_number INT NOT NULL,          -- Numéro du mois (1 à 12)
    month_name VARCHAR(20) NOT NULL,    -- Nom du mois ('January', 'February'...)
    week_number INT NOT NULL,           -- Numéro de semaine dans l'année (1 à 53)
    day_number_of_month INT NOT NULL,   -- Jour du mois (1 à 31)
    day_name VARCHAR(20) NOT NULL,      -- Nom du jour ('Monday', 'Tuesday'...)
    is_weekend BIT NOT NULL,            -- 1 si Samedi/Dimanche, sinon 0
    CONSTRAINT PK_dim_date PRIMARY KEY (date_key)
);

-- Génération récursive des dates de 2016 à 2020
WITH DateSequence AS (
    SELECT CAST('2016-01-01' AS DATE) AS CalendarDate
    UNION ALL
    SELECT DATEADD(DAY, 1, CalendarDate)
    FROM DateSequence
    WHERE CalendarDate < '2020-12-31'
)
INSERT INTO analytics.dim_date (
    date_key,
    full_date,
    year_number,
    quarter_number,
    quarter_name,
    month_number,
    month_name,
    week_number,
    day_number_of_month,
    day_name,
    is_weekend
)
SELECT 
    CAST(FORMAT(CalendarDate, 'yyyyMMdd') AS INT) AS date_key,
    CalendarDate AS full_date,
    YEAR(CalendarDate) AS year_number,
    DATEPART(QUARTER, CalendarDate) AS quarter_number,
    'Q' + CAST(DATEPART(QUARTER, CalendarDate) AS VARCHAR(1)) AS quarter_name,
    MONTH(CalendarDate) AS month_number,
    DATENAME(MONTH, CalendarDate) AS month_name,
    DATEPART(WEEK, CalendarDate) AS week_number,
    DAY(CalendarDate) AS day_number_of_month,
    DATENAME(WEEKDAY, CalendarDate) AS day_name,
    CASE 
        WHEN DATENAME(WEEKDAY, CalendarDate) IN ('Saturday', 'Sunday') THEN 1 
        ELSE 0 
    END AS is_weekend
FROM DateSequence
OPTION (MAXRECURSION 0);

-- Vérification
SELECT * FROM analytics.dim_date ORDER BY date_key ASC;


/*
CREATE TABLE : On crée le moule de fact_orders contenant toutes les colonnes nécessaires (identifiants métier, métriques chiffrées, et les colonnes pour les clés étrangères).

INSERT INTO ... SELECT :

On prend la table orders comme base.

INNER JOIN avec order_items pour avoir chaque article vendu.

LEFT JOIN avec les 4 dimensions (dim_customers, dim_products, dim_sellers, dim_date) pour récupérer leurs clés numériques (key) respectives.

LEFT JOIN avec les sous-requêtes agrégées de payments (SUM) et reviews (AVG) pour éviter de dupliquer les lignes.

ALTER TABLE (Contraintes) : On officialise les relations pour que la base de données et Power BI sachent exactement quelle clé pointe vers quelle dimension.
*/

-- ==============================================================================
-- 5. CRÉATION DE LA TABLE DE FAITS : analytics.fact_orders
-- ==============================================================================

USE olist;
GO

IF OBJECT_ID('analytics.fact_orders', 'U') IS NOT NULL 
    DROP TABLE analytics.fact_orders;

-- 1. Création du moule / structure de la table de faits
CREATE TABLE analytics.fact_orders (
    fact_order_key BIGINT IDENTITY(1,1) NOT NULL,
    
    -- Clés étrangères vers les dimensions (Surrogate Keys)
    customer_key BIGINT NULL,
    product_key BIGINT NULL,
    seller_key BIGINT NULL,
    order_purchase_date_key INT NULL,
    
    -- Identifiants métier
    order_id NVARCHAR(4000) NULL,
    order_item_id INT NULL,
    order_status NVARCHAR(100) NULL,
    
    -- Horodatages originaux
    order_purchase_timestamp DATETIME NULL,
    order_delivered_customer_date DATETIME NULL,
    order_estimated_delivery_date DATETIME NULL,
    
    -- Mesures chiffrées (Métriques)
    price FLOAT NULL,
    freight_value FLOAT NULL,
    payment_value FLOAT NULL,
    payment_installments INT NULL,
    review_score INT NULL,
    
    CONSTRAINT PK_fact_orders PRIMARY KEY (fact_order_key)
);

-- 2. Insertion des données combinées et enregistrement des clés
INSERT INTO analytics.fact_orders (
    customer_key,
    product_key,
    seller_key,
    order_purchase_date_key,
    order_id,
    order_item_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    price,
    freight_value,
    payment_value,
    payment_installments,
    review_score
)
SELECT 
    -- Récupération des Surrogate Keys depuis les Dimensions
    c.customer_key,
    p.product_key,
    s.seller_key,
    d.date_key AS order_purchase_date_key,
    
    -- Identifiants métier & statut
    o.order_id,
    i.order_item_id,
    o.order_status,
    
    -- Dates
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    
    -- Mesures
    i.price,
    i.freight_value,
    pay.payment_value,
    pay.payment_installments,
    rev.review_score

FROM clean.orders o
INNER JOIN clean.order_items i 
    ON o.order_id = i.order_id

-- Jointures avec nos Dimensions pour capturer les Surrogate Keys
LEFT JOIN analytics.dim_customers c 
    ON o.customer_id = c.customer_id
LEFT JOIN analytics.dim_products p 
    ON i.product_id = p.product_id
LEFT JOIN analytics.dim_sellers s 
    ON i.seller_id = s.seller_id
LEFT JOIN analytics.dim_date d 
    ON CAST(FORMAT(o.order_purchase_timestamp, 'yyyyMMdd') AS INT) = d.date_key

-- Jointures avec les paiements et avis
LEFT JOIN (
    SELECT order_id, SUM(payment_value) AS payment_value, MAX(payment_installments) AS payment_installments
    FROM clean.order_payments
    GROUP BY order_id
) pay ON o.order_id = pay.order_id

LEFT JOIN (
    SELECT order_id, AVG(CAST(review_score AS FLOAT)) AS review_score
    FROM clean.order_reviews
    GROUP BY order_id
) rev ON o.order_id = rev.order_id;

-- 3. Déclaration des contraintes de Clés Étrangères (Foreign Keys)
ALTER TABLE analytics.fact_orders
ADD CONSTRAINT FK_fact_orders_customers FOREIGN KEY (customer_key) REFERENCES analytics.dim_customers(customer_key);

ALTER TABLE analytics.fact_orders
ADD CONSTRAINT FK_fact_orders_products FOREIGN KEY (product_key) REFERENCES analytics.dim_products(product_key);

ALTER TABLE analytics.fact_orders
ADD CONSTRAINT FK_fact_orders_sellers FOREIGN KEY (seller_key) REFERENCES analytics.dim_sellers(seller_key);

ALTER TABLE analytics.fact_orders
ADD CONSTRAINT FK_fact_orders_date FOREIGN KEY (order_purchase_date_key) REFERENCES analytics.dim_date(date_key);

-- Vérification
SELECT TOP 10 * FROM analytics.fact_orders;
SELECT TOP 10 * FROM analytics.dim_products;


/*
             ┌─────────────────────────┐
             │   analytics.dim_date    │
             └────────────┬────────────┘
                          │ 1
                          │
                          │ *
┌──────────────────────┐  │  ┌──────────────────────┐
│analytics.dim_customer│──┼──│ analytics.fact_orders│
└──────────────────────┘1 *  *└──────────────────────┘
                             * 1
                             │   ┌──────────────────┐
                             ├───│analytics.dim_seller
                             │   └──────────────────┘
                             * 1
                             │   ┌──────────────────┐
                             └───│analytics.dim_product
                                 └──────────────────┘


                                 */








