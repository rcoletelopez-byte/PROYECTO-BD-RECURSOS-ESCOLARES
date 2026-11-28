-- Creación de la base de datos de la biblioteca
DROP DATABASE if EXISTS biblioteca;
CREATE DATABASE biblioteca;
USE biblioteca;

-- Tablas de las relaciones de la biblioteca
DROP TABLE if EXISTS reservas;
DROP TABLE if EXISTS incidencias;
DROP TABLE if EXISTS prestamos;
DROP TABLE if EXISTS ejemplares;
DROP TABLE if EXISTS libros;
DROP TABLE if EXISTS alumnos;


CREATE TABLE alumnos(
dni VARCHAR(40) PRIMARY KEY,
nombre VARCHAR(30) NOT NULL,
apellidos VARCHAR(50),
curso INT,
comedor BOOLEAN DEFAULT FALSE
);

CREATE TABLE libros(
oidL SMALLINT AUTO_INCREMENT PRIMARY KEY, 
titulo VARCHAR(60) NOT NULL,
editorial VARCHAR(40) NOT NULL,
genero VARCHAR(30),
esLecturaObligatoria BOOLEAN DEFAULT FALSE,
UNIQUE (titulo, editorial)
);

CREATE TABLE ejemplares(
oidE SMALLINT AUTO_INCREMENT PRIMARY KEY,
codigo INT UNIQUE NOT NULL,
estadoConservacion VARCHAR(60),
disponibilidad BOOLEAN,
oidL SMALLINT,
FOREIGN KEY (oidL) REFERENCES libros(oidL) ON UPDATE CASCADE 
);

CREATE TABLE prestamos(
oidP SMALLINT AUTO_INCREMENT PRIMARY KEY, 
fechaInicio DATE DEFAULT SYSDATE(),
fechaLimite DATE,
fechaDevolucion DATE DEFAULT NULL,
dni VARCHAR (40),
oidE SMALLINT,
FOREIGN KEY (dni) REFERENCES alumnos(dni) ON UPDATE CASCADE ,
FOREIGN KEY (oidE) REFERENCES ejemplares(oidE) ON UPDATE CASCADE,
CONSTRAINT fechasValidas CHECK (fechaInicio<fechaLimite)
);


CREATE TABLE incidencias(
oidI SMALLINT AUTO_INCREMENT PRIMARY KEY,
descripcionDesperfecto ENUM ('Páginas pintadas','Páginas arrancadas', 'Libro mojado'),
gravedad ENUM ('Leve', 'Media', 'Alta'),
oidP SMALLINT,
FOREIGN KEY (oidP) REFERENCES prestamos(oidP) ON UPDATE CASCADE 
);

CREATE TABLE reservas(
oidR SMALLINT AUTO_INCREMENT PRIMARY KEY,
fechaSolicitud DATE DEFAULT SYSDATE(), 
ordenPrioridad INT, 
estadoReserva VARCHAR(30),
dni VARCHAR(40),
oidL SMALLINT,
FOREIGN KEY (dni) REFERENCES alumnos(dni),
FOREIGN KEY (oidL) REFERENCES libros(oidL) ON UPDATE CASCADE,
CONSTRAINT ordenPositivo CHECK (ordenPrioridad >= 0)
);
DELIMITER //

-- RN-01: Bloquea nuevos préstamos si el alumno tiene algún libro vencido sin devolver
CREATE OR REPLACE TRIGGER tPrestamosBiRn01
BEFORE INSERT ON prestamos
FOR EACH ROW
BEGIN
    IF NEW.fechaDevolucion IS NULL THEN
        IF (SELECT COUNT(*) FROM prestamos WHERE dni = NEW.dni AND fechaDevolucion IS NULL AND fechaLimite < NEW.fechaInicio) > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-01: el alumno tiene préstamos vencidos sin devolver';
        END IF;
    END IF;
END //

