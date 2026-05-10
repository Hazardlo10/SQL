-- ============================================================
-- Аналитические запросы: Логистика РЦ → Магазины
-- СУБД: Oracle 19c+
-- ============================================================


-- 1. ABC-анализ товаров по объёму отгрузок за квартал
-- Категория A — 80% оборота, B — 15%, C — 5%
WITH product_revenue AS (
    SELECT
        p.product_id,
        p.sku,
        p.product_name,
        pc.category_name,
        SUM(sm.qty) AS total_qty,
        SUM(sm.qty * p.weight_kg) AS total_weight
    FROM stock_movements sm
    JOIN products p ON p.product_id = sm.product_id
    JOIN product_categories pc ON pc.category_id = p.category_id
    WHERE sm.movement_type = 'outbound'
      AND sm.created_at >= ADD_MONTHS(SYSDATE, -3)
    GROUP BY p.product_id, p.sku, p.product_name, pc.category_name
),
ranked AS (
    SELECT
        pr.*,
        SUM(total_qty) OVER (ORDER BY total_qty DESC) AS running_total,
        SUM(total_qty) OVER () AS grand_total
    FROM product_revenue pr
)
SELECT
    sku,
    product_name,
    category_name,
    total_qty,
    ROUND(total_qty / grand_total * 100, 2) AS pct_of_total,
    CASE
        WHEN running_total <= grand_total * 0.8 THEN 'A'
        WHEN running_total <= grand_total * 0.95 THEN 'B'
        ELSE 'C'
    END AS abc_class
FROM ranked
ORDER BY total_qty DESC;


-- 2. Динамика отгрузок по неделям с процентом роста (WoW)
WITH weekly_stats AS (
    SELECT
        TRUNC(created_at, 'IW') AS week_start,
        COUNT(DISTINCT reference_id) AS orders_count,
        SUM(qty) AS total_qty,
        COUNT(DISTINCT product_id) AS unique_skus
    FROM stock_movements
    WHERE movement_type = 'outbound'
      AND created_at >= ADD_MONTHS(SYSDATE, -3)
    GROUP BY TRUNC(created_at, 'IW')
)
SELECT
    TO_CHAR(week_start, 'YYYY-MM-DD') AS week,
    orders_count,
    total_qty,
    unique_skus,
    ROUND(
        (total_qty - LAG(total_qty) OVER (ORDER BY week_start)) /
        NULLIF(LAG(total_qty) OVER (ORDER BY week_start), 0) * 100, 1
    ) AS wow_growth_pct
FROM weekly_stats
ORDER BY week_start;


-- 3. Топ-10 магазинов по объёму заказов с рангом внутри формата
SELECT * FROM (
    SELECT
        st.store_code,
        st.store_name,
        st.store_format,
        COUNT(so.order_id) AS total_orders,
        SUM(so.total_qty) AS total_items,
        ROUND(SUM(so.total_weight), 0) AS total_weight_kg,
        ROUND(AVG(so.total_qty), 0) AS avg_order_size,
        DENSE_RANK() OVER (
            PARTITION BY st.store_format
            ORDER BY SUM(so.total_qty) DESC
        ) AS rank_in_format
    FROM store_orders so
    JOIN stores st ON st.store_id = so.store_id
    WHERE so.status = 'delivered'
      AND so.order_date >= ADD_MONTHS(SYSDATE, -1)
    GROUP BY st.store_code, st.store_name, st.store_format
)
WHERE rank_in_format <= 10
ORDER BY store_format, rank_in_format;


-- 4. Анализ сроков годности: товары с риском просрочки на РЦ
SELECT
    w.warehouse_code,
    p.sku,
    p.product_name,
    ii.expiry_date,
    TRUNC(ii.expiry_date) - TRUNC(SYSDATE) AS days_until_expiry,
    SUM(ii.qty_received) AS qty_at_risk,
    CASE
        WHEN ii.expiry_date < SYSDATE THEN 'ПРОСРОЧЕН'
        WHEN ii.expiry_date < SYSDATE + 3 THEN 'КРИТИЧНО (< 3 дней)'
        WHEN ii.expiry_date < SYSDATE + 7 THEN 'ВНИМАНИЕ (< 7 дней)'
        ELSE 'НОРМА'
    END AS risk_level
