-- ============================================================
-- Тестовые данные: Логистика РЦ → Магазины
-- СУБД: Oracle 19c+
-- ============================================================

-- Регионы
INSERT INTO regions (region_name, federal_dist) VALUES ('Московская область', 'ЦФО');
INSERT INTO regions (region_name, federal_dist) VALUES ('Ленинградская область', 'СЗФО');
INSERT INTO regions (region_name, federal_dist) VALUES ('Новосибирская область', 'СФО');
INSERT INTO regions (region_name, federal_dist) VALUES ('Краснодарский край', 'ЮФО');

-- РЦ
INSERT INTO warehouses (warehouse_code, warehouse_name, region_id, address, capacity_m3)
VALUES ('RC-MSK-01', 'РЦ Москва Север', 1, 'Московская обл., Солнечногорский р-н', 25000);
INSERT INTO warehouses (warehouse_code, warehouse_name, region_id, address, capacity_m3)
VALUES ('RC-MSK-02', 'РЦ Москва Юг', 1, 'Московская обл., Домодедово', 18000);
INSERT INTO warehouses (warehouse_code, warehouse_name, region_id, address, capacity_m3)
VALUES ('RC-SPB-01', 'РЦ Санкт-Петербург', 2, 'Ленинградская обл., Тосно', 15000);
INSERT INTO warehouses (warehouse_code, warehouse_name, region_id, address, capacity_m3)
VALUES ('RC-NSK-01', 'РЦ Новосибирск', 3, 'Новосибирская обл., Обь', 12000);

-- Магазины
INSERT INTO stores (store_code, store_name, region_id, warehouse_id, store_format, opened_at)
VALUES ('S-001', 'Маркет на Ленина', 1, 1, 'standard', DATE '2023-03-15');
INSERT INTO stores (store_code, store_name, region_id, warehouse_id, store_format, opened_at)
VALUES ('S-002', 'Маркет на Мира', 1, 1, 'super', DATE '2022-11-01');
INSERT INTO stores (store_code, store_name, region_id, warehouse_id, store_format, opened_at)
VALUES ('S-003', 'Маркет Центральный', 1, 2, 'hyper', DATE '2022-06-20');
INSERT INTO stores (store_code, store_name, region_id, warehouse_id, store_format, opened_at)
VALUES ('S-004', 'Маркет у метро', 2, 3, 'mini', DATE '2023-08-10');
INSERT INTO stores (store_code, store_name, region_id, warehouse_id, store_format, opened_at)
VALUES ('S-005', 'Маркет Невский', 2, 3, 'standard', DATE '2023-01-25');
INSERT INTO stores (store_code, store_name, region_id, warehouse_id, store_format, opened_at)
VALUES ('S-006', 'Маркет Сибирский', 3, 4, 'standard', DATE '2023-05-01');
INSERT INTO stores (store_code, store_name, region_id, warehouse_id, store_format, opened_at)
VALUES ('S-007', 'Маркет Академ', 3, 4, 'super', DATE '2024-02-14');

-- Категории товаров
INSERT INTO product_categories (category_name, parent_id, storage_type) VALUES ('Молочная продукция', NULL, 'chilled');
INSERT INTO product_categories (category_name, parent_id, storage_type) VALUES ('Хлебобулочные', NULL, 'ambient');
INSERT INTO product_categories (category_name, parent_id, storage_type) VALUES ('Мясо', NULL, 'frozen');
INSERT INTO product_categories (category_name, parent_id, storage_type) VALUES ('Овощи и фрукты', NULL, 'chilled');
INSERT INTO product_categories (category_name, parent_id, storage_type) VALUES ('Бакалея', NULL, 'ambient');
INSERT INTO product_categories (category_name, parent_id, storage_type) VALUES ('Напитки', NULL, 'ambient');

