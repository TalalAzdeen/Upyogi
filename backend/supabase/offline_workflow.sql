begin;
alter table public.bookings drop constraint bookings_booking_status_check;
alter table public.bookings add constraint bookings_booking_status_check check (booking_status in ('Requested','Accepted','OnTheWay','Rejected','Completed','Cancelled'));
alter table public.bookings drop constraint bookings_payment_status_check;
alter table public.bookings add constraint bookings_payment_status_check check (payment_status in ('Pending','Paid','Refunded','External'));
alter table public.bookings alter column payment_status set default 'External';
-- Preserve all historical confirmed payments and any payment intent awaiting reconciliation.
commit;
