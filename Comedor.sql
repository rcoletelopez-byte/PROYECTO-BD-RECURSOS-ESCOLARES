DROP TABLE IF EXISTS Asistencia;
DROP TABLE IF EXISTS Alergia;
DROP TABLE IF EXISTS Intolerancia;
DROP TABLE IF EXISTS Menus;
DROP TABLE IF EXISTS alumno;

CREATE TABLE Alumno
(	Nombre VARCHAR(50) NOT NULL,
	Apellidos VARCHAR(50) NOT NULL,
	dni CHAR(9) PRIMARY KEY,
	Curso TINYINT,
	Comedor BOOLEAN DEFAULT FALSE,
	CONSTRAINT uq_dni_alumno UNIQUE (dni),
	CONSTRAINT chk_curso_alumno_psotivo CHECK (Curso > 0)
);

CREATE TABLE Menus
(	OID_MD SMALLINT PRIMARY KEY AUTO_INCREMENT,
	FechaHoy DATE NOT NULL DEFAULT SYSDATE(),
	Postre VARCHAR(50),
	Clase TINYINT,
	primer_plato VARCHAR(50) DEFAULT NULL,
	segundo_plato VARCHAR(50) DEFAULT NULL,
	primer_plato_especial VARCHAR(50) DEFAULT NULL,
	segundo_plato_especial VARCHAR(50) DEFAULT NULL,
	CONSTRAINT chk_menus_clase_positivo CHECK (Clase > 0),
	CONSTRAINT uq_menu_clase UNIQUE (FechaHoy, Clase)
	
);

CREATE TABLE Asistencia
(	OID_AD SMALLINT PRIMARY KEY AUTO_INCREMENT,
	FechaHoy DATE DEFAULT SYSDATE(),
	Asiste BOOLEAN DEFAULT FALSE,
	FichaLeida BOOLEAN NOT NULL DEFAULT FALSE,
	dni CHAR(9) NOT NULL,
	OID_Menu SMALLINT NOT NULL,
	FOREIGN KEY (dni) REFERENCES Alumno (dni),
	FOREIGN KEY (OID_Menu) REFERENCES Menus (OID_MD),
	UNIQUE (dni, OID_Menu)
);

CREATE TABLE Intolerancia
(	OID_IN SMALLINT PRIMARY KEY AUTO_INCREMENT,
	Lactosa BOOLEAN DEFAULT FALSE,
	Gluten BOOLEAN DEFAULT FALSE,
	Fructosa BOOLEAN DEFAULT FALSE,
	dni CHAR(9) NOT NULL,
	CONSTRAINT fk_intolerancia_alumno FOREIGN KEY (dni) 
   	REFERENCES Alumno (dni) ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT uq_dni_intolerancia UNIQUE (dni)
);

CREATE TABLE Alergia
( 	OID_AL SMALLINT PRIMARY KEY AUTO_INCREMENT,
	Huevo BOOLEAN DEFAULT FALSE,
	Lacteos BOOLEAN DEFAULT FALSE,
	Frutos_secos BOOLEAN DEFAULT FALSE,
	Pescado BOOLEAN DEFAULT FALSE,
	dni CHAR(9),
	CONSTRAINT fk_alergia_alumno FOREIGN KEY (dni)
   	REFERENCES Alumno (dni) ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT uq_dni_alergia UNIQUE (dni)
);


DELIMITER //

