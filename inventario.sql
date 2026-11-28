DROP TABLE IF EXISTS movimientosStock;
DROP TABLE IF EXISTS pedidosCompra;
DROP TABLE IF EXISTS proveedores;
DROP TABLE IF EXISTS articulos;


CREATE TABLE articulos (
    oidAr SMALLINT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(60) NOT NULL UNIQUE,
    categoria ENUM('Aula', 'Deporte', 'Fiestas', 'Laboratorio') NOT NULL,
    stockActual INT NOT NULL DEFAULT 0,
    stockMinimo INT NOT NULL,
    ubicacion VARCHAR(40) NOT NULL,
    estadoArticulo ENUM('Requiere Reposicion', 'Cantidad Adecuada', 'Sin Unidades') NOT NULL DEFAULT 'Sin Unidades',
	CONSTRAINT stockActualPositivo CHECK (stockActual >= 0),
	CONSTRAINT stockMinimoPositivo CHECK (stockMinimo >= 0),
	CONSTRAINT estadoAdecuadoStock CHECK (
		(stockActual = 0 AND estadoArticulo = 'Sin Unidades')
		OR (stockActual > 0 AND stockActual <= stockMinimo AND estadoArticulo = 'Requiere Reposicion')
		OR (stockActual > stockMinimo AND estadoArticulo = 'Cantidad Adecuada')
	)
);


CREATE TABLE movimientosStock (
    oidMs INT PRIMARY KEY AUTO_INCREMENT,
    fecha DATE NOT NULL,
    tipoMvto ENUM('Entrada', 'Salida', 'Transferencia', 'Baja') NOT NULL,
    cantidad INT NOT NULL,
    motivo VARCHAR(80) NOT NULL,
    oidAr SMALLINT NOT NULL,
    CHECK (cantidad > 0),
    FOREIGN KEY (oidAr) REFERENCES articulos (oidAr)
);

CREATE TABLE proveedores (
    oidPr SMALLINT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(60) NOT NULL UNIQUE,
    telefono VARCHAR(15),
    email VARCHAR(60)
);

CREATE TABLE pedidosCompra (
    oidPc INT PRIMARY KEY AUTO_INCREMENT,
    fechaPedido DATE NOT NULL,
    unidades INT NOT NULL,
    precio DECIMAL(8,2) NOT NULL,   -- importe total del pedido
    oidAr SMALLINT NOT NULL,
    oidPr SMALLINT NOT NULL,
	CONSTRAINT unidadesPositivas CHECK (unidades > 0),
	CONSTRAINT precioPositivo CHECK (precio >= 0),
	FOREIGN KEY (oidAr) REFERENCES articulos (oidAr),
	FOREIGN KEY (oidPr) REFERENCES proveedores (oidPr)
);

-- Triggers

-- RN-04: recalcula el estado del artículo cada vez que cambia su stock o su mínimo
-- y deja en @alertaStock el aviso para Dirección cuando el artículo
-- PASA a 'Sin Unidades' (SinStock) o a 'Requiere Reposicion' (StockBajo).
DELIMITER //
CREATE TRIGGER tArticulosBu
BEFORE UPDATE ON articulos
FOR EACH ROW
BEGIN
    IF NEW.stockActual = 0 THEN
        SET NEW.estadoArticulo = 'Sin Unidades';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sin unidades';
    ELSEIF NEW.stockActual <= NEW.stockMinimo THEN
        SET NEW.estadoArticulo = 'Requiere Reposicion';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Requiere reposición';
    ELSE
        SET NEW.estadoArticulo = 'Cantidad Adecuada';
    END IF;
END//
DELIMITER ;


