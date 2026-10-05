-- ============================================================
-- 04_views_reports.sql — reporting views: occupancy, vacancy,
-- cancellations, housekeeping status, guest history, revenue
-- ============================================================
USE hotel_pbl;

-- Current occupancy: which rooms are occupied right now, by whom
CREATE OR REPLACE VIEW v_current_occupancy AS
SELECT r.room_id, r.room_number, rt.type_name, g.full_name AS guest_name,
       s.actual_check_in, res.planned_check_out
FROM stay s
JOIN reservation res ON s.reservation_id = res.reservation_id
JOIN room r ON res.room_id = r.room_id
JOIN room_type rt ON r.type_id = rt.type_id
JOIN guest g ON res.guest_id = g.guest_id
WHERE s.actual_check_out IS NULL;

-- Vacant rooms right now (not currently occupied, not under maintenance)
CREATE OR REPLACE VIEW v_vacant_rooms AS
SELECT r.room_id, r.room_number, rt.type_name, rt.capacity
FROM room r
JOIN room_type rt ON r.type_id = rt.type_id
WHERE r.status = 'available'
  AND r.room_id NOT IN (SELECT room_id FROM reservation WHERE reservation_status = 'checked_in');

-- Cancelled / no-show reservations
CREATE OR REPLACE VIEW v_cancellations AS
SELECT res.reservation_id, g.full_name AS guest_name, r.room_number,
       res.planned_check_in, res.planned_check_out, res.reservation_status
FROM reservation res
JOIN guest g ON res.guest_id = g.guest_id
JOIN room r ON res.room_id = r.room_id
WHERE res.reservation_status IN ('cancelled','no_show');

-- Housekeeping status across all rooms
CREATE OR REPLACE VIEW v_housekeeping_status AS
SELECT ht.task_id, r.room_number, ht.task_type, st.full_name AS assigned_staff,
       ht.task_status, ht.scheduled_at, ht.completed_at
FROM housekeeping_task ht
JOIN room r ON ht.room_id = r.room_id
LEFT JOIN staff st ON ht.assigned_to = st.staff_id
ORDER BY ht.scheduled_at;

-- Guest stay history (past and present stays, with spend so far)
CREATE OR REPLACE VIEW v_guest_history AS
SELECT g.guest_id, g.full_name, res.reservation_id, r.room_number,
       s.actual_check_in, s.actual_check_out,
       COALESCE((SELECT SUM(sc.amount) FROM service_charge sc WHERE sc.stay_id = s.stay_id), 0) AS service_spend,
       COALESCE((SELECT inv.total FROM invoice inv WHERE inv.stay_id = s.stay_id), 0) AS invoice_total
FROM guest g
JOIN reservation res ON g.guest_id = res.guest_id
JOIN room r ON res.room_id = r.room_id
JOIN stay s ON s.reservation_id = res.reservation_id
ORDER BY s.actual_check_in DESC;

-- Service revenue per stay
CREATE OR REPLACE VIEW v_service_revenue AS
SELECT s.stay_id, g.full_name AS guest_name, SUM(sc.amount) AS total_service_revenue
FROM service_charge sc
JOIN stay s ON sc.stay_id = s.stay_id
JOIN reservation res ON s.reservation_id = res.reservation_id
JOIN guest g ON res.guest_id = g.guest_id
GROUP BY s.stay_id, g.full_name;

-- Total revenue (room charges + service charges) by month, from paid invoices
CREATE OR REPLACE VIEW v_total_revenue AS
SELECT DATE_FORMAT(p.payment_date, '%Y-%m') AS month,
       SUM(p.amount) AS revenue_collected
FROM payment p
WHERE p.payment_status = 'success'
GROUP BY DATE_FORMAT(p.payment_date, '%Y-%m')
ORDER BY month;

-- Occupancy rate (nested query: occupied rooms vs total rooms)
CREATE OR REPLACE VIEW v_occupancy_rate AS
SELECT
    (SELECT COUNT(*) FROM reservation WHERE reservation_status = 'checked_in') AS occupied_rooms,
    (SELECT COUNT(*) FROM room) AS total_rooms,
    ROUND(
        (SELECT COUNT(*) FROM reservation WHERE reservation_status = 'checked_in') * 100.0
        / (SELECT COUNT(*) FROM room), 2
    ) AS occupancy_pct;
