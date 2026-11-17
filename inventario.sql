DROP TABLE IF EXISTS MovimientosStock;
DROP TABLE IF EXISTS PedidosCompra;
DROP TABLE IF EXISTS Proveedores;
DROP TABLE IF EXISTS Articulos;


-- Creacion de tablas
CREATE TABLE Articulos
(	OID_AR SMALLINT PRIMARY KEY AUTO_INCREMENT,
	nombre VARCHAR(60) NOT NULL UNIQUE,
	categoria ENUM('Aula', 'Deporte', 'Fiestas', 'Laboratorio') NOT NULL,
	stock_actual INT NOT NULL,
	stock_minimo INT NOT NULL,
	ubicacion VARCHAR(40) NOT NULL,
	estado_articulo ENUM('Requiere Reposicion', 'Cantidad Adecuada', 'Sin Unidades') NOT NULL,
	CHECK (stock_actual >= 0),
	CHECK (stock_minimo >= 0),
	CHECK (
		(stock_actual = 0 AND estado_articulo = 'Sin Unidades')
		OR (stock_actual > 0 AND stock_actual <= stock_minimo AND estado_articulo = 'Requiere Reposicion')
		OR (stock_actual > stock_minimo AND estado_articulo = 'Cantidad Adecuada')
	)
);

CREATE TABLE MovimientosStock
(	OID_MS INT PRIMARY KEY AUTO_INCREMENT,
	fecha DATE NOT NULL,
	tipo_mvto ENUM('Entrada', 'Salida', 'Transferencia', 'Baja') NOT NULL,
	cantidad INT NOT NULL,
	motivo VARCHAR(80) NOT NULL,
	OID_AR SMALLINT NOT NULL,
	CHECK (cantidad > 0),
	FOREIGN KEY (OID_AR) REFERENCES Articulos (OID_AR)
);

CREATE TABLE Proveedores
(	OID_PR SMALLINT PRIMARY KEY AUTO_INCREMENT,
	nombre VARCHAR(60) NOT NULL UNIQUE,
	telefono VARCHAR(15),
	email VARCHAR(60)
);

CREATE TABLE PedidosCompra
(	OID_PC INT PRIMARY KEY AUTO_INCREMENT,
	fecha_pedido DATE NOT NULL,
	unidades INT NOT NULL,
	precio DECIMAL(8,2) NOT NULL,   -- importe total del pedido
	OID_AR SMALLINT NOT NULL,
	OID_PR SMALLINT NOT NULL,
	CHECK (unidades > 0),
	CHECK (precio >= 0),
	FOREIGN KEY (OID_AR) REFERENCES Articulos (OID_AR),
	FOREIGN KEY (OID_PR) REFERENCES Proveedores (OID_PR)
);


-- Poblacion: Articulos

INSERT INTO Articulos (OID_AR, nombre, categoria, stock_actual, stock_minimo, ubicacion, estado_articulo) VALUES
-- Deporte (Gimnasio)
(1,  'Pelota de futbol',                 'Deporte',     5,  5,  'Gimnasio',                'Requiere Reposicion'), -- Escenario 4: stock = minimo
(2,  'Pelota de baloncesto',             'Deporte',     12, 6,  'Gimnasio',                'Cantidad Adecuada'),
(3,  'Cuerda de saltar',                 'Deporte',     3,  10, 'Gimnasio',                'Requiere Reposicion'), -- stock < minimo
-- Aula
(4,  'Folios DIN A4 (paquete 500)',      'Aula',        40, 15, 'Almacen general',         'Cantidad Adecuada'),
(5,  'Lapices HB (caja 12)',             'Aula',        25, 10, 'Almacen general',         'Cantidad Adecuada'),
(6,  'Rotuladores de colores (caja)',    'Aula',        6,  8,  'Almacen general',         'Requiere Reposicion'),
(7,  'Tizas (caja 100)',                 'Aula',        0,  5,  'Almacen general',         'Sin Unidades'),        -- agotado con movimientos
(8,  'Borradores de pizarra',            'Aula',        14, 4,  'Armario aula 3',          'Cantidad Adecuada'),   -- unica en su ubicacion
(17, 'Grapas (caja)',                    'Aula',        30, 10, 'Secretaria',              'Cantidad Adecuada'),   -- unica en su ubicacion
-- Fiestas
(9,  'Globos (bolsa 100)',               'Fiestas',     20, 10, 'Salon de actos',          'Cantidad Adecuada'),
(10, 'Guirnaldas decorativas',           'Fiestas',     10, 10, 'Salon de actos',          'Requiere Reposicion'), -- stock = minimo
(11, 'Cartulinas de colores (paquete)',  'Fiestas',     50, 20, 'Almacen general',         'Cantidad Adecuada'),
(12, 'Pintura facial (set)',             'Fiestas',     0,  2,  'Almacen general',         'Sin Unidades'),        -- dado de alta, sin movimientos ni pedidos
-- Laboratorio
(13, 'Microscopio escolar',              'Laboratorio', 6,  2,  'Laboratorio de ciencias', 'Cantidad Adecuada'),
(14, 'Probetas',               'Laboratorio', 15, 10, 'Laboratorio de ciencias', 'Cantidad Adecuada'),
(15, 'Gafas de proteccion',              'Laboratorio', 4,  6,  'Laboratorio de ciencias', 'Requiere Reposicion'),
(16, 'Caja de guantes',    'Laboratorio', 9,  3,  'Laboratorio de ciencias', 'Cantidad Adecuada');

