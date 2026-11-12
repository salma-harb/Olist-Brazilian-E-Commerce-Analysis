/*
Nom de la vue : analytics.vw_monthly_sales_performance
But : Centraliser et pré-calculer la performance mensuelle des ventes (Chiffre d'affaires, 
      nombre de commandes, panier moyen et CA du mois précédent) pour alimenter 
      directement les graphiques temporels du tableau de bord Power BI.
*/
USE olist;
GO

-- Création de la vue pour les performances mensuelles des ventes
CREATE VIEW analytics.vw_monthly_sales_performance AS
WITH VentesMensuelles AS (
    SELECT 
        d.year_number,
        d.month_number,
        d.month_name,
        SUM(f.price) AS chiffre_affaire,
        COUNT(DISTINCT f.order_id) AS nombre_commandes
    FROM analytics.fact_orders f
    INNER JOIN analytics.dim_date d 
        ON f.order_purchase_date_key = d.date_key
    GROUP BY 
        d.year_number, 
        d.month_number, 
        d.month_name
)
SELECT 
    year_number,
    month_number,
    month_name,
    chiffre_affaire,
    nombre_commandes,
    -- Le panier moyen par mois
    ROUND(chiffre_affaire / NULLIF(nombre_commandes, 0), 2) AS panier_moyen,
    -- Le CA du mois précédent
    LAG(chiffre_affaire, 1) OVER (ORDER BY year_number, month_number) AS ca_mois_precedent
FROM VentesMensuelles;


select top 10 * from analytics.vw_monthly_sales_performance;
GO
/*

Nom de la vue : analytics.vw_customer_rfm_summary
But : Calculer la segmentation RFM (Récence, Fréquence, Montant) et le profil 
      de satisfaction de chaque client unique afin d'alimenter les graphiques 
      de typologie clients et de ciblage marketing dans Power BI.

*/

CREATE VIEW analytics.vw_customer_rfm_summary AS
WITH DerniereDateGlobale AS (
    -- On isole la toute dernière date de tout le dataset pour calculer la récence
    SELECT MAX(order_purchase_timestamp) AS max_date
    FROM analytics.fact_orders
),
CustomerAgg AS (
    SELECT 
        c.customer_unique_id,
        c.customer_state,
        MAX(f.order_purchase_timestamp) AS derniere_date_commande,
        COUNT(DISTINCT f.order_id) AS frequence,
        SUM(f.price) AS montant_total,
        ROUND(AVG(CAST(f.review_score AS FLOAT)), 2) AS note_moyenne_satisfaction
    FROM analytics.fact_orders f
    INNER JOIN analytics.dim_customers c ON f.customer_key = c.customer_key
    WHERE f.order_status = 'delivered'
    GROUP BY c.customer_unique_id, c.customer_state
)
SELECT 
    customer_unique_id,
    customer_state,
    derniere_date_commande,
    -- 1. Récence : Écart en jours entre le dernier achat du client et la date max globale
    DATEDIFF(day, derniere_date_commande, (SELECT max_date FROM DerniereDateGlobale)) AS recence_jours,
    frequence,
    ROUND(montant_total, 2) AS montant_total,
    note_moyenne_satisfaction,
    -- 2. Segmentation intelligente du client
    CASE 
        WHEN montant_total >= 500 AND frequence >= 2 THEN 'VIP'
        WHEN frequence >= 2 THEN 'Fidèle'
        WHEN DATEDIFF(day, derniere_date_commande, (SELECT max_date FROM DerniereDateGlobale)) > 180 THEN 'À Risque / Churn'
        ELSE 'Occasionnel'
    END AS segment_client
FROM CustomerAgg;

select top 10 * from analytics.vw_customer_rfm_summary;
GO


GO -- Sépare ce bloc du précédent pour éviter l'erreur de syntaxe

/*
------------------------------------------------------------------------------------
Nom de la vue : analytics.vw_delivery_performance
But : Analyser la performance logistique, les délais de livraison réels vs estimés,
      le taux de retard par région (État) et son impact sur la note de satisfaction 
      pour le tableau de bord Power BI.
------------------------------------------------------------------------------------
*/

CREATE VIEW analytics.vw_delivery_performance AS
SELECT 
    c.customer_state AS etat_client,
    COUNT(f.order_id) AS total_commandes,
    COUNT(CASE WHEN f.order_delivered_customer_date > f.order_estimated_delivery_date THEN 1 END) AS commandes_en_retard,
    ROUND(
        100.0 * COUNT(CASE WHEN f.order_delivered_customer_date > f.order_estimated_delivery_date THEN 1 END) / COUNT(f.order_id), 
        2
    ) AS taux_retard_pct,
    ROUND(AVG(CAST(DATEDIFF(day, f.order_purchase_timestamp, f.order_delivered_customer_date) AS FLOAT)), 1) AS delai_moyen_livraison_jours,
    ROUND(AVG(CAST(f.review_score AS FLOAT)), 2) AS note_satisfaction_moyenne
