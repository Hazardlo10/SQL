-- ============================================================
-- Функции: Логистика РЦ → Магазины
-- СУБД: Oracle 19c+
-- ============================================================

-- Доступный остаток товара на РЦ (за вычетом резерва)
CREATE OR REPLACE FUNCTION get_available_stock(
    p_warehouse_id IN NUMBER,
    p_product_id   IN NUMBER
) RETURN NUMBER AS
    v_available NUMBER;
BEGIN
    SELECT NVL(qty_available - qty_reserved, 0)
      INTO v_available
      FROM warehouse_stock
     WHERE warehouse_id = p_warehouse_id
       AND product_id = p_product_id;

    RETURN v_available;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END;
/


-- Оборачиваемость товара на РЦ за период (дней на продажу среднего запаса)
CREATE OR REPLACE FUNCTION calc_turnover_days(
    p_warehouse_id IN NUMBER,
    p_product_id   IN NUMBER,
    p_days         IN NUMBER DEFAULT 30
) RETURN NUMBER AS
    v_avg_stock    NUMBER;
    v_total_sold   NUMBER;
    v_turnover     NUMBER;
BEGIN
    -- Средний остаток по движениям
    SELECT NVL(AVG(qty), 0)
      INTO v_avg_stock
      FROM (
          SELECT SUM(CASE WHEN movement_type = 'inbound' THEN qty ELSE -qty END)
                 OVER (ORDER BY created_at) AS qty
            FROM stock_movements
           WHERE warehouse_id = p_warehouse_id
             AND product_id = p_product_id
             AND created_at >= SYSTIMESTAMP - NUMTODSINTERVAL(p_days, 'DAY')
      );

    -- Всего отгружено за период
    SELECT NVL(SUM(qty), 0)
      INTO v_total_sold
      FROM stock_movements
     WHERE warehouse_id = p_warehouse_id
       AND product_id = p_product_id
       AND movement_type = 'outbound'
       AND created_at >= SYSTIMESTAMP - NUMTODSINTERVAL(p_days, 'DAY');

    IF v_total_sold = 0 THEN
        RETURN -1; -- нет продаж
    END IF;

    v_turnover := ROUND(v_avg_stock / (v_total_sold / p_days), 1);
    RETURN v_turnover;
END;
/


-- Процент выполнения заказа (qty_received / qty_ordered)
CREATE OR REPLACE FUNCTION order_fulfillment_rate(
    p_order_id IN NUMBER
) RETURN NUMBER AS
    v_rate NUMBER;
BEGIN
    SELECT ROUND(
        NVL(SUM(qty_received), 0) / NULLIF(SUM(qty_ordered), 0) * 100, 2
    )
      INTO v_rate
      FROM order_items
     WHERE order_id = p_order_id;

    RETURN NVL(v_rate, 0);
END;
/


-- Среднее время доставки заказов от РЦ до магазина (в часах) за период
CREATE OR REPLACE FUNCTION avg_delivery_hours(
    p_warehouse_id IN NUMBER,
    p_store_id     IN NUMBER DEFAULT NULL,
    p_days         IN NUMBER DEFAULT 30
) RETURN NUMBER AS
    v_avg_hours NUMBER;
BEGIN
    SELECT ROUND(AVG(
        EXTRACT(DAY FROM (delivered_at - shipped_at)) * 24 +
        EXTRACT(HOUR FROM (delivered_at - shipped_at))
    ), 1)
      INTO v_avg_hours
      FROM store_orders
     WHERE warehouse_id = p_warehouse_id
       AND (p_store_id IS NULL OR store_id = p_store_id)
       AND status = 'delivered'
       AND shipped_at IS NOT NULL
       AND delivered_at IS NOT NULL
       AND order_date >= SYSTIMESTAMP - NUMTODSINTERVAL(p_days, 'DAY');

    RETURN NVL(v_avg_hours, 0);
END;
/


-- Прогноз дефицита: через сколько дней закончится товар на РЦ при текущей скорости отгрузки
CREATE OR REPLACE FUNCTION days_until_stockout(
    p_warehouse_id IN NUMBER,
    p_product_id   IN NUMBER
) RETURN NUMBER AS
    v_stock     NUMBER;
    v_daily_avg NUMBER;
BEGIN
    SELECT NVL(qty_available - qty_reserved, 0)
      INTO v_stock
      FROM warehouse_stock
     WHERE warehouse_id = p_warehouse_id
       AND product_id = p_product_id;

    -- Среднедневная отгрузка за 30 дней
    SELECT NVL(SUM(qty), 0) / 30
      INTO v_daily_avg
      FROM stock_movements
     WHERE warehouse_id = p_warehouse_id
       AND product_id = p_product_id
       AND movement_type = 'outbound'
       AND created_at >= SYSTIMESTAMP - NUMTODSINTERVAL(30, 'DAY');

    IF v_daily_avg = 0 THEN
        RETURN 999; -- нет расхода
    END IF;

    RETURN ROUND(v_stock / v_daily_avg);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END;
/


-- ABC-классификация товара по выручке за период
-- Возвращает 'A' (80% выручки), 'B' (15%), 'C' (5%)
CREATE OR REPLACE FUNCTION product_abc_class(
    p_product_id   IN NUMBER,
    p_warehouse_id IN NUMBER,
    p_days         IN NUMBER DEFAULT 90
) RETURN CHAR AS
    v_rank_pct NUMBER;
BEGIN
    SELECT pct INTO v_rank_pct FROM (
        SELECT
            product_id,
            ROUND(
                CUME_DIST() OVER (ORDER BY total_revenue DESC) * 100
            ) AS pct
        FROM (
            SELECT
                sm.product_id,
                SUM(sm.qty * p.weight_kg) AS total_revenue
              FROM stock_movements sm
              JOIN products p ON p.product_id = sm.product_id
             WHERE sm.warehouse_id = p_warehouse_id
               AND sm.movement_type = 'outbound'
               AND sm.created_at >= SYSTIMESTAMP - NUMTODSINTERVAL(p_days, 'DAY')
             GROUP BY sm.product_id
        )
    )
    WHERE product_id = p_product_id;

    IF v_rank_pct <= 20 THEN
        RETURN 'A';
    ELSIF v_rank_pct <= 50 THEN
        RETURN 'B';
    ELSE
        RETURN 'C';
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'C';
END;
/
