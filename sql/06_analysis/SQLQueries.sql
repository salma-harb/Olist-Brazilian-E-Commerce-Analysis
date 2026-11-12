-- Q1. Quels sont le chiffre d'affaires, le nombre de commandes et le panier moyen, au total et par état du client ?

USE olist;
GO

SELECT 
    c.customer_state,
    -- 1. Le Chiffre d'affaires total (Somme des prix)
    SUM(f.price) AS chiffre_affaires,
    
    -- 2. Le nombre de commandes uniques (Attention à bien compter les order_id distincts)
    COUNT(DISTINCT f.order_id) AS nombre_commandes,
    
    -- 3. Le panier moyen (CA / Nombre de commandes)
    SUM(f.price) / COUNT(DISTINCT f.order_id) AS panier_moyen

FROM analytics.fact_orders f
INNER JOIN analytics.dim_customers c 
    ON f.customer_key = c.customer_key
GROUP BY c.customer_state
ORDER BY chiffre_affaires DESC;


-- 2. Q2.Comment le chiffre d'affaires évolue-t-il mois par mois, et quels sont les mois les plus forts ?

-- Calculer la Tendance Globale (Mois $N$ vs Mois $N-1$)
  -- 1 Le CTE (VentesMensuelles)
  WITH VentesMensuelles AS (
    SELECT 
        d.year_number,
        d.month_number,
        d.month_name,
  sum(f.price) as chiffre_affaire,
  count(distinct f.order_id) AS nombre_commandes
  FROM analytics.fact_orders f
    INNER JOIN analytics.dim_date d 
        ON f.order_purchase_date_key = d.date_key
    GROUP BY 
        d.year_number, 
        d.month_number, 
        d.month_name
)

select 
    year_number,
    month_number,
    month_name,
    chiffre_affaire,
-- Récupère le CA du mois précédent dans le fil du temps
lag(chiffre_affaire,1) over(order by year_number, month_number) as ca_mois_precedent,
concat(round((chiffre_affaire -  lag(chiffre_affaire,1) over(order by year_number, month_number)) /nullif(lag(chiffre_affaire,1) over(order by year_number, month_number),0)*100,2),'%')
as pourcentage_de_variation_mois_par_mois

from VentesMensuelles
order by  year_number, month_number;