-- Poblacion: Proveedores
INSERT INTO Proveedores (OID_PR, nombre, telefono, email) VALUES
(1, 'PRODIUR Sports',               '954001122', 'pedidos@prodiursports.es'),
(2, 'Papeleria Hispalis',           '954223344', 'ventas@papeleriahispalis.es'),
(3, 'Suministros Cientificos Camas','954556677', 'info@sumicamas.es'),
(4, 'Fiestas Triana',       '955112233', 'tienda@fiestastriana.es'),
(5, 'Distribuciones Aljarafe',      '955998877', 'contacto@distaljarafe.es');


-- Poblacion: MovimientosStock
INSERT INTO MovimientosStock (fecha, tipo_mvto, cantidad, motivo, OID_AR) VALUES
-- 1 Pelota de futbol: 12 - 2 - 2 - 2 - 1 = 5  (Escenario 4: 6 -> 5 el 02/11)
('2026-09-01', 'Entrada',       12, 'Alta inicial de stock',                     1),
('2026-09-28', 'Baja',          2,  'Pelotas pinchadas',                         1),
('2026-10-05', 'Salida',        2,  'Clase de Educacion Fisica',                 1),
('2026-10-19', 'Salida',        2,  'Clase de Educacion Fisica',                 1),
('2026-11-02', 'Salida',        1,  'Clase de Educacion Fisica',                 1),

-- 2 Pelota de baloncesto: 15 - 3 = 12 (+ transferencia sin efecto en stock)
('2026-09-01', 'Entrada',       15, 'Alta inicial de stock',                     2),
('2026-09-08', 'Transferencia', 4,  'Traslado de Almacen general a Gimnasio',    2),
('2026-10-14', 'Salida',        3,  'Torneo de recreo',                          2),

-- 3 Cuerda de saltar: 10 - 5 - 2 = 3
('2026-09-01', 'Entrada',       10, 'Alta inicial de stock',                     3),
('2026-10-12', 'Salida',        5,  'Unidad didactica de comba',                 3),
('2026-11-09', 'Baja',          2,  'Cuerdas deterioradas',                      3),

-- 4 Folios: 40 + 20 - 10 - 10 = 40 (Entrada por compra del pedido 2)
('2026-09-01', 'Entrada',       40, 'Alta inicial de stock',                     4),
('2026-09-22', 'Salida',        10, 'Reparto a tutorias',                        4),
('2026-10-06', 'Entrada',       20, 'Recepcion de pedido de compra',             4),
('2026-10-20', 'Salida',        10, 'Reparto a tutorias',                        4),

-- 5 Lapices: 30 - 5 = 25
('2026-09-01', 'Entrada',       30, 'Alta inicial de stock',                     5),
('2026-09-15', 'Salida',        5,  'Entrega a Educacion Infantil',              5),

