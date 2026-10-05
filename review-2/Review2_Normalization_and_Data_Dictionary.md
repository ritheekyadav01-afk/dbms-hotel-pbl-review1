# Review 2 — Normalization, Functional Dependencies and Data Dictionary

Hotel Reservation and Guest Services Management System · Project 12 · Dandigam Ritheek · AI-ML · Woxsen University

All counts below were read from the live MySQL schema (`hotel_pbl`), not typed by hand.

**Schema at a glance:** 12 tables · 14 foreign keys · 5 UNIQUE · 8 CHECK · 7 ENUM columns · 16 columns with DEFAULT · 3 secondary indexes · 10 triggers · 8 views.

## 1. Starting point and anomalies

A first, flat design would keep everything in one `booking` table (guest name/email/phone, room number, room type, capacity, nightly rate, dates, service lines, invoice total, payment). That causes:

- **Update anomaly** — changing a room type's capacity means editing every booking row for that type.
- **Insert anomaly** — a new room type or guest cannot be stored until a booking exists.
- **Delete anomaly** — deleting a guest's only booking also deletes the guest.
- **Repeating groups (violates 1NF)** — a stay has many service lines and many payments.

## 2. Normal forms applied

- **1NF** — every column holds a single atomic value; service lines and payments moved to their own tables (`service_request`, `service_charge`, `payment`); statuses are single-valued ENUMs.
- **2NF** — every table has a single-column surrogate primary key, so no non-key attribute can depend on only part of a key; guest, room, rate and staff details left the booking table.
- **3NF** — no non-key attribute depends on another non-key attribute: `room` stores `type_id` (not capacity), `reservation` stores `rate_plan_id` (not the nightly rate), money collected lives in `payment` (not in `invoice`).

## 3. Functional dependencies per table

| Table | Functional dependencies | Result |
|---|---|---|
| `room_type` | type_id → type_name, capacity, description<br>type_name → type_id (candidate key) | BCNF |
| `room` | room_id → room_number, type_id, status<br>room_number → room_id (candidate key) | BCNF |
| `rate_plan` | rate_plan_id → type_id, plan_name, nightly_rate, description | BCNF |
| `guest` | guest_id → full_name, email, phone<br>email → guest_id (candidate key) | BCNF |
| `staff` | staff_id → full_name, role | BCNF |
| `reservation` | reservation_id → guest_id, room_id, rate_plan_id, reservation_status, planned_check_in, planned_check_out, adults, children, created_at | BCNF |
| `stay` | stay_id → reservation_id, actual_check_in, actual_check_out<br>reservation_id → stay_id (1:0..1, candidate key) | BCNF |
| `housekeeping_task` | task_id → room_id, stay_id, task_type, assigned_to, task_status, scheduled_at, completed_at<br>stay_id → room_id (only when stay_id is present) † | 3NF exception † |
| `service_request` | service_request_id → stay_id, service_name, requested_at, status | BCNF |
| `service_charge` | charge_id → stay_id, service_request_id, description, amount, charged_at<br>service_request_id → stay_id (only when present) † | 3NF exception † |
| `invoice` | invoice_id → stay_id, invoice_date, subtotal, tax, total<br>stay_id → invoice_id (1:1, candidate key) | BCNF |
| `payment` | payment_id → invoice_id, payment_date, amount, payment_method, payment_status | BCNF |

† **Two deliberate, documented exceptions to strict 3NF.** `service_charge.service_request_id` is optional (a charge can exist without a request), so `stay_id` must be stored on the charge itself; when a request *is* present, `stay_id` is derivable from it. The same applies to `housekeeping_task.room_id` / `stay_id`. Rather than make these links mandatory (which would force fake requests/stays or NULL-heavy tables), the redundancy is kept and **guarded by triggers** that reject any row where the two disagree (see section 5). All other tables have only candidate keys as determinants (BCNF, hence 3NF).

## 4. Design decisions

- **`stay` is separate from `reservation`.** A reservation exists before arrival and may be cancelled or a no-show; a stay holds the *actual* check-in/out and exists only if the guest arrives (1 : 0..1).
- **`staff` is its own table.** The ER diagram showed `assigned_to` as a plain attribute; storing staff names/roles on every task would repeat them and invite update anomalies, so `housekeeping_task.assigned_to` is a foreign key to `staff`.
- **Invoice totals are stored.** `subtotal`, `tax` and `total` are derivable from the stay and its charges, but are stored as a billing snapshot so a closed invoice does not change if rates change later. The app computes them once, at check-out.

## 5. Business rules enforced in the database

| Rule | Enforced by | Message when violated |
|---|---|---|
| No overlapping room bookings | Trigger | Room is already booked for an overlapping date range. |
| Occupants within room capacity | Trigger | Occupant count exceeds room type capacity. |
| Check-out after check-in | CHECK | Check constraint 'chk_dates' is violated. |
| Charge amounts not negative | CHECK | Check constraint 'chk_charge_nonneg' is violated. |
| Payments cannot exceed invoice total | Trigger | Payment would exceed the invoice total. |
| Rate plan belongs to the room's type | Trigger | Rate plan does not belong to this room type. |
| Charge's stay matches its request's stay | Trigger | Service charge stay does not match its service request. |
| Task's room matches its stay's room | Trigger | Housekeeping task room does not match the stay's room. |

Every rule above was tested by attempting the violating INSERT; each was rejected and no data changed.

## 6. Data dictionary

