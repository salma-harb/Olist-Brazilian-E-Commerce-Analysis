USE olist;
GO

/*
====================================================================================
PHASE 8 : PERFORMANCE & INDEXATION
====================================================================================
But : Créer des index non-agrégés (Non-Clustered Indexes) sur les clés de jointure 
      et les colonnes de filtrage fréquentes afin d'optimiser les performances 
      des requêtes et du futur tableau de bord Power BI.
====================================================================================
*/

-- 1. Index sur la clé client dans la table de faits (Accélère les jointures clients)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_fact_orders_customer_key' AND object_id = OBJECT_ID('analytics.fact_orders'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_orders_customer_key
    ON analytics.fact_orders (customer_key);
    PRINT 'Index IX_fact_orders_customer_key créé avec succès.';
END;
GO

-- 2. Index sur la clé produit dans la table de faits (Accélère les analyses par catégorie/produit)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_fact_orders_product_key' AND object_id = OBJECT_ID('analytics.fact_orders'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_orders_product_key
    ON analytics.fact_orders (product_key);
    PRINT 'Index IX_fact_orders_product_key créé avec succès.';
END;
GO

-- 3. Index sur la clé vendeur dans la table de faits (Accélère les classements de vendeurs)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_fact_orders_seller_key' AND object_id = OBJECT_ID('analytics.fact_orders'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_orders_seller_key
    ON analytics.fact_orders (seller_key);
    PRINT 'Index IX_fact_orders_seller_key créé avec succès.';
END;
GO

-- 4. Index sur la date d'achat dans la table de faits (Accélère les filtres temporels et mensuels)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_fact_orders_purchase_date_key' AND object_id = OBJECT_ID('analytics.fact_orders'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_orders_purchase_date_key
    ON analytics.fact_orders (order_purchase_date_key);
    PRINT 'Index IX_fact_orders_purchase_date_key créé avec succès.';
END;
GO

-- 5. Index sur l'état client dans la dimension clients (Accélère les cartes géographiques)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_dim_customers_state' AND object_id = OBJECT_ID('analytics.dim_customers'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_customers_state
    ON analytics.dim_customers (customer_state);
    PRINT 'Index IX_dim_customers_state créé avec succès.';
END;
GO