FROM analytics.fact_orders f
INNER JOIN analytics.dim_customers c ON f.customer_key = c.customer_key
WHERE f.order_status = 'delivered'
  AND f.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state;
select top 10 * from analytics.vw_delivery_performance;
GO




GO -- Sépare ce bloc du précédent

/*
------------------------------------------------------------------------------------
Nom de la vue : analytics.vw_product_category_performance
But : Analyser la performance des catégories de produits (chiffre d'affaires, 
      volume des ventes et note de satisfaction moyenne) pour alimenter les 
      graphiques de catalogue produits dans Power BI.
------------------------------------------------------------------------------------
*/

CREATE VIEW analytics.vw_product_category_performance AS
SELECT 
    p.product_category_name_english AS categorie_produit,
    COUNT(f.order_id) AS nombre_ventes,
    ROUND(SUM(f.price), 2) AS chiffre_affaires_total,
    ROUND(AVG(CAST(f.review_score AS FLOAT)), 2) AS note_moyenne_satisfaction
FROM analytics.fact_orders f
INNER JOIN analytics.dim_products p 
    ON f.product_key = p.product_key
WHERE f.order_status = 'delivered'
  AND p.product_category_name_english IS NOT NULL
GROUP BY p.product_category_name_english;

select top 10 * from analytics.vw_product_category_performance
GO


-- procédures et fonctions 


USE olist;
GO

/*
====================================================================================
PHASE 7 : PROGRAMMABILITÉ & ARCHITECTURE ENTERPRISE
====================================================================================
Ce fichier rassemble l'ensemble des objets programmables du schéma `analytics` :
  1. Fonctions Scalaires (Transformation de valeurs)
  2. Fonctions à Table (Filtrage dynamique)
  3. Procédures Stockées avec Transactions et TRY...CATCH (Sécurité & Rapports)
  4. Table de Audit Logs (Traçabilité)
  5. Triggers d'Audit (Journalisation automatique des modifications)
====================================================================================
*/


-- ==================================================================================
-- 1. FONCTION SCALAIRE : fn_customer_segment
-- ==================================================================================
/*
------------------------------------------------------------------------------------
BUT METIER :
  Classifier automatiquement le niveau de valeur d'un client (VIP Or, VIP Argent, 
  Fidèle, Occasionnel) en fonction de la somme totale dépensée.

TÂCHE AUTOMATISÉE :
  Evite de réécrire des règles d'affaires complexes avec des `CASE WHEN` dans 
  chaque requête d'analyse ou rapport financier.

CE QUE FAIT LE CODE :
  - Reçoit en paramètre un montant decimal (`@montant`).
  - Compare ce montant à des seuils définis (>= 1000, >= 500, >= 100).
  - Renvoie une chaîne de caractères (VARCHAR) indiquant le segment attribué.
------------------------------------------------------------------------------------
*/
IF OBJECT_ID('analytics.fn_customer_segment', 'FN') IS NOT NULL
    DROP FUNCTION analytics.fn_customer_segment;
GO

CREATE FUNCTION analytics.fn_customer_segment (@montant DECIMAL(10,2))
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @segment VARCHAR(50);
    
    IF @montant >= 1000
        SET @segment = 'VIP Or';
    ELSE IF @montant >= 500
        SET @segment = 'VIP Argent';
    ELSE IF @montant >= 100
        SET @segment = 'Fidèle';
    ELSE
        SET @segment = 'Occasionnel';
        
    RETURN @segment;
END;
GO


-- ==================================================================================
-- 2. FONCTION À TABLE (TABLE-VALUED FUNCTION) : fn_get_orders_by_state
-- ==================================================================================
/*
------------------------------------------------------------------------------------
BUT METIER :
  Permettre aux équipes régionales d'extraire rapidement toutes les commandes livrées 
  pour un État spécifique (ex: 'SP', 'RJ').

TÂCHE AUTOMATISÉE :
  Centralise la jointure entre la table de faits `fact_orders` et la dimension `dim_customers` 
  tout en appliquant directement le filtre sur les commandes livrées.

CE QUE FAIT LE CODE :
  - Prend en entrée le code de l'État sur 2 lettres (`@state`).
  - Exécute la jointure SQL pré-configurée.
  - Renvoie un ensemble de résultats sous forme de table virtuelle interrogeable.
------------------------------------------------------------------------------------
*/
IF OBJECT_ID('analytics.fn_get_orders_by_state', 'IF') IS NOT NULL
    DROP FUNCTION analytics.fn_get_orders_by_state;
