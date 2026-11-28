
DROP TABLE IF EXISTS asistencias;
DROP TABLE IF EXISTS alergias;
DROP TABLE IF EXISTS intolerancias;
DROP TABLE IF EXISTS menus;
DROP TABLE if EXISTS alumnos;

DROP PROCEDURE IF EXISTS pValidarAsistencia;

CREATE TABLE alumnos (
    dni CHAR(9) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellidos VARCHAR(50) NOT NULL,
    curso TINYINT NOT NULL,
    comedor BOOLEAN NOT NULL DEFAULT FALSE,
    CHECK (curso BETWEEN 1 AND 6)
);

CREATE TABLE menus
(	oidM SMALLINT PRIMARY KEY AUTO_INCREMENT,
   fecha DATE NOT NULL,
   clase ENUM('Normal', 'Especial') NOT NULL,
   postre VARCHAR(50) NOT NULL,
   primerPlato VARCHAR(60),
   segundoPlato VARCHAR(60),
   primerPlatoEspecial VARCHAR(60),
   segundoPlatoEspecial VARCHAR(60),
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
	CONSTRAINT fk_asistencia_alumno FOREIGN KEY (dni) 
	REFERENCES alumnos (dni) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT fk_asistencia_menus FOREIGN KEY (oidM) 
	REFERENCES menus (oidM) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT uq_asistencia_alumno_menu UNIQUE (dni, oidM)
);

CREATE TABLE intolerancias
(	 oidIn SMALLINT PRIMARY KEY AUTO_INCREMENT,
    lactosa BOOLEAN NOT NULL DEFAULT FALSE,
    gluten BOOLEAN NOT NULL DEFAULT FALSE,
    fructosa BOOLEAN NOT NULL DEFAULT FALSE,
    dni CHAR(9) NOT NULL,
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
    dni CHAR(9) NOT NULL,
	CONSTRAINT fk_alergia_alumno FOREIGN KEY (dni)
   	REFERENCES alumnos (dni) ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT uq_dni_alergia UNIQUE (dni)
);



DELIMITER //
CREATE PROCEDURE pValidarAsistencia(newAsiste BOOLEAN, newFichaConfirmada BOOLEAN, newDni CHAR(9), newOidAd SMALLINT, newOidM SMALLINT)
	BEGIN 
	DECLARE newTieneRestriccion BOOLEAN DEFAULT FALSE;
	DECLARE newClase ENUM("Normal", "Especial");
	DECLARE newFecha DATE;
	
	IF (newAsiste = TRUE) THEN
			IF EXISTS (
            SELECT 1 FROM alergias
            WHERE dni = newDni AND (huevo = TRUE OR lacteos = TRUE OR frutosSecos = TRUE OR pescado = TRUE)
        ) OR EXISTS (
            SELECT 1 FROM intolerancias 
            WHERE dni = newDni AND (lactosa = TRUE OR gluten = TRUE OR fructosa = TRUE)
        ) THEN
        		SET newTieneRestriccion = TRUE;
			END IF;
        
   END IF;
   
   SELECT clase, fecha INTO newClase, newFecha FROM menus WHERE newOidM = oidM;
   
   IF (newTieneRestriccion = TRUE AND newFichaConfirmada = FALSE) 
		THEN
			SIGNAL SQLSTATE '45000'
      	SET MESSAGE_TEXT = 'Error RN-05: Debe confirmar la lectura de la ficha de alergias/intolerancias antes de validar la asistencia.';
	END IF;
	IF (newTieneRestriccion = TRUE AND newClase <> "Especial") 
		THEN
			SIGNAL SQLSTATE '45000'
      	SET MESSAGE_TEXT = 'Error: Un alumno con alergias o intolerancias debe tener asignado un menú Especial.';
   END IF;
   
   IF EXISTS(
   	SELECT 1 FROM asistencias A JOIN menus M ON A.oidM = M.oidM WHERE M.fecha = newFecha
									AND A.dni = newDni AND (newOidAd <> A.oidAd OR newOidAd IS NULL))
		THEN
			SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'Error: El alumno ya tiene un menú asignado para esa fecha.';
   END IF;
		
END//

DELIMITER ;



DELIMITER //

-- Validación al insertar una nueva asistencia
CREATE TRIGGER t_validar_asistencia_insert
BEFORE INSERT ON asistencias
FOR EACH ROW
BEGIN
	CALL pValidarAsistencia(NEW.asiste, NEW.fichaConfirmada, NEW.dni, NULL, NEW.oidM);
