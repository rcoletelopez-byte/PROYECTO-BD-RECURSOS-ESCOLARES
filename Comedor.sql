USE sigre;

DROP TABLE IF EXISTS asistencias;
DROP TABLE IF EXISTS alergias;
DROP TABLE IF EXISTS intolerancias;
DROP TABLE IF EXISTS menus;

CREATE TABLE menus
(	oidM SMALLINT PRIMARY KEY AUTO_INCREMENT,
   fecha DATE NOT NULL,
   clase ENUM('Normal', 'Especial') NOT NULL,
   postre VARCHAR(50) NOT NULL,
   primerPlato VARCHAR(60),
   segundoPlato VARCHAR(60),
   primerPlatoEspecial VARCHAR(60),
   segundoPlatoEspecial VARCHAR(60),
	CONSTRAINT chk_menus_clase_positivo CHECK (clase > 0),
	CONSTRAINT uq_menu_clase UNIQUE (fecha, clase),
	CONSTRAINT chk_platos_menu_segun_clase CHECK ((clase = 'Normal'
            AND primerPlato IS NOT NULL AND segundoPlato IS NOT NULL
            AND primerPlatoEspecial IS NULL AND segundoPlatoEspecial IS NULL)
        OR
        (clase = 'Especial'
            AND primerPlatoEspecial IS NOT NULL AND segundoPlatoEspecial IS NOT NULL
            AND primerPlato IS NULL AND segundoPlato IS NULL))
	
);

CREATE TABLE asistencias
(	oidAd SMALLINT PRIMARY KEY AUTO_INCREMENT,
   asiste BOOLEAN NOT NULL DEFAULT FALSE,
   fichaConfirmada BOOLEAN NOT NULL DEFAULT FALSE,
   dni CHAR(9) NOT NULL,
   oidM SMALLINT NOT NULL,
	CONSTRAINT uq_asistencia_alumno FOREIGN KEY (dni) 
	REFERENCES alumnos (dni) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT uq_asistencia_menus FOREIGN KEY (oidM) 
	REFERENCES menus (oidM) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT uq_asistencia_alumno_menu UNIQUE (dni, oidM)
);

CREATE TABLE intolerancias
(	 oidIn SMALLINT PRIMARY KEY AUTO_INCREMENT,
    lactosa BOOLEAN NOT NULL DEFAULT FALSE,
    gluten BOOLEAN NOT NULL DEFAULT FALSE,
    fructosa BOOLEAN NOT NULL DEFAULT FALSE,
    dni CHAR(9) NOT NULL UNIQUE,
	CONSTRAINT fk_intolerancia_alumno FOREIGN KEY (dni) 
   	REFERENCES alumnos (dni) ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT uq_dni_intolerancia UNIQUE (dni)
);

CREATE TABLE alergias
( 	 oidAle SMALLINT PRIMARY KEY AUTO_INCREMENT,
    huevo BOOLEAN NOT NULL DEFAULT FALSE,
    lacteos BOOLEAN NOT NULL DEFAULT FALSE,
    frutosSecos BOOLEAN NOT NULL DEFAULT FALSE,
    pescado BOOLEAN NOT NULL DEFAULT FALSE,
    dni CHAR(9) NOT NULL UNIQUE,
	CONSTRAINT fk_alergia_alumno FOREIGN KEY (dni)
   	REFERENCES alumnos (dni) ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT uq_dni_alergia UNIQUE (dni)
);


DELIMITER //

