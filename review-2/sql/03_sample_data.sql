-- ============================================================
-- 03_sample_data.sql — realistic sample data for demo & testing
-- ============================================================
USE hotel_pbl;

-- Room types
INSERT INTO room_type (type_name, capacity, description) VALUES
('Standard', 2, 'Queen bed, city view'),
('Deluxe', 3, 'King bed, balcony'),
('Suite', 4, 'Separate living area, premium amenities');

-- Rooms
INSERT INTO room (room_number, type_id, status) VALUES
('101', 1, 'available'),
('102', 1, 'available'),
('103', 1, 'occupied'),
('201', 2, 'available'),
('202', 2, 'available'),
('301', 3, 'available'),
('302', 3, 'maintenance');

-- Rate plans
INSERT INTO rate_plan (type_id, plan_name, nightly_rate, description) VALUES
(1, 'Standard - Flexible', 2500.00, 'Free cancellation up to 24h'),
(1, 'Standard - Saver', 2100.00, 'Non-refundable'),
(2, 'Deluxe - Flexible', 4200.00, 'Free cancellation up to 24h'),
(3, 'Suite - Flexible', 7500.00, 'Free cancellation up to 24h'),
(3, 'Suite - Breakfast Included', 8200.00, 'Includes breakfast for all guests');

-- Staff
INSERT INTO staff (full_name, role) VALUES
('Lakshmi Devi', 'Housekeeping Supervisor'),
('Ravi Kumar', 'Housekeeping Staff'),
('Anita Rao', 'Room Service Staff');

-- Guests
INSERT INTO guest (full_name, email, phone) VALUES
('Arjun Mehta', 'arjun.mehta@example.com', '9876500001'),
('Priya Sharma', 'priya.sharma@example.com', '9876500002'),
('Karthik Iyer', 'karthik.iyer@example.com', '9876500003'),
('Sneha Reddy', 'sneha.reddy@example.com', '9876500004'),
('Farhan Ali', 'farhan.ali@example.com', '9876500005');

-- Reservations (mix of statuses, past/current/future, one cancelled)
INSERT INTO reservation (guest_id, room_id, rate_plan_id, reservation_status, planned_check_in, planned_check_out, adults, children) VALUES
(1, 3, 1, 'checked_in', '2026-09-20', '2026-09-24', 2, 0),
(2, 4, 3, 'booked',      '2026-10-10', '2026-10-13', 2, 1),
(3, 1, 2, 'completed',   '2026-08-01', '2026-08-03', 1, 0),
(4, 6, 4, 'booked',      '2026-10-15', '2026-10-18', 3, 1),
(5, 2, 1, 'cancelled',   '2026-09-25', '2026-09-27', 2, 0);

-- Stay for the checked-in and the completed reservation
INSERT INTO stay (reservation_id, actual_check_in, actual_check_out) VALUES
(1, '2026-09-20 14:05:00', NULL),
(3, '2026-08-01 13:40:00', '2026-08-03 11:15:00');

-- Housekeeping tasks
INSERT INTO housekeeping_task (room_id, stay_id, task_type, assigned_to, task_status, scheduled_at, completed_at) VALUES
(3, 1, 'Daily cleaning', 2, 'done', '2026-09-21 10:00:00', '2026-09-21 10:30:00'),
(1, NULL, 'Post-checkout cleaning', 2, 'pending', '2026-09-22 09:00:00', NULL),
(7, NULL, 'Maintenance check', 1, 'in_progress', '2026-09-22 08:00:00', NULL);

-- Service requests + charges for the active stay
INSERT INTO service_request (stay_id, service_name, status) VALUES
(1, 'Room Service - Breakfast', 'fulfilled'),
(1, 'Extra Towels', 'fulfilled'),
(2, 'Spa Booking', 'fulfilled');

INSERT INTO service_charge (stay_id, service_request_id, description, amount) VALUES
(1, 1, 'Breakfast for 2', 600.00),
(1, 2, 'Extra towels', 0.00),
(2, 3, 'Spa session (60 min)', 2200.00);

-- Invoice + payment for the completed stay (stay_id=2, reservation 3)
INSERT INTO invoice (stay_id, invoice_date, subtotal, tax, total, status) VALUES
(2, '2026-08-03', 4200.00, 210.00, 4410.00, 'open');

INSERT INTO payment (invoice_id, amount, payment_method, payment_status) VALUES
(1, 4410.00, 'card', 'success');
