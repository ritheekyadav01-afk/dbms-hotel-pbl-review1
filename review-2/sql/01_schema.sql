-- ============================================================
-- Hotel Reservation and Guest Services Management System
-- Project 12 — DBMS PBL
-- 01_schema.sql — DDL: tables, keys, constraints
-- ============================================================

DROP DATABASE IF EXISTS hotel_pbl;
CREATE DATABASE hotel_pbl CHARACTER SET utf8mb4;
USE hotel_pbl;

-- ---------- ROOM_TYPE ----------
CREATE TABLE room_type (
    type_id       INT AUTO_INCREMENT PRIMARY KEY,
    type_name     VARCHAR(50) NOT NULL UNIQUE,
    capacity      INT NOT NULL,
    description   VARCHAR(255),
    CONSTRAINT chk_room_type_capacity CHECK (capacity > 0)
);

-- ---------- ROOM ----------
CREATE TABLE room (
    room_id       INT AUTO_INCREMENT PRIMARY KEY,
    room_number   VARCHAR(10) NOT NULL UNIQUE,
    type_id       INT NOT NULL,
    status        ENUM('available','occupied','maintenance','cleaning') NOT NULL DEFAULT 'available',
    FOREIGN KEY (type_id) REFERENCES room_type(type_id)
);

-- ---------- RATE_PLAN ----------
CREATE TABLE rate_plan (
    rate_plan_id  INT AUTO_INCREMENT PRIMARY KEY,
    type_id       INT NOT NULL,
    plan_name     VARCHAR(50) NOT NULL,
    nightly_rate  DECIMAL(10,2) NOT NULL,
    description   VARCHAR(255),
    FOREIGN KEY (type_id) REFERENCES room_type(type_id),
    CONSTRAINT chk_rate_nonneg CHECK (nightly_rate >= 0)
);

-- ---------- GUEST ----------
CREATE TABLE guest (
    guest_id      INT AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    phone         VARCHAR(20)
);

-- ---------- RESERVATION ----------
CREATE TABLE reservation (
    reservation_id     INT AUTO_INCREMENT PRIMARY KEY,
    guest_id           INT NOT NULL,
    room_id            INT NOT NULL,
    rate_plan_id       INT NOT NULL,
    reservation_status ENUM('booked','checked_in','completed','cancelled','no_show') NOT NULL DEFAULT 'booked',
    planned_check_in   DATE NOT NULL,
    planned_check_out  DATE NOT NULL,
    adults             INT NOT NULL DEFAULT 1,
    children           INT NOT NULL DEFAULT 0,
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (guest_id) REFERENCES guest(guest_id),
    FOREIGN KEY (room_id) REFERENCES room(room_id),
    FOREIGN KEY (rate_plan_id) REFERENCES rate_plan(rate_plan_id),
    CONSTRAINT chk_dates CHECK (planned_check_out > planned_check_in),
    CONSTRAINT chk_occupants CHECK (adults >= 1 AND children >= 0)
);

-- ---------- STAY ----------
CREATE TABLE stay (
    stay_id          INT AUTO_INCREMENT PRIMARY KEY,
    reservation_id    INT NOT NULL UNIQUE,
    actual_check_in   DATETIME NOT NULL,
    actual_check_out  DATETIME NULL,
    FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id),
    CONSTRAINT chk_stay_dates CHECK (actual_check_out IS NULL OR actual_check_out > actual_check_in)
);

-- ---------- STAFF (lightweight — assigned_to in housekeeping_task) ----------
CREATE TABLE staff (
    staff_id      INT AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    role          VARCHAR(50) NOT NULL
);

-- ---------- HOUSEKEEPING_TASK ----------
CREATE TABLE housekeeping_task (
    task_id       INT AUTO_INCREMENT PRIMARY KEY,
    room_id       INT NOT NULL,
    stay_id       INT NULL,
    task_type     VARCHAR(50) NOT NULL,
    assigned_to   INT NULL,
    task_status   ENUM('pending','in_progress','done') NOT NULL DEFAULT 'pending',
    scheduled_at  DATETIME NOT NULL,
    completed_at  DATETIME NULL,
    FOREIGN KEY (room_id) REFERENCES room(room_id),
    FOREIGN KEY (stay_id) REFERENCES stay(stay_id),
    FOREIGN KEY (assigned_to) REFERENCES staff(staff_id)
);

-- ---------- SERVICE_REQUEST ----------
CREATE TABLE service_request (
    service_request_id  INT AUTO_INCREMENT PRIMARY KEY,
    stay_id              INT NOT NULL,
    service_name         VARCHAR(100) NOT NULL,
    requested_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
    status                ENUM('requested','fulfilled','cancelled') NOT NULL DEFAULT 'requested',
    FOREIGN KEY (stay_id) REFERENCES stay(stay_id)
);

-- ---------- SERVICE_CHARGE ----------
CREATE TABLE service_charge (
    charge_id            INT AUTO_INCREMENT PRIMARY KEY,
    stay_id              INT NOT NULL,
    service_request_id   INT NULL,
    description           VARCHAR(255),
    amount                DECIMAL(10,2) NOT NULL,
    charged_at            DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stay_id) REFERENCES stay(stay_id),
    FOREIGN KEY (service_request_id) REFERENCES service_request(service_request_id),
    CONSTRAINT chk_charge_nonneg CHECK (amount >= 0)
);

-- ---------- INVOICE ----------
CREATE TABLE invoice (
    invoice_id    INT AUTO_INCREMENT PRIMARY KEY,
    stay_id       INT NOT NULL UNIQUE,
    invoice_date  DATE DEFAULT (CURRENT_DATE),
    subtotal      DECIMAL(10,2) NOT NULL DEFAULT 0,
    tax           DECIMAL(10,2) NOT NULL DEFAULT 0,
    total         DECIMAL(10,2) NOT NULL DEFAULT 0,
    status        ENUM('open','paid','partially_paid') NOT NULL DEFAULT 'open',
    FOREIGN KEY (stay_id) REFERENCES stay(stay_id),
    CONSTRAINT chk_invoice_nonneg CHECK (subtotal >= 0 AND tax >= 0 AND total >= 0)
);

-- ---------- PAYMENT ----------
CREATE TABLE payment (
    payment_id      INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id      INT NOT NULL,
    payment_date    DATETIME DEFAULT CURRENT_TIMESTAMP,
    amount          DECIMAL(10,2) NOT NULL,
    payment_method  ENUM('cash','card','upi','netbanking') NOT NULL,
    payment_status  ENUM('success','failed','refunded') NOT NULL DEFAULT 'success',
    FOREIGN KEY (invoice_id) REFERENCES invoice(invoice_id),
    CONSTRAINT chk_payment_nonneg CHECK (amount >= 0)
);

-- Helpful indexes on frequently-searched columns
CREATE INDEX idx_reservation_dates ON reservation(room_id, planned_check_in, planned_check_out);
CREATE INDEX idx_stay_actual ON stay(actual_check_in, actual_check_out);
CREATE INDEX idx_guest_name ON guest(full_name);
