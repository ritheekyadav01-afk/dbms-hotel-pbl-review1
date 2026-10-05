# Validation & Error-Handling Tests

Each business rule was deliberately violated against the live MySQL database. Every violation was rejected by a CHECK constraint or trigger, and the row count of the affected table was unchanged afterwards.

| # | Rule | Enforced by | Result |
|---|------|-------------|--------|
| 1 | No overlapping room bookings | Trigger | **Rejected** — `Room is already booked for an overlapping date range.` |
| 2 | Occupants within room capacity | Trigger | **Rejected** — `Occupant count exceeds room type capacity.` |
| 3 | Check-out after check-in | CHECK | **Rejected** — `Check constraint 'chk_dates' is violated.` |
| 4 | Charge amounts not negative | CHECK | **Rejected** — `Check constraint 'chk_charge_nonneg' is violated.` |
| 5 | Payments cannot exceed invoice total | Trigger | **Rejected** — `Payment would exceed the invoice total.` |
| 6 | Rate plan belongs to the room's type | Trigger | **Rejected** — `Rate plan does not belong to this room type.` |
| 7 | Charge's stay matches its request's stay | Trigger | **Rejected** — `Service charge stay does not match its service request.` |
| 8 | Task's room matches its stay's room | Trigger | **Rejected** — `Housekeeping task room does not match the stay's room.` |

A valid, non-conflicting reservation was also inserted afterwards to confirm the rules block only genuine violations. The Python app catches each rejection and prints `[Rejected] <message>` instead of crashing (see `sample_run_log.txt`).