-- RC-03.2: no se puede sacar o dar de baja más stock del disponible
-- (solo valida; no modifica nada antes de que el movimiento se haya aceptado)
DELIMITER //
CREATE TRIGGER tMovimientosStockBi
BEFORE INSERT ON movimientosStock
FOR EACH ROW
BEGIN
    DECLARE vStock INT DEFAULT 0;

    SELECT stockActual INTO vStock
      FROM articulos
     WHERE oidAr = NEW.oidAr;

    IF NEW.tipoMvto IN ('Salida', 'Baja') AND NEW.cantidad > vStock THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente para realizar el movimiento';
    END IF;

    SET vDelta = CASE NEW.tipoMvto
        WHEN 'Entrada' THEN NEW.cantidad
        WHEN 'Salida'  THEN -NEW.cantidad
        WHEN 'Baja'    THEN -NEW.cantidad
        ELSE 0
    END;

    IF vDelta <> 0 THEN
        UPDATE articulos
           SET stockActual = vStock + vDelta
         WHERE oidAr = NEW.oidAr;
    END IF;
END//
DELIMITER ;


-- Aplica el movimiento al stock una vez insertado: Entrada suma; Salida y Baja
-- restan; Transferencia no cambia el stock. El UPDATE dispara tArticulosBu,
-- que recalcula el estado y genera el aviso.
DELIMITER //
CREATE TRIGGER tMovimientosStockAi
AFTER INSERT ON movimientosStock
FOR EACH ROW
BEGIN
    DECLARE vDelta INT DEFAULT 0;

    SET vDelta = CASE NEW.tipoMvto
        WHEN 'Entrada' THEN NEW.cantidad
        WHEN 'Salida'  THEN -NEW.cantidad
        WHEN 'Baja'    THEN -NEW.cantidad
        ELSE 0
    END;

    IF vDelta <> 0 THEN
        UPDATE articulos
           SET stockActual = stockActual + vDelta
         WHERE oidAr = NEW.oidAr;
    END IF;
END//
DELIMITER ;

SET @alertaStock = NULL;


-- Poblacion: Articulos

INSERT INTO articulos (oidAr, nombre, categoria, stockMinimo, ubicacion) VALUES
-- Deporte
(1,  'Pelota de futbol',                 'Deporte',     5,  'Gimnasio'),
(2,  'Pelota de baloncesto',             'Deporte',     6,  'Gimnasio'),
(3,  'Cuerda de saltar',                 'Deporte',     10, 'Gimnasio'),
-- Aula
(4,  'Folios DIN A4 (paquete 500)',      'Aula',        15, 'Almacen general'),
(5,  'Lapices HB (caja 12)',             'Aula',        10, 'Almacen general'),
(6,  'Rotuladores de colores (caja)',    'Aula',        8,  'Almacen general'),
(7,  'Tizas (caja 100)',                 'Aula',        5,  'Almacen general'),
(8,  'Borradores de pizarra',            'Aula',        4,  'Armario aula 3'),
(17, 'Grapas (caja)',                    'Aula',        10, 'Secretaria'),
-- Fiestas
(9,  'Globos (bolsa 100)',               'Fiestas',     10, 'Salon de actos'),
(10, 'Guirnaldas decorativas',           'Fiestas',     10, 'Salon de actos'),
(11, 'Cartulinas de colores (paquete)',  'Fiestas',     20, 'Almacen general'),
(12, 'Pintura facial (set)',             'Fiestas',     2,  'Almacen general'),   -- sin movimientos ni pedidos
-- Laboratorio
(13, 'Microscopio escolar',              'Laboratorio', 2,  'Laboratorio de ciencias'),
(14, 'Probetas',                         'Laboratorio', 10, 'Laboratorio de ciencias'),
(15, 'Gafas de proteccion',              'Laboratorio', 6,  'Laboratorio de ciencias'),
(16, 'Caja de guantes',                  'Laboratorio', 3,  'Laboratorio de ciencias');