-- $$\text{Taux de croissance (\%)} = \frac{\text{CA du mois actuel} - \text{CA du mois précédent}}{\text{CA du mois précédent}} \times 100$$

 -- 2. calculer la saisonnalité
 WITH VentesMensuelles AS (
    SELECT 
        d.year_number,
        d.month_number,
        d.month_name,
        SUM(f.price) AS chiffre_affaire
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
    
    -- 1. Le CA du même mois l'année précédente (grâce au PARTITION BY)
    LAG(chiffre_affaire, 1) OVER (PARTITION BY month_number ORDER BY year_number) AS ca_annee_precedente,
    
    -- 2. Le pourcentage de variation YoY (Year-over-Year)
    ROUND(
        (chiffre_affaire - LAG(chiffre_affaire, 1) OVER (PARTITION BY month_number ORDER BY year_number)) 
        / NULLIF(LAG(chiffre_affaire, 1) OVER (PARTITION BY month_number ORDER BY year_number), 0) * 100, 
    2) AS pourcentage_croissance_yoy

FROM VentesMensuelles
ORDER BY year_number, month_number;


-- 3.Q3.Quand le chiffre d'affaires change, est-ce à cause du nombre de commandes ou du panier moyen ?

WITH VentesMensuelles AS (
    SELECT 
        d.year_number,
        d.month_number,
        d.month_name,
        SUM(f.price) AS chiffre_affaire,
        COUNT(DISTINCT f.order_id) AS nombre_commandes,
        -- Calcul du panier moyen (AOV) par mois
        SUM(f.price) / NULLIF(COUNT(DISTINCT f.order_id), 0) AS panier_moyen
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
    ROUND(panier_moyen, 2) AS panier_moyen
FROM VentesMensuelles
ORDER BY year_number, month_number;

/*L'analyse montre que les variations du chiffre 
d'affaires sont principalement pilotées par le volume des commandes, le panier moyen restant relativement stable dans le temps.*/

-- Q4.Quelles catégories génèrent 80 % du chiffre d'affaires ?

-- Étape 1 : Calculer le CA par catégorie
WITH VentesParCategorie AS (
    SELECT 
        p.product_category_name,
        SUM(f.price) AS chiffre_affaire
    FROM analytics.fact_orders f
    INNER JOIN analytics.dim_products p 
        ON f.product_key = p.product_key -- (ou la clé de jointure produit de ton schéma)
    GROUP BY p.product_category_name
),
-- Étape 2 : Calculer le cumul et le pourcentage cumulé
CumulCategories AS (
    SELECT 
        product_category_name,
        chiffre_affaire,
        -- Somme cumulée du CA (de la plus grande à la plus petite)
        SUM(chiffre_affaire) OVER (ORDER BY chiffre_affaire DESC ROWS UNBOUNDED PRECEDING) AS ca_cumule,
        -- Somme totale de tout le CA (pour faire le ratio)
        SUM(chiffre_affaire) OVER () AS ca_total
    FROM VentesParCategorie
),
-- Étape 3 : Transformer en pourcentage
PourcentageCumule AS (
    SELECT 
        product_category_name,
        chiffre_affaire,
        ROUND((ca_cumule * 100.0) / ca_total, 2) AS pourcentage_cumule
    FROM CumulCategories
)
-- Étape 4 : Le filtre final (les catégories qui font jusqu'à 80% du CA)
SELECT 
    product_category_name,
    chiffre_affaire,
    pourcentage_cumule
FROM PourcentageCumule
WHERE pourcentage_cumule <= 80
ORDER BY chiffre_affaire DESC;


-- Q5.Combien de vendeurs génèrent 50 % du chiffre d'affaires, et qui est le meilleur vendeur de chaque état ?

-- 1. CA par vendeur
WITH VentesParVendeur AS (
    SELECT 
        f.seller_key,
        SUM(f.price) AS chiffre_affaire
    FROM analytics.fact_orders f
    GROUP BY f.seller_key
),
-- 2. Somme cumulée + CA total
CumulVendeurs AS (
    SELECT 
        seller_key,
        chiffre_affaire,
        SUM(chiffre_affaire) OVER (ORDER BY chiffre_affaire DESC ROWS UNBOUNDED PRECEDING) AS ca_cumule,
        SUM(chiffre_affaire) OVER () AS ca_total
    FROM VentesParVendeur
),
-- 3. Conversion en pourcentage cumulé
PourcentageCumuleVendeurs AS (
    SELECT 
        seller_key,
        chiffre_affaire,
        ROUND((ca_cumule * 100.0) / ca_total, 2) AS pourcentage_cumule
    FROM CumulVendeurs
)
-- 4. Comptage des vendeurs générant <= 50% du CA
SELECT 
    COUNT(seller_key) AS nombre_de_vendeurs_50_pct_ca
FROM PourcentageCumuleVendeurs
WHERE pourcentage_cumule <= 50;

-- les meilleurs vendeurs 

WITH VentesParVendeurEtat AS (
    SELECT 
        s.seller_state,
        f.seller_key,
        SUM(f.price) AS chiffre_affaire,
        ROW_NUMBER() over(partition by s.seller_state 
            ORDER BY SUM(f.price) DESC
        ) AS rang_vendeur
        FROM analytics.fact_orders f
    INNER JOIN analytics.dim_sellers s 
        ON f.seller_key = s.seller_key
    GROUP BY 
        s.seller_state, 
        f.seller_key
)
select   seller_state,
        seller_key,
        rang_vendeur,
        chiffre_affaire
        from VentesParVendeurEtat 
        WHERE rang_vendeur = 1
ORDER BY chiffre_affaire DESC;

-- Q6.Quelle part des clients achète plus d'une fois, et après combien de temps ?
WITH CommandesParClient AS (
    SELECT 
        c.customer_unique_id, 
        COUNT(DISTINCT f.order_id) AS nb_commandes
    FROM analytics.fact_orders f
    INNER JOIN analytics.dim_customers c 
        ON f.customer_key = c.customer_key
    GROUP BY c.customer_unique_id
)
SELECT 
    COUNT(*) AS total_clients,
    COUNT(CASE WHEN nb_commandes > 1 THEN 1 END) AS clients_fidelises,
    concat(ROUND(
        (COUNT(CASE WHEN nb_commandes > 1 THEN 1 END) * 100.0) / COUNT(*), 
    2),'%') AS pourcentage_clients_fidelises
FROM CommandesParClient;

-- Deuxième partie : Après combien de temps reviennent-ils ? (Le Délai de Rachat)
WITH CommandesOrdonnees AS (
    SELECT 
        c.customer_unique_id,
        d.full_date,
        ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id ORDER BY d.full_date ASC) AS rang_commande
    FROM analytics.fact_orders f
    INNER JOIN analytics.dim_customers c 
        ON f.customer_key = c.customer_key
    INNER JOIN analytics.dim_date d 
        ON f.order_purchase_date_key = d.date_key
),
DelaisPremiereSeconde AS (
    SELECT 
        c1.customer_unique_id,
        c1.full_date AS date_premiere_commande,
        c2.full_date AS date_seconde_commande,
        DATEDIFF(day, c1.full_date, c2.full_date) AS delai_en_jours
    FROM CommandesOrdonnees c1
    INNER JOIN CommandesOrdonnees c2 
        ON c1.customer_unique_id = c2.customer_unique_id 
        AND c1.rang_commande = 1 
        AND c2.rang_commande = 2
)
SELECT 
   -- ROUND(AVG(CAST(delai_en_jours AS FLOAT)), 1) AS delai_moyen_jours_avant_second_achat
   customer_unique_id,delai_en_jours
FROM DelaisPremiereSeconde;




-- Q7. Qui sont les meilleurs clients (récence, fréquence, montant) ?

/*Fréquence = Son historique (combien de fois il est venu).

Montant = Son portefeuille (combien il a dépensé au total).

Récence = Sa fraîcheur (à quel point son dernier achat est proche d'aujourd'hui).*/

WITH DerniereDateGlobale AS (
    -- 1. On isole la toute dernière date de tout le dataset directement depuis les faits
    SELECT MAX(order_purchase_timestamp) AS max_date
    FROM analytics.fact_orders
)
SELECT 
    c.customer_unique_id,
    -- 2. Récence : Écart en jours entre le dernier achat du client et la date max globale
    DATEDIFF(
        day, 
        MAX(f.order_purchase_timestamp), 
        (SELECT max_date FROM DerniereDateGlobale)
    ) AS recence_jours,
    
    -- 3. Fréquence : Nombre de commandes distinctes
    COUNT(DISTINCT f.order_id) AS frequence,
    
    -- 4. Montant : Chiffre d'affaires total
    ROUND(SUM(f.price), 2) AS montant_total

FROM analytics.fact_orders f
INNER JOIN analytics.dim_customers c 
    ON f.customer_key = c.customer_key
GROUP BY c.customer_unique_id
ORDER BY montant_total DESC;

-- Q8.Quel est le délai moyen de livraison, et quel pourcentage de commandes arrive en retard ?

WITH CalculsLivraison AS (
    SELECT 
        order_id,
        -- 1. Calcul du délai de livraison réel pour chaque commande (en jours)
        DATEDIFF(day, order_purchase_timestamp, order_delivered_customer_date) AS delai_jours,
        
        -- 2. Marqueur de retard (1 si en retard, 0 sinon)
        CASE 
            WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 
            ELSE 0 
        END AS est_en_retard
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)
-- Requête principale générale et très simple
SELECT 
    ROUND(AVG(CAST(delai_jours AS FLOAT)), 1) AS delai_moyen_livraison_jours,
    COUNT(order_id) AS total_commandes_livrees,
    SUM(est_en_retard) AS nb_commandes_en_retard,
    ROUND((SUM(est_en_retard) * 100.0) / COUNT(order_id), 2) AS pourcentage_retard
FROM CalculsLivraison;


-- Q9.Où se concentrent les retards (états, vendeurs) ?

WITH RetardsComplets AS (
    SELECT 
        f.order_id,
        c.customer_state,
        s.seller_key,
        s.seller_state,
        CASE 
            WHEN f.order_delivered_customer_date > f.order_estimated_delivery_date THEN 1 
            ELSE 0 
        END AS est_en_retard
    FROM analytics.fact_orders f
    INNER JOIN analytics.dim_customers c 
        ON f.customer_key = c.customer_key
    INNER JOIN analytics.dim_sellers s 
        ON f.seller_key = s.seller_key
    WHERE f.order_status = 'delivered'
      AND f.order_delivered_customer_date IS NOT NULL
)
SELECT 
    customer_state,
    seller_key,
    seller_state,
    COUNT(order_id) AS total_commandes,
    SUM(est_en_retard) AS nb_commandes_en_retard,
    ROUND((SUM(est_en_retard) * 100.0) / COUNT(order_id), 2) AS pourcentage_retard
FROM RetardsComplets
GROUP BY customer_state, seller_key, seller_state
HAVING COUNT(order_id) >= 5 -- Filtre pour garder les paires avec un volume significatif
ORDER BY pourcentage_retard DESC, total_commandes DESC;



-- Q10.Un retard fait-il baisser la note de satisfaction, et de combien ?



WITH ImpactRetard AS (
    SELECT 
        review_score,
        CASE 
            WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'En retard'
            ELSE 'À l''heure'
        END AS statut_livraison
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND review_score IS NOT NULL
)
SELECT 
    -- 1. Note moyenne des commandes à l'heure
    ROUND(AVG(CASE WHEN statut_livraison = 'À l''heure' THEN CAST(review_score AS FLOAT) END), 2) AS note_a_l_heure,
    
    -- 2. Note moyenne des commandes en retard
    ROUND(AVG(CASE WHEN statut_livraison = 'En retard' THEN CAST(review_score AS FLOAT) END), 2) AS note_en_retard,
    
    -- 3. La différence exacte (de combien la note a baissé)
    ROUND(
        AVG(CASE WHEN statut_livraison = 'À l''heure' THEN CAST(review_score AS FLOAT) END) 
        - AVG(CASE WHEN statut_livraison = 'En retard' THEN CAST(review_score AS FLOAT) END), 
        2
    ) AS baisse_de_satisfaction_points

FROM ImpactRetard;

-- Q11.Quels produits ou catégories se vendent beaucoup mais sont mal notés ?

WITH VentesEtNotesParCategorie AS (
    SELECT 
        p.product_category_name_english AS categorie_produit,
        COUNT(f.order_id) AS nombre_ventes,
        ROUND(AVG(CAST(f.review_score AS FLOAT)), 2) AS note_moyenne
    FROM analytics.fact_orders f
    INNER JOIN analytics.dim_products p 
        ON f.product_key = p.product_key
    WHERE f.order_status = 'delivered'
      AND f.review_score IS NOT NULL
      AND p.product_category_name_english IS NOT NULL
    GROUP BY p.product_category_name_english
)
SELECT 
    categorie_produit,
    nombre_ventes,
    note_moyenne
FROM VentesEtNotesParCategorie
WHERE nombre_ventes >= 500  -- Filtre pour garder les catégories à forte vente
  AND note_moyenne < 4.0    -- Filtre pour cibler les catégories mal notées
ORDER BY note_moyenne ASC, nombre_ventes DESC;

-- Q12.Quels clients de 2017 n'ont pas racheté en 2018, et étaient-ils plus souvent mécontents ?


WITH Clients2017 AS (
    -- Clients uniques ayant acheté en 2017
    SELECT DISTINCT c.customer_unique_id
    FROM analytics.fact_orders f
    INNER JOIN analytics.dim_customers c ON f.customer_key = c.customer_key
    INNER JOIN analytics.dim_date d ON f.order_purchase_date_key = d.date_key
    WHERE d.year_number = 2017
),
Clients2018 AS (
    -- Clients uniques ayant acheté en 2018
    SELECT DISTINCT c.customer_unique_id
    FROM analytics.fact_orders f
    INNER JOIN analytics.dim_customers c ON f.customer_key = c.customer_key
    INNER JOIN analytics.dim_date d ON f.order_purchase_date_key = d.date_key
    WHERE d.year_number = 2018
),
Chunrs2017 AS (
    -- Clients de 2017 qui n'ont PAS racheté en 2018 (EXCEPT)
    SELECT customer_unique_id FROM Clients2017
    EXCEPT
    SELECT customer_unique_id FROM Clients2018
)
-- Analyse de leur score moyen de satisfaction global
SELECT 
    DISTINCT c.customer_unique_id AS clients_churners_2017,
    ROUND(AVG(CAST(f.review_score AS FLOAT)), 2) AS note_moyenne_satisfaction_churners
FROM Chunrs2017 ch
INNER JOIN analytics.dim_customers c ON ch.customer_unique_id = c.customer_unique_id
INNER JOIN analytics.fact_orders f ON c.customer_key = f.customer_key
where f.review_score IS NOT NULL
group by c.customer_unique_id
;

-- Q13.Quels types de paiement rapportent le plus, et le paiement en plusieurs fois est-il lié à des paniers plus gros ?

WITH DetailsPaiement AS (
    SELECT 
        p.order_id,
        p.payment_type,
        p.payment_value,
        -- Qualification : Paiement en plusieurs fois vs Comptant
        CASE 
            WHEN p.payment_installments > 1 THEN 'Plusieurs fois'
            ELSE 'Comptant (1x)'
        END AS modalite_paiement
    FROM clean.order_payments p
    INNER JOIN analytics.fact_orders f 
        ON p.order_id = f.order_id
    WHERE f.order_status = 'delivered'
)
SELECT 
    payment_type,
    modalite_paiement,
    
    -- 1. Quel type rapporte le plus (Volume total) ?
    ROUND(SUM(payment_value), 2) AS chiffre_affaires_total,
    
    -- 2. Le paiement en plusieurs fois est-il lié à de plus gros paniers ?
    ROUND(AVG(payment_value), 2) AS panier_moyen,
    
    -- Indication complémentaire du nombre de transactions
    COUNT(DISTINCT order_id) AS nb_commandes

FROM DetailsPaiement
GROUP BY payment_type, modalite_paiement
ORDER BY chiffre_affaires_total DESC;



--  Q14.Que représente l'écart entre ce que le client paie et la somme prix + fret ?
WITH EcartPaiement AS (
    SELECT 
        order_id,
        -- Montant payé total de la commande (on prend MAX ou AVG car la valeur est répétée par article)
        MAX(payment_value) AS total_paye_client,
        
        -- Somme du Prix + Fret pour l'ensemble des articles de la commande
        SUM(price + freight_value) AS total_catalogue_theorique,
        
        -- Calcul de la différence
        ROUND(MAX(payment_value) - SUM(price + freight_value), 2) AS ecart
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
    GROUP BY order_id
)
SELECT 
    COUNT(CASE WHEN ecart = 0 THEN 1 END) AS nb_commandes_exactes,
    COUNT(CASE WHEN ecart > 0 THEN 1 END) AS nb_commandes_surpayees, -- (ex: intérêts/frais de paiement échelonné)
    COUNT(CASE WHEN ecart < 0 THEN 1 END) AS nb_commandes_souspayees, -- (ex: utilisation de bons de réduction / vouchers)
    ROUND(AVG(ecart), 2) AS ecart_moyen_valeur
FROM EcartPaiement;



-- Q15.Les données sont-elles cohérentes (doublons, dates impossibles, lignes sans correspondance) ?


-- 1. Vérification des dates impossibles (anomalies chronologiques)
SELECT COUNT(*) AS nb_dates_incoherentes
FROM analytics.fact_orders
WHERE order_delivered_customer_date < order_purchase_timestamp
   OR order_estimated_delivery_date < order_purchase_timestamp;

-- 2. Vérification des orphelins (commandes sans client associé)
SELECT COUNT(f.order_id) AS nb_commandes_orphelines
FROM analytics.fact_orders f
LEFT JOIN analytics.dim_customers c ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;

-- 3. Vérification des doublons dans la dimension client
SELECT customer_key, COUNT(*) AS nb_occurrences
FROM analytics.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- plan estimé ctrl+l
-- plan réel ctrl+m


