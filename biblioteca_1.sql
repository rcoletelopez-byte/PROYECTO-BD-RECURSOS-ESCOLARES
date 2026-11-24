-- =====================================================================
-- SIGRE · Módulo Biblioteca y Libros (RI-02.x, RC-02.x, RN-01/02/03/06)
-- Ejecutar después de sigre.sql.
-- =====================================================================
SET NAMES utf8mb4;
USE sigre;

DROP TABLE IF EXISTS reservas;
DROP TABLE IF EXISTS incidencias;
DROP TABLE IF EXISTS prestamos;
DROP TABLE IF EXISTS ejemplares;
DROP TABLE IF EXISTS libros;
DELETE FROM avisos WHERE tipo IN ('Retraso', 'ReservaDisponible');

-- ---------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------
CREATE TABLE libros (
    oidL INT PRIMARY KEY AUTO_INCREMENT,
    titulo VARCHAR(60) NOT NULL,
    editorial VARCHAR(40) NOT NULL,
    genero VARCHAR(30) NOT NULL,
    esLecturaObligatoria BOOLEAN NOT NULL DEFAULT FALSE,
    esLibroTexto BOOLEAN NOT NULL DEFAULT FALSE,   -- necesario para RN-03 (excluye libros de texto)
    UNIQUE (titulo, editorial)                      -- AK del PDF
);

CREATE TABLE ejemplares (
    oidE INT PRIMARY KEY AUTO_INCREMENT,
    codigo VARCHAR(10) NOT NULL UNIQUE,             -- RN-06
    estadoConservacion ENUM('Perfecto', 'Bueno', 'Regular', 'Deteriorado') NOT NULL,
    disponibilidad BOOLEAN NOT NULL DEFAULT TRUE,
    oidL INT NOT NULL,
    FOREIGN KEY (oidL) REFERENCES libros (oidL)
);

CREATE TABLE prestamos (
    oidP INT PRIMARY KEY AUTO_INCREMENT,
    fechaInicio DATE NOT NULL,
    fechaLimite DATE NOT NULL,
    fechaDevolucion DATE,
    dni CHAR(9) NOT NULL,
    oidE INT NOT NULL,
    UNIQUE (oidE, fechaInicio),                     -- AK del PDF
    CHECK (fechaLimite > fechaInicio),
    CHECK (fechaDevolucion IS NULL OR fechaDevolucion >= fechaInicio),
    FOREIGN KEY (dni) REFERENCES alumnos (dni),
    FOREIGN KEY (oidE) REFERENCES ejemplares (oidE)
);

CREATE TABLE incidencias (
    oidI INT PRIMARY KEY AUTO_INCREMENT,
    descripcionDesperfecto ENUM('Páginas pintadas', 'Páginas arrancadas', 'Libro mojado') NOT NULL,
    gravedad ENUM('Leve', 'Media', 'Grave') NOT NULL,
    oidP INT NOT NULL,
    FOREIGN KEY (oidP) REFERENCES prestamos (oidP)
);

CREATE TABLE reservas (
    oidR INT PRIMARY KEY AUTO_INCREMENT,
    fechaSolicitud DATE NOT NULL,
    ordenPrioridad INT NOT NULL DEFAULT 0,          -- 0 = que lo asigne el trigger
    estadoReserva ENUM('Pendiente', 'Notificada', 'Completada', 'Cancelada') NOT NULL DEFAULT 'Pendiente',
    dni CHAR(9) NOT NULL,
    oidL INT NOT NULL,
    UNIQUE (oidL, ordenPrioridad),                  -- AK del PDF
    FOREIGN KEY (dni) REFERENCES alumnos (dni),
    FOREIGN KEY (oidL) REFERENCES libros (oidL)
);

-- ---------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------
DELIMITER $$

