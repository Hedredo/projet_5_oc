# Un script avec l’ensemble des requêtes SQL demandées par Fernanda
# 1
query_1 = """
-- On crée une nouvelle vue avec un champs qui calcule la différence entre le délai estimé et le délai réel
WITH filtered_dates AS (
    SELECT
        order_id,
        order_purchase_timestamp,
        julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) AS delay_estimated_to_delivery
    FROM orders
    WHERE date(order_purchase_timestamp) >= (
    SELECT
        date(MAX(order_purchase_timestamp), '-3 months')
    FROM orders
    )
        AND order_status NOT LIKE 'canceled'
)
-- Enfin on filtre les commandes avec un délai supérieur à 3 jours
SELECT order_id, delay_estimated_to_delivery
FROM filtered_dates
WHERE delay_estimated_to_delivery >=3;
"""
# 2
query_2 = """
WITH grouped_orders AS (
    SELECT
        order_id,
        seller_id,
        SUM(price) AS total_order_value
    FROM order_items
    WHERE order_id IN
        (SELECT order_id
        FROM orders
        WHERE order_status LIKE 'delivered')
    GROUP BY order_id
)
SELECT seller_id, SUM(total_order_value) AS total_value_by_seller
FROM grouped_orders
GROUP BY seller_id
HAVING total_value_by_seller >= 100000;
"""
# 3
query = """
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
max_date AS (
    SELECT date(MAX(order_purchase_timestamp), '-3 months') AS max_order_date
    FROM orders
),
filtered_sellers AS (
    SELECT seller_id
    FROM seller_and_items
    WHERE order_purchase_timestamp > (SELECT max_order_date FROM max_date)
    EXCEPT
    SELECT seller_id
    FROM seller_and_items
    WHERE order_purchase_timestamp <= (SELECT max_order_date FROM max_date)
)
SELECT seller_id, COUNT(product_id) AS count_product
FROM seller_and_items
WHERE seller_id IN 
    (SELECT seller_id FROM filtered_sellers)
GROUP BY seller_id
HAVING count_product > 30;
"""
# 4
query = """
WITH review_by_zip_code AS (
    SELECT
        customer_zip_code_prefix,
        reviews.review_score,
        orders.order_id
    FROM customers
    LEFT JOIN orders
    USING(customer_id)
    LEFT JOIN order_reviews AS reviews
    USING(order_id)
    WHERE reviews.review_score IS NOT NULL
)
SELECT
    customer_zip_code_prefix,
    AVG(review_score) as avg_review,
    COUNT(order_id) as count_order
FROM review_by_zip_code
GROUP BY customer_zip_code_prefix
HAVING count_order > 30
ORDER BY avg_review ASC
LIMIT 5;
"""