-- ============================================================
-- Продвинутые хранимые процедуры и пакеты
-- СУБД: Oracle 19c+
-- ============================================================


-- ============================================================
-- Пакет logistics_pkg: основная бизнес-логика
-- ============================================================

-- Спецификация пакета
CREATE OR REPLACE PACKAGE logistics_pkg AS

    -- Типы
    TYPE t_deficit_rec IS RECORD (
        store_id      NUMBER,
        product_id    NUMBER,
        deficit       NUMBER,
        available_wh  NUMBER
    );
    TYPE t_deficit_tab IS TABLE OF t_deficit_rec;

    -- Пересчёт остатков на РЦ по журналу движения (сверка)
    PROCEDURE reconcile_warehouse_stock(
        p_warehouse_id IN NUMBER,
        p_fix          IN BOOLEAN DEFAULT FALSE
    );

    -- Пакетная отгрузка: обработать все заказы в статусе picking
    PROCEDURE batch_ship_orders(
        p_warehouse_id IN NUMBER,
        p_max_orders   IN NUMBER DEFAULT 100
    );

    -- Расчёт оптимального заказа (Economic Order Quantity)
    FUNCTION calc_eoq(
        p_annual_demand IN NUMBER,
        p_order_cost    IN NUMBER,
        p_holding_cost  IN NUMBER
    ) RETURN NUMBER;

    -- Пайплайн-функция: дефициты по всем магазинам РЦ
    FUNCTION get_deficit_list(
        p_warehouse_id IN NUMBER
    ) RETURN t_deficit_tab PIPELINED;

END logistics_pkg;
/