-- RC-02.1 + RN-01 + RN-03: validaciones al registrar un préstamo activo.
-- (Los préstamos que se cargan ya devueltos son histórico y no se validan.)
CREATE TRIGGER trgPrestamosBi BEFORE INSERT ON prestamos
FOR EACH ROW
BEGIN
    DECLARE vDisponible BOOLEAN DEFAULT FALSE;
    DECLARE vEsTexto BOOLEAN DEFAULT FALSE;
    DECLARE vVencidos INT DEFAULT 0;
    DECLARE vActivos INT DEFAULT 0;

    IF NEW.fechaDevolucion IS NULL THEN
        SELECT e.disponibilidad, l.esLibroTexto INTO vDisponible, vEsTexto
          FROM ejemplares e JOIN libros l ON l.oidL = e.oidL
         WHERE e.oidE = NEW.oidE;

        IF NOT vDisponible THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-02.1: el ejemplar no está disponible';
        END IF;

        -- RN-01: bloqueo por préstamos vencidos
        SELECT COUNT(*) INTO vVencidos FROM prestamos
         WHERE dni = NEW.dni AND fechaDevolucion IS NULL AND fechaLimite < NEW.fechaInicio;
        IF vVencidos > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-01: el alumno tiene préstamos vencidos sin devolver';
        END IF;

        -- RN-03: máximo 2 libros de lectura activos (los de texto no cuentan)
        IF NOT vEsTexto THEN
            SELECT COUNT(*) INTO vActivos
              FROM prestamos p
              JOIN ejemplares e ON e.oidE = p.oidE
              JOIN libros l ON l.oidL = e.oidL
             WHERE p.dni = NEW.dni AND p.fechaDevolucion IS NULL AND l.esLibroTexto = FALSE;
            IF vActivos >= 2 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-03: máximo 2 libros de lectura en préstamo activo';
            END IF;
        END IF;
    END IF;
END$$

-- El ejemplar prestado deja de estar disponible; el préstamo completa
-- la reserva que el propio alumno tuviera de ese libro.
CREATE TRIGGER trgPrestamosAi AFTER INSERT ON prestamos
FOR EACH ROW
BEGIN
    IF NEW.fechaDevolucion IS NULL THEN
        UPDATE ejemplares SET disponibilidad = FALSE WHERE oidE = NEW.oidE;
        UPDATE reservas SET estadoReserva = 'Completada'
         WHERE dni = NEW.dni
           AND estadoReserva IN ('Pendiente', 'Notificada')
           AND oidL = (SELECT oidL FROM ejemplares WHERE oidE = NEW.oidE);
    END IF;
END$$

-- Una devolución registrada no se puede reabrir ni cambiar.
CREATE TRIGGER trgPrestamosBu BEFORE UPDATE ON prestamos
FOR EACH ROW
BEGIN
    IF OLD.fechaDevolucion IS NOT NULL
       AND (NEW.fechaDevolucion IS NULL OR NEW.fechaDevolucion <> OLD.fechaDevolucion) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-02.2: el préstamo ya está devuelto, no se puede modificar la devolución';
    END IF;
END$$

-- RC-02.2 + RC-02.4 + RG-03: al devolver, el ejemplar vuelve a estar
-- disponible, se avisa si hay retraso y se notifica la primera reserva.
CREATE TRIGGER trgPrestamosAu AFTER UPDATE ON prestamos
FOR EACH ROW
BEGIN
    DECLARE vOidL INT;
    DECLARE vTitulo VARCHAR(60);
    DECLARE vOidR INT DEFAULT NULL;

    IF OLD.fechaDevolucion IS NULL AND NEW.fechaDevolucion IS NOT NULL THEN
        UPDATE ejemplares SET disponibilidad = TRUE WHERE oidE = NEW.oidE;

        IF NEW.fechaDevolucion > NEW.fechaLimite THEN
            INSERT INTO avisos (fecha, tipo, panel, mensaje)
            VALUES (NEW.fechaDevolucion, 'Retraso', 'Biblioteca',
                    CONCAT('Préstamo ', NEW.oidP, ' devuelto con ',
                           DATEDIFF(NEW.fechaDevolucion, NEW.fechaLimite), ' día(s) de retraso'));
        END IF;

        SELECT l.oidL, l.titulo INTO vOidL, vTitulo
          FROM ejemplares e JOIN libros l ON l.oidL = e.oidL
         WHERE e.oidE = NEW.oidE;

        SELECT oidR INTO vOidR FROM reservas
         WHERE oidL = vOidL AND estadoReserva = 'Pendiente'
         ORDER BY ordenPrioridad LIMIT 1;

        IF vOidR IS NOT NULL THEN
            UPDATE reservas SET estadoReserva = 'Notificada' WHERE oidR = vOidR;
            INSERT INTO avisos (fecha, tipo, panel, mensaje)
            VALUES (NEW.fechaDevolucion, 'ReservaDisponible', 'Biblioteca',
                    CONCAT('Ya está disponible "', vTitulo, '" para la reserva ', vOidR));
        END IF;
    END IF;
