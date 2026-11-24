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
OID_L SMALLINT AUTO_INCREMENT PRIMARY KEY, 
titulo VARCHAR(40),
editorial VARCHAR(40),
genero VARCHAR(30),
es_lectura_obligatoria BOOLEAN DEFAULT FALSE
);

CREATE TABLE ejemplares(
OID_E SMALLINT AUTO_INCREMENT PRIMARY KEY,
codigo INT UNIQUE,
estado_conservacion VARCHAR(40),
disponibilidad BOOLEAN,
OID_L SMALLINT,
FOREIGN KEY (OID_L) REFERENCES libros(OID_L) ON UPDATE CASCADE 
);

CREATE TABLE prestamos(
OID_P SMALLINT AUTO_INCREMENT PRIMARY KEY, 
fecha_inicio DATE DEFAULT SYSDATE(),
fecha_limite DATE,
fecha_devolucion DATE DEFAULT NULL,
dni VARCHAR (40),
OID_E SMALLINT,
FOREIGN KEY (dni) REFERENCES alumnos(dni),
FOREIGN KEY (OID_E) REFERENCES ejemplares(OID_E) ON UPDATE CASCADE,
CONSTRAINT fechasValidas CHECK (fecha_inicio < fecha_limite)
);


CREATE TABLE incidencias(
OID_I SMALLINT AUTO_INCREMENT PRIMARY KEY,
descripcion_desperfecto ENUM ('Páginas pintadas','Páginas arrancadas', 'Libro mojado'),
gravedad ENUM ('Leve', 'Media', 'Alta'),
OID_P SMALLINT,
FOREIGN KEY (OID_P) REFERENCES prestamos(OID_P) ON UPDATE CASCADE 
);

CREATE TABLE reservas(
OID_R SMALLINT AUTO_INCREMENT PRIMARY KEY,
fecha_solicitud DATE DEFAULT SYSDATE(), 
orden_prioridad INT, 
estado_reserva VARCHAR(30),
dni VARCHAR(40),
OID_L SMALLINT,
FOREIGN KEY (dni) REFERENCES alumnos(dni),
FOREIGN KEY (OID_L) REFERENCES libros(OID_L) ON UPDATE CASCADE,
CONSTRAINT ordenPositivo CHECK orden_prioridad >= 0
);

-- Poblamos las tablas 
-- Alumnos 
INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES ('7684943A','Pedro', 'Benitez Alonso', 3 ,True);
INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES ('4512987B', 'Marta', 'Sánchez López', 1, True);
INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES ('2938475C', 'Javier', 'Ruiz Morales', 4, False);
INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES ('8374651D', 'Elena', 'Navarro Torres', 2, True);
INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES ('5647382E', 'Hugo', 'Castro Romero', 3, False);
INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES ('1928374F', 'Sofía', 'Delgado Ortiz', 5, True);


-- Libros
INSERT INTO libros (OID_L, titulo, editorial, genero, es_lectura_obligatoria) VALUES (1, 'El Hobbit', 'Minotauro', 'Fantasía', True);
INSERT INTO libros (OID_L, titulo, editorial, genero, es_lectura_obligatoria) VALUES (2, 'La sombra del viento', 'Planeta', 'Misterio', False);
INSERT INTO libros (OID_L, titulo, editorial, genero, es_lectura_obligatoria) VALUES (3, 'Rayuela', 'Sudamericana', 'Novela', True);
INSERT INTO libros (OID_L, titulo, editorial, genero, es_lectura_obligatoria) VALUES (4, 'Crimen y castigo', 'Alianza', 'Clásico', True);
INSERT INTO libros (OID_L, titulo, editorial, genero, es_lectura_obligatoria) VALUES (5, 'Fundación', 'Debolsillo', 'Ciencia Ficción', False);
INSERT INTO libros (OID_L, titulo, editorial, genero, es_lectura_obligatoria) VALUES (6, 'Los juegos del hambre', 'Molino', 'Juvenil', FALSE);