-- Тело пакета
CREATE OR REPLACE PACKAGE BODY logistics_pkg AS

    -- --------------------------------------------------------
    -- Сверка остатков: пересчёт по движениям vs текущие остатки
    -- --------------------------------------------------------
    PROCEDURE reconcile_warehouse_stock(
        p_warehouse_id IN NUMBER,
        p_fix          IN BOOLEAN DEFAULT FALSE
    ) AS
        v_calc_qty NUMBER;
        v_diff     NUMBER;
        v_count    NUMBER := 0;
    BEGIN
        FOR prod IN (
            SELECT DISTINCT product_id
              FROM warehouse_stock
             WHERE warehouse_id = p_warehouse_id
        ) LOOP
            -- Пересчёт по движениям
            SELECT NVL(SUM(
                CASE movement_type
                    WHEN 'inbound' THEN qty
                    WHEN 'outbound' THEN -qty
                    WHEN 'write_off' THEN -qty
                    WHEN 'adjustment' THEN qty
                    ELSE 0
                END
            ), 0)
              INTO v_calc_qty
              FROM stock_movements
             WHERE warehouse_id = p_warehouse_id
               AND product_id = prod.product_id;

            -- Сравнить с текущим
            SELECT qty_available - v_calc_qty
              INTO v_diff
              FROM warehouse_stock
             WHERE warehouse_id = p_warehouse_id
               AND product_id = prod.product_id;

            IF v_diff != 0 THEN
                DBMS_OUTPUT.PUT_LINE(
                    'Расхождение product_id=' || prod.product_id ||
                    ': в таблице=' || (v_calc_qty + v_diff) ||
                    ', по движениям=' || v_calc_qty ||
                    ', разница=' || v_diff
                );

                IF p_fix THEN
                    UPDATE warehouse_stock
                       SET qty_available = v_calc_qty,
                           last_updated = SYSTIMESTAMP
                     WHERE warehouse_id = p_warehouse_id
                       AND product_id = prod.product_id;

                    INSERT INTO stock_movements
                        (movement_type, warehouse_id, product_id, qty,
                         reference_type, created_by)
                    VALUES
                        ('adjustment', p_warehouse_id, prod.product_id,
                         -v_diff, 'reconciliation', 'system');
                END IF;

                v_count := v_count + 1;
            END IF;
        END LOOP;

        IF p_fix THEN
            COMMIT;
        END IF;

        DBMS_OUTPUT.PUT_LINE('Итого расхождений: ' || v_count);
    END reconcile_warehouse_stock;


    -- --------------------------------------------------------
    -- Пакетная отгрузка заказов с логированием
    -- --------------------------------------------------------
    PROCEDURE batch_ship_orders(
        p_warehouse_id IN NUMBER,
        p_max_orders   IN NUMBER DEFAULT 100
    ) AS
        v_shipped NUMBER := 0;
        v_failed  NUMBER := 0;
    BEGIN
        FOR ord IN (
            SELECT order_id
              FROM store_orders
             WHERE warehouse_id = p_warehouse_id
               AND status = 'picking'
             ORDER BY order_date
             FETCH FIRST p_max_orders ROWS ONLY
        ) LOOP
            BEGIN
                SAVEPOINT before_ship;

                ship_order(ord.order_id, 'batch_processor');
                v_shipped := v_shipped + 1;

            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK TO before_ship;
                    v_failed := v_failed + 1;
                    DBMS_OUTPUT.PUT_LINE(
                        'Ошибка отгрузки #' || ord.order_id || ': ' || SQLERRM
                    );
            END;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE(
            'Пакетная отгрузка: успешно=' || v_shipped || ', ошибок=' || v_failed
        );
    END batch_ship_orders;


    -- --------------------------------------------------------
    -- EOQ — формула Уилсона
    -- --------------------------------------------------------
    FUNCTION calc_eoq(
        p_annual_demand IN NUMBER,
        p_order_cost    IN NUMBER,
        p_holding_cost  IN NUMBER
    ) RETURN NUMBER AS
    BEGIN
        IF p_holding_cost <= 0 OR p_annual_demand <= 0 THEN
            RETURN 0;
        END IF;
        RETURN ROUND(SQRT(2 * p_annual_demand * p_order_cost / p_holding_cost));
    END calc_eoq;


    -- --------------------------------------------------------
    -- Пайплайн-функция для потоковой выдачи дефицитов
    -- --------------------------------------------------------
    FUNCTION get_deficit_list(
        p_warehouse_id IN NUMBER
    ) RETURN t_deficit_tab PIPELINED AS
        v_rec t_deficit_rec;
    BEGIN
        FOR r IN (
            SELECT
                ss.store_id,
                ss.product_id,
                ss.qty_min - ss.qty_on_hand AS deficit,
                NVL(ws.qty_available - ws.qty_reserved, 0) AS available_wh
            FROM store_stock ss
            JOIN stores st ON st.store_id = ss.store_id
            LEFT JOIN warehouse_stock ws
                ON ws.warehouse_id = st.warehouse_id
               AND ws.product_id = ss.product_id
            WHERE st.warehouse_id = p_warehouse_id
              AND ss.qty_on_hand < ss.qty_min
              AND st.is_active = 1
            ORDER BY deficit DESC
        ) LOOP
            v_rec.store_id     := r.store_id;
            v_rec.product_id   := r.product_id;
            v_rec.deficit      := r.deficit;
            v_rec.available_wh := r.available_wh;
            PIPE ROW(v_rec);
        END LOOP;
        RETURN;
    END get_deficit_list;

END logistics_pkg;
/


-- Использование пайплайн-функции
SELECT * FROM TABLE(logistics_pkg.get_deficit_list(1));

-- Использование EOQ
SELECT
    p.sku,
    p.product_name,
    outbound.annual_demand,
    logistics_pkg.calc_eoq(outbound.annual_demand, 500, 50) AS optimal_order_qty
FROM products p
JOIN (
    SELECT product_id, SUM(qty) AS annual_demand
      FROM stock_movements
     WHERE movement_type = 'outbound'
       AND created_at >= ADD_MONTHS(SYSDATE, -12)
     GROUP BY product_id
) outbound ON outbound.product_id = p.product_id
ORDER BY annual_demand DESC;


-- ============================================================
-- Процедура с BULK COLLECT и FORALL (массовые операции)
-- ============================================================