-- 6 Rotuladores: 20 - 8 - 6 = 6
('2026-09-01', 'Entrada',       20, 'Alta inicial de stock',                     6),
('2026-09-29', 'Salida',        8,  'Reparto a tutorias',                        6),
('2026-10-27', 'Salida',        6,  'Reparto a tutorias',                        6),

-- 7 Tizas: 10 - 4 - 3 - 3 = 0
('2026-09-01', 'Entrada',       10, 'Alta inicial de stock',                     7),
('2026-09-30', 'Salida',        4,  'Uso en aulas',                              7),
('2026-10-21', 'Salida',        3,  'Uso en aulas',                              7),
('2026-11-04', 'Salida',        3,  'Uso en aulas',                              7),

-- 8 Borradores: 14 (un unico movimiento)
('2026-09-01', 'Entrada',       14, 'Alta inicial de stock',                     8),

-- 9 Globos: 30 - 10 = 20 (+ transferencia)
('2026-09-01', 'Entrada',       30, 'Alta inicial de stock',                     9),
('2026-09-10', 'Transferencia', 20, 'Traslado de Almacen general a Salon de actos', 9),
('2026-10-30', 'Salida',        10, 'Fiesta de Halloween',                       9),

-- 10 Guirnaldas: 12 - 2 = 10
('2026-09-01', 'Entrada',       12, 'Alta inicial de stock',                     10),
('2026-10-30', 'Salida',        2,  'Fiesta de Halloween',                       10),

-- 11 Cartulinas: 60 - 10 = 50
('2026-09-01', 'Entrada',       60, 'Alta inicial de stock',                     11),
('2026-10-09', 'Salida',        10, 'Mural del Dia de la Hispanidad',            11),

-- 12 Pintura facial: SIN movimientos (dado de alta con stock 0)

-- 13 Microscopios: 6 (+ transferencia)
('2026-09-01', 'Entrada',       6,  'Alta inicial de stock',                     13),
('2026-09-03', 'Transferencia', 6,  'Traslado de Almacen general a Laboratorio de ciencias', 13),

-- 14 Probetas: 20 - 5 = 15
('2026-09-01', 'Entrada',       20, 'Alta inicial de stock',                     14),
('2026-10-15', 'Baja',          5,  'Rotura en practica de laboratorio',         14),

-- 15 Gafas de proteccion: 10 - 2 - 4 = 4
('2026-09-01', 'Entrada',       10, 'Alta inicial de stock',                     15),
('2026-10-27', 'Salida',        2,  'Practica de laboratorio de 6º',             15),
('2026-11-10', 'Baja',          4,  'Gafas rayadas',                             15),

-- 16 Guantes de nitrilo: 12 - 3 = 9
('2026-09-01', 'Entrada',       12, 'Alta inicial de stock',                     16),
('2026-10-13', 'Salida',        3,  'Practica de laboratorio',                   16),

-- 17 Grapas: 30 (un unico movimiento)
('2026-09-01', 'Entrada',       30, 'Alta inicial de stock',                     17);

-- Poblacion: PedidosCompra (precio = importe total del pedido)

INSERT INTO PedidosCompra (OID_PC, fecha_pedido, unidades, precio, OID_AR, OID_PR) VALUES
(1,  '2026-10-24', 10, 150.00, 1,  1),  -- Escenario 4: pelotas de futbol a PRODIUR Sports
(2,  '2026-10-01', 20, 70.00,  4,  2),  -- Recibido el 06/10 (Entrada en MovimientosStock)
(3,  '2026-10-26', 15, 45.00,  3,  1),  -- Pendiente de recibir
(4,  '2026-11-05', 10, 18.00,  7,  2),  -- Reposicion de tizas agotadas
(5,  '2026-11-05', 12, 36.00,  6,  2),
(6,  '2026-11-11', 10, 25.00,  15, 3),
(7,  '2026-09-14', 12, 24.00,  10, 4),  -- Guirnaldas, proveedor 4
(8,  '2026-11-03', 10, 22.00,  10, 2),  -- Guirnaldas, otro proveedor distinto
(9,  '2026-09-02', 6,  540.00, 13, 3),  -- Pedido de mayor importe
(10, '2026-09-02', 20, 60.00,  14, 3);