END//

-- Validación al actualizar una asistencia existente (ej. paso de lista)
CREATE TRIGGER t_validar_asistencia_update
BEFORE UPDATE ON asistencias
FOR EACH ROW
BEGIN
    CALL pValidarAsistencia(NEW.asiste, NEW.fichaConfirmada, NEW.dni, NEW.oidAd, NEW.oidM);
END//

DELIMITER ;








-- ---------------------------------------------------------------------
-- 1. ALUMNOS (20 alumnos: cursos 1 a 6, fijos y ocasionales)
-- ---------------------------------------------------------------------
INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES
-- Comensales fijos (comedor = TRUE)
('12345678A', 'Lucía',     'García López',       2, TRUE),
('23456789B', 'Mateo',     'Martínez Ruiz',      3, TRUE),
('34567890C', 'Sofía',     'Sánchez Pérez',      1, TRUE),
('56789012E', 'Daniela',   'Jiménez Díaz',       2, TRUE),
('67890123F', 'Álvaro',    'Moreno Álvarez',     5, TRUE),
('39482015L', 'Carmen',    'Navarro Torres',     3, TRUE),
('72940183F', 'Elena',     'Ortega Morales',     6, TRUE),
('11223344G', 'Pablo',     'Delgado Castro',     1, TRUE),
('22334455H', 'Valeria',   'Rubio Ortiz',        4, TRUE),
('33445566J', 'Adrián',    'Molina Marín',       5, TRUE),
('44556677K', 'Martina',   'Sanz Iglesias',      6, TRUE),
('55667788M', 'Leo',       'Garrido Cortés',     2, TRUE),
('66778899N', 'Julia',     'Vázquez Medina',     3, TRUE),
('77889900P', 'Izan',      'Reyes Guerrero',     4, TRUE),
-- Comensales ocasionales / no habituales (comedor = FALSE)
('45678901D', 'Hugo',      'Fernández Gómez',    4, FALSE),
('77975237R', 'Juan',      'Romero Castillo',    1, FALSE),
('88990011Q', 'Carla',     'Lozano Cano',        5, FALSE),
('99001122S', 'Bruno',     'Prieto Méndez',      6, FALSE),
('10203040T', 'Nora',      'Cruz Herrera',       2, FALSE),
('20304050V', 'Diego',     'Flores Peña',        3, FALSE);

-- ---------------------------------------------------------------------
-- 2. INTOLERANCIAS (solo intolerancia y combinadas con alergias)
-- ---------------------------------------------------------------------
INSERT INTO intolerancias (lactosa, gluten, fructosa, dni) VALUES
(TRUE,  FALSE, FALSE, '12345678A'), -- Lucía: solo lactosa
(FALSE, TRUE,  FALSE, '23456789B'), -- Mateo: gluten (+ alergia huevo)
(TRUE,  TRUE,  FALSE, '34567890C'), -- Sofía: lactosa + gluten (+ alergia frutos secos y pescado)
(FALSE, FALSE, TRUE,  '67890123F'), -- Álvaro: solo fructosa
(TRUE,  FALSE, TRUE,  '11223344G'), -- Pablo: lactosa + fructosa
(FALSE, TRUE,  FALSE, '88990011Q'), -- Carla (ocasional): gluten (+ alergia lácteos)
(FALSE, FALSE, FALSE, '77889900P'); -- Izan: ficha creada pero todo en FALSE (sin restricción real)

-- ---------------------------------------------------------------------
-- 3. ALERGIAS (solo alergia y combinadas con intolerancias)
-- ---------------------------------------------------------------------
INSERT INTO alergias (huevo, lacteos, frutosSecos, pescado, dni) VALUES
(TRUE,  TRUE,  FALSE, FALSE, '39482015L'), -- Carmen: huevo + lácteos
(TRUE,  FALSE, FALSE, FALSE, '23456789B'), -- Mateo: huevo (+ intolerancia gluten)
(FALSE, FALSE, TRUE,  TRUE,  '34567890C'), -- Sofía: frutos secos + pescado (+ intol. lactosa/gluten)
(FALSE, TRUE,  FALSE, FALSE, '45678901D'), -- Hugo (ocasional): lácteos
(FALSE, FALSE, TRUE,  FALSE, '22334455H'), -- Valeria: frutos secos
(FALSE, FALSE, FALSE, TRUE,  '44556677K'), -- Martina: pescado
(FALSE, TRUE,  FALSE, FALSE, '88990011Q'), -- Carla (ocasional): lácteos (+ intolerancia gluten)
(FALSE, FALSE, FALSE, FALSE, '66778899N'); -- Julia: ficha creada pero todo en FALSE (sin restricción real)