CREATE OR REPLACE PROCEDURE bulk_update_store_stock(
    p_store_id IN NUMBER
) AS
    TYPE t_ids  IS TABLE OF NUMBER;
    TYPE t_qtys IS TABLE OF NUMBER;
    v_pids t_ids;
    v_qtys t_qtys;
BEGIN
    -- BULK COLLECT: одним запросом в массив
    SELECT oi.product_id, SUM(oi.qty_received)
      BULK COLLECT INTO v_pids, v_qtys
      FROM order_items oi
      JOIN store_orders so ON so.order_id = oi.order_id
     WHERE so.store_id = p_store_id
       AND so.status = 'delivered'
       AND so.delivered_at >= SYSTIMESTAMP - INTERVAL '1' DAY
     GROUP BY oi.product_id;

    IF v_pids.COUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Нет новых поставок для магазина ' || p_store_id);
        RETURN;
    END IF;

    -- FORALL: массовый UPDATE за одно обращение к БД
    FORALL i IN 1..v_pids.COUNT
        MERGE INTO store_stock ss
        USING (SELECT p_store_id AS sid, v_pids(i) AS pid, v_qtys(i) AS qty FROM dual) src
           ON (ss.store_id = src.sid AND ss.product_id = src.pid)
         WHEN MATCHED THEN
            UPDATE SET qty_on_hand = qty_on_hand + src.qty,
                       last_updated = SYSTIMESTAMP
         WHEN NOT MATCHED THEN
            INSERT (store_id, product_id, qty_on_hand)
            VALUES (src.sid, src.pid, src.qty);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Обновлено позиций: ' || v_pids.COUNT);
END;
/


-- ============================================================
-- Materialized View с автообновлением
-- ============================================================

-- Матвью: ежедневная сводка отгрузок по РЦ
-- Используется для тяжёлых дашбордов вместо прямых запросов
CREATE MATERIALIZED VIEW mv_daily_shipments
    BUILD IMMEDIATE
    REFRESH FAST ON DEMAND
    ENABLE QUERY REWRITE
AS
SELECT
    TRUNC(sm.created_at) AS ship_date,
    sm.warehouse_id,
    sm.movement_type,
    COUNT(*) AS ops_count,
    SUM(sm.qty) AS total_qty,
    COUNT(DISTINCT sm.product_id) AS unique_products,
    COUNT(DISTINCT sm.store_id) AS stores_served
FROM stock_movements sm
WHERE sm.warehouse_id IS NOT NULL
GROUP BY TRUNC(sm.created_at), sm.warehouse_id, sm.movement_type;

-- Матвью лог для FAST REFRESH
CREATE MATERIALIZED VIEW LOG ON stock_movements
    WITH ROWID, SEQUENCE (warehouse_id, store_id, product_id,
                          movement_type, qty, created_at)
    INCLUDING NEW VALUES;

-- Ручное обновление матвью
BEGIN
    DBMS_MVIEW.REFRESH('MV_DAILY_SHIPMENTS', method => 'F'); -- F=fast, C=complete
END;
/

-- Запрос по матвью — Oracle может использовать Query Rewrite
SELECT /*+ gather_plan_statistics REWRITE(mv_daily_shipments) */
    ship_date,
    w.warehouse_code,
    ops_count,
    total_qty,
    stores_served
FROM mv_daily_shipments mv
JOIN warehouses w ON w.warehouse_id = mv.warehouse_id
WHERE ship_date >= TRUNC(SYSDATE) - 7
  AND movement_type = 'outbound'
ORDER BY ship_date DESC, warehouse_code;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));


-- ============================================================
-- Триггер с автоматическим логированием
-- ============================================================

CREATE OR REPLACE TRIGGER trg_stock_movement_audit
    AFTER INSERT ON stock_movements
    FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    -- Обновить last_updated в warehouse_stock при любом движении
    IF :NEW.warehouse_id IS NOT NULL THEN
        UPDATE warehouse_stock
           SET last_updated = SYSTIMESTAMP
         WHERE warehouse_id = :NEW.warehouse_id
           AND product_id = :NEW.product_id;
    END IF;

    COMMIT;
END;
/
