-- ============================================================
-- 05_queries.sql — labeled queries demonstrating joins,
-- subqueries, aggregation, views and index use.
-- Each query starts with a "-- [Qn] title" marker.
-- ============================================================
USE hotel_pbl;

-- [Q1] INNER JOIN (4 tables): every reservation with guest, room, type and rate
SELECT res.reservation_id, g.full_name, r.room_number, rt.type_name,
       rp.plan_name, rp.nightly_rate, res.planned_check_in, res.planned_check_out,
       res.reservation_status
FROM reservation res
JOIN guest g       ON res.guest_id = g.guest_id
JOIN room r        ON res.room_id = r.room_id
JOIN room_type rt  ON r.type_id = rt.type_id
JOIN rate_plan rp  ON res.rate_plan_id = rp.rate_plan_id
ORDER BY res.planned_check_in;

-- [Q2] LEFT JOIN: every room with its current guest (NULL when vacant)
SELECT r.room_number, rt.type_name, r.status, g.full_name AS current_guest
FROM room r
JOIN room_type rt ON r.type_id = rt.type_id
LEFT JOIN reservation res ON res.room_id = r.room_id AND res.reservation_status = 'checked_in'
LEFT JOIN guest g ON res.guest_id = g.guest_id
ORDER BY r.room_number;

-- [Q3] JOIN + aggregate: invoice breakdown per stay (room charge vs services)
SELECT s.stay_id, g.full_name,
       DATEDIFF(DATE(s.actual_check_out), DATE(s.actual_check_in)) AS nights,
       inv.subtotal, inv.tax, inv.total, inv.status
FROM invoice inv
JOIN stay s ON inv.stay_id = s.stay_id
JOIN reservation res ON s.reservation_id = res.reservation_id
JOIN guest g ON res.guest_id = g.guest_id;

-- [Q4] NESTED SUBQUERY (NOT IN): rooms free for a requested date range
SELECT r.room_number, rt.type_name
FROM room r
JOIN room_type rt ON r.type_id = rt.type_id
WHERE r.status <> 'maintenance'
  AND r.room_id NOT IN (
      SELECT room_id FROM reservation
      WHERE reservation_status NOT IN ('cancelled','no_show')
        AND '2026-10-11' < planned_check_out
        AND '2026-10-12' > planned_check_in)
ORDER BY r.room_number;

-- [Q5] CORRELATED SUBQUERY: stays whose service spend is above the average per stay
SELECT sc.stay_id, SUM(sc.amount) AS service_spend
FROM service_charge sc
GROUP BY sc.stay_id
HAVING SUM(sc.amount) > (SELECT AVG(t.spend)
                         FROM (SELECT SUM(amount) AS spend
                               FROM service_charge GROUP BY stay_id) t);

-- [Q6] GROUP BY: reservations and average nightly rate per room type
SELECT rt.type_name, COUNT(res.reservation_id) AS reservations,
       ROUND(AVG(rp.nightly_rate), 2) AS avg_nightly_rate
FROM room_type rt
LEFT JOIN room r ON r.type_id = rt.type_id
LEFT JOIN reservation res ON res.room_id = r.room_id
LEFT JOIN rate_plan rp ON res.rate_plan_id = rp.rate_plan_id
GROUP BY rt.type_name;

-- [Q7] GROUP BY + HAVING: housekeeping workload per staff member
SELECT st.full_name, st.role, COUNT(ht.task_id) AS tasks,
       SUM(ht.task_status = 'pending') AS pending
FROM staff st
LEFT JOIN housekeeping_task ht ON ht.assigned_to = st.staff_id
GROUP BY st.staff_id, st.full_name, st.role
HAVING COUNT(ht.task_id) >= 1;

-- [Q8] AGGREGATE: total revenue collected and total service revenue
SELECT (SELECT COALESCE(SUM(amount),0) FROM payment WHERE payment_status='success') AS revenue_collected,
       (SELECT COALESCE(SUM(amount),0) FROM service_charge) AS service_revenue;

-- [Q9] SUBQUERY RATIO: cancellation rate
SELECT ROUND(100 * (SELECT COUNT(*) FROM reservation
                    WHERE reservation_status IN ('cancelled','no_show'))
                 / (SELECT COUNT(*) FROM reservation), 2) AS cancellation_pct;

-- [Q10] VIEW: current occupancy report
SELECT * FROM v_current_occupancy;

-- [Q11] VIEW: guest history with spend
SELECT * FROM v_guest_history;

-- [Q12] VIEW: housekeeping status
SELECT * FROM v_housekeeping_status;

-- [Q13] INDEX USE: the availability lookup uses idx_reservation_dates
EXPLAIN SELECT reservation_id FROM reservation
WHERE room_id = 3 AND planned_check_in < '2026-10-01' AND planned_check_out > '2026-09-01';
