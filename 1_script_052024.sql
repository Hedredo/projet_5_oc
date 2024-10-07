-- Code SQL des 4 requêtes - format SQLite
-- Pour obtenir le résultat de chaque requête, il faut exécuter le code de chaque requête séparemment dans un éditeur de requête et être connecté à la base de données

-- Requete 1 : En excluant les commandes annulées, sélection des commandes récentes de moins de 3 mois que les clients ont reçues avec au moins 3 jours de retard
-- On crée une nouvelle vue avec un nouveau champs qui calcule le delta entre les dates de livraison estimée et réelle
WITH filtered_dates AS (
    SELECT
        order_id,
        order_purchase_timestamp,
        julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) AS difference_in_days_between_reel_and_estimated_delivery_date
    FROM orders
    -- On filtre toutes les commandes qui sont à - de 3 mois de la date maximum ET qui n'ont pas le statut canceled
    WHERE date(order_purchase_timestamp) >= (
    SELECT
        date(MAX(order_purchase_timestamp), '-3 months')
    FROM orders
    )
        AND order_status NOT LIKE 'canceled'
)
-- On affiche les commandes avec la différence de temps de livraison associée
SELECT order_id, ROUND(difference_in_days_between_reel_and_estimated_delivery_date, 0) AS difference_in_days_rounded_between_reel_and_estimated_delivery_date
FROM filtered_dates
-- On filtre les commandes qui ont un retard de livraison de + de 3 jours
WHERE difference_in_days_between_reel_and_estimated_delivery_date >= 3
ORDER BY difference_in_days_between_reel_and_estimated_delivery_date DESC;


-- Requete 2 : Sélection des vendeurs qui ont un CA > 100 000 Real sur des commandes livrées via OLIST
-- On crée une nouvelle vue avec une aggrégation de la somme du montant en Real par commande sur OLIST
WITH grouped_orders AS (
    SELECT
        order_id,
        seller_id,
        SUM(price) AS total_price_by_order_and_by_seller
    FROM order_items
    -- On filtre les commandes qui ont le statut delivered
    WHERE order_id IN
        (SELECT order_id
        FROM orders
        WHERE order_status LIKE 'delivered')
    GROUP BY order_id, seller_id
    ORDER BY seller_id
)
-- On effectue une nouvelle aggrégation par vendeur avec la somme des ventes en real, arrondies à 2 décimales, de chaque vendeur
SELECT seller_id, ROUND(SUM(total_price_by_order_and_by_seller), 2) AS total_sales_value_by_seller
FROM grouped_orders
GROUP BY seller_id
-- On filtre enfin tous les résultats de l'aggrégation qui sont supérieurs à 100000 real
HAVING total_sales_value_by_seller >= 100000
-- On ordonne du plus grand CA au plus petit CA 
ORDER BY total_sales_value_by_seller DESC;


-- Requete 3 : Sélection des vendeurs avec - de 3 mois d'ancienneté qui ont déjà vendus plus de 30 produits sur OLIST
-- On crée une nouvelle vue qui fusionne les tables orders et orders_items sur le numéro de commande avec le numéro du vendeur, des produits dans chaque item du panier et date d'achat
WITH seller_and_items AS (
    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        order_purchase_timestamp
    FROM orders
    LEFT JOIN order_items
    USING(order_id)
),
-- On crée une nouvelle vue où on calcule la date maximum d'achat dans la table orders et on déduit 3 mois pour obtenir notre date plancher
max_date AS (
    SELECT date(MAX(order_purchase_timestamp), '-3 months') AS max_order_date_minus_3_months
    FROM orders
),
-- On crée une nouvelle vue qui fait une différence de SET entre les vendeurs qui ont vendus dans les 3 derniers mois et les vendeurs qui ont vendu avant la date plancher
filtered_sellers AS (
    SELECT seller_id
    FROM seller_and_items
    WHERE order_purchase_timestamp > (SELECT max_order_date_minus_3_months FROM max_date)
    EXCEPT
    SELECT seller_id
    FROM seller_and_items
    WHERE order_purchase_timestamp <= (SELECT max_order_date_minus_3_months FROM max_date)
)
-- Enfin on crée une vue avec les vendeurs filtrés à -3 de mois uniquement et on fait une aggrégation de la somme de produits vendus par vendeur
SELECT seller_id, COUNT(product_id) AS total_count_of_products_by_seller
FROM seller_and_items
WHERE seller_id IN 
    (SELECT seller_id FROM filtered_sellers)
GROUP BY seller_id
-- On filtre ceux qui ont vendu plus de 30 produits
HAVING total_count_of_products_by_seller > 30
ORDER BY total_count_of_products_by_seller DESC;


-- Requete 4 : Sélection des 5 codes postaux de clients qui ont + de 30 commandes avec le pire review score moyen sur les 12 derniers mois (référence date d'achat)
-- On crée une nouvelle vue où on calcule la date maximum d'achat dans la table orders et on déduit 12 mois pour obtenir notre date plancher
WITH max_date AS (
    SELECT DATE(MAX(order_purchase_timestamp), '-12 months') AS max_order_date_minus_12_months
    FROM orders
),
-- On crée une nouvelle vue qui fusionne les tables clients, orders par customer_id et reviews par order_id (qui est l'équivalent de customer_id)
review_by_orders_and_customers_zip_code AS (
    SELECT
        customers.customer_zip_code_prefix,
        order_reviews.review_score,
        orders.order_id
    FROM customers
    INNER JOIN orders
    USING(customer_id)
    INNER JOIN order_reviews
    USING(order_id)
    -- On filtre les commandes sans review score et celles qui ont été faites dans les 12 derniers mois
    WHERE order_reviews.review_score IS NOT NULL
        AND orders.order_purchase_timestamp >= (SELECT max_order_date_minus_12_months FROM max_date)
)
-- On crée une nouvelle vue avec une aggrégation par CP de la moyenne des review score et du nombre total de commandes
SELECT
    customer_zip_code_prefix,
    ROUND(AVG(review_score), 2) AS average_review_score,
    COUNT(order_id) AS total_count_of_orders
FROM review_by_orders_and_customers_zip_code
GROUP BY customer_zip_code_prefix
-- On filtre uniquement les CP avec plus de 30 commandes
HAVING total_count_of_orders > 30
-- On ordonne et filtre les 5 pires review score
ORDER BY average_review_score ASC
LIMIT 5;