INSERT INTO proveedores (oidPr, nombre, telefono, email) VALUES
(1, 'PRODIUR Sports',                '954001122', 'pedidos@prodiursports.es'),
(2, 'Papeleria Hispalis',            '954223344', 'ventas@papeleriahispalis.es'),
(3, 'Suministros Cientificos Camas', '954556677', 'info@sumicamas.es'),
(4, 'Fiestas Triana',                '955112233', 'tienda@fiestastriana.es'),
(5, 'Distribuciones Aljarafe',       '955998877', 'contacto@distaljarafe.es');

-- El stock resultante de cada artículo se indica en los comentarios.
INSERT INTO movimientosStock (fecha, tipoMvto, cantidad, motivo, oidAr) VALUES
-- 1 Pelota de futbol: 12-2-2-2-1 = 5 (escenario 4: el 02/11 baja de 6 a 5 y avisa a Dirección)
('2026-09-01', 'Entrada',       12, 'Alta inicial de stock',                     1),
('2026-09-28', 'Baja',          2,  'Pelotas pinchadas',                         1),
('2026-10-05', 'Salida',        2,  'Clase de Educacion Fisica',                 1),
('2026-10-19', 'Salida',        2,  'Clase de Educacion Fisica',                 1),
('2026-11-02', 'Salida',        1,  'Clase de Educacion Fisica',                 1),

-- 2 Pelota de baloncesto: 15-3 = 12 (la transferencia no cambia el stock)
('2026-09-01', 'Entrada',       15, 'Alta inicial de stock',                     2),
('2026-09-08', 'Transferencia', 4,  'Traslado de Almacen general a Gimnasio',    2),
('2026-10-14', 'Salida',        3,  'Torneo de recreo',                          2),

-- 3 Cuerda de saltar: 10-5-2 = 3
('2026-09-01', 'Entrada',       10, 'Alta inicial de stock',                     3),
('2026-10-12', 'Salida',        5,  'Unidad didactica de comba',                 3),
('2026-11-09', 'Baja',          2,  'Cuerdas deterioradas',                      3),

-- 4 Folios: 40+20-10-10 = 40
('2026-09-01', 'Entrada',       40, 'Alta inicial de stock',                     4),
('2026-09-22', 'Salida',        10, 'Reparto a tutorias',                        4),
('2026-10-06', 'Entrada',       20, 'Recepcion de pedido de compra',             4),
('2026-10-20', 'Salida',        10, 'Reparto a tutorias',                        4),

-- 5 Lapices: 30-5 = 25
('2026-09-01', 'Entrada',       30, 'Alta inicial de stock',                     5),
('2026-09-15', 'Salida',        5,  'Entrega a Educacion Infantil',              5),

-- 6 Rotuladores: 20-8-6 = 6
('2026-09-01', 'Entrada',       20, 'Alta inicial de stock',                     6),
('2026-09-29', 'Salida',        8,  'Reparto a tutorias',                        6),
('2026-10-27', 'Salida',        6,  'Reparto a tutorias',                        6),

-- 7 Tizas: 10-4-3-3 = 0 (agotado, con movimientos)
('2026-09-01', 'Entrada',       10, 'Alta inicial de stock',                     7),
('2026-09-30', 'Salida',        4,  'Uso en aulas',                              7),
('2026-10-21', 'Salida',        3,  'Uso en aulas',                              7),
('2026-11-04', 'Salida',        3,  'Uso en aulas',                              7),

-- 8 Borradores: 14
('2026-09-01', 'Entrada',       14, 'Alta inicial de stock',                     8),

-- 9 Globos: 30-10 = 20
('2026-09-01', 'Entrada',       30, 'Alta inicial de stock',                     9),
('2026-09-10', 'Transferencia', 20, 'Traslado de Almacen general a Salon de actos', 9),
('2026-10-30', 'Salida',        10, 'Fiesta de Halloween',                       9),

-- 10 Guirnaldas: 12-2 = 10
('2026-09-01', 'Entrada',       12, 'Alta inicial de stock',                     10),
('2026-10-30', 'Salida',        2,  'Fiesta de Halloween',                       10),