-- Ejemplares
INSERT INTO ejemplares (codigo, estado_conservacion, disponibilidad, OID_L) VALUES (101, 'Excelente', True, 1);
INSERT INTO ejemplares (codigo, estado_conservacion, disponibilidad, OID_L) VALUES (102, 'Bueno', True, 1);
INSERT INTO ejemplares (codigo, estado_conservacion, disponibilidad, OID_L) VALUES (201, 'Regular', False, 2);
INSERT INTO ejemplares (codigo, estado_conservacion, disponibilidad, OID_L) VALUES (301, 'Deteriorado', False, 3);
INSERT INTO ejemplares (codigo, estado_conservacion, disponibilidad, OID_L) VALUES (401, 'Como nuevo', True, 4);
INSERT INTO ejemplares (codigo, estado_conservacion, disponibilidad, OID_L) VALUES (501, 'Bueno', True, 5);

-- Prestamos
INSERT INTO prestamos (OID_P, fecha_inicio, fecha_limite, fecha_devolucion, dni, OID_E) VALUES (1, '2026-05-01', '2026-05-15', '2026-05-10', '4512987B', 1);
INSERT INTO prestamos (OID_P, fecha_inicio, fecha_limite, fecha_devolucion, dni, OID_E) VALUES (2, '2026-05-02', '2026-05-16', NULL, '2938475C', 2);
INSERT INTO prestamos (OID_P, fecha_inicio, fecha_limite, fecha_devolucion, dni, OID_E) VALUES (3, '2026-05-04', '2026-05-18', '2026-05-15', '8374651D', 3);
INSERT INTO prestamos (OID_P, fecha_inicio, fecha_limite, fecha_devolucion, dni, OID_E) VALUES (4, '2026-05-05', '2026-05-19', NULL, '5647382E', 4);
INSERT INTO prestamos (OID_P, fecha_inicio, fecha_limite, fecha_devolucion, dni, OID_E) VALUES (5, '2026-05-06', '2026-05-20', '2026-05-19', '1928374F', 5);
INSERT INTO prestamos (OID_P, fecha_inicio, fecha_limite, fecha_devolucion, dni, OID_E) VALUES (6, '2026-05-08', '2026-05-22', NULL, '7684943A', 6);
 
-- Incidencias
INSERT INTO incidencias (descripcion_desperfecto, gravedad, OID_P) VALUES ('Páginas pintadas', 'Leve', 1);
INSERT INTO incidencias (descripcion_desperfecto, gravedad, OID_P) VALUES ('Libro mojado', 'Alta', 2);
INSERT INTO incidencias (descripcion_desperfecto, gravedad, OID_P) VALUES ('Páginas arrancadas', 'Media', 3);
INSERT INTO incidencias (descripcion_desperfecto, gravedad, OID_P) VALUES ('Páginas pintadas', 'Media', 4);
INSERT INTO incidencias (descripcion_desperfecto, gravedad, OID_P) VALUES ('Libro mojado', 'Alta', 5);
INSERT INTO incidencias (descripcion_desperfecto, gravedad, OID_P) VALUES ('Páginas arrancadas', 'Alta', 6);

-- Reservas
INSERT INTO reservas (OID_R, fecha_solicitud, orden_prioridad, estado_reserva, dni, OID_L) VALUES (1, '2026-05-01', 1, 'Completada', '4512987B', 1);
INSERT INTO reservas (OID_R, fecha_solicitud, orden_prioridad, estado_reserva, dni, OID_L) VALUES (2, '2026-05-03', 2, 'Pendiente', '2938475C', 2);
INSERT INTO reservas (OID_R, fecha_solicitud, orden_prioridad, estado_reserva, dni, OID_L) VALUES (3, '2026-05-05', 1, 'Cancelada', '8374651D', 3);
INSERT INTO reservas (OID_R, fecha_solicitud, orden_prioridad, estado_reserva, dni, OID_L) VALUES (4, '2026-05-06', 3, 'Pendiente', '5647382E', 4);
INSERT INTO reservas (OID_R, fecha_solicitud, orden_prioridad, estado_reserva, dni, OID_L) VALUES (5, '2026-05-08', 1, 'Completada', '1928374F', 5);
INSERT INTO reservas (OID_R, fecha_solicitud, orden_prioridad, estado_reserva, dni, OID_L) VALUES (6, '2026-05-15', 1, 'Completada', '7684943A', 6);










