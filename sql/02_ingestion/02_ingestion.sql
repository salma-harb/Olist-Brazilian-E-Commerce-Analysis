-- =============================================
-- 02_ingestion.sql
-- But : charger les CSV dans les tables raw
-- Les CSV sont copiés dans C:\olist_data car SQL Server
-- ne peut pas lire le Bureau/OneDrive
-- =============================================
USE olist;
GO

-- 1. customers
TRUNCATE TABLE raw.customers;

BULK INSERT raw.customers
FROM 'C:\olist_data\olist_customers_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    CODEPAGE = '65001'
);
GO

SELECT COUNT(*) AS nb_lignes FROM raw.customers;

-- geolocation
TRUNCATE TABLE raw.geolocation;
BULK INSERT raw.geolocation
FROM 'C:\olist_data\olist_geolocation_dataset.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001');
GO

-- order_items
TRUNCATE TABLE raw.order_items;
BULK INSERT raw.order_items
FROM 'C:\olist_data\olist_order_items_dataset.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001');
GO

-- order_payments
TRUNCATE TABLE raw.order_payments;
BULK INSERT raw.order_payments
FROM 'C:\olist_data\olist_order_payments_dataset.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001');
GO

-- orders
TRUNCATE TABLE raw.orders;
BULK INSERT raw.orders
FROM 'C:\olist_data\olist_orders_dataset.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001');
GO

SELECT 'customers' AS table_name, COUNT(*) AS nb_lignes FROM raw.customers
UNION ALL SELECT 'geolocation', COUNT(*) FROM raw.geolocation
UNION ALL SELECT 'order_items', COUNT(*) FROM raw.order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM raw.order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM raw.order_reviews
UNION ALL SELECT 'orders', COUNT(*) FROM raw.orders
UNION ALL SELECT 'products', COUNT(*) FROM raw.products
UNION ALL SELECT 'sellers', COUNT(*) FROM raw.sellers
UNION ALL SELECT 'product_category_translation', COUNT(*) FROM raw.product_category_translation;