-- 11 Cartulinas: 60-10 = 50
('2026-09-01', 'Entrada',       60, 'Alta inicial de stock',                     11),
('2026-10-09', 'Salida',        10, 'Mural del Dia de la Hispanidad',            11),

-- 12 Pintura facial: sin movimientos

-- 13 Microscopios: 6
('2026-09-01', 'Entrada',       6,  'Alta inicial de stock',                     13),
('2026-09-03', 'Transferencia', 6,  'Traslado de Almacen general a Laboratorio de ciencias', 13),

-- 14 Probetas: 20-5 = 15
('2026-09-01', 'Entrada',       20, 'Alta inicial de stock',                     14),
('2026-10-15', 'Baja',          5,  'Rotura en practica de laboratorio',         14),

-- 15 Gafas de proteccion: 10-2-4 = 4
('2026-09-01', 'Entrada',       10, 'Alta inicial de stock',                     15),
('2026-10-27', 'Salida',        2,  'Practica de laboratorio de 6º',             15),
('2026-11-10', 'Baja',          4,  'Gafas rayadas',                             15),

-- 16 Caja de guantes: 12-3 = 9
('2026-09-01', 'Entrada',       12, 'Alta inicial de stock',                     16),
('2026-10-13', 'Salida',        3,  'Practica de laboratorio',                   16),

-- 17 Grapas: 30
('2026-09-01', 'Entrada',       30, 'Alta inicial de stock',                     17);

INSERT INTO pedidosCompra (oidPc, fechaPedido, unidades, precio, oidAr, oidPr) VALUES
(1,  '2026-10-24', 10, 150.00, 1,  1),  -- escenario 4: pelotas de futbol a PRODIUR Sports
(2,  '2026-10-01', 20, 70.00,  4,  2),  -- recibido el 06/10
(3,  '2026-10-26', 15, 45.00,  3,  1),  -- pendiente de recibir
(4,  '2026-11-05', 10, 18.00,  7,  2),  -- reposicion de tizas agotadas
(5,  '2026-11-05', 12, 36.00,  6,  2),
(6,  '2026-11-11', 10, 25.00,  15, 3),
(7,  '2026-09-14', 12, 24.00,  10, 4),  -- guirnaldas, proveedor 4
(8,  '2026-11-03', 10, 22.00,  10, 2),  -- guirnaldas, otro proveedor distinto
(9,  '2026-09-02', 6,  540.00, 13, 3),  -- pedido de mayor importe
(10, '2026-09-02', 20, 60.00,  14, 3);

-- Comprobacion tras cargar
SHOW TRIGGERS;
SELECT @alertaStock AS ultimaAlertaTrasCarga;
SELECT oidAr, nombre, stockActual, estadoArticulo FROM articulos;

-- Pruebas (ejecutar a mano)
-- RC-03.2: sacar más unidades de las que hay (tizas tiene 0) -> ERROR
-- INSERT INTO movimientosStock (fecha, tipoMvto, cantidad, motivo, oidAr) VALUES ('2026-11-12', 'Salida', 1, 'Prueba', 7);
-- RN-04: llevar las cuerdas a 0 -> estado 'Sin Unidades' y mostrar alerta 'SinStock'
-- INSERT INTO movimientosStock (fecha, tipoMvto, cantidad, motivo, oidAr) VALUES ('2026-11-12', 'Baja', 3, 'Prueba', 3);
-- Subir el mínimo de las probetas a 20 -> pasa solo a 'Requiere Reposicion'
-- UPDATE articulos SET stockMinimo = 20 WHERE oidAr = 14;



-- Consultas SQL

-- CONSULTA 1: Artículos que necesitan reposición
-- Nos indica lo que está bajo mínimos y cuántas unidades faltan para llegar al mínimo.
SELECT nombre, ubicacion, stockActual, stockMinimo,
       stockMinimo - stockActual AS unidadesHastaMinimo,
       estadoArticulo
  FROM articulos
 WHERE estadoArticulo <> 'Cantidad Adecuada'
 ORDER BY unidadesHastaMinimo DESC;


