-- ============================================================
-- Хранимые процедуры: Логистика РЦ → Магазины
-- СУБД: Oracle 19c+
-- ============================================================

-- Приёмка поставки на РЦ
-- Обновляет статус поставки, пересчитывает остатки, пишет в журнал движения
CREATE OR REPLACE PROCEDURE receive_shipment(
    p_shipment_id IN NUMBER,
    p_user        IN VARCHAR2 DEFAULT 'system'
) AS
    v_warehouse_id NUMBER;
    v_status       VARCHAR2(20);
BEGIN
    SELECT warehouse_id, status
      INTO v_warehouse_id, v_status
      FROM inbound_shipments
     WHERE shipment_id = p_shipment_id;

    IF v_status != 'in_transit' THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Приёмка возможна только для поставок в статусе in_transit. Текущий: ' || v_status);
    END IF;

    -- Обновить статус поставки
    UPDATE inbound_shipments
       SET status = 'received',
           received_at = SYSTIMESTAMP
     WHERE shipment_id = p_shipment_id;

    -- Обработать каждую позицию
    FOR item IN (
        SELECT item_id, product_id, qty_expected
          FROM inbound_items
         WHERE shipment_id = p_shipment_id
    ) LOOP
        -- Принимаем полное количество
        UPDATE inbound_items
           SET qty_received = qty_expected
         WHERE item_id = item.item_id;

        -- Обновить остатки на РЦ (MERGE — upsert)
        MERGE INTO warehouse_stock ws
        USING (SELECT v_warehouse_id AS wh, item.product_id AS pid FROM dual) src
           ON (ws.warehouse_id = src.wh AND ws.product_id = src.pid)
         WHEN MATCHED THEN
            UPDATE SET qty_available = qty_available + item.qty_expected,
                       last_updated = SYSTIMESTAMP
         WHEN NOT MATCHED THEN
            INSERT (warehouse_id, product_id, qty_available)
            VALUES (src.wh, src.pid, item.qty_expected);

        -- Журнал движения
        INSERT INTO stock_movements
            (movement_type, warehouse_id, product_id, qty, reference_id, reference_type, created_by)
        VALUES
            ('inbound', v_warehouse_id, item.product_id, item.qty_expected,
             p_shipment_id, 'inbound_shipment', p_user);
    END LOOP;

    COMMIT;
END;
/


-- Создание заказа магазина на РЦ
-- Проверяет наличие, резервирует товар, рассчитывает вес
CREATE OR REPLACE PROCEDURE create_store_order(
    p_store_id     IN NUMBER,
    p_items        IN SYS.ODCINUMBERLIST,   -- product_id массив
    p_quantities   IN SYS.ODCINUMBERLIST,   -- qty массив
    p_order_id     OUT NUMBER
) AS
    v_warehouse_id NUMBER;
    v_available    NUMBER;
    v_weight       NUMBER(10, 2);
    v_total_qty    NUMBER := 0;
    v_total_weight NUMBER(10, 2) := 0;
BEGIN
    IF p_items.COUNT != p_quantities.COUNT THEN
        RAISE_APPLICATION_ERROR(-20002, 'Массивы товаров и количеств должны быть одинаковой длины');
    END IF;

    -- Определить РЦ магазина
    SELECT warehouse_id INTO v_warehouse_id
      FROM stores
     WHERE store_id = p_store_id;

    -- Создать заказ
    INSERT INTO store_orders (store_id, warehouse_id, status)
    VALUES (p_store_id, v_warehouse_id, 'new')
    RETURNING order_id INTO p_order_id;

    -- Обработать позиции
    FOR i IN 1..p_items.COUNT LOOP
        -- Проверить остаток
        SELECT NVL(qty_available - qty_reserved, 0)
          INTO v_available
          FROM warehouse_stock
         WHERE warehouse_id = v_warehouse_id
           AND product_id = p_items(i);

        IF v_available < p_quantities(i) THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20003,
                'Недостаточно товара ID=' || p_items(i) ||
                '. Доступно: ' || v_available || ', запрошено: ' || p_quantities(i));
        END IF;

        -- Получить вес
        SELECT NVL(weight_kg, 0) * p_quantities(i)
          INTO v_weight
          FROM products
         WHERE product_id = p_items(i);

        -- Добавить позицию
        INSERT INTO order_items (order_id, product_id, qty_ordered)
        VALUES (p_order_id, p_items(i), p_quantities(i));

        -- Зарезервировать
        UPDATE warehouse_stock
           SET qty_reserved = qty_reserved + p_quantities(i),
               last_updated = SYSTIMESTAMP
         WHERE warehouse_id = v_warehouse_id
           AND product_id = p_items(i);

        v_total_qty    := v_total_qty + p_quantities(i);
        v_total_weight := v_total_weight + v_weight;
    END LOOP;

    -- Обновить итоги заказа
    UPDATE store_orders
       SET total_qty = v_total_qty,
           total_weight = v_total_weight
     WHERE order_id = p_order_id;

    COMMIT;
END;
/


-- Отгрузка заказа с РЦ
-- Списывает резерв и остатки, обновляет статус
CREATE OR REPLACE PROCEDURE ship_order(
    p_order_id IN NUMBER,
    p_user     IN VARCHAR2 DEFAULT 'system'
) AS
    v_warehouse_id NUMBER;
    v_store_id     NUMBER;
    v_status       VARCHAR2(20);