GO

CREATE FUNCTION analytics.fn_get_orders_by_state (@state VARCHAR(2))
RETURNS TABLE
AS
RETURN
(
    SELECT 
        f.order_id,
        c.customer_unique_id,
        c.customer_state,
        f.price,
        f.freight_value,
        f.order_status
    FROM analytics.fact_orders f
    INNER JOIN analytics.dim_customers c ON f.customer_key = c.customer_key
    WHERE c.customer_state = @state 
      AND f.order_status = 'delivered'
);
GO


-- ==================================================================================
-- 3. TABLE D'AUDIT ET DE LOGS : pipeline_audit_logs
-- ==================================================================================
/*
------------------------------------------------------------------------------------
BUT METIER :
  Garantir la traçabilité complète des exécutions du pipeline de données (horodatage, 
  statut de réussite/échec, volume de données traitées et messages d'erreur).

TÂCHE AUTOMATISÉE :
  Offre un tableau de bord technique pour l'ingénieur data afin de vérifier la santé 
  des chargements et d'investiguer rapidement en cas d'anomalie.

CE QUE FAIT LE CODE :
  - Crée une table physique `analytics.pipeline_audit_logs` avec un identifiant auto-incrémenté.
  - Stocke le nom de l'action/procédure, la date système (`GETDATE()`), le statut ('SUCCES'/'ECHEC') 
    et le nombre de lignes impactées.
------------------------------------------------------------------------------------
*/
IF OBJECT_ID('analytics.pipeline_audit_logs', 'U') IS NULL
BEGIN
    CREATE TABLE analytics.pipeline_audit_logs (
        log_id INT IDENTITY(1,1) PRIMARY KEY,
        nom_action VARCHAR(100) NOT NULL,
        date_execution DATETIME DEFAULT GETDATE(),
        statut VARCHAR(20) NOT NULL,
        lignes_traitees INT NULL,
        message_erreur VARCHAR(MAX) NULL
    );
END;
GO


-- ==================================================================================
-- 4. PROCÉDURE STOCKÉE AVEC TRANSACTION & TRY...CATCH : sp_sales_report
-- ==================================================================================
/*
------------------------------------------------------------------------------------
BUT METIER :
  Générer le rapport financier officiel pour un mois et une année donnés à destination 
  de la direction commerciale.

TÂCHE AUTOMATISÉE :
  Sécurise l'extraction du rapport avec une transaction explicite et enregistre 
  automatiquement l'exécution dans la table d'audit.

CE QUE FAIT LE CODE :
  - Accepte deux paramètres : l'année (`@annee`) et le mois (`@mois`).
  - Utilise un bloc `BEGIN TRY ... END TRY` :
      1. Démarre une transaction (`BEGIN TRANSACTION`).
      2. Calcule le total des commandes, le chiffre d'affaires et le panier moyen.
      3. Valide la transaction (`COMMIT TRANSACTION`).
      4. Insère un log de succès dans `analytics.pipeline_audit_logs`.
  - Utilise un bloc `BEGIN CATCH ... END CATCH` :
      1. Annule la transaction (`ROLLBACK TRANSACTION`) si une erreur survient.
      2. Insère un log d'échec avec le détail du message d'erreur SQL.
------------------------------------------------------------------------------------
*/
IF OBJECT_ID('analytics.sp_sales_report', 'P') IS NOT NULL
    DROP PROCEDURE analytics.sp_sales_report;
GO

CREATE PROCEDURE analytics.sp_sales_report
    @annee INT,
    @mois INT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Génération du rapport analytique
        SELECT 
            d.year_number,
            d.month_number,
            d.month_name,
            COUNT(DISTINCT f.order_id) AS total_commandes,
            ROUND(SUM(f.price), 2) AS chiffre_affaires,
            ROUND(SUM(f.price) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2) AS panier_moyen
        FROM analytics.fact_orders f
        INNER JOIN analytics.dim_date d ON f.order_purchase_date_key = d.date_key
        WHERE d.year_number = @annee 
          AND d.month_number = @mois
        GROUP BY d.year_number, d.month_number, d.month_name;

        -- 2. Validation de la transaction
        COMMIT TRANSACTION;

        -- 3. Enregistrement du succès dans les logs
        INSERT INTO analytics.pipeline_audit_logs (nom_action, statut, lignes_traitees)
        VALUES ('sp_sales_report (' + CAST(@annee AS VARCHAR) + '-' + CAST(@mois AS VARCHAR) + ')', 'SUCCES', @@ROWCOUNT);

    END TRY
    BEGIN CATCH
        -- En cas d'erreur, annulation de la transaction
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Enregistrement de l'échec dans les logs
        INSERT INTO analytics.pipeline_audit_logs (nom_action, statut, message_erreur)
        VALUES ('sp_sales_report', 'ECHEC', ERROR_MESSAGE());

        -- Affichage de l'erreur
        RAISERROR('Erreur lors de la génération du rapport de ventes.', 16, 1);
    END CATCH