-- CONSULTA 2: Resumen por categoría (agregación)
-- Cuenta artículos, suma unidades y calcula cuántos están en problemas en cada categoría.
SELECT categoria,
       COUNT(*) AS numArticulos,
       SUM(stockActual) AS unidadesTotales,
       SUM(estadoArticulo = 'Requiere Reposicion') AS requierenReposicion,
       SUM(estadoArticulo = 'Sin Unidades') AS sinUnidades,
       ROUND(100 * SUM(estadoArticulo <> 'Cantidad Adecuada') / COUNT(*), 1) AS pctProblemas
  FROM articulos
 GROUP BY categoria
 ORDER BY pctProblemas DESC;


-- CONSULTA 3: Gasto por proveedor, incluidos los que no tienen pedidos (lo hacemos con LEFT JOIN)
SELECT p.nombre AS proveedor,
       COUNT(pc.oidPc) AS numPedidos,
       IFNULL(SUM(pc.precio), 0) AS gastoTotal,
       IFNULL(SUM(pc.unidades), 0) AS unidadesPedidas,
       IFNULL(ROUND(SUM(pc.precio) / NULLIF(SUM(pc.unidades), 0), 2), 0.00) AS precioMedioUnidad
  FROM proveedores p
  LEFT JOIN pedidosCompra pc ON pc.oidPr = p.oidPr
 GROUP BY p.oidPr, p.nombre
 ORDER BY gastoTotal DESC;


-- CONSULTA 4: Artículos bajo mínimos con o sin pedido en curso
-- Considera que hay un pedido pendiente si el último pedido es posterior a la última Entrada de stock.
SELECT a.nombre, a.stockActual, a.stockMinimo,
       ped.ultimoPedido,
       ent.ultimaEntrada,
       CASE
           WHEN ped.ultimoPedido IS NULL THEN 'SIN PEDIDO: hay que pedir'
           WHEN ent.ultimaEntrada IS NULL OR ped.ultimoPedido > ent.ultimaEntrada
                THEN 'Pedido pendiente de recibir'
           ELSE 'Pedido ya recibido, sigue bajo mínimos'
       END AS situacion
  FROM articulos a
  LEFT JOIN (SELECT oidAr, MAX(fechaPedido) AS ultimoPedido
               FROM pedidosCompra GROUP BY oidAr) ped ON ped.oidAr = a.oidAr
  LEFT JOIN (SELECT oidAr, MAX(fecha) AS ultimaEntrada
               FROM movimientosStock WHERE tipoMvto = 'Entrada' GROUP BY oidAr) ent
         ON ent.oidAr = a.oidAr
 WHERE a.stockActual <= a.stockMinimo
 ORDER BY (ped.ultimoPedido IS NULL) DESC, a.nombre;


-- CONSULTA 5: stock guardado vs. stock recalculado <- ¡MUY CURIOSA PARA ENSEÑAR EN LA DEFENSA!
-- Como el stock lo mantienen los triggers, esta consulta recalcula el stock desde el histórico de movimientos 
-- y detecta incoherencias. Si todo está bien, no devuelve filas.
SELECT a.oidAr, a.nombre, a.stockActual AS stockGuardado,
       IFNULL(SUM(CASE m.tipoMvto 
                    WHEN 'Entrada' THEN  m.cantidad
                    WHEN 'Salida'  THEN -m.cantidad
                    WHEN 'Baja'    THEN -m.cantidad
                    ELSE 0
                  END), 0) AS stockRecalculado
  FROM articulos a LEFT JOIN movimientosStock m ON m.oidAr = a.oidAr
 GROUP BY a.oidAr, a.nombre, a.stockActual HAVING stockGuardado <> stockRecalculado;