-- RN-02 (1/2): Exige una incidencia en el último préstamo antes de marcar el ejemplar como deteriorado o dañado
CREATE OR REPLACE TRIGGER tEjemplaresBuRn02
BEFORE UPDATE ON ejemplares
FOR EACH ROW
BEGIN
    IF NEW.estadoConservacion IN ('Deteriorado', 'Dañado')
       AND IFNULL(OLD.estadoConservacion, '') NOT IN ('Deteriorado', 'Dañado') THEN
        IF NOT EXISTS (
            SELECT 1
            FROM incidencias
            WHERE oidP = (
                SELECT oidP
                FROM prestamos
                WHERE oidE = NEW.oidE
                ORDER BY fechaInicio DESC, oidP DESC
                LIMIT 1
            )
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-02: para marcar un ejemplar como deteriorado hay que registrar la incidencia en su último préstamo';
        END IF;
    END IF;
END //

-- RN-02 (2/2): Asegura que cualquier incidencia registrada se asocie al último préstamo del ejemplar
CREATE OR REPLACE TRIGGER tIncidenciasBiRn02
BEFORE INSERT ON incidencias
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM prestamos p1
        JOIN prestamos p2 ON p2.oidE = p1.oidE
        WHERE p1.oidP = NEW.oidP
          AND (p2.fechaInicio > p1.fechaInicio OR (p2.fechaInicio = p1.fechaInicio AND p2.oidP > p1.oidP))
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN-02: la incidencia debe asociarse al último préstamo del ejemplar';
    END IF;
END //

-- RN-03: Impide tener más de 2 libros de lectura en préstamo activo simultáneamente (excluye libros de texto)
CREATE OR REPLACE TRIGGER tPrestamosBiRn03
BEFORE INSERT ON prestamos
FOR EACH ROW
BEGIN
    IF NEW.fechaDevolucion IS NULL THEN
        IF (SELECT l.genero FROM ejemplares e JOIN libros l ON l.oidL = e.oidL WHERE e.oidE = NEW.oidE) <> 'Texto' THEN
            IF (
                SELECT COUNT(*)
                FROM prestamos p
                JOIN ejemplares e ON e.oidE = p.oidE
                JOIN libros l ON l.oidL = e.oidL
                WHERE p.dni = NEW.dni AND p.fechaDevolucion IS NULL AND l.genero <> 'Texto'
            ) >= 2 THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RN-03: máximo 2 libros de lectura en préstamo activo';
            END IF;
        END IF;
    END IF;
END //

-- RN-06: Garantiza que cada ejemplar físico posea un código identificativo único
CREATE OR REPLACE TRIGGER tEjemplaresBiRn06
BEFORE INSERT ON ejemplares
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM ejemplares WHERE codigo = NEW.codigo) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN-06: ya existe un ejemplar registrado con ese código';
    END IF;
END //

DELIMITER ;


-- Alumnos (datos exactos de los escenarios del documento)
INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES
('51234876P', 'Pablo',   'Gil Soto',           3, TRUE),
('72940183F', 'Lucía',   'Pérez Ruiz',         2, TRUE),
('77975237R', 'Juan',    'Martín García',      1, TRUE),
('40679852K', 'Sara',    'Gómez Díaz',         2, FALSE),
('89635244G', 'Rafael',  'Navarro Villalobos', 3, FALSE),
('56789012E', 'Daniela', 'Moreno Torres',      6, TRUE),
('23456789B', 'Mateo',   'Jiménez Navarro',    3, FALSE),
('12345678A', 'Lucía',   'Gómez Ortiz',        2, TRUE),
('66698510S', 'Nuria',   'Campos Rey',         4, FALSE),
('39482015L', 'Carmen',  'Ortiz Vega',         1, TRUE),
('78901234G', 'Elena',   'Serrano Molina',     5, FALSE);

-- Libros
INSERT INTO libros (oidL, titulo, editorial, genero, esLecturaObligatoria) VALUES
(1,  'Jojolion',                  'Ivrea',      'Aventura',        TRUE),
(2,  'Matilda',                   'SM',         'Infantil',        TRUE),
(3,  'La Celestina',              'SM',         'Drama',           TRUE),
(4,  'El principito',             'SM',         'Fábula',          FALSE),
(5,  'La historia interminable',  'Alfaguara',  'Fantasía',        FALSE),
(6,  'El Hobbit',                 'Minotauro',  'Fantasía',        TRUE),
(7,  'La sombra del viento',      'Planeta',    'Misterio',        FALSE),
(8,  'Los juegos del hambre',     'Molino',     'Juvenil',         FALSE),
(9,  'Matemáticas 5.º',           'Santillana', 'Texto',           FALSE),
(10, 'Lengua Castellana 6.º',     'Santillana', 'Texto',           FALSE),
(11, 'Fundación',                 'Debolsillo', 'Ciencia Ficción', FALSE);

-- Ejemplares (nacen en TRUE para que RC-02.1 permita registrar sus préstamos activos)
INSERT INTO ejemplares (oidE, codigo, estadoConservacion, disponibilidad, oidL) VALUES
(1,  1,  'Perfecto', TRUE, 1),
(2,  2,  'Perfecto', TRUE, 2),
(3,  3,  'Bueno',    TRUE, 6),
(4,  4,  'Perfecto', TRUE, 6),
(5,  5,  'Regular',  TRUE, 6),
(6,  6,  'Bueno',    TRUE, 7),
(7,  7,  'Regular',  TRUE, 8),
(8,  8,  'Bueno',    TRUE, 9),
(9,  9,  'Bueno',    TRUE, 9),
(10, 10, 'Perfecto', TRUE, 4),
(11, 11, 'Perfecto', TRUE, 3),
(12, 12, 'Perfecto', TRUE, 5),
(13, 13, 'Perfecto', TRUE, 10);

