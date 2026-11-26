
DROP TABLE IF EXISTS asistencias;
DROP TABLE IF EXISTS alergias;
DROP TABLE IF EXISTS intolerancias;
DROP TABLE IF EXISTS menus;
DROP TABLE if EXISTS alumnos;

DROP PROCEDURE IF EXISTS pFichaLeida;

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
CREATE PROCEDURE pFichaLeida(newAsiste BOOLEAN, newFichaconfirmada BOOLEAN, newDni CHAR(9))
	BEGIN 
    IF newAsiste = TRUE AND newFichaconfirmada = FALSE THEN
        IF EXISTS (
            SELECT 1 FROM alergias
            WHERE dni = newDni AND (huevo = TRUE OR lacteos = TRUE OR frutosSecos = TRUE OR pescado = TRUE)
        ) OR EXISTS (
            SELECT 1 FROM intolerancias 
            WHERE dni = newDni AND (lactosa = TRUE OR gluten = TRUE OR fructosa = TRUE)
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error RN-05: Debe confirmar la lectura de la ficha de alergias/intolerancias antes de validar la asistencia.';
        END IF;
    END IF;
END//

DELIMITER ;



DELIMITER //

-- Validación al insertar una nueva asistencia
CREATE TRIGGER t_validar_asistencia_insert
BEFORE INSERT ON asistencias
FOR EACH ROW
BEGIN
	CALL pFichaLeida(NEW.asiste, NEW.fichaConfirmada, NEW.dni);
END//

-- Validación al actualizar una asistencia existente (ej. paso de lista)
CREATE TRIGGER t_validar_asistencia_update
BEFORE UPDATE ON asistencias
FOR EACH ROW
BEGIN
    CALL pFichaLeida(NEW.asiste, NEW.fichaConfirmada, NEW.dni);
END//

DELIMITER ;