END$$

-- RC-02.3 + RN-02: la incidencia solo cuelga de un préstamo ya devuelto
-- y que sea el último del ejemplar (el último prestatario es el responsable).
CREATE TRIGGER trgIncidenciasBi BEFORE INSERT ON incidencias
FOR EACH ROW
BEGIN
    DECLARE vDevolucion DATE;
    DECLARE vOidE INT;
    DECLARE vInicio DATE;
    DECLARE vPosteriores INT DEFAULT 0;

    SELECT fechaDevolucion, oidE, fechaInicio INTO vDevolucion, vOidE, vInicio
      FROM prestamos WHERE oidP = NEW.oidP;

    IF vDevolucion IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RC-02.3: la incidencia se registra al devolver, el préstamo sigue activo';
    END IF;

    SELECT COUNT(*) INTO vPosteriores FROM prestamos WHERE oidE = vOidE AND fechaInicio > vInicio;
    IF vPosteriores > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-02: la incidencia debe asociarse al último préstamo del ejemplar';
    END IF;
END$$

-- Escenario 2: la incidencia degrada el ejemplar (Leve: Regular;
-- Media o Grave: Deteriorado).
CREATE TRIGGER trgIncidenciasAi AFTER INSERT ON incidencias
FOR EACH ROW
BEGIN
    DECLARE vOidE INT;
    SELECT oidE INTO vOidE FROM prestamos WHERE oidP = NEW.oidP;

    IF NEW.gravedad = 'Leve' THEN
        UPDATE ejemplares SET estadoConservacion = 'Regular'
         WHERE oidE = vOidE AND estadoConservacion IN ('Perfecto', 'Bueno');
    ELSE
        UPDATE ejemplares SET estadoConservacion = 'Deteriorado' WHERE oidE = vOidE;
    END IF;
END$$

-- RN-02 (cara inversa): un ejemplar solo pasa a "Deteriorado" si existe
-- una incidencia sobre su último préstamo.
CREATE TRIGGER trgEjemplaresBu BEFORE UPDATE ON ejemplares
FOR EACH ROW
BEGIN
    DECLARE vIncidencias INT DEFAULT 0;

    IF NEW.estadoConservacion = 'Deteriorado' AND OLD.estadoConservacion <> 'Deteriorado' THEN
        SELECT COUNT(*) INTO vIncidencias
          FROM incidencias i JOIN prestamos p ON p.oidP = i.oidP
         WHERE p.oidE = NEW.oidE
           AND p.fechaInicio = (SELECT MAX(p2.fechaInicio) FROM prestamos p2 WHERE p2.oidE = NEW.oidE);
        IF vIncidencias = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-02: para marcar un ejemplar como deteriorado hay que registrar la incidencia';
        END IF;
    END IF;
END$$

-- RI-02.4 + RC-02.4: solo se reserva lo agotado, sin duplicar reservas
-- vivas del mismo alumno, y la prioridad se asigna sola si no se indica.
CREATE TRIGGER trgReservasBi BEFORE INSERT ON reservas
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
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- RC-02.5 Listado de préstamos fuera de plazo
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vPrestamosFueraPlazo AS
SELECT p.oidP, a.dni, a.nombre, a.apellidos, l.titulo, e.codigo,
       p.fechaLimite, DATEDIFF(CURDATE(), p.fechaLimite) AS diasDemora
  FROM prestamos p
  JOIN alumnos a ON a.dni = p.dni
  JOIN ejemplares e ON e.oidE = p.oidE
  JOIN libros l ON l.oidL = e.oidL
 WHERE p.fechaDevolucion IS NULL AND p.fechaLimite < CURDATE();

