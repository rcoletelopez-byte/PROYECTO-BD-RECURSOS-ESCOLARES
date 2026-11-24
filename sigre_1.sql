-- =====================================================================
-- SIGRE · Sistema de Gestión Integral de Recursos Escolares
-- CEIP Virgen del Rocío (Camas, Sevilla) · curso 2026/27
-- Script base. Ejecutar PRIMERO (después: biblioteca, comedor, inventario).
-- Crea la base de datos única (RG-01) y las tablas compartidas por los
-- tres módulos: alumnos y avisos.
-- Convención de nombres: camelCase (tablas, columnas, triggers, vistas).
-- Requiere MySQL 8.0.16 o superior (CHECK se aplica desde esa versión).
-- =====================================================================
SET NAMES utf8mb4;

DROP DATABASE IF EXISTS sigre;
CREATE DATABASE sigre CHARACTER SET utf8mb4;
USE sigre;

-- RI-01.1 Datos del alumnado (compartida por biblioteca y comedor)
CREATE TABLE alumnos (
    dni CHAR(9) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellidos VARCHAR(50) NOT NULL,
    curso TINYINT NOT NULL,
    comedor BOOLEAN NOT NULL DEFAULT FALSE,
    CHECK (curso BETWEEN 1 AND 6)
);

-- RG-03 Control de avisos y alertas. La rellenan los triggers de los
-- tres módulos; el panel de Dirección / Biblioteca solo la consulta.
CREATE TABLE avisos (
    oidAv INT PRIMARY KEY AUTO_INCREMENT,
    fecha DATE NOT NULL,
    tipo ENUM('Retraso', 'ReservaDisponible', 'StockBajo', 'SinStock') NOT NULL,
    panel ENUM('Biblioteca', 'Direccion') NOT NULL,
    mensaje VARCHAR(200) NOT NULL,
    leido BOOLEAN NOT NULL DEFAULT FALSE
);

-- Alumnos: los de los escenarios 1-6 del PDF (con sus DNI) y algunos más
-- para cubrir los cursos 1 a 6 y todos los casos de comedor.
INSERT INTO alumnos (dni, nombre, apellidos, curso, comedor) VALUES
('77975237R', 'Juan',     'Martín García',        1, TRUE),   -- escenario 1
('72940183F', 'Lucía',    'Pérez Ruiz',           2, TRUE),   -- escenario 2
('51234876P', 'Pablo',    'Gil Soto',             2, FALSE),  -- escenario 2
('40679852K', 'Sara',     'Gómez Díaz',           2, FALSE),  -- escenario 3
('39482015L', 'Carmen',   'Ortiz Vega',           1, TRUE),   -- escenario 5
('89635244G', 'Rafael',   'Navarro Villalobos',   3, FALSE),  -- escenario 6
('66698510S', 'Nuria',    'Campos Rey',           4, FALSE),  -- escenario 6
('12345678A', 'Lucía',    'Gómez Pérez',          3, TRUE),
('23456789B', 'Mateo',    'Ruiz Sánchez',         4, TRUE),
('34567890C', 'Sofía',    'Martínez López',       2, TRUE),
('45678901D', 'Hugo',     'Fernández Díaz',       5, FALSE),  -- comensal ocasional
('56789012E', 'Daniela',  'Romero Cano',          6, TRUE),
('67890123F', 'Álvaro',   'Molina Vega',          5, TRUE),
('78901234G', 'Irene',    'Castillo Ríos',        6, FALSE);