Legend: **PK** primary key · **FK→t** foreign key to table `t` · **UNIQUE** unique · **NULL** nullable · **DEFAULT** default value.

### `guest` — Guest contact details.

| Column | Type | Constraints |
|---|---|---|
| `guest_id` | INT | PK |
| `full_name` | VARCHAR(100) | — |
| `email` | VARCHAR(100) | UNIQUE |
| `phone` | VARCHAR(20) | NULL |

### `housekeeping_task` — Cleaning or maintenance job for a room.

| Column | Type | Constraints |
|---|---|---|
| `task_id` | INT | PK |
| `room_id` | INT | FK→room |
| `stay_id` | INT | FK→stay, NULL |
| `task_type` | VARCHAR(50) | — |
| `assigned_to` | INT | FK→staff, NULL |
| `task_status` | ENUM(3) | DEFAULT pending |
| `scheduled_at` | DATETIME | — |
| `completed_at` | DATETIME | NULL |

### `invoice` — Bill for a stay: subtotal, tax, total.

| Column | Type | Constraints |
|---|---|---|
| `invoice_id` | INT | PK |
| `stay_id` | INT | FK→stay, UNIQUE |
| `invoice_date` | DATE | NULL, DEFAULT CURRENT_DATE |
| `subtotal` | DECIMAL(10,2) | DEFAULT 0.00 |
| `tax` | DECIMAL(10,2) | DEFAULT 0.00 |
| `total` | DECIMAL(10,2) | DEFAULT 0.00 |
| `status` | ENUM(3) | DEFAULT open |

### `payment` — One payment against an invoice.

| Column | Type | Constraints |
|---|---|---|
| `payment_id` | INT | PK |
| `invoice_id` | INT | FK→invoice |
| `payment_date` | DATETIME | NULL, DEFAULT CURRENT_TIMESTAMP |
| `amount` | DECIMAL(10,2) | — |
| `payment_method` | ENUM(4) | — |
| `payment_status` | ENUM(3) | DEFAULT success |

### `rate_plan` — Priced plan for one room type.

| Column | Type | Constraints |
|---|---|---|
| `rate_plan_id` | INT | PK |
| `type_id` | INT | FK→room_type |
| `plan_name` | VARCHAR(50) | — |
| `nightly_rate` | DECIMAL(10,2) | — |
| `description` | VARCHAR(255) | NULL |

### `reservation` — A planned booking: who, which room, which plan, which dates.

| Column | Type | Constraints |
|---|---|---|
| `reservation_id` | INT | PK |
| `guest_id` | INT | FK→guest |
| `room_id` | INT | FK→room |
| `rate_plan_id` | INT | FK→rate_plan |
| `reservation_status` | ENUM(5) | DEFAULT booked |
| `planned_check_in` | DATE | — |
| `planned_check_out` | DATE | — |
| `adults` | INT | DEFAULT 1 |
| `children` | INT | DEFAULT 0 |
| `created_at` | TIMESTAMP | NULL, DEFAULT CURRENT_TIMESTAMP |

### `room` — Physical room, its type and live status.

| Column | Type | Constraints |
|---|---|---|
| `room_id` | INT | PK |
| `room_number` | VARCHAR(10) | UNIQUE |
| `type_id` | INT | FK→room_type |
| `status` | ENUM(4) | DEFAULT available |

### `room_type` — Category of room: capacity and description.

| Column | Type | Constraints |
|---|---|---|
| `type_id` | INT | PK |
| `type_name` | VARCHAR(50) | UNIQUE |
| `capacity` | INT | — |
| `description` | VARCHAR(255) | NULL |

### `service_charge` — Billable amount for a service (or ad-hoc charge).

| Column | Type | Constraints |
|---|---|---|
| `charge_id` | INT | PK |
| `stay_id` | INT | FK→stay |
| `service_request_id` | INT | FK→service_request, NULL |
| `description` | VARCHAR(255) | NULL |
| `amount` | DECIMAL(10,2) | — |
| `charged_at` | DATETIME | NULL, DEFAULT CURRENT_TIMESTAMP |

### `service_request` — A guest's in-stay request for a service.

| Column | Type | Constraints |
|---|---|---|
| `service_request_id` | INT | PK |
| `stay_id` | INT | FK→stay |
| `service_name` | VARCHAR(100) | — |
| `requested_at` | DATETIME | NULL, DEFAULT CURRENT_TIMESTAMP |
| `status` | ENUM(3) | DEFAULT requested |

### `staff` — Hotel staff who can be assigned housekeeping tasks.

| Column | Type | Constraints |
|---|---|---|
| `staff_id` | INT | PK |
| `full_name` | VARCHAR(100) | — |
| `role` | VARCHAR(50) | — |

### `stay` — The actual check-in/check-out against a reservation.

| Column | Type | Constraints |
|---|---|---|
| `stay_id` | INT | PK |
| `reservation_id` | INT | FK→reservation, UNIQUE |
| `actual_check_in` | DATETIME | — |
| `actual_check_out` | DATETIME | NULL |

## 7. Row counts in the sample data

| Table | Rows |
|---|---|
| `guest` | 5 |
| `housekeeping_task` | 3 |
| `invoice` | 1 |
| `payment` | 1 |
| `rate_plan` | 5 |
| `reservation` | 5 |
| `room` | 7 |
| `room_type` | 3 |
| `service_charge` | 3 |
| `service_request` | 3 |
| `staff` | 3 |
| `stay` | 2 |