-- Validación al insertar una nueva asistencia
CREATE TRIGGER trg_rn05_validar_asistencia_insert
BEFORE INSERT ON Asistencia
FOR EACH ROW
BEGIN
    IF NEW.Asiste = TRUE AND NEW.FichaLeida = FALSE THEN
        IF EXISTS (
            SELECT 1 FROM Alergia 
            WHERE dni = NEW.dni AND (Huevo = TRUE OR Lacteos = TRUE OR Frutos_secos = TRUE OR Pescado = TRUE)
        ) OR EXISTS (
            SELECT 1 FROM Intolerancia 
            WHERE dni = NEW.dni AND (Lactosa = TRUE OR Gluten = TRUE OR Fructosa = TRUE)
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error RN-05: Debe confirmar la lectura de la ficha de alergias/intolerancias antes de validar la asistencia.';
        END IF;
    END IF;
END//

-- Validación al actualizar una asistencia existente (ej. paso de lista)
CREATE TRIGGER trg_rn05_validar_asistencia_update
BEFORE UPDATE ON Asistencia
FOR EACH ROW
BEGIN
    IF NEW.Asiste = TRUE AND NEW.FichaLeida = FALSE THEN
        IF EXISTS (
            SELECT 1 FROM Alergia 
            WHERE dni = NEW.dni AND (Huevo = TRUE OR Lacteos = TRUE OR Frutos_secos = TRUE OR Pescado = TRUE)
        ) OR EXISTS (
            SELECT 1 FROM Intolerancia 
            WHERE dni = NEW.dni AND (Lactosa = TRUE OR Gluten = TRUE OR Fructosa = TRUE)
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error RN-05: Debe confirmar la lectura de la ficha de alergias/intolerancias antes de validar la asistencia.';
        END IF;
    END IF;
END//

DELIMITER ;






-- ============================================================================
-- 1. ALUMNOS (6 perfiles que cubren todos los escenarios fijos, ocasionales y restricciones)
-- ============================================================================
INSERT INTO Alumno (Nombre, Apellidos, dni, Curso, Comedor) VALUES
-- Fijo (Comedor=TRUE) SIN alergias ni intolerancias (para consultar "comensales sin restricciones")
('Ana', 'Gómez Pérez', '11111111A', 1, TRUE),

-- Fijo (Comedor=TRUE) SOLO con alergia (Escenario 5: Huevo y Lácteos, sin intolerancia)
('Luis', 'Martínez Ruiz', '22222222B', 2, TRUE),

-- Fijo (Comedor=TRUE) SOLO con intolerancia (Gluten y Lactosa, sin alergia)
('Carla', 'López Sanz', '33333333C', 3, TRUE),

-- Fijo (Comedor=TRUE) con AMBAS (varias marcas a TRUE en alergia e intolerancia)
('Diego', 'Fernández Gil', '44444444D', 1, TRUE),

-- Fijo (Comedor=TRUE) que faltará un día (Asiste=FALSE) y otro día no tendrá registro
('Elena', 'Torres Vega', '55555555E', 2, TRUE),

-- Ocasional (Comedor=FALSE) que asiste un día puntual
('Marco', 'Ruiz Diaz', '66666666F', 3, FALSE);


-- ============================================================================
-- 2. INTOLERANCIAS (Asociadas a Carla y Diego)
-- ============================================================================
INSERT INTO Intolerancia (Lactosa, Gluten, Fructosa, dni) VALUES
(TRUE, TRUE, FALSE, '33333333C'), -- Carla: solo intolerancias
(TRUE, FALSE, TRUE, '44444444D'); -- Diego: intolerancias + alergias


-- ============================================================================
-- 3. ALERGIAS (Asociadas a Luis y Diego)
-- ============================================================================
INSERT INTO Alergia (Huevo, Lacteos, Frutos_secos, Pescado, dni) VALUES
(TRUE, TRUE, FALSE, FALSE, '22222222B'), -- Luis: Escenario 5 (Huevo y Lácteos)
(FALSE, TRUE, TRUE, TRUE, '44444444D');  -- Diego: varias marcas a TRUE + intolerancias


-- ============================================================================
-- 4. MENÚS (Semana completa del lunes 16/11/2026 al viernes 20/11/2026)
-- ============================================================================
-- OID_MD = 1 (Lunes 16/11): Cubre menú sin gluten
INSERT INTO Menus (FechaHoy, Postre, Clase, primer_plato, segundo_plato, primer_plato_especial, segundo_plato_especial) VALUES
('2026-11-16', 'Manzana', 1, 'Macarrones con tomate', 'Filete de pollo', 'Macarrones sin gluten', 'Filete de pollo a la plancha'),

-- OID_MD = 2 (Martes 17/11): Cubre menú sin huevo ni lácteos (Escenario 5 para Luis)
('2026-11-17', 'Plátano', 2, 'Crema de calabacín con queso', 'Tortilla de patatas', 'Crema de calabacín sin lácteos', 'Patatas panaderas con pavo (sin huevo)'),

-- OID_MD = 3 (Miércoles 18/11): Cubre menú sin frutos secos ni pescado
('2026-11-18', 'Yogur', 3, 'Ensalada con nueces', 'Merluza al horno', 'Ensalada mixta sin frutos secos', 'Pechuga de pavo a la plancha (sin pescado)'),

-- OID_MD = 4 (Jueves 19/11): Adrede SIN menú especial (NULL en platos especiales)
('2026-11-19', 'Pera', 1, 'Lentejas estofadas', 'Lomo adobado', NULL, NULL),

-- OID_MD = 5 (Viernes 20/11): Cierre de semana (viernes) para probar "menú de la semana" (RC-04.3)
('2026-11-20', 'Naranja', 2, 'Arroz a la cubana', 'Albóndigas en salsa', 'Arroz blanco con tomate (sin huevo)', 'Albóndigas sin gluten ni lácteos');


-- ============================================================================
-- 5. ASISTENCIAS (Cubre todos los casos de asistencia, faltas y días completos)
-- ============================================================================
INSERT INTO Asistencia (FechaHoy, Asiste, dni, OID_Menu) VALUES
-- LUNES 16/11/2026 (Menú 1 - Sin gluten):
('2026-11-16', TRUE, '11111111A', 1),  -- Ana (fija sin restricciones) asiste
('2026-11-16', TRUE, '33333333C', 1),  -- Carla (celíaca) asiste y aprovecha menú sin gluten
('2026-11-16', FALSE, '55555555E', 1), -- Elena (fija) falta este día (Asiste = FALSE)

-- MARTES 17/11/2026 (Menú 2 - Sin huevo y sin lácteos - Escenario 5):
('2026-11-17', TRUE, '22222222B', 2),  -- Luis (alergia huevo y lácteos) ligado al menú especial 2
('2026-11-17', TRUE, '11111111A', 2),  -- Ana asiste
-- Nota: Elena ('55555555E') NO tiene registro este día (caso: alumno fijo sin registro ese día)

-- MIÉRCOLES 18/11/2026 (Menú 3 - Sin frutos secos ni pescado):
('2026-11-18', TRUE, '44444444D', 3),  -- Diego (alergia frutos secos/pescado + intolerancias)
('2026-11-18', TRUE, '66666666F', 3),  -- Marco (Comedor = FALSE) asiste este día puntual

-- JUEVES 19/11/2026 (Menú 4 - Sin menú especial):
('2026-11-19', TRUE, '11111111A', 4),  -- Ana (sin restricciones) asiste al menú normal
('2026-11-19', TRUE, '55555555E', 4),  -- Elena asiste

-- VIERNES 20/11/2026 (Menú 5 - Fin de semana escolar):
('2026-11-20', TRUE, '11111111A', 5),
('2026-11-20', TRUE, '22222222B', 5),
('2026-11-20', TRUE, '33333333C', 5),
('2026-11-20', TRUE, '44444444D', 5),
('2026-11-20', TRUE, '55555555E', 5);