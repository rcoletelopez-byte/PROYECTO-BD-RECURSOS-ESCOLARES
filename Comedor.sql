DROP TABLE IF EXISTS Alergia;
DROP TABLE IF EXISTS Intolerancia;
DROP TABLE IF EXISTS MenuEspecial;
DROP TABLE IF EXISTS MenuNormal;
DROP TABLE IF EXISTS AsistenciaDiaria;
DROP TABLE IF EXISTS MenuDiario;
DROP TABLE IF EXISTS Alumno;

CREATE TABLE Alumno
(	Nombre VARCHAR(50) NOT NULL,
	Apellidos VARCHAR(50) NOT NULL,
	dni CHAR(9) PRIMARY KEY,
	Curso TINYINT,
	Comedor BOOLEAN DEFAULT FALSE
);

CREATE TABLE MenuDiario
(	OID_MD SMALLINT PRIMARY KEY AUTO_INCREMENT,
	FechaHoy DATE DEFAULT SYSDATE(),
	Postre VARCHAR(50)
);

CREATE TABLE MenuNormal
(	OID_MN SMALLINT PRIMARY KEY AUTO_INCREMENT,
	Primer_plato VARCHAR(50),
	Segundo_plato VARCHAR(50),
	MenuDir SMALLINT,
	FOREIGN KEY (MenuDir) REFERENCES MenuDiario (OID_MD)
);

CREATE TABLE MenuEspecial
(	OID_ME SMALLINT PRIMARY KEY AUTO_INCREMENT,
	Primer_plato_especial VARCHAR(50),
	Segundo_plato_especial VARCHAR(50),
	MenuDir SMALLINT,
	FOREIGN KEY (MenuDir) REFERENCES MenuDiario (OID_MD)
);

CREATE TABLE AsistenciaDiaria
(	OID_AD SMALLINT PRIMARY KEY AUTO_INCREMENT,
	FechaHoy DATE DEFAULT SYSDATE(),
	Asiste BOOLEAN DEFAULT FALSE,
	dni CHAR(9),
	MenuDir SMALLINT,
	FOREIGN KEY (dni) REFERENCES Alumno (dni),
	FOREIGN KEY (MenuDir) REFERENCES MenuDiario (OID_MD)
);

CREATE TABLE Intolerancia
(	OID_IN SMALLINT PRIMARY KEY AUTO_INCREMENT,
	Lactosa BOOLEAN DEFAULT FALSE,
	Gluten BOOLEAN DEFAULT FALSE,
	Fructosa BOOLEAN DEFAULT FALSE,
	dni CHAR(9),
	FOREIGN KEY (dni) REFERENCES Alumno (dni)
);

CREATE TABLE Alergia
( 	OID_AL SMALLINT PRIMARY KEY AUTO_INCREMENT,
	Huevo BOOLEAN DEFAULT FALSE,
	Lacteos BOOLEAN DEFAULT FALSE,
	Frutos_secos BOOLEAN DEFAULT FALSE,
	Pescado BOOLEAN DEFAULT FALSE,
	dni CHAR(9),
	FOREIGN KEY (dni) REFERENCES Alumno (dni)
);





-- 1. Tablas padre (sin claves ajenas)
INSERT INTO Alumno (Nombre, Apellidos, dni, Curso, Comedor) VALUES
('Lucía', 'Gómez Pérez', '12345678A', 3, TRUE),
('Mateo', 'Ruiz Sánchez', '23456789B', 4, TRUE),
('Sofía', 'Martínez López', '34567890C', 2, TRUE),
('Hugo', 'Fernández Díaz', '45678901D', 5, FALSE);

INSERT INTO MenuDiario (FechaHoy, Postre) VALUES
('2026-11-16', 'Manzana'),
('2026-11-17', 'Yogur natural'),
('2026-11-18', 'Plátano'),
('2026-11-19', 'Mandarina');

-- 2. Tablas hijas (referencian a MenuDiario y Alumno)
INSERT INTO MenuNormal (Primer_plato, Segundo_plato, MenuDir) VALUES
('Lentejas estofadas', 'Pechuga de pollo a la plancha', 1),
('Macarrones con tomate', 'Merluza al horno', 2),
('Crema de calabacín', 'Tortilla de patatas', 3),
('Arroz a la cubana', 'Filete de ternera con ensalada', 4);

INSERT INTO MenuEspecial (Primer_plato_especial, Segundo_plato_especial, MenuDir) VALUES
('Lentejas con verduras sin gluten', 'Pechuga de pollo a la plancha', 1),
('Macarrones sin gluten con tomate', 'Pechuga de pavo asada', 2),
('Puré de patata y zanahoria', 'Filete de ternera a la plancha', 3);

INSERT INTO AsistenciaDiaria (FechaHoy, Asiste, dni, MenuDir) VALUES
('2026-11-16', TRUE, '12345678A', 1),
('2026-11-16', TRUE, '23456789B', 1),
('2026-11-16', FALSE, '34567890C', 1),
('2026-11-17', TRUE, '12345678A', 2);

INSERT INTO Intolerancia (Lactosa, Gluten, Fructosa, dni) VALUES
(TRUE, FALSE, FALSE, '12345678A'),
(FALSE, TRUE, FALSE, '23456789B'),
(TRUE, TRUE, FALSE, '34567890C');

INSERT INTO Alergia (Huevo, Lacteos, Frutos_secos, Pescado, dni) VALUES
(TRUE, FALSE, FALSE, FALSE, '23456789B'),
(FALSE, FALSE, TRUE, TRUE, '34567890C'),
(FALSE, TRUE, FALSE, FALSE, '45678901D');