END;
GO


-- ==================================================================================
-- 5. PROCÉDURE STOCKÉE D'EXÉCUTION DU PIPELINE : sp_refresh_pipeline_logs
-- ==================================================================================
/*
------------------------------------------------------------------------------------
BUT METIER :
  Simuler l'actualisation périodique du pipeline de données et consigner les métriques 
  globales de la table de faits.

TÂCHE AUTOMATISÉE :
  Compte le nombre de lignes rechargées dans le schéma `analytics` et met à jour les logs.

CE QUE FAIT LE CODE :
  - Calcule le nombre total de lignes présentes dans `analytics.fact_orders`.
  - Insère un enregistrement récapitulatif dans `analytics.pipeline_audit_logs`.
------------------------------------------------------------------------------------
*/
IF OBJECT_ID('analytics.sp_refresh_pipeline_logs', 'P') IS NOT NULL
    DROP PROCEDURE analytics.sp_refresh_pipeline_logs;
GO

CREATE PROCEDURE analytics.sp_refresh_pipeline_logs
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        DECLARE @total_lignes INT;
        SELECT @total_lignes = COUNT(*) FROM analytics.fact_orders;

        INSERT INTO analytics.pipeline_audit_logs (nom_action, statut, lignes_traitees)
        VALUES ('sp_refresh_pipeline_logs', 'SUCCES', @total_lignes);
        
        PRINT 'Pipeline d''audit rafraîchi avec succès.';
    END TRY
    BEGIN CATCH
        INSERT INTO analytics.pipeline_audit_logs (nom_action, statut, message_erreur)
        VALUES ('sp_refresh_pipeline_logs', 'ECHEC', ERROR_MESSAGE());
    END CATCH
END;
GO


-- ==================================================================================
-- 6. TRIGGER D'AUDIT EN TEMPS RÉEL : trg_audit_dim_customers_changes
-- ==================================================================================
/*
------------------------------------------------------------------------------------
BUT METIER :
  Détecter et traquer automatiquement toute modification ou suppression opérée sur la 
  dimension critique des clients (`analytics.dim_customers`).

TÂCHE AUTOMATISÉE :
  S'exécute silencieusement en arrière-plan à chaque mise à jour (`UPDATE`) ou suppression 
  (`DELETE`) de données clients sans intervention humaine.

CE QUE FAIT LE CODE :
  - S'active automatiquement `AFTER UPDATE, DELETE` sur la table `analytics.dim_customers`.
  - Utilise la table système temporaire `deleted` de SQL Server pour compter le nombre 
    de lignes impactées par la modification.
  - Insère automatiquement une ligne d'alerte dans `analytics.pipeline_audit_logs`.
------------------------------------------------------------------------------------
*/
IF OBJECT_ID('analytics.trg_audit_dim_customers_changes', 'TR') IS NOT NULL
    DROP TRIGGER analytics.trg_audit_dim_customers_changes;
GO

CREATE TRIGGER analytics.trg_audit_dim_customers_changes
ON analytics.dim_customers
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @nb_lignes_modifiees INT;
    SELECT @nb_lignes_modifiees = COUNT(*) FROM deleted;

    IF @nb_lignes_modifiees > 0
    BEGIN
        INSERT INTO analytics.pipeline_audit_logs (nom_action, statut, lignes_traitees, message_erreur)
        VALUES (
            'TRIGGER: Modification/Suppression sur dim_customers', 
            'AVERTISSEMENT', 
            @nb_lignes_modifiees, 
            'Des données clients ont été altérées ou supprimées.'
        );
    END
END;
GO


SELECT analytics.fn_customer_segment(1250.00) AS segment_test;
-- Résultat attendu : 'VIP Or'

SELECT * FROM analytics.fn_get_orders_by_state('RJ');

EXEC analytics.sp_sales_report @annee = 2018, @mois = 8;

SELECT * FROM analytics.pipeline_audit_logs ORDER BY log_id DESC;