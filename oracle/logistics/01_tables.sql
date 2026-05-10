-- ============================================================
-- Схема БД: Логистика РЦ → Магазины
-- СУБД: Oracle 19c+
-- ============================================================

-- Справочник регионов
CREATE TABLE regions (
    region_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    region_name  VARCHAR2(100) NOT NULL,
    federal_dist VARCHAR2(100)
);

-- Распределительные центры (РЦ)
CREATE TABLE warehouses (
    warehouse_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    warehouse_code VARCHAR2(20)  NOT NULL UNIQUE,
    warehouse_name VARCHAR2(200) NOT NULL,
    region_id      NUMBER        NOT NULL REFERENCES regions(region_id),
    address        VARCHAR2(500),
    capacity_m3    NUMBER(10, 2) DEFAULT 0,
    is_active      NUMBER(1)     DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at     TIMESTAMP     DEFAULT SYSTIMESTAMP
);

-- Магазины
CREATE TABLE stores (
    store_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_code     VARCHAR2(20)  NOT NULL UNIQUE,
    store_name     VARCHAR2(200) NOT NULL,
    region_id      NUMBER        NOT NULL REFERENCES regions(region_id),
    warehouse_id   NUMBER        NOT NULL REFERENCES warehouses(warehouse_id),
    store_format   VARCHAR2(30)  CHECK (store_format IN ('mini', 'standard', 'super', 'hyper')),
    address        VARCHAR2(500),
    is_active      NUMBER(1)     DEFAULT 1 CHECK (is_active IN (0, 1)),
    opened_at      DATE
);

-- Категории товаров
CREATE TABLE product_categories (
    category_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR2(100) NOT NULL,
    parent_id     NUMBER        REFERENCES product_categories(category_id),
    storage_type  VARCHAR2(30)  CHECK (storage_type IN ('ambient', 'chilled', 'frozen'))
);

-- Товары (SKU)
CREATE TABLE products (
    product_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku          VARCHAR2(30)  NOT NULL UNIQUE,
    product_name VARCHAR2(300) NOT NULL,
    category_id  NUMBER        NOT NULL REFERENCES product_categories(category_id),
    unit         VARCHAR2(10)  DEFAULT 'шт' CHECK (unit IN ('шт', 'кг', 'л', 'уп')),
    weight_kg    NUMBER(8, 3),
    volume_m3    NUMBER(8, 4),
    shelf_life   NUMBER(5)     -- срок годности в днях
);

-- Поставщики
CREATE TABLE suppliers (
    supplier_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_name VARCHAR2(200) NOT NULL,
    inn           VARCHAR2(12)  UNIQUE,
    contact_phone VARCHAR2(20),
    lead_time_days NUMBER(3)    DEFAULT 1,
    is_active     NUMBER(1)     DEFAULT 1
);

-- Поставки на РЦ (от поставщика)
CREATE TABLE inbound_shipments (
    shipment_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    warehouse_id  NUMBER       NOT NULL REFERENCES warehouses(warehouse_id),
    supplier_id   NUMBER       NOT NULL REFERENCES suppliers(supplier_id),
    shipment_date TIMESTAMP    DEFAULT SYSTIMESTAMP,
    status        VARCHAR2(20) DEFAULT 'planned'
                  CHECK (status IN ('planned', 'in_transit', 'received', 'cancelled')),
    doc_number    VARCHAR2(50),
    received_at   TIMESTAMP
);

-- Позиции поставки
CREATE TABLE inbound_items (
    item_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shipment_id   NUMBER     NOT NULL REFERENCES inbound_shipments(shipment_id),
    product_id    NUMBER     NOT NULL REFERENCES products(product_id),
    qty_expected  NUMBER(10) NOT NULL CHECK (qty_expected > 0),
    qty_received  NUMBER(10) DEFAULT 0,
    production_date DATE,
    expiry_date   DATE
);

-- Заказы магазинов (отгрузка с РЦ)
CREATE TABLE store_orders (
    order_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id      NUMBER       NOT NULL REFERENCES stores(store_id),
    warehouse_id  NUMBER       NOT NULL REFERENCES warehouses(warehouse_id),
    order_date    TIMESTAMP    DEFAULT SYSTIMESTAMP,
    status        VARCHAR2(20) DEFAULT 'new'
                  CHECK (status IN ('new', 'picking', 'shipped', 'delivered', 'cancelled')),
    shipped_at    TIMESTAMP,
    delivered_at  TIMESTAMP,
    total_qty     NUMBER(10)   DEFAULT 0,
    total_weight  NUMBER(10, 2) DEFAULT 0
);

-- Позиции заказа магазина
CREATE TABLE order_items (
    item_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id     NUMBER     NOT NULL REFERENCES store_orders(order_id),
    product_id   NUMBER     NOT NULL REFERENCES products(product_id),
    qty_ordered  NUMBER(10) NOT NULL CHECK (qty_ordered > 0),
    qty_shipped  NUMBER(10) DEFAULT 0,
    qty_received NUMBER(10) DEFAULT 0
);

-- Остатки на РЦ
CREATE TABLE warehouse_stock (
    warehouse_id  NUMBER NOT NULL REFERENCES warehouses(warehouse_id),
    product_id    NUMBER NOT NULL REFERENCES products(product_id),
    qty_available NUMBER(10) DEFAULT 0,
    qty_reserved  NUMBER(10) DEFAULT 0,
    last_updated  TIMESTAMP  DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_wh_stock PRIMARY KEY (warehouse_id, product_id)
);

-- Остатки в магазинах
CREATE TABLE store_stock (
    store_id     NUMBER NOT NULL REFERENCES stores(store_id),
    product_id   NUMBER NOT NULL REFERENCES products(product_id),
    qty_on_hand  NUMBER(10) DEFAULT 0,
    qty_min      NUMBER(10) DEFAULT 0,  -- мин. запас для автозаказа
    last_updated TIMESTAMP  DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_store_stock PRIMARY KEY (store_id, product_id)
);

-- Журнал движения товаров (для аудита)
CREATE TABLE stock_movements (
    movement_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    movement_type  VARCHAR2(20) NOT NULL
                   CHECK (movement_type IN ('inbound', 'outbound', 'adjustment', 'write_off', 'transfer')),
    warehouse_id   NUMBER REFERENCES warehouses(warehouse_id),
    store_id       NUMBER REFERENCES stores(store_id),
    product_id     NUMBER NOT NULL REFERENCES products(product_id),
    qty            NUMBER(10) NOT NULL,
    reference_id   NUMBER,        -- ID связанного документа
    reference_type VARCHAR2(30),  -- 'inbound_shipment', 'store_order', 'manual'
    created_at     TIMESTAMP DEFAULT SYSTIMESTAMP,
    created_by     VARCHAR2(100)
);

-- Индексы
CREATE INDEX idx_store_orders_date ON store_orders(order_date);
CREATE INDEX idx_store_orders_status ON store_orders(status);
CREATE INDEX idx_inbound_date ON inbound_shipments(shipment_date);
CREATE INDEX idx_movements_date ON stock_movements(created_at);
CREATE INDEX idx_movements_product ON stock_movements(product_id);
CREATE INDEX idx_stores_warehouse ON stores(warehouse_id);
CREATE INDEX idx_products_category ON products(category_id);