-- Préstamos
INSERT INTO prestamos (oidP, fechaInicio, fechaLimite, fechaDevolucion, dni, oidE) VALUES
(1,  '2026-10-01', '2026-10-15', '2026-10-14', '51234876P', 2),
(2,  '2026-10-25', '2026-11-05', '2026-11-02', '72940183F', 2),
(3,  '2026-10-20', '2026-10-30', NULL,         '77975237R', 1),
(4,  '2026-10-28', '2026-11-11', NULL,         '40679852K', 11),
(5,  '2026-10-25', '2026-11-05', NULL,         '40679852K', 10),
(7,  '2026-09-10', '2026-09-24', '2026-09-22', '77975237R', 3),
(8,  '2026-09-28', '2026-10-12', '2026-10-20', '89635244G', 3),
(9,  '2026-11-18', '2026-12-02', NULL,         '89635244G', 4),
(10, '2026-11-09', '2026-11-30', NULL,         '56789012E', 8),
(11, '2026-11-09', '2026-11-30', NULL,         '56789012E', 13),
(12, '2026-11-10', '2026-11-30', NULL,         '56789012E', 6),
(13, '2026-10-05', '2026-10-19', '2026-10-19', '23456789B', 7),
(14, '2026-09-15', '2026-09-29', '2026-09-25', '12345678A', 12);

-- Incidencias
INSERT INTO incidencias (descripcionDesperfecto, gravedad, oidP) VALUES
('Páginas arrancadas', 'Alta',  2),
('Páginas pintadas',   'Leve',  8),
('Libro mojado',       'Media', 13),
('Páginas pintadas',   'Leve',  13);

-- Escenario 2 (RN-02): Se marca Matilda (ejemplar 2) como Deteriorado tras registrar la incidencia en el préstamo 2
UPDATE ejemplares
SET estadoConservacion = 'Deteriorado'
WHERE oidE = 2;

-- Escenario 6: Préstamo activo de Nuria sobre Matilda (ejemplar 2)
INSERT INTO prestamos (oidP, fechaInicio, fechaLimite, fechaDevolucion, dni, oidE) VALUES
(6, '2026-11-02', '2026-11-16', NULL, '66698510S', 2);

-- Se actualiza a FALSE la disponibilidad de todos los ejemplares con préstamo activo
UPDATE ejemplares
SET disponibilidad = FALSE
WHERE oidE IN (SELECT oidE FROM prestamos WHERE fechaDevolucion IS NULL);

-- Reservas (se ejecutan al final cuando Matilda ya figura como no disponible para cumplir tReservasBi)
INSERT INTO reservas (fechaSolicitud, ordenPrioridad, estadoReserva, dni, oidL) VALUES
('2026-11-02', 1, 'Pendiente',  '89635244G', 2),
('2026-11-04', 2, 'Pendiente',  '51234876P', 2),
('2026-11-06', 3, 'Pendiente',  '39482015L', 2),
('2026-10-20', 1, 'Notificada', '78901234G', 8),
('2026-09-20', 1, 'Completada', '89635244G', 6),
('2026-10-10', 1, 'Cancelada',  '23456789B', 3),
('2026-11-10', 1, 'Pendiente',  '12345678A', 11);

-- =====================================================================
-- 1. PRUEBAS PARA tPrestamosBiRn01 (RN-01: Bloqueo por préstamos vencidos)
-- =====================================================================

-- [FALLA - Salta tPrestamosBiRn01]
-- Juan (77975237R) tiene el préstamo 3 vencido desde el 2026-10-30 (Escenario 1).
-- Al intentar sacar otro libro el 2026-11-02, el trigger bloquea el INSERT.
-- INSERT INTO prestamos (fechaInicio, fechaLimite, fechaDevolucion, dni, oidE)
-- VALUES ('2026-11-02', '2026-11-16', NULL, '77975237R', 3);

-- [PASA - No salta]
-- Rafael (89635244G) tiene el préstamo 9 activo, pero vence el 2026-12-02 (en plazo).
-- Como no tiene ningún préstamo vencido el 2026-11-20, el INSERT se permite.
 INSERT INTO prestamos (fechaInicio, fechaLimite, fechaDevolucion, dni, oidE)
 VALUES ('2026-11-20', '2026-12-04', NULL, '89635244G', 5);