-- ---------------------------------------------------------------------
-- 4. MENÚS (2 semanas completas: Normal y Especial cada día)
-- ---------------------------------------------------------------------
INSERT INTO menus (oidM, fecha, clase, postre, primerPlato, segundoPlato) VALUES
(1,  '2026-11-02', 'Normal', 'Manzana',   'Macarrones con tomate',     'Pollo a la plancha con patatas'),
(3,  '2026-11-16', 'Normal', 'Manzana',   'Lentejas estofadas',        'Pechuga de pollo a la plancha'),
(5,  '2026-11-17', 'Normal', 'Pera',      'Macarrones con tomate',     'Merluza al horno'),
(7,  '2026-11-18', 'Normal', 'Plátano',   'Crema de calabacín',        'Tortilla de patatas'),
(9,  '2026-11-19', 'Normal', 'Mandarina', 'Arroz a la cubana',         'Filete de ternera con ensalada'),
(11, '2026-11-20', 'Normal', 'Uvas',      'Garbanzos con espinacas',   'Lomo a la plancha'),
(13, '2026-11-23', 'Normal', 'Yogur',     'Sopa de fideos',            'Albóndigas en salsa'),
(15, '2026-11-24', 'Normal', 'Naranja',   'Judías verdes con patatas', 'Salmón a la plancha');

INSERT INTO menus (oidM, fecha, clase, postre, primerPlatoEspecial, segundoPlatoEspecial) VALUES
(2,  '2026-11-02', 'Especial', 'Manzana',   'Puré de verduras',                 'Pollo a la plancha con patatas'),
(4,  '2026-11-16', 'Especial', 'Manzana',   'Lentejas con verduras sin gluten', 'Pechuga de pollo a la plancha'),
(6,  '2026-11-17', 'Especial', 'Pera',      'Arroz blanco con verduras',        'Pechuga de pavo asada'),
(8,  '2026-11-18', 'Especial', 'Plátano',   'Puré de patata y zanahoria',       'Filete de ternera a la plancha'),
(10, '2026-11-19', 'Especial', 'Mandarina', 'Arroz blanco con tomate',          'Pollo asado con patatas'),
(12, '2026-11-20', 'Especial', 'Uvas',      'Verduras salteadas',               'Pechuga de pollo a la plancha'),
(14, '2026-11-23', 'Especial', 'Manzana',   'Caldo de pollo con arroz',         'Pechuga de pavo a la plancha'),
(16, '2026-11-24', 'Especial', 'Naranja',   'Menestra de verduras',             'Pollo asado sin especias');

-- ---------------------------------------------------------------------
-- 5. ASISTENCIAS (casos variados para consultas SELECT)
-- ---------------------------------------------------------------------
INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES
-- Lunes 02/11/2026
(TRUE,  TRUE,  '39482015L', 2),  -- Carmen (alérgica) asiste con ficha confirmada y menú Especial
(TRUE,  FALSE, '77975237R', 1),  -- Juan (ocasional, sin restricciones) asiste con menú Normal
(TRUE,  FALSE, '72940183F', 1),  -- Elena (fija, sin restricciones) asiste con menú Normal
(TRUE,  FALSE, '66778899N', 1),  -- Julia (ficha en FALSE -> sin restricción real) puede ir a Normal

-- Lunes 16/11/2026
(TRUE,  TRUE,  '12345678A', 4),  -- Lucía (lactosa) -> Especial
(TRUE,  TRUE,  '23456789B', 4),  -- Mateo (gluten + huevo) -> Especial
(FALSE, FALSE, '34567890C', 4),  -- Sofía (múltiples restricciones) NO asiste (ficha sin confirmar permitida al no asistir)
(TRUE,  FALSE, '56789012E', 3),  -- Daniela (sin restricciones) -> Normal
(TRUE,  FALSE, '77975237R', 3),  -- Juan (ocasional) -> Normal
(TRUE,  TRUE,  '11223344G', 4),  -- Pablo (lactosa + fructosa) -> Especial
(TRUE,  FALSE, '33445566J', 3),  -- Adrián (sin restricciones) -> Normal

