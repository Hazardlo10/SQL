-- ============================================================
-- Работа с планами выполнения запросов
-- СУБД: Oracle 19c+
-- ============================================================
-- Демонстрация: EXPLAIN PLAN, DBMS_XPLAN, реальный план (GATHER_PLAN_STATISTICS),
-- хинты, анализ метрик выполнения, сравнение планов


-- ============================================================
-- 1. EXPLAIN PLAN — оценочный план (без выполнения запроса)
-- ============================================================

-- Построить план для тяжёлого аналитического запроса
EXPLAIN PLAN SET STATEMENT_ID = 'turnover_query' FOR
SELECT
    w.warehouse_code,
    p.sku,
    p.product_name,
    ws.qty_available,
    SUM(CASE WHEN sm.movement_type = 'outbound' THEN sm.qty ELSE 0 END) AS shipped_30d,
    SUM(CASE WHEN sm.movement_type = 'inbound' THEN sm.qty ELSE 0 END) AS received_30d
FROM warehouse_stock ws
JOIN warehouses w ON w.warehouse_id = ws.warehouse_id
JOIN products p ON p.product_id = ws.product_id
LEFT JOIN stock_movements sm
    ON sm.warehouse_id = ws.warehouse_id
   AND sm.product_id = ws.product_id
   AND sm.created_at >= SYSTIMESTAMP - INTERVAL '30' DAY
WHERE w.is_active = 1
GROUP BY w.warehouse_code, p.sku, p.product_name, ws.qty_available
ORDER BY shipped_30d DESC;

-- Вывод плана в базовом формате
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'turnover_query'
));

-- Вывод плана с предикатами и информацией о колонках
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
    statement_id => 'turnover_query',
    format       => 'ALL'  -- BASIC, TYPICAL, ALL, ADVANCED
));


-- ============================================================
-- 2. Реальный план выполнения (GATHER_PLAN_STATISTICS)
-- ============================================================

-- Хинт gather_plan_statistics заставляет Oracle собирать реальную статистику:
-- actual rows, actual time, buffer gets, reads для КАЖДОЙ операции плана

-- Запрос: поиск дефицитных товаров по всем магазинам с джойнами
SELECT /*+ gather_plan_statistics */
    st.store_code,
    st.store_name,
    p.sku,
    p.product_name,
    ss.qty_on_hand,
    ss.qty_min,
    ss.qty_min - ss.qty_on_hand AS deficit,
    w.warehouse_code,
    NVL(ws.qty_available - ws.qty_reserved, 0) AS available_at_wh
FROM store_stock ss
JOIN stores st ON st.store_id = ss.store_id
JOIN products p ON p.product_id = ss.product_id
JOIN warehouses w ON w.warehouse_id = st.warehouse_id
LEFT JOIN warehouse_stock ws
    ON ws.warehouse_id = st.warehouse_id
   AND ws.product_id = ss.product_id
WHERE ss.qty_on_hand < ss.qty_min
  AND st.is_active = 1
ORDER BY deficit DESC;

-- Вывод РЕАЛЬНОГО плана из курсорного кэша
-- format => 'ALLSTATS LAST' показывает:
--   Starts  — сколько раз выполнялась операция
--   E-Rows  — оценка оптимизатора (estimated rows)
--   A-Rows  — реальное кол-во строк (actual rows)
--   A-Time  — реальное время выполнения
--   Buffers — logical reads (buffer gets)
--   Reads   — physical reads
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
    sql_id  => NULL,   -- NULL = последний выполненный запрос
    format  => 'ALLSTATS LAST'
));


-- ============================================================
-- 3. Анализ расхождений E-Rows vs A-Rows
-- ============================================================

-- Запрос с подзапросом и оконными функциями — часто ошибается оптимизатор
SELECT /*+ gather_plan_statistics */
    warehouse_code,
    sku,
    product_name,
    movement_date,
    daily_qty,
    running_total,
    daily_qty - LAG(daily_qty) OVER (
        PARTITION BY warehouse_id, product_id ORDER BY movement_date
    ) AS qty_change
