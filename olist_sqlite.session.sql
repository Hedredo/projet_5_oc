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