-- Martes 17/11/2026
(TRUE,  TRUE,  '12345678A', 6),  -- Lucía -> Especial
(TRUE,  FALSE, '56789012E', 5),  -- Daniela -> Normal
(TRUE,  TRUE,  '67890123F', 6),  -- Álvaro (fructosa) -> Especial
(TRUE,  TRUE,  '22334455H', 6),  -- Valeria (frutos secos) -> Especial
(TRUE,  TRUE,  '44556677K', 6),  -- Martina (pescado; evita merluza del menú normal) -> Especial
(FALSE, FALSE, '55667788M', 5),  -- Leo (fijo) falta este día

-- Miércoles 18/11/2026
(TRUE,  TRUE,  '45678901D', 8),  -- Hugo (ocasional con alergia lácteos) -> Especial
(FALSE, FALSE, '56789012E', 7),  -- Daniela falta este día
(TRUE,  FALSE, '77889900P', 7),  -- Izan (ficha todo en FALSE) -> Normal
(TRUE,  FALSE, '99001122S', 7),  -- Bruno (ocasional sin restricciones) -> Normal

-- Jueves 19/11/2026
(TRUE,  TRUE,  '23456789B', 10), -- Mateo -> Especial
(TRUE,  TRUE,  '88990011Q', 10), -- Carla (ocasional con gluten + lácteos) -> Especial
(TRUE,  FALSE, '10203040T', 9),  -- Nora (ocasional sin restricciones) -> Normal
(TRUE,  FALSE, '20304050V', 9),  -- Diego (ocasional sin restricciones) -> Normal

-- Viernes 20/11/2026
(TRUE,  TRUE,  '34567890C', 12), -- Sofía asiste con ficha confirmada -> Especial
(TRUE,  FALSE, '72940183F', 11), -- Elena -> Normal
(TRUE,  FALSE, '55667788M', 11), -- Leo -> Normal

-- Lunes 23/11/2026 y Martes 24/11/2026
(TRUE,  TRUE,  '39482015L', 14), -- Carmen -> Especial
(TRUE,  FALSE, '33445566J', 13), -- Adrián -> Normal
(TRUE,  TRUE,  '44556677K', 16), -- Martina (pescado; evita salmón del menú normal) -> Especial
(TRUE,  FALSE, '56789012E', 15); -- Daniela -> Normal


-- =====================================================================
-- PRUEBAS DE ERROR: CONSTRAINTS Y TRIGGERS (DESCOMENTAR PARA PROBAR)
-- =====================================================================

-- ---------------------------------------------------------------------
-- A) ERRORES EN CONSTRAINTS DE TABLAS
-- ---------------------------------------------------------------------

-- 1. PRIMARY KEY duplicada en alumnos (ERROR 1062: Duplicate entry)
-- INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES ('12345678A', 'Repetido', 'Test', 1, TRUE);

-- 2. CHECK curso fuera de rango 1..6 en alumnos (ERROR 4025: CONSTRAINT `alumnos.curso` failed)
-- INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES ('99999999Z', 'Carlos', 'Fuera Rango', 7, TRUE);

-- 3. NOT NULL en nombre de alumnos (ERROR 1048: Column 'nombre' cannot be null)
-- INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES ('88888888Y', NULL, 'Sin Nombre', 2, TRUE);

-- 4. UNIQUE (fecha, clase) en menus: ya existe menú 'Normal' el 2026-11-02 (ERROR 1062: Duplicate entry)
-- INSERT INTO menus (fecha, clase, postre, primerPlato, segundoPlato) VALUES ('2026-11-02', 'Normal', 'Pera', 'Sopa', 'Pollo');

-- 5. CHECK chk_platos_menu_segun_clase: menú 'Normal' con platos especiales rellenos (ERROR 4025)
-- INSERT INTO menus (fecha, clase, postre, primerPlato, segundoPlato, primerPlatoEspecial) VALUES ('2026-12-01', 'Normal', 'Pera', 'Sopa', 'Pollo', 'Puré');

-- 6. CHECK chk_platos_menu_segun_clase: menú 'Especial' sin platos especiales (ERROR 4025)
-- INSERT INTO menus (fecha, clase, postre, primerPlato, segundoPlato) VALUES ('2026-12-02', 'Especial', 'Pera', 'Sopa', 'Pollo');