FROM (
    SELECT
        sm.warehouse_id,
        w.warehouse_code,
        sm.product_id,
        p.sku,
        p.product_name,
        TRUNC(sm.created_at) AS movement_date,
        SUM(sm.qty) AS daily_qty,
        SUM(SUM(sm.qty)) OVER (
            PARTITION BY sm.warehouse_id, sm.product_id
            ORDER BY TRUNC(sm.created_at)
        ) AS running_total
    FROM stock_movements sm
    JOIN warehouses w ON w.warehouse_id = sm.warehouse_id
    JOIN products p ON p.product_id = sm.product_id
    WHERE sm.movement_type = 'outbound'
      AND sm.created_at >= ADD_MONTHS(SYSDATE, -3)
    GROUP BY sm.warehouse_id, w.warehouse_code, sm.product_id,
             p.sku, p.product_name, TRUNC(sm.created_at)
)
ORDER BY warehouse_code, sku, movement_date;

-- Реальный план с метриками + информация о предикатах
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
    sql_id  => NULL,
    format  => 'ALLSTATS LAST +PREDICATE +COST +BYTES'
));


-- ============================================================
-- 4. Сравнение планов с хинтами и без
-- ============================================================

-- Вариант A: без хинтов — пусть оптимизатор решает
SELECT /*+ gather_plan_statistics */
    so.order_id,
    st.store_name,
    so.order_date,
    so.total_qty,
    COUNT(oi.item_id) AS items_count,
    SUM(oi.qty_ordered * p.weight_kg) AS total_weight
FROM store_orders so
JOIN stores st ON st.store_id = so.store_id
JOIN order_items oi ON oi.order_id = so.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE so.status = 'delivered'
  AND so.order_date >= ADD_MONTHS(SYSDATE, -1)
GROUP BY so.order_id, st.store_name, so.order_date, so.total_qty
ORDER BY so.order_date DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));


-- Вариант B: принудительный HASH JOIN вместо NESTED LOOPS
SELECT /*+ gather_plan_statistics USE_HASH(so st oi p) LEADING(so st oi p) */
    so.order_id,
    st.store_name,
    so.order_date,
    so.total_qty,
    COUNT(oi.item_id) AS items_count,
    SUM(oi.qty_ordered * p.weight_kg) AS total_weight
FROM store_orders so
JOIN stores st ON st.store_id = so.store_id
JOIN order_items oi ON oi.order_id = so.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE so.status = 'delivered'
  AND so.order_date >= ADD_MONTHS(SYSDATE, -1)
GROUP BY so.order_id, st.store_name, so.order_date, so.total_qty
ORDER BY so.order_date DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));


-- Вариант C: FULL TABLE SCAN с параллелизмом
SELECT /*+ gather_plan_statistics FULL(so) PARALLEL(so, 4) */
    so.order_id,
    st.store_name,
    so.order_date,
    so.total_qty,
    COUNT(oi.item_id) AS items_count,
    SUM(oi.qty_ordered * p.weight_kg) AS total_weight
FROM store_orders so
JOIN stores st ON st.store_id = so.store_id
JOIN order_items oi ON oi.order_id = so.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE so.status = 'delivered'
  AND so.order_date >= ADD_MONTHS(SYSDATE, -1)
GROUP BY so.order_id, st.store_name, so.order_date, so.total_qty
ORDER BY so.order_date DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));


-- ============================================================
-- 5. Поиск проблемных запросов через V$SQL
-- ============================================================

-- Топ-10 самых тяжёлых запросов по buffer gets (logical reads)
SELECT
    sql_id,
    plan_hash_value,
    executions,
    ROUND(elapsed_time / 1e6, 2) AS elapsed_sec,
    buffer_gets,
    ROUND(buffer_gets / NULLIF(executions, 0)) AS gets_per_exec,
    disk_reads,
    rows_processed,
    SUBSTR(sql_text, 1, 120) AS sql_preview
FROM v$sql
WHERE parsing_schema_name = USER
  AND executions > 0