-- Товары
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('MLK-001', 'Молоко 3.2% 1л', 1, 'шт', 1.05, 0.001, 14);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('MLK-002', 'Кефир 2.5% 0.5л', 1, 'шт', 0.53, 0.0006, 10);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('MLK-003', 'Сметана 20% 200г', 1, 'шт', 0.22, 0.0003, 14);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('BRD-001', 'Хлеб белый нарезной', 2, 'шт', 0.5, 0.003, 3);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('BRD-002', 'Батон нарезной', 2, 'шт', 0.4, 0.002, 3);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('MET-001', 'Курица охлаждённая 1кг', 3, 'кг', 1.0, 0.002, 5);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('MET-002', 'Фарш говяжий 0.5кг', 3, 'уп', 0.5, 0.001, 3);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('VEG-001', 'Картофель', 4, 'кг', 1.0, 0.001, 30);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('VEG-002', 'Помидоры', 4, 'кг', 1.0, 0.002, 7);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('VEG-003', 'Огурцы', 4, 'кг', 1.0, 0.002, 7);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('GRC-001', 'Рис 900г', 5, 'шт', 0.9, 0.001, 365);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('GRC-002', 'Макароны 500г', 5, 'шт', 0.5, 0.001, 365);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('GRC-003', 'Масло подсолнечное 1л', 5, 'шт', 0.95, 0.001, 180);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('DRK-001', 'Вода питьевая 1.5л', 6, 'шт', 1.5, 0.002, 180);
INSERT INTO products (sku, product_name, category_id, unit, weight_kg, volume_m3, shelf_life)
VALUES ('DRK-002', 'Сок апельсиновый 1л', 6, 'шт', 1.1, 0.001, 90);

-- Поставщики
INSERT INTO suppliers (supplier_name, inn, contact_phone, lead_time_days)
VALUES ('МолПром', '7701234567', '+7-495-111-22-33', 2);
INSERT INTO suppliers (supplier_name, inn, contact_phone, lead_time_days)
VALUES ('Хлебозавод №5', '7801234568', '+7-812-222-33-44', 1);
INSERT INTO suppliers (supplier_name, inn, contact_phone, lead_time_days)
VALUES ('АгроМясо', '5001234569', '+7-495-333-44-55', 3);
INSERT INTO suppliers (supplier_name, inn, contact_phone, lead_time_days)
VALUES ('ФрешФрукт', '2301234570', '+7-861-444-55-66', 2);
INSERT INTO suppliers (supplier_name, inn, contact_phone, lead_time_days)
VALUES ('БакалейТорг', '5401234571', '+7-383-555-66-77', 5);

-- Начальные остатки на РЦ
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 1, 500, 20);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 2, 300, 10);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 3, 200, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 4, 400, 50);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 5, 350, 30);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 6, 150, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 7, 100, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 8, 800, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 9, 200, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 10, 150, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 11, 600, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 12, 450, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 13, 300, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 14, 1000, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (1, 15, 250, 0);

INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (3, 1, 300, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (3, 4, 200, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (3, 8, 500, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (3, 11, 400, 0);
INSERT INTO warehouse_stock (warehouse_id, product_id, qty_available, qty_reserved) VALUES (3, 14, 600, 0);

-- Минимальные запасы магазинов
INSERT INTO store_stock (store_id, product_id, qty_on_hand, qty_min) VALUES (1, 1, 30, 50);
INSERT INTO store_stock (store_id, product_id, qty_on_hand, qty_min) VALUES (1, 4, 15, 40);
INSERT INTO store_stock (store_id, product_id, qty_on_hand, qty_min) VALUES (1, 8, 60, 30);
INSERT INTO store_stock (store_id, product_id, qty_on_hand, qty_min) VALUES (1, 11, 25, 20);
INSERT INTO store_stock (store_id, product_id, qty_on_hand, qty_min) VALUES (2, 1, 80, 100);
INSERT INTO store_stock (store_id, product_id, qty_on_hand, qty_min) VALUES (2, 6, 10, 30);
INSERT INTO store_stock (store_id, product_id, qty_on_hand, qty_min) VALUES (2, 14, 150, 200);

COMMIT;