-- Validación al insertar una nueva asistencia
CREATE TRIGGER t_validar_asistencia_insert
BEFORE INSERT ON asistencias
FOR EACH ROW
BEGIN
    IF NEW.asiste = TRUE AND NEW.fichaConfirmada = FALSE THEN
        IF EXISTS (
            SELECT 1 FROM alergias 
            WHERE dni = NEW.dni AND (huevo = TRUE OR lacteos = TRUE OR frutosSecos = TRUE OR pescado = TRUE)
        ) OR EXISTS (
            SELECT 1 FROM intolerancias 
            WHERE dni = NEW.dni AND (lactosa = TRUE OR gluten = TRUE OR fructosa = TRUE)
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error RN-05: Debe confirmar la lectura de la ficha de alergias/intolerancias antes de validar la asistencia.';
        END IF;
    END IF;
END//

-- Validación al actualizar una asistencia existente (ej. paso de lista)
CREATE TRIGGER t_validar_asistencia_update
BEFORE UPDATE ON asistencias
FOR EACH ROW
BEGIN
    IF NEW.Asiste = TRUE AND NEW.fichaConfirmada = FALSE THEN
        IF EXISTS (
            SELECT 1 FROM alergias 
            WHERE dni = NEW.dni AND (huevo = TRUE OR lacteos = TRUE OR frutosSecos = TRUE OR pescado = TRUE)
        ) OR EXISTS (
            SELECT 1 FROM intolerancias 
            WHERE dni = NEW.dni AND (lactosa = TRUE OR gluten = TRUE OR fructosa = TRUE)
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error RN-05: Debe confirmar la lectura de la ficha de alergias/intolerancias antes de validar la asistencia.';
        END IF;
    END IF;
END//

DELIMITER ;





INSERT INTO intolerancias (lactosa, gluten, fructosa, dni) VALUES
(TRUE,  FALSE, FALSE, '12345678A'),
(FALSE, TRUE,  FALSE, '23456789B'),
(TRUE,  TRUE,  FALSE, '34567890C'),
(FALSE, FALSE, TRUE,  '67890123F');

INSERT INTO alergias (huevo, lacteos, frutosSecos, pescado, dni) VALUES
(TRUE,  TRUE,  FALSE, FALSE, '39482015L'),   -- escenario 5: Carmen
(TRUE,  FALSE, FALSE, FALSE, '23456789B'),
(FALSE, FALSE, TRUE,  TRUE,  '34567890C'),
(FALSE, TRUE,  FALSE, FALSE, '45678901D');

-- Semana del 16 al 20/11/2026 completa (con menú especial todos los días)
-- y el lunes 02/11/2026 del escenario 5.
INSERT INTO menus (oidM, fecha, clase, postre, primerPlato, segundoPlato) VALUES
(1,  '2026-11-02', 'Normal', 'Manzana',  'Macarrones con tomate',  'Pollo a la plancha con patatas'),
(3,  '2026-11-16', 'Normal', 'Manzana',  'Lentejas estofadas',     'Pechuga de pollo a la plancha'),
(5,  '2026-11-17', 'Normal', 'Pera',     'Macarrones con tomate',  'Merluza al horno'),
(7,  '2026-11-18', 'Normal', 'Plátano',  'Crema de calabacín',     'Tortilla de patatas'),
(9,  '2026-11-19', 'Normal', 'Mandarina','Arroz a la cubana',      'Filete de ternera con ensalada'),
(11, '2026-11-20', 'Normal', 'Uvas',     'Garbanzos con espinacas','Lomo a la plancha');

INSERT INTO menus (oidM, fecha, clase, postre, primerPlatoEspecial, segundoPlatoEspecial) VALUES
(2,  '2026-11-02', 'Especial', 'Manzana',  'Puré de verduras',                  'Pollo a la plancha con patatas'),
(4,  '2026-11-16', 'Especial', 'Manzana',  'Lentejas con verduras sin gluten',  'Pechuga de pollo a la plancha'),
(6,  '2026-11-17', 'Especial', 'Pera',     'Arroz blanco con verduras',         'Pechuga de pavo asada'),
(8,  '2026-11-18', 'Especial', 'Plátano',  'Puré de patata y zanahoria',        'Filete de ternera a la plancha'),
(10, '2026-11-19', 'Especial', 'Mandarina','Arroz blanco con tomate',           'Pollo asado con patatas'),
(12, '2026-11-20', 'Especial', 'Uvas',     'Verduras salteadas',                'Pechuga de pollo a la plancha');

INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES
-- 02/11 (escenario 5): Carmen, alérgica, solo se valida tras confirmar la ficha y con menú especial
(TRUE,  TRUE,  '39482015L', 2),
(TRUE,  FALSE, '77975237R', 1),
(TRUE,  FALSE, '72940183F', 1),
-- 16/11
(TRUE,  TRUE,  '12345678A', 4),
(TRUE,  TRUE,  '23456789B', 4),
(FALSE, FALSE, '34567890C', 4),   -- comensal fija que falta
(TRUE,  FALSE, '56789012E', 3),
(TRUE,  FALSE, '77975237R', 3),
-- 17/11
(TRUE,  TRUE,  '12345678A', 6),
(TRUE,  FALSE, '56789012E', 5),
(TRUE,  TRUE,  '67890123F', 6),
-- 18/11
(TRUE,  TRUE,  '45678901D', 8),   -- Hugo: comedor = FALSE, asiste un día puntual (ocasional)
(FALSE, FALSE, '56789012E', 7),
-- 19/11 (Daniela, comensal fija, no tiene registro ese día)
(TRUE,  TRUE,  '23456789B', 10);

-- ---------------------------------------------------------------------
-- Pruebas (ejecutar a mano)
-- ---------------------------------------------------------------------
-- Escenario 5 / RN-05: Mateo (gluten + huevo) sin confirmar la ficha -> ERROR
-- INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES (TRUE, FALSE, '23456789B', 12);
-- Mateo con la ficha confirmada pero asociado al menú normal -> ERROR
-- INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES (TRUE, TRUE, '23456789B', 11);
-- Mismo alumno, mismo día, otro menú -> ERROR
-- INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES (TRUE, FALSE, '56789012E', 4);
-- Daniela (sin restricciones) el 19/11 con el menú normal -> OK
-- INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES (TRUE, FALSE, '56789012E', 9);