BEGIN
    SELECT warehouse_id, store_id, status
      INTO v_warehouse_id, v_store_id, v_status
      FROM store_orders
     WHERE order_id = p_order_id;

    IF v_status NOT IN ('new', 'picking') THEN
        RAISE_APPLICATION_ERROR(-20004,
            'Отгрузка невозможна для заказа в статусе ' || v_status);
    END IF;

    FOR item IN (
        SELECT product_id, qty_ordered
          FROM order_items
         WHERE order_id = p_order_id
    ) LOOP
        -- Списать с РЦ
        UPDATE warehouse_stock
           SET qty_available = qty_available - item.qty_ordered,
               qty_reserved  = qty_reserved - item.qty_ordered,
               last_updated  = SYSTIMESTAMP
         WHERE warehouse_id = v_warehouse_id
           AND product_id = item.product_id;

        -- Отметить отгруженное кол-во
        UPDATE order_items
           SET qty_shipped = qty_ordered
         WHERE order_id = p_order_id
           AND product_id = item.product_id;

        -- Журнал
        INSERT INTO stock_movements
            (movement_type, warehouse_id, store_id, product_id, qty,
             reference_id, reference_type, created_by)
        VALUES
            ('outbound', v_warehouse_id, v_store_id, item.product_id,
             item.qty_ordered, p_order_id, 'store_order', p_user);
    END LOOP;

    UPDATE store_orders
       SET status = 'shipped',
           shipped_at = SYSTIMESTAMP
     WHERE order_id = p_order_id;

    COMMIT;
END;
/


-- Приёмка товара магазином
-- Обновляет остатки магазина, ставит статус delivered
CREATE OR REPLACE PROCEDURE receive_at_store(
    p_order_id IN NUMBER
) AS
    v_store_id NUMBER;
    v_status   VARCHAR2(20);
BEGIN
    SELECT store_id, status
      INTO v_store_id, v_status
      FROM store_orders
     WHERE order_id = p_order_id;

    IF v_status != 'shipped' THEN
        RAISE_APPLICATION_ERROR(-20005,
            'Приёмка в магазине возможна только для отгруженных заказов');
    END IF;

    FOR item IN (
        SELECT product_id, qty_shipped
          FROM order_items
         WHERE order_id = p_order_id
    ) LOOP
        -- Обновить остатки магазина
        MERGE INTO store_stock ss
        USING (SELECT v_store_id AS sid, item.product_id AS pid FROM dual) src
           ON (ss.store_id = src.sid AND ss.product_id = src.pid)
         WHEN MATCHED THEN
            UPDATE SET qty_on_hand = qty_on_hand + item.qty_shipped,
                       last_updated = SYSTIMESTAMP
         WHEN NOT MATCHED THEN
            INSERT (store_id, product_id, qty_on_hand)
            VALUES (src.sid, src.pid, item.qty_shipped);

        UPDATE order_items
           SET qty_received = qty_shipped
         WHERE order_id = p_order_id
           AND product_id = item.product_id;
    END LOOP;

    UPDATE store_orders
       SET status = 'delivered',
           delivered_at = SYSTIMESTAMP
     WHERE order_id = p_order_id;

    COMMIT;
END;
/


-- Списание просроченного товара на РЦ
CREATE OR REPLACE PROCEDURE write_off_expired(
    p_warehouse_id IN NUMBER,
    p_user         IN VARCHAR2 DEFAULT 'system'
) AS
    v_count NUMBER := 0;
BEGIN
    FOR exp IN (
        SELECT ii.product_id, SUM(ii.qty_received) AS qty
          FROM inbound_items ii
          JOIN inbound_shipments s ON s.shipment_id = ii.shipment_id
         WHERE s.warehouse_id = p_warehouse_id
           AND s.status = 'received'
           AND ii.expiry_date < TRUNC(SYSDATE)
         GROUP BY ii.product_id
    ) LOOP
        UPDATE warehouse_stock
           SET qty_available = GREATEST(qty_available - exp.qty, 0),
               last_updated = SYSTIMESTAMP
         WHERE warehouse_id = p_warehouse_id
           AND product_id = exp.product_id;

        INSERT INTO stock_movements
            (movement_type, warehouse_id, product_id, qty, reference_type, created_by)
        VALUES
            ('write_off', p_warehouse_id, exp.product_id, exp.qty, 'expiry', p_user);

        v_count := v_count + 1;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Списано позиций: ' || v_count);
END;
/


-- Автозаказ: генерация заказов для магазинов с дефицитом
-- Если qty_on_hand < qty_min — создаёт заказ до двойного минимума
CREATE OR REPLACE PROCEDURE generate_auto_orders(
    p_warehouse_id IN NUMBER
) AS
    v_order_id NUMBER;
    v_items    SYS.ODCINUMBERLIST;
    v_qtys     SYS.ODCINUMBERLIST;
BEGIN
    FOR store_rec IN (
        SELECT DISTINCT ss.store_id
          FROM store_stock ss
          JOIN stores st ON st.store_id = ss.store_id
         WHERE st.warehouse_id = p_warehouse_id
           AND ss.qty_on_hand < ss.qty_min
           AND st.is_active = 1
    ) LOOP
        -- Собрать дефицитные позиции
        SELECT product_id, (qty_min * 2 - qty_on_hand)
          BULK COLLECT INTO v_items, v_qtys
          FROM store_stock
         WHERE store_id = store_rec.store_id
           AND qty_on_hand < qty_min;

        IF v_items.COUNT > 0 THEN
            BEGIN
                create_store_order(
                    p_store_id   => store_rec.store_id,
                    p_items      => v_items,
                    p_quantities => v_qtys,
                    p_order_id   => v_order_id
                );
                DBMS_OUTPUT.PUT_LINE(
                    'Автозаказ #' || v_order_id ||
                    ' для магазина ' || store_rec.store_id ||
                    ': ' || v_items.COUNT || ' позиций'
                );
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE(
                        'Ошибка автозаказа для магазина ' || store_rec.store_id ||
                        ': ' || SQLERRM
                    );
            END;
        END IF;
    END LOOP;
END;
/
