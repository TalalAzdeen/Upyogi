begin;
create table public.booking_locations (
 booking_id bigint primary key references public.bookings(id) on delete cascade,
 latitude double precision not null check(latitude between -90 and 90),
 longitude double precision not null check(longitude between -180 and 180),
 updated_at timestamptz not null default now()
);
alter table public.booking_locations enable row level security;
revoke all on public.booking_locations from public,anon,authenticated;
grant all on public.booking_locations to service_role;
commit;
