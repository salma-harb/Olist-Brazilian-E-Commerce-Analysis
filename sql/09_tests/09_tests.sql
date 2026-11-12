USE olist;
GO

/*
====================================================================================
PHASE 9 : TESTS & VALIDATION FINALE DU PIPELINE
====================================================================================
*/

print '------------------------------------------------------------------';
PRINT '1. TEST DES VUES POWER BI';
print '------------------------------------------------------------------';

-- Vérification de la vue des ventes mensuelles
SELECT TOP 5 * FROM analytics.vw_monthly_sales_performance;

-- Vérification de la vue RFM clients
SELECT TOP 5 * FROM analytics.vw_customer_rfm_summary;

-- Vérification de la vue logistique
SELECT TOP 5 * FROM analytics.vw_delivery_performance;

-- Vérification de la vue des catégories produits
SELECT TOP 5 * FROM analytics.vw_product_category_performance;


print '------------------------------------------------------------------';
PRINT '2. TEST DES FONCTIONS ET PROCÉDURES';
print '------------------------------------------------------------------';

-- Test de la fonction scalaire (Classification d'un montant de 1200$)
SELECT analytics.fn_customer_segment(1200.00) AS Segment_Teste;

-- Test de la fonction à table (Commandes de l'État de São Paulo 'SP')
SELECT TOP 5 * FROM analytics.fn_get_orders_by_state('SP');

-- Test de la procédure stockée de rapport (août 2018)
EXEC analytics.sp_sales_report @annee = 2018, @mois = 8;


print '------------------------------------------------------------------';
PRINT '3. TEST DES LOGS D''AUDIT';
print '------------------------------------------------------------------';

-- Vérification que les actions s'enregistrent bien dans la table de logs
SELECT TOP 10 * FROM analytics.pipeline_audit_logs ORDER BY log_id DESC;
GO






USE olist;
GO

-- 1. Activer l'affichage du temps d'exécution et des statistiques d'E/S (Entrées/Sorties)
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- 2. Lancer une requête filtrée sur une colonne indexée (ex: l'état 'SP' dans dim_customers)
SELECT 
    c.customer_state,
    COUNT(f.order_id) AS total_commandes,
    SUM(f.price) AS ca_total
FROM analytics.fact_orders f
INNER JOIN analytics.dim_customers c ON f.customer_key = c.customer_key
WHERE c.customer_state = 'SP'
GROUP BY c.customer_state;
GO

-- 3. Désactiver les statistiques pour les requêtes suivantes
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO