begin;
alter table public.app_profiles add column profile_image_url text;
create table public.provider_profiles (
  owner_id uuid primary key references auth.users(id),
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create table public.services (
  id bigint generated always as identity primary key,
  owner_id uuid not null references auth.users(id),
  data jsonb not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create index services_owner_idx on public.services(owner_id);
create table public.bookings (
  id bigint generated always as identity primary key,
  service_id bigint not null references public.services(id),
  customer_id uuid not null references auth.users(id),
  provider_id uuid not null references auth.users(id),
  data jsonb not null,
  amount_minor bigint not null check(amount_minor > 0),
  currency text not null default 'sar' check(currency = 'sar'),
  booking_status text not null default 'Requested' check(booking_status in ('Requested','Accepted','Rejected','Completed','Cancelled')),
  payment_status text not null default 'Pending' check(payment_status in ('Pending','Paid','Refunded')),
  stripe_payment_intent_id text unique,
  created_at timestamptz not null default now(),
  check(customer_id <> provider_id)
);
create index bookings_customer_idx on public.bookings(customer_id, created_at desc);
create index bookings_provider_idx on public.bookings(provider_id, created_at desc);
create index bookings_service_idx on public.bookings(service_id);
create table public.reviews (
  id bigint generated always as identity primary key,
  booking_id bigint not null unique references public.bookings(id),
  service_id bigint not null references public.services(id),
  customer_id uuid not null references auth.users(id),
  customer_name text not null,
  rating integer not null check(rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);
create index reviews_service_idx on public.reviews(service_id);
create index reviews_customer_idx on public.reviews(customer_id);
create table public.notifications (
  id bigint generated always as identity primary key,
  owner_id uuid not null references auth.users(id),
  title text not null,
  message text not null,
  type text not null default 'Booking',
  related_id bigint,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index notifications_owner_idx on public.notifications(owner_id,created_at desc);
alter table public.provider_profiles enable row level security;
alter table public.services enable row level security;
alter table public.bookings enable row level security;
alter table public.reviews enable row level security;
alter table public.notifications enable row level security;
-- Private personal data stays behind the authenticated API. Public listings contain only advertised data.
revoke all on public.provider_profiles, public.services, public.bookings, public.reviews, public.notifications from public, anon, authenticated;
grant all on public.provider_profiles, public.services, public.bookings, public.reviews, public.notifications to service_role;
grant usage,select on all sequences in schema public to service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('service-images','service-images',true,5242880,array['image/jpeg','image/png','image/webp']),
('private-documents','private-documents',false,5242880,array['image/jpeg','image/png','application/pdf']);
commit;