ORDER BY buffer_gets DESC
FETCH FIRST 10 ROWS ONLY;

-- Запросы с большим расхождением E-Rows vs A-Rows (возможна stale-статистика)
SELECT
    s.sql_id,
    s.plan_hash_value,
    p.operation,
    p.options,
    p.object_name,
    p.cardinality AS estimated_rows,
    st.output_rows AS actual_rows,
    CASE
        WHEN p.cardinality > 0
        THEN ROUND(st.output_rows / p.cardinality, 1)
        ELSE NULL
    END AS ratio
FROM v$sql s
JOIN v$sql_plan p
    ON p.sql_id = s.sql_id AND p.plan_hash_value = s.plan_hash_value
JOIN v$sql_plan_statistics_all st
    ON st.sql_id = s.sql_id AND st.plan_hash_value = s.plan_hash_value
   AND st.id = p.id
WHERE s.parsing_schema_name = USER
  AND p.cardinality > 0
  AND st.output_rows > 0
  AND (st.output_rows / p.cardinality > 10 OR p.cardinality / st.output_rows > 10)
ORDER BY ABS(st.output_rows - p.cardinality) DESC
FETCH FIRST 20 ROWS ONLY;


-- ============================================================
-- 6. Диагностика через DBMS_XPLAN.DISPLAY_AWR (исторические планы)
-- ============================================================

-- Получить sql_id нужного запроса
SELECT sql_id, plan_hash_value, executions, elapsed_time
FROM dba_hist_sqlstat
WHERE sql_text LIKE '%store_orders%deficit%'
  AND executions > 0
ORDER BY snap_id DESC
FETCH FIRST 5 ROWS ONLY;

-- Посмотреть план из AWR (после того как запрос вытеснен из курсорного кэша)
-- SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_AWR('sql_id_here'));


-- ============================================================
-- 7. SQL Monitor (для запросов > 5 секунд или с MONITOR хинтом)
-- ============================================================

-- Принудительный мониторинг короткого запроса
SELECT /*+ MONITOR */
    w.warehouse_code,
    COUNT(DISTINCT sm.product_id) AS unique_products,
    SUM(sm.qty) AS total_qty,
    ROUND(SUM(sm.qty * p.weight_kg), 0) AS total_weight_kg
FROM stock_movements sm
JOIN warehouses w ON w.warehouse_id = sm.warehouse_id
JOIN products p ON p.product_id = sm.product_id
WHERE sm.movement_type = 'outbound'
  AND sm.created_at >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP BY w.warehouse_code;

-- Отчёт SQL Monitor в текстовом формате
SELECT DBMS_SQL_MONITOR.REPORT_SQL_MONITOR(
    type         => 'TEXT',
    report_level => 'ALL'
) AS report
FROM dual;


-- ============================================================
-- 8. Адаптивные планы (Adaptive Plans) — Oracle 12c+
-- ============================================================

-- Oracle может менять метод JOIN на лету (NL → HASH) если E-Rows сильно
-- расходятся с A-Rows. Формат +ADAPTIVE показывает обе ветки плана.

SELECT /*+ gather_plan_statistics */
    s.supplier_name,
    p.product_name,
    SUM(ii.qty_received) AS total_received,
    COUNT(DISTINCT sh.shipment_id) AS shipments,
    ROUND(AVG(
        EXTRACT(DAY FROM (sh.received_at - sh.shipment_date))
    ), 1) AS avg_lead_days
FROM inbound_items ii
JOIN inbound_shipments sh ON sh.shipment_id = ii.shipment_id
JOIN suppliers s ON s.supplier_id = sh.supplier_id
JOIN products p ON p.product_id = ii.product_id
WHERE sh.status = 'received'
  AND sh.received_at >= ADD_MONTHS(SYSDATE, -6)
GROUP BY s.supplier_name, p.product_name
HAVING SUM(ii.qty_received) > 100
ORDER BY total_received DESC;

-- Показать адаптивный план с обеими ветками
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
    NULL, NULL, 'ALLSTATS LAST +ADAPTIVE'
));