-- =====================================================================
-- 2. PRUEBAS PARA tIncidenciasBiRn02 (RN-02: Incidencia al último préstamo)
-- =====================================================================

-- [FALLA - Salta tIncidenciasBiRn02]
-- El ejemplar 3 (El Hobbit) tuvo primero el préstamo 7 (Juan) y después el 8 (Rafael).
-- Al intentar asociar un desperfecto al préstamo antiguo (7), el trigger lo rechaza.
-- INSERT INTO incidencias (descripcionDesperfecto, gravedad, oidP)
-- VALUES ('Páginas pintadas', 'Leve', 7);

-- [PASA - No salta]
-- Asociar la incidencia al último préstamo registrado de ese ejemplar (8) sí se permite.
INSERT INTO incidencias (descripcionDesperfecto, gravedad, oidP)
VALUES ('Páginas arrancadas', 'Media', 8);


-- =====================================================================
-- 3. PRUEBAS PARA tEjemplaresBuRn02 (RN-02: Deteriorado exige incidencia)
-- Nota: Este trigger actúa sobre UPDATE en ejemplares, no sobre INSERT.
-- =====================================================================

-- [FALLA - Salta tEjemplaresBuRn02]
-- El último préstamo del ejemplar 12 (La historia interminable) es el 14 y no tiene incidencias.
-- Intentar marcarlo directamente como 'Deteriorado' dispara el trigger y bloquea el UPDATE.
-- UPDATE ejemplares
-- SET estadoConservacion = 'Deteriorado'
-- WHERE oidE = 12;

-- [PASA - No salta]
-- Primero registramos la incidencia sobre su último préstamo (14) con un INSERT,
-- y ahora el trigger sí permite actualizar el ejemplar 12 a 'Deteriorado'.
INSERT INTO incidencias (descripcionDesperfecto, gravedad, oidP)
VALUES ('Libro mojado', 'Alta', 14);

UPDATE ejemplares
SET estadoConservacion = 'Deteriorado'
WHERE oidE = 12;


-- =====================================================================
-- 4. PRUEBAS PARA tPrestamosBiRn03 (RN-03: Máximo 2 libros de lectura activos)
-- =====================================================================

-- [FALLA - Salta tPrestamosBiRn03]
-- Sara (40679852K) ya tiene 2 libros de lectura activos: préstamos 4 y 5 (Escenario 3).
-- Al intentar sacar un 3.º de lectura (ejemplar 7), el trigger bloquea el INSERT.
-- INSERT INTO prestamos (fechaInicio, fechaLimite, fechaDevolucion, dni, oidE)
-- VALUES ('2026-11-02', '2026-11-16', NULL, '40679852K', 7);

-- [PASA - No salta]
-- Daniela (56789012E) tiene 3 préstamos activos, pero 2 son de 'Texto' (10 y 11) y solo 1 de lectura (12).
-- Como los de texto no cuentan, puede sacar su 2.º libro de lectura (ejemplar 7) sin que salte el trigger.
INSERT INTO prestamos (fechaInicio, fechaLimite, fechaDevolucion, dni, oidE)
VALUES ('2026-11-12', '2026-11-26', NULL, '56789012E', 7);


-- =====================================================================
-- 5. PRUEBAS PARA tEjemplaresBiRn06 (RN-06: Código de ejemplar único)
-- =====================================================================

-- [FALLA - Salta tEjemplaresBiRn06]
-- El código 1 ya pertenece al ejemplar 1 (Jojolion). El trigger bloquea el duplicado.
-- INSERT INTO ejemplares (codigo, estadoConservacion, disponibilidad, oidL)
-- VALUES (1, 'Perfecto', TRUE, 11);

-- [PASA - No salta]
-- Al usar un código libre (14) para dar de alta una copia de Fundación (oidL = 11), se inserta sin problemas.
INSERT INTO ejemplares (codigo, estadoConservacion, disponibilidad, oidL)
VALUES (14, 'Perfecto', TRUE, 11);

CREATE OR REPLACE VIEW vbiblioteca
AS 
SELECT * FROM alumnos NATURAL JOIN prestamos NATURAL JOIN ejemplares NATURAL JOIN incidencias NATURAL JOIN reservas;
SELECT * FROM alumnos a
LEFT JOIN prestamos p ON a.dni = p.dni
LEFT JOIN ejemplares e ON p.oidE = e.oidE
LEFT JOIN libros lp ON e.oidL = lp.oidL
LEFT JOIN incidencias i ON p.oidP = i.oidP
LEFT JOIN reservas r ON a.dni = r.dni
LEFT JOIN libros lr ON r.oidL = lr.oidL;