-- 7. FOREIGN KEY fk_intolerancia_alumno: DNI inexistente en alumnos (ERROR 1452)
-- INSERT INTO intolerancias (lactosa, gluten, fructosa, dni) VALUES (TRUE, FALSE, FALSE, '00000000X');

-- 8. UNIQUE uq_dni_intolerancia: alumno que ya tiene registro en intolerancias (ERROR 1062)
-- INSERT INTO intolerancias (lactosa, gluten, fructosa, dni) VALUES (FALSE, TRUE, FALSE, '12345678A');

-- 9. FOREIGN KEY fk_alergia_alumno: DNI inexistente en alumnos (ERROR 1452)
-- INSERT INTO alergias (huevo, lacteos, frutosSecos, pescado, dni) VALUES (TRUE, FALSE, FALSE, FALSE, '00000000X');

-- 10. UNIQUE uq_dni_alergia: alumno que ya tiene registro en alergias (ERROR 1062)
-- INSERT INTO alergias (huevo, lacteos, frutosSecos, pescado, dni) VALUES (FALSE, FALSE, TRUE, FALSE, '39482015L');

-- 11. FOREIGN KEY fk_asistencia_alumno: DNI inexistente en alumnos (ERROR 1452)
-- INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES (TRUE, FALSE, '00000000X', 1);

-- 12. FOREIGN KEY fk_asistencia_menus: oidM inexistente en menus (ERROR 1452)
-- INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES (TRUE, FALSE, '56789012E', 999);

-- 13. UNIQUE uq_asistencia_alumno_menu: mismo alumno y mismo oidM exacto (ERROR 1062)
-- INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES (TRUE, FALSE, '56789012E', 3);


-- ---------------------------------------------------------------------
-- B) ERRORES EN TRIGGERS (t_validar_asistencia_insert y update)
-- ---------------------------------------------------------------------

-- 14. TRIGGER INSERT - Regla RN-05 (Alergia sin confirmar ficha):
-- Mateo ('23456789B', gluten + huevo) asiste el 20/11 (oidM=12 Especial) con fichaConfirmada = FALSE -> ERROR 45000
-- INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES (TRUE, FALSE, '23456789B', 12);

-- 15. TRIGGER INSERT - Regla RN-05 (Intolerancia sin confirmar ficha):
-- Álvaro ('67890123F', fructosa) asiste el 20/11 (oidM=12 Especial) con fichaConfirmada = FALSE -> ERROR 45000
-- INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES (TRUE, FALSE, '67890123F', 12);

-- 16. TRIGGER INSERT - Menú incorrecto para alumno con restricciones:
-- Mateo ('23456789B') con fichaConfirmada = TRUE pero asignado al menú Normal (oidM=11) -> ERROR 45000
-- INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES (TRUE, TRUE, '23456789B', 11);

-- 17. TRIGGER INSERT - Doble menú en la misma fecha:
-- Daniela ('56789012E') ya tiene menú Normal (oidM=3) el 16/11; se intenta darle el Especial (oidM=4) ese día -> ERROR 45000
-- INSERT INTO asistencias (asiste, fichaConfirmada, dni, oidM) VALUES (TRUE, FALSE, '56789012E', 4);

-- 18. TRIGGER UPDATE - Pasar lista (asiste FALSE -> TRUE) sin confirmar ficha:
-- Sofía ('34567890C', alérgica/intolerante) tenía asiste=FALSE y fichaConfirmada=FALSE el 16/11 (oidM=4); al marcar asiste=TRUE sin confirmar -> ERROR 45000
-- UPDATE asistencias SET asiste = TRUE WHERE dni = '34567890C' AND oidM = 4;

-- 19. TRIGGER UPDATE - Cambiar a menú Normal a un alumno con alergia que asiste:
-- Carmen ('39482015L') asiste el 02/11 con oidM=2 (Especial); se intenta cambiar su oidM a 1 (Normal) -> ERROR 45000
-- UPDATE asistencias SET oidM = 1 WHERE dni = '39482015L' AND oidM = 2;

-- 20. TRIGGER UPDATE - Cambiar la fecha/menú a un día donde el alumno ya tiene otro menú:
-- Daniela ('56789012E') asiste el 17/11 (oidM=5); se intenta cambiar al menú 4 (16/11, donde ya tiene el oidM=3) -> ERROR 45000
-- UPDATE asistencias SET oidM = 4 WHERE dni = '56789012E' AND oidM = 5;