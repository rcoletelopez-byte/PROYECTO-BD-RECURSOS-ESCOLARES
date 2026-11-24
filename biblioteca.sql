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

CREATE OR REPLACE TRIGGER tReservasBi
BEFORE INSERT ON reservas
FOR EACH ROW
BEGIN
    IF NEW.estadoReserva = 'Pendiente' THEN
        IF (SELECT COUNT(*) FROM ejemplares WHERE oidL = NEW.oidL AND disponibilidad = TRUE) > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RI-02.4: el libro tiene ejemplares disponibles, solo se reservan los agotados';
        END IF;

        IF (SELECT COUNT(*) FROM reservas WHERE dni = NEW.dni AND oidL = NEW.oidL AND estadoReserva IN ('Pendiente', 'Notificada')) > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El alumno ya tiene una reserva activa de este libro';
        END IF;
    END IF;

    IF NEW.ordenPrioridad = 0 THEN
        SET NEW.ordenPrioridad = (SELECT IFNULL(MAX(ordenPrioridad), 0) + 1 FROM reservas WHERE oidL = NEW.oidL);
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE OR REPLACE TRIGGER tReservasBi BEFORE INSERT ON reservas
FOR EACH ROW
BEGIN
    DECLARE vDisponibles INT DEFAULT 0;
    DECLARE vDuplicadas INT DEFAULT 0;

    IF NEW.estadoReserva = 'Pendiente' THEN
        SELECT COUNT(*) INTO vDisponibles FROM ejemplares
         WHERE oidL = NEW.oidL AND disponibilidad = TRUE;
        IF vDisponibles > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RI-02.4: el libro tiene ejemplares disponibles, solo se reservan los agotados';
        END IF;

        SELECT COUNT(*) INTO vDuplicadas FROM reservas
         WHERE dni = NEW.dni AND oidL = NEW.oidL AND estadoReserva IN ('Pendiente', 'Notificada');
        IF vDuplicadas > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El alumno ya tiene una reserva activa de este libro';
        END IF;
    END IF;

    IF NEW.ordenPrioridad = 0 THEN
        SET NEW.ordenPrioridad = (SELECT IFNULL(MAX(ordenPrioridad), 0) + 1 FROM reservas WHERE oidL = NEW.oidL);
    END IF;
END // 
DELIMITER ;

	


INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES
('51234876P', 'Pablo',   'García Pérez',    3, TRUE),
('72940183F', 'Lucía',   'Martínez Ruiz',   2, FALSE),
('77975237R', 'Juan',    'López Sánchez',   4, TRUE),
('40679852K', 'Sara',    'Gómez Díaz',      1, FALSE),
('89635244G', 'Rafael',  'Fernández Gil',   5, TRUE),
('56789012E', 'Daniela', 'Moreno Torres',   6, TRUE),
('23456789B', 'Mateo',   'Jiménez Navarro', 3, FALSE),
('12345678A', 'Lucía',   'Gómez Ortiz',     2, TRUE),
('66698510S', 'Nuria',   'Romero Castro',   4, FALSE),
('39482015L', 'Carlos',  'Vázquez Alonso',  1, TRUE),
('78901234G', 'Elena',   'Serrano Molina',  5, FALSE);

-- Libros (se elimina esLibroTexto porque no existe en tu tabla)
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

-- Ejemplares (codigo convertido a INT y disponibilidad añadida explícitamente)
INSERT INTO ejemplares (oidE, codigo, estadoConservacion, disponibilidad, oidL) VALUES
(1,  1,  'Perfecto', FALSE, 1),
(2,  2,  'Perfecto', FALSE, 2),
(3,  3,  'Bueno',    TRUE,  6),
(4,  4,  'Perfecto', FALSE, 6),
(5,  5,  'Regular',  TRUE,  6),
(6,  6,  'Bueno',    FALSE, 7),
(7,  7,  'Regular',  TRUE,  8),
(8,  8,  'Bueno',    FALSE, 9),
(9,  9,  'Bueno',    TRUE,  9),
(10, 10, 'Perfecto', FALSE, 4),
(11, 11, 'Perfecto', FALSE, 3),
(12, 12, 'Perfecto', TRUE,  5),
(13, 13, 'Perfecto', FALSE, 10);

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

-- Incidencias ('Grave' cambiado a 'Alta' para coincidir con el ENUM)
INSERT INTO incidencias (descripcionDesperfecto, gravedad, oidP) VALUES
('Páginas arrancadas', 'Alta',  2),
('Páginas pintadas',   'Leve',  8),
('Libro mojado',       'Media', 13),
('Páginas pintadas',   'Leve',  13);

INSERT INTO prestamos (oidP, fechaInicio, fechaLimite, fechaDevolucion, dni, oidE) VALUES
(6, '2026-11-02', '2026-11-16', NULL, '66698510S', 2);

-- Reservas
INSERT INTO reservas (fechaSolicitud, ordenPrioridad, estadoReserva, dni, oidL) VALUES
('2026-11-02', 1, 'Pendiente',  '89635244G', 2),
('2026-11-04', 2, 'Pendiente',  '51234876P', 2),
('2026-11-06', 3, 'Pendiente',  '39482015L', 2),
('2026-10-20', 1, 'Notificada', '78901234G', 8),
('2026-09-20', 1, 'Completada', '89635244G', 6),
('2026-10-10', 1, 'Cancelada',  '23456789B', 3),
('2026-11-10', 1, 'Pendiente',  '12345678A', 11);









