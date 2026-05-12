-- ==========================================================
-- Group 3 - Campus Resource Manager - Database Schema
-- CMP6210 Cloud Computing - D2 Deliverable
-- ==========================================================
-- Run this against RDS from your EC2 instance:
--   mysql -h <rds-endpoint> -u admin -p < schema.sql
-- ==========================================================

CREATE DATABASE IF NOT EXISTS myprojectdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE myprojectdb;

-- ==========================================================
-- Services / Resources available for booking
-- ==========================================================
DROP TABLE IF EXISTS services;
CREATE TABLE services (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    description     VARCHAR(255) NOT NULL,
    image_filename  VARCHAR(100) NOT NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================================
-- Appointments / Bookings
-- ==========================================================
DROP TABLE IF EXISTS appointments;
CREATE TABLE appointments (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    email        VARCHAR(150) NOT NULL,
    service_id   INT NOT NULL,
    appt_date    DATE NOT NULL,
    appt_time    TIME NOT NULL,
    notes        VARCHAR(500) DEFAULT NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_appt_date (appt_date),
    INDEX idx_created (created_at),
    FOREIGN KEY (service_id) REFERENCES services(id)
);