-- ---------------------------------------------------------------------
-- Datos
-- ---------------------------------------------------------------------
INSERT INTO libros (oidL, titulo, editorial, genero, esLecturaObligatoria, esLibroTexto) VALUES
(1,  'Jojolion',                  'Ivrea',      'Aventura',   TRUE,  FALSE),  -- escenario 1
(2,  'Matilda',                   'SM',         'Infantil',   TRUE,  FALSE),  -- escenarios 2 y 6
(3,  'La Celestina',              'SM',         'Drama',      TRUE,  FALSE),  -- escenario 3
(4,  'El principito',             'SM',         'Fábula',     FALSE, FALSE),  -- escenario 3
(5,  'La historia interminable',  'Alfaguara',  'Fantasía',   FALSE, FALSE),  -- escenario 3
(6,  'El Hobbit',                 'Minotauro',  'Fantasía',   TRUE,  FALSE),  -- 3 ejemplares
(7,  'La sombra del viento',      'Planeta',    'Misterio',   FALSE, FALSE),
(8,  'Los juegos del hambre',     'Molino',     'Juvenil',    FALSE, FALSE),
(9,  'Matemáticas 5.º',           'Santillana', 'Texto',      FALSE, TRUE),
(10, 'Lengua Castellana 6.º',     'Santillana', 'Texto',      FALSE, TRUE),
(11, 'Fundación',                 'Debolsillo', 'Ciencia Ficción', FALSE, FALSE);  -- sin ejemplares

-- La disponibilidad no se indica: nace en TRUE y la ajustan los triggers
-- al cargar los préstamos activos.
INSERT INTO ejemplares (oidE, codigo, estadoConservacion, oidL) VALUES
(1,  'EJ-00001', 'Perfecto', 1),
(2,  'EJ-00002', 'Perfecto', 2),
(3,  'EJ-00003', 'Bueno',    6),
(4,  'EJ-00004', 'Perfecto', 6),
(5,  'EJ-00005', 'Regular',  6),
(6,  'EJ-00006', 'Bueno',    7),
(7,  'EJ-00007', 'Regular',  8),
(8,  'EJ-00008', 'Bueno',    9),
(9,  'EJ-00009', 'Bueno',    9),
(10, 'EJ-00010', 'Perfecto', 4),
(11, 'EJ-00011', 'Perfecto', 3),
(12, 'EJ-00012', 'Perfecto', 5),
(13, 'EJ-00013', 'Perfecto', 10);

-- El préstamo 6 (Nuria, Matilda) se inserta DESPUÉS de las incidencias:
-- RN-02 exige que la incidencia del préstamo 2 (Lucía) sea sobre el último
-- préstamo del ejemplar en ese momento.
INSERT INTO prestamos (oidP, fechaInicio, fechaLimite, fechaDevolucion, dni, oidE) VALUES
(1,  '2026-10-01', '2026-10-15', '2026-10-14', '51234876P', 2),   -- Pablo, devuelve en perfecto estado (esc. 2)
(2,  '2026-10-25', '2026-11-05', '2026-11-02', '72940183F', 2),   -- Lucía, devuelve con daños (esc. 2)
(3,  '2026-10-20', '2026-10-30', NULL,         '77975237R', 1),   -- Juan, vencido (esc. 1)
(4,  '2026-10-28', '2026-11-11', NULL,         '40679852K', 11),  -- Sara, La Celestina (esc. 3)
(5,  '2026-10-25', '2026-11-05', NULL,         '40679852K', 10),  -- Sara, El principito (esc. 3)
(7,  '2026-09-10', '2026-09-24', '2026-09-22', '77975237R', 3),   -- Juan, histórico
(8,  '2026-09-28', '2026-10-12', '2026-10-20', '89635244G', 3),   -- Rafael, devuelto TARDE
(9,  '2026-11-18', '2026-12-02', NULL,         '89635244G', 4),   -- Rafael, activo dentro de plazo
(10, '2026-11-09', '2026-11-30', NULL,         '56789012E', 8),   -- Daniela: texto
(11, '2026-11-09', '2026-11-30', NULL,         '56789012E', 13),  -- Daniela: texto
(12, '2026-11-10', '2026-11-30', NULL,         '56789012E', 6),   -- Daniela: 3 activos (2 de texto + 1 lectura)
(13, '2026-10-05', '2026-10-19', '2026-10-19', '23456789B', 7),   -- Mateo, dos incidencias
(14, '2026-09-15', '2026-09-29', '2026-09-25', '12345678A', 12);  -- Lucía G., sin incidencias

