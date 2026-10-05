-- ============================================================
-- 02_triggers.sql — business rules that need to look across
-- rows/tables (can't be expressed as a plain CHECK constraint)
-- ============================================================
USE hotel_pbl;

DELIMITER $$

-- Rule: no overlapping room stays for the same room (checked at
-- reservation time, on the planned dates; ignores cancelled/no_show).
CREATE TRIGGER trg_reservation_no_overlap_insert
BEFORE INSERT ON reservation
FOR EACH ROW
BEGIN
    DECLARE conflict_count INT;
    SELECT COUNT(*) INTO conflict_count
    FROM reservation
    WHERE room_id = NEW.room_id
      AND reservation_status NOT IN ('cancelled','no_show')
      AND NEW.planned_check_in < planned_check_out
      AND NEW.planned_check_out > planned_check_in;
    IF conflict_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Room is already booked for an overlapping date range.';
    END IF;
END$$

CREATE TRIGGER trg_reservation_no_overlap_update
BEFORE UPDATE ON reservation
FOR EACH ROW
BEGIN
    DECLARE conflict_count INT;
    IF NEW.reservation_status NOT IN ('cancelled','no_show') THEN
        SELECT COUNT(*) INTO conflict_count
        FROM reservation
        WHERE room_id = NEW.room_id
          AND reservation_id <> NEW.reservation_id
          AND reservation_status NOT IN ('cancelled','no_show')
          AND NEW.planned_check_in < planned_check_out
          AND NEW.planned_check_out > planned_check_in;
        IF conflict_count > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Room is already booked for an overlapping date range.';
        END IF;
    END IF;
END$$

-- Rule: adults + children must not exceed the room type's capacity
CREATE TRIGGER trg_reservation_capacity_insert
BEFORE INSERT ON reservation
FOR EACH ROW
BEGIN
    DECLARE room_capacity INT;
    SELECT rt.capacity INTO room_capacity
    FROM room r JOIN room_type rt ON r.type_id = rt.type_id
    WHERE r.room_id = NEW.room_id;
    IF (NEW.adults + NEW.children) > room_capacity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Occupant count exceeds room type capacity.';
    END IF;
END$$

CREATE TRIGGER trg_reservation_capacity_update
BEFORE UPDATE ON reservation
FOR EACH ROW
BEGIN
    DECLARE room_capacity INT;
    SELECT rt.capacity INTO room_capacity
    FROM room r JOIN room_type rt ON r.type_id = rt.type_id
    WHERE r.room_id = NEW.room_id;
    IF (NEW.adults + NEW.children) > room_capacity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Occupant count exceeds room type capacity.';
    END IF;
END$$

-- Rule: a payment cannot push total paid beyond the invoice total
CREATE TRIGGER trg_payment_limit_insert
BEFORE INSERT ON payment
FOR EACH ROW
BEGIN
    DECLARE already_paid DECIMAL(10,2);
    DECLARE inv_total DECIMAL(10,2);
    SELECT COALESCE(SUM(amount), 0) INTO already_paid
    FROM payment
    WHERE invoice_id = NEW.invoice_id AND payment_status = 'success';
    SELECT total INTO inv_total FROM invoice WHERE invoice_id = NEW.invoice_id;
    IF NEW.payment_status = 'success' AND (already_paid + NEW.amount) > inv_total THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment would exceed the invoice total.';
    END IF;
END$$

-- Convenience: auto-update invoice.status based on payments so far
CREATE TRIGGER trg_invoice_status_after_payment
AFTER INSERT ON payment
FOR EACH ROW
BEGIN
    DECLARE already_paid DECIMAL(10,2);
    DECLARE inv_total DECIMAL(10,2);
    IF NEW.payment_status = 'success' THEN
        SELECT COALESCE(SUM(amount), 0) INTO already_paid
        FROM payment WHERE invoice_id = NEW.invoice_id AND payment_status = 'success';
        SELECT total INTO inv_total FROM invoice WHERE invoice_id = NEW.invoice_id;
        IF already_paid >= inv_total THEN
            UPDATE invoice SET status = 'paid' WHERE invoice_id = NEW.invoice_id;
        ELSE
            UPDATE invoice SET status = 'partially_paid' WHERE invoice_id = NEW.invoice_id;
        END IF;
    END IF;
END$$

-- Convenience: when a stay is checked out, free the room back to 'cleaning'
-- and mark the reservation completed.
CREATE TRIGGER trg_stay_checkout
AFTER UPDATE ON stay
FOR EACH ROW
BEGIN
    IF NEW.actual_check_out IS NOT NULL AND OLD.actual_check_out IS NULL THEN
        UPDATE reservation SET reservation_status = 'completed'
        WHERE reservation_id = NEW.reservation_id;
        UPDATE room r JOIN reservation res ON r.room_id = res.room_id
        SET r.status = 'cleaning'
        WHERE res.reservation_id = NEW.reservation_id;
    END IF;
END$$

-- Rule: a reservation's rate plan must belong to the same room type as its room
CREATE TRIGGER trg_reservation_rateplan_match_insert
BEFORE INSERT ON reservation
FOR EACH ROW
BEGIN
    DECLARE room_type_id INT;
    DECLARE plan_type_id INT;
    SELECT type_id INTO room_type_id FROM room WHERE room_id = NEW.room_id;
    SELECT type_id INTO plan_type_id FROM rate_plan WHERE rate_plan_id = NEW.rate_plan_id;
    IF room_type_id <> plan_type_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Rate plan does not belong to this room type.';
    END IF;
END$$

-- Rule: a service charge linked to a service request must reference the same stay
CREATE TRIGGER trg_charge_stay_match_insert
BEFORE INSERT ON service_charge
FOR EACH ROW
BEGIN
    DECLARE req_stay INT;
    IF NEW.service_request_id IS NOT NULL THEN
        SELECT stay_id INTO req_stay FROM service_request
        WHERE service_request_id = NEW.service_request_id;
        IF req_stay <> NEW.stay_id THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Service charge stay does not match its service request.';
        END IF;
    END IF;
END$$

-- Rule: a housekeeping task tied to a stay must be for that stay's room
CREATE TRIGGER trg_task_room_match_insert
BEFORE INSERT ON housekeeping_task
FOR EACH ROW
BEGIN
    DECLARE stay_room INT;
    IF NEW.stay_id IS NOT NULL THEN
        SELECT res.room_id INTO stay_room
        FROM stay s JOIN reservation res ON s.reservation_id = res.reservation_id
        WHERE s.stay_id = NEW.stay_id;
        IF stay_room <> NEW.room_id THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Housekeeping task room does not match the stay''s room.';
        END IF;
    END IF;
END$$

DELIMITER ;