FROM inbound_items ii
JOIN inbound_shipments sh ON sh.shipment_id = ii.shipment_id
JOIN warehouses w ON w.warehouse_id = sh.warehouse_id
JOIN products p ON p.product_id = ii.product_id
WHERE sh.status = 'received'
  AND ii.expiry_date <= SYSDATE + 7
GROUP BY w.warehouse_code, p.sku, p.product_name, ii.expiry_date
ORDER BY ii.expiry_date;


-- 5. Загрузка РЦ по дням недели (паттерны отгрузки)
SELECT
    TO_CHAR(created_at, 'DY', 'NLS_DATE_LANGUAGE=RUSSIAN') AS day_of_week,
    TO_CHAR(created_at, 'D') AS day_num,
    COUNT(*) AS operations,
    SUM(qty) AS total_qty,
    COUNT(DISTINCT store_id) AS stores_served,
    ROUND(AVG(qty), 1) AS avg_qty_per_op
FROM stock_movements
WHERE movement_type = 'outbound'
  AND created_at >= ADD_MONTHS(SYSDATE, -3)
GROUP BY TO_CHAR(created_at, 'DY', 'NLS_DATE_LANGUAGE=RUSSIAN'),
         TO_CHAR(created_at, 'D')
ORDER BY day_num;


-- 6. Когортный анализ магазинов: как меняется объём заказов с момента открытия
WITH store_months AS (
    SELECT
        so.store_id,
        st.store_name,
        st.opened_at,
        TRUNC(so.order_date, 'MM') AS order_month,
        MONTHS_BETWEEN(TRUNC(so.order_date, 'MM'), TRUNC(st.opened_at, 'MM')) AS month_num,
        SUM(so.total_qty) AS monthly_qty
    FROM store_orders so
    JOIN stores st ON st.store_id = so.store_id
    WHERE so.status = 'delivered'
    GROUP BY so.store_id, st.store_name, st.opened_at, TRUNC(so.order_date, 'MM')
)
SELECT
    month_num,
    COUNT(DISTINCT store_id) AS stores_count,
    ROUND(AVG(monthly_qty), 0) AS avg_qty_per_store,
    ROUND(MEDIAN(monthly_qty), 0) AS median_qty
FROM store_months
WHERE month_num >= 0
GROUP BY month_num
ORDER BY month_num;


-- 7. Выявление аномалий в заказах (отклонение > 2 сигмы от среднего)
WITH order_stats AS (
    SELECT
        so.store_id,
        st.store_name,
        so.order_id,
        so.total_qty,
        so.order_date,
        AVG(so.total_qty) OVER (PARTITION BY so.store_id) AS avg_qty,
        STDDEV(so.total_qty) OVER (PARTITION BY so.store_id) AS stddev_qty
    FROM store_orders so
    JOIN stores st ON st.store_id = so.store_id
    WHERE so.status IN ('delivered', 'shipped')
      AND so.order_date >= ADD_MONTHS(SYSDATE, -3)
)
SELECT
    store_name,
    order_id,
    total_qty,
    ROUND(avg_qty, 0) AS avg_qty,
    ROUND((total_qty - avg_qty) / NULLIF(stddev_qty, 0), 2) AS z_score,
    TO_CHAR(order_date, 'YYYY-MM-DD HH24:MI') AS order_date
FROM order_stats
WHERE ABS(total_qty - avg_qty) > 2 * stddev_qty
  AND stddev_qty > 0
ORDER BY ABS(total_qty - avg_qty) / stddev_qty DESC;


-- 8. Матрица поставщик × категория: кто что поставляет и сколько
SELECT *
FROM (
    SELECT
        s.supplier_name,
        pc.category_name,
        SUM(ii.qty_received) AS total_qty
    FROM inbound_items ii
    JOIN inbound_shipments sh ON sh.shipment_id = ii.shipment_id
    JOIN suppliers s ON s.supplier_id = sh.supplier_id
    JOIN products p ON p.product_id = ii.product_id
    JOIN product_categories pc ON pc.category_id = p.category_id
    WHERE sh.status = 'received'
      AND sh.received_at >= ADD_MONTHS(SYSDATE, -6)
    GROUP BY s.supplier_name, pc.category_name
)
PIVOT (
    SUM(total_qty)
    FOR category_name IN (
        'Молочная продукция' AS dairy,
        'Хлебобулочные' AS bakery,
        'Мясо' AS meat,
        'Овощи и фрукты' AS produce,
        'Бакалея' AS grocery,
        'Напитки' AS beverages
    )
);
