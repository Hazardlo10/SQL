-- ============================================================
-- Представления (Views): Логистика РЦ → Магазины
-- СУБД: Oracle 19c+
-- ============================================================

-- Текущие остатки на всех РЦ с информацией о товаре
CREATE OR REPLACE VIEW v_warehouse_stock_detail AS
SELECT
    w.warehouse_code,
    w.warehouse_name,
    p.sku,
    p.product_name,
    pc.category_name,
    pc.storage_type,
    ws.qty_available,
    ws.qty_reserved,
    ws.qty_available - ws.qty_reserved AS qty_free,
    ws.last_updated
FROM warehouse_stock ws
JOIN warehouses w ON w.warehouse_id = ws.warehouse_id
JOIN products p ON p.product_id = ws.product_id
JOIN product_categories pc ON pc.category_id = p.category_id
WHERE w.is_active = 1;


-- Дефицит в магазинах (остаток ниже минимума)
CREATE OR REPLACE VIEW v_store_deficit AS
SELECT
    st.store_code,
    st.store_name,
    st.store_format,
    p.sku,
    p.product_name,
    ss.qty_on_hand,
    ss.qty_min,
    ss.qty_min - ss.qty_on_hand AS deficit,
    w.warehouse_code AS supply_warehouse
FROM store_stock ss
JOIN stores st ON st.store_id = ss.store_id
JOIN products p ON p.product_id = ss.product_id
JOIN warehouses w ON w.warehouse_id = st.warehouse_id
WHERE ss.qty_on_hand < ss.qty_min
  AND st.is_active = 1
ORDER BY deficit DESC;


-- Сводка по заказам магазинов за текущий месяц
CREATE OR REPLACE VIEW v_orders_summary AS
SELECT
    w.warehouse_code,
    st.store_code,
    st.store_name,
    so.status,
    COUNT(so.order_id) AS order_count,
    SUM(so.total_qty) AS total_items,
    ROUND(SUM(so.total_weight), 2) AS total_weight_kg,
    ROUND(AVG(
        CASE WHEN so.delivered_at IS NOT NULL AND so.shipped_at IS NOT NULL
             THEN EXTRACT(DAY FROM (so.delivered_at - so.shipped_at)) * 24
                  + EXTRACT(HOUR FROM (so.delivered_at - so.shipped_at))
        END
    ), 1) AS avg_delivery_hours
FROM store_orders so
JOIN stores st ON st.store_id = so.store_id
JOIN warehouses w ON w.warehouse_id = so.warehouse_id
WHERE so.order_date >= TRUNC(SYSDATE, 'MM')
GROUP BY w.warehouse_code, st.store_code, st.store_name, so.status;


-- Оборачиваемость товаров на РЦ за последние 30 дней
CREATE OR REPLACE VIEW v_turnover_report AS
SELECT
    w.warehouse_code,
    p.sku,
    p.product_name,
    ws.qty_available AS current_stock,
    NVL(outbound.total_shipped, 0) AS shipped_30d,
    NVL(inbound.total_received, 0) AS received_30d,
    CASE
        WHEN NVL(outbound.daily_avg, 0) = 0 THEN NULL
        ELSE ROUND(ws.qty_available / outbound.daily_avg, 1)
    END AS days_of_stock,
    CASE
        WHEN NVL(outbound.daily_avg, 0) = 0 THEN 'Нет движения'
        WHEN ws.qty_available / outbound.daily_avg < 3 THEN 'Критический'
        WHEN ws.qty_available / outbound.daily_avg < 7 THEN 'Низкий'
        WHEN ws.qty_available / outbound.daily_avg < 30 THEN 'Норма'
        ELSE 'Избыток'
    END AS stock_status
FROM warehouse_stock ws
JOIN warehouses w ON w.warehouse_id = ws.warehouse_id
JOIN products p ON p.product_id = ws.product_id
LEFT JOIN (
    SELECT warehouse_id, product_id,
           SUM(qty) AS total_shipped,
           SUM(qty) / 30 AS daily_avg
      FROM stock_movements
     WHERE movement_type = 'outbound'
       AND created_at >= SYSTIMESTAMP - INTERVAL '30' DAY
     GROUP BY warehouse_id, product_id
) outbound ON outbound.warehouse_id = ws.warehouse_id
          AND outbound.product_id = ws.product_id
LEFT JOIN (
    SELECT warehouse_id, product_id,
           SUM(qty) AS total_received
      FROM stock_movements
     WHERE movement_type = 'inbound'
       AND created_at >= SYSTIMESTAMP - INTERVAL '30' DAY
     GROUP BY warehouse_id, product_id
) inbound ON inbound.warehouse_id = ws.warehouse_id
         AND inbound.product_id = ws.product_id
WHERE w.is_active = 1;


-- Ежедневная сводка движений по РЦ
CREATE OR REPLACE VIEW v_daily_movements AS
SELECT
    TRUNC(sm.created_at) AS movement_date,
    w.warehouse_code,
    sm.movement_type,
    COUNT(*) AS operations_count,
    SUM(sm.qty) AS total_qty,
    COUNT(DISTINCT sm.product_id) AS unique_products
FROM stock_movements sm
JOIN warehouses w ON w.warehouse_id = sm.warehouse_id
WHERE sm.created_at >= SYSTIMESTAMP - INTERVAL '90' DAY
GROUP BY TRUNC(sm.created_at), w.warehouse_code, sm.movement_type
ORDER BY movement_date DESC, w.warehouse_code;


-- KPI поставщиков: среднее время поставки и процент выполнения
CREATE OR REPLACE VIEW v_supplier_kpi AS
SELECT
    s.supplier_name,
    COUNT(sh.shipment_id) AS total_shipments,
    COUNT(CASE WHEN sh.status = 'received' THEN 1 END) AS received_count,
    COUNT(CASE WHEN sh.status = 'cancelled' THEN 1 END) AS cancelled_count,
    ROUND(AVG(
        CASE WHEN sh.received_at IS NOT NULL
             THEN EXTRACT(DAY FROM (sh.received_at - sh.shipment_date))
        END
    ), 1) AS avg_lead_days,
    ROUND(
        SUM(CASE WHEN ii.qty_received >= ii.qty_expected THEN 1 ELSE 0 END) /
        NULLIF(COUNT(ii.item_id), 0) * 100, 1
    ) AS fulfillment_pct
FROM suppliers s
JOIN inbound_shipments sh ON sh.supplier_id = s.supplier_id
LEFT JOIN inbound_items ii ON ii.shipment_id = sh.shipment_id
WHERE sh.shipment_date >= ADD_MONTHS(SYSDATE, -6)
GROUP BY s.supplier_name
ORDER BY total_shipments DESC;