-- Los estados de conservación de los ejemplares los cambian los triggers.
INSERT INTO incidencias (descripcionDesperfecto, gravedad, oidP) VALUES
('Páginas arrancadas', 'Grave', 2),   -- escenario 2
('Páginas pintadas',   'Leve',  8),
('Libro mojado',       'Media', 13),
('Páginas pintadas',   'Leve',  13);

INSERT INTO prestamos (oidP, fechaInicio, fechaLimite, fechaDevolucion, dni, oidE) VALUES
(6, '2026-11-02', '2026-11-16', NULL, '66698510S', 2);            -- Nuria, Matilda (esc. 6)

INSERT INTO reservas (fechaSolicitud, ordenPrioridad, estadoReserva, dni, oidL) VALUES
('2026-11-02', 1, 'Pendiente',  '89635244G', 2),    -- escenario 6: Rafael, primero de la cola
('2026-11-04', 2, 'Pendiente',  '51234876P', 2),
('2026-11-06', 3, 'Pendiente',  '39482015L', 2),
('2026-10-20', 1, 'Notificada', '78901234G', 8),
('2026-09-20', 1, 'Completada', '89635244G', 6),
('2026-10-10', 1, 'Cancelada',  '23456789B', 3),
('2026-11-10', 1, 'Pendiente',  '12345678A', 11);   -- libro sin ejemplares

-- ---------------------------------------------------------------------
-- Pruebas de los escenarios (ejecutar a mano; cada una indica el resultado)
-- ---------------------------------------------------------------------
-- Escenario 1 (RN-01): Juan tiene el préstamo 3 vencido -> ERROR RN-01
-- INSERT INTO prestamos (fechaInicio, fechaLimite, dni, oidE) VALUES ('2026-11-02', '2026-11-16', '77975237R', 5);
--
-- Escenario 3 (RN-03): Sara ya tiene 2 lecturas activas -> ERROR RN-03
-- INSERT INTO prestamos (fechaInicio, fechaLimite, dni, oidE) VALUES ('2026-11-02', '2026-11-16', '40679852K', 12);
--
-- Daniela tiene 3 activos pero 2 son de texto -> un 4.º de texto SÍ se permite:
-- INSERT INTO prestamos (fechaInicio, fechaLimite, dni, oidE) VALUES ('2026-11-12', '2026-11-30', '56789012E', 9);
--
-- Escenario 6 / RC-02.4: Nuria devuelve Matilda -> ejemplar disponible, reserva de
-- Rafael pasa a 'Notificada', aviso 'ReservaDisponible' y aviso 'Retraso':
-- UPDATE prestamos SET fechaDevolucion = '2026-11-20' WHERE oidP = 6;
--
-- RN-02: incidencia sobre el préstamo 1 (Pablo, ya no es el último) -> ERROR
-- INSERT INTO incidencias (descripcionDesperfecto, gravedad, oidP) VALUES ('Libro mojado', 'Leve', 1);
--
-- RI-02.4: reservar un libro con ejemplares disponibles (El Hobbit) -> ERROR
-- INSERT INTO reservas (fechaSolicitud, dni, oidL) VALUES ('2026-11-12', '77975237R', 6);
