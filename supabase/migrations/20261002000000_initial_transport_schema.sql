-- MUET Smart Bus Tracking System
-- Phase 4: transport schema and row-level security.

create extension if not exists "pgcrypto";

create schema if not exists private;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  email text not null unique,
  role text not null default 'student',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_role_check check (role in ('student', 'driver', 'admin'))
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles (id) on delete cascade,
  student_id text not null unique,
  created_at timestamptz not null default now()
);

create table public.drivers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles (id) on delete cascade,
  cnic text not null unique,
  phone text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint drivers_status_check check (status in ('active', 'inactive', 'suspended'))
);

comment on column public.drivers.cnic is
  'Sensitive identity data. Never expose through student-facing queries or views.';

create table public.buses (
  id uuid primary key default gen_random_uuid(),
  bus_number text not null unique,
  bus_name text not null,
  status text not null default 'inactive',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint buses_status_check check (status in ('active', 'inactive', 'delayed', 'maintenance'))
);

create table public.routes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint routes_status_check check (status in ('active', 'inactive'))
);

create table public.stops (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes (id) on delete cascade,
  name text not null,
  latitude numeric(9, 6) not null,
  longitude numeric(9, 6) not null,
  stop_order integer not null,
  created_at timestamptz not null default now(),
  constraint stops_latitude_check check (latitude between -90 and 90),
  constraint stops_longitude_check check (longitude between -180 and 180),
  constraint stops_order_check check (stop_order > 0),
  constraint stops_route_order_unique unique (route_id, stop_order),
  constraint stops_route_id_id_unique unique (route_id, id)
);

create table public.route_schedules (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes (id) on delete cascade,
  stop_id uuid not null references public.stops (id) on delete cascade,
  day_of_week smallint not null,
  scheduled_time time not null,
  created_at timestamptz not null default now(),
  constraint route_schedules_stop_route_fk
    foreign key (route_id, stop_id)
    references public.stops (route_id, id)
    on delete cascade,
  constraint route_schedules_day_check check (day_of_week between 0 and 6),
  constraint route_schedules_unique
    unique (route_id, stop_id, day_of_week, scheduled_time)
);

create table public.bus_assignments (
  id uuid primary key default gen_random_uuid(),
  bus_id uuid not null references public.buses (id) on delete cascade,
  driver_id uuid not null references public.drivers (id) on delete cascade,
  assigned_at timestamptz not null default now(),
  active boolean not null default true
);

create table public.route_assignments (
  id uuid primary key default gen_random_uuid(),
  bus_id uuid not null references public.buses (id) on delete cascade,
  route_id uuid not null references public.routes (id) on delete cascade,
  assigned_at timestamptz not null default now(),
  active boolean not null default true
);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  bus_id uuid not null references public.buses (id) on delete restrict,
  driver_id uuid not null references public.drivers (id) on delete restrict,
  route_id uuid not null references public.routes (id) on delete restrict,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  status text not null default 'active',
  constraint trips_status_check check (status in ('active', 'completed', 'cancelled')),
  constraint trips_end_time_check check (ended_at is null or ended_at >= started_at),
  constraint trips_status_time_check check (
    (status = 'active' and ended_at is null)
    or (status in ('completed', 'cancelled') and ended_at is not null)
  )
);

create table public.bus_locations (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  latitude numeric(9, 6) not null,
  longitude numeric(9, 6) not null,
  speed numeric(7, 2),
  heading numeric(6, 2),
  recorded_at timestamptz not null default now(),
  constraint bus_locations_latitude_check check (latitude between -90 and 90),
  constraint bus_locations_longitude_check check (longitude between -180 and 180),
  constraint bus_locations_speed_check check (speed is null or speed >= 0),
  constraint bus_locations_heading_check check (heading is null or (heading >= 0 and heading < 360))
);

create table public.student_alerts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students (id) on delete cascade,
  bus_id uuid not null references public.buses (id) on delete cascade,
  stop_id uuid not null references public.stops (id) on delete cascade,
  radius_meters numeric(8, 2) not null,
  enabled boolean not null default true,
  triggered_at timestamptz,
  created_at timestamptz not null default now(),
  constraint student_alerts_radius_check check (radius_meters >= 0)
);

create unique index bus_assignments_active_bus_unique
  on public.bus_assignments (bus_id)
  where active;

create unique index bus_assignments_active_driver_unique
  on public.bus_assignments (driver_id)
  where active;

create unique index route_assignments_active_bus_unique
  on public.route_assignments (bus_id)
  where active;

create unique index trips_active_bus_unique
  on public.trips (bus_id)
  where status = 'active';

create unique index trips_active_driver_unique
  on public.trips (driver_id)
  where status = 'active';

create index students_profile_id_idx on public.students (profile_id);
create index drivers_profile_id_idx on public.drivers (profile_id);
create index stops_route_id_idx on public.stops (route_id);
create index route_schedules_route_day_idx
  on public.route_schedules (route_id, day_of_week, scheduled_time);
create index route_schedules_stop_id_idx on public.route_schedules (stop_id);
create index bus_assignments_driver_active_idx
  on public.bus_assignments (driver_id, active);
create index route_assignments_route_active_idx
  on public.route_assignments (route_id, active);
create index trips_status_started_at_idx on public.trips (status, started_at desc);
create index trips_driver_id_idx on public.trips (driver_id);
create index trips_route_id_idx on public.trips (route_id);
create index bus_locations_trip_recorded_at_idx
  on public.bus_locations (trip_id, recorded_at desc);
create index student_alerts_student_enabled_idx
  on public.student_alerts (student_id, enabled);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger drivers_set_updated_at
before update on public.drivers
for each row execute function public.set_updated_at();

create trigger buses_set_updated_at
before update on public.buses
for each row execute function public.set_updated_at();

create trigger routes_set_updated_at
before update on public.routes
for each row execute function public.set_updated_at();

create or replace function public.prevent_driver_trip_reassignment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select auth.uid()) is not null
     and not (select private.is_admin())
     and (
       new.driver_id <> old.driver_id
       or new.bus_id <> old.bus_id
       or new.route_id <> old.route_id
     ) then
    raise exception 'Drivers cannot reassign trips';
  end if;
  return new;
end;
$$;

create trigger trips_prevent_driver_reassignment
before update on public.trips
for each row execute function public.prevent_driver_trip_reassignment();

create or replace function public.prevent_driver_location_reassignment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select auth.uid()) is not null
     and not (select private.is_admin())
     and new.trip_id <> old.trip_id then
    raise exception 'Drivers cannot reassign bus locations';
  end if;
  return new;
end;
$$;

create trigger bus_locations_prevent_driver_reassignment
before update on public.bus_locations
for each row execute function public.prevent_driver_location_reassignment();

create or replace function private.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.role
  from public.profiles as p
  where p.id = (select auth.uid())
  limit 1;
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select private.current_user_role()) = 'admin', false);
$$;

create or replace function private.current_driver_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select d.id
  from public.drivers as d
  where d.profile_id = (select auth.uid())
  limit 1;
$$;

create or replace function private.current_student_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select s.id
  from public.students as s
  where s.profile_id = (select auth.uid())
  limit 1;
$$;

create or replace function private.is_driver_assigned_to_bus(target_bus_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.bus_assignments as ba
    where ba.bus_id = target_bus_id
      and ba.driver_id = (select private.current_driver_id())
      and ba.active
  );
$$;

create or replace function private.is_driver_assigned_to_route(
  target_bus_id uuid,
  target_route_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.bus_assignments as ba
    join public.route_assignments as ra on ra.bus_id = ba.bus_id
    where ba.bus_id = target_bus_id
      and ra.route_id = target_route_id
      and ba.driver_id = (select private.current_driver_id())
      and ba.active
      and ra.active
  );
$$;

create or replace function private.is_driver_for_trip(target_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.trips as t
    where t.id = target_trip_id
      and t.driver_id = (select private.current_driver_id())
  );
$$;

revoke all on function private.current_user_role() from public;
revoke all on function private.is_admin() from public;
revoke all on function private.current_driver_id() from public;
revoke all on function private.current_student_id() from public;
revoke all on function private.is_driver_assigned_to_bus(uuid) from public;
revoke all on function private.is_driver_assigned_to_route(uuid, uuid) from public;
revoke all on function private.is_driver_for_trip(uuid) from public;

grant execute on function private.current_user_role() to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.current_driver_id() to authenticated;
grant execute on function private.current_student_id() to authenticated;
grant execute on function private.is_driver_assigned_to_bus(uuid) to authenticated;
grant execute on function private.is_driver_assigned_to_route(uuid, uuid) to authenticated;
grant execute on function private.is_driver_for_trip(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.drivers enable row level security;
alter table public.buses enable row level security;
alter table public.routes enable row level security;
alter table public.stops enable row level security;
alter table public.route_schedules enable row level security;
alter table public.bus_assignments enable row level security;
alter table public.route_assignments enable row level security;
alter table public.trips enable row level security;
alter table public.bus_locations enable row level security;
alter table public.student_alerts enable row level security;

create policy profiles_select_own_or_admin
on public.profiles for select to authenticated
using (id = (select auth.uid()) or (select private.is_admin()));

create policy profiles_admin_manage
on public.profiles for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy students_select_own_or_admin
on public.students for select to authenticated
using (profile_id = (select auth.uid()) or (select private.is_admin()));

create policy students_admin_manage
on public.students for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy drivers_select_own_or_admin
on public.drivers for select to authenticated
using (profile_id = (select auth.uid()) or (select private.is_admin()));

create policy drivers_admin_manage
on public.drivers for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy buses_authenticated_read
on public.buses for select to authenticated
using (true);

create policy buses_admin_manage
on public.buses for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy routes_authenticated_read
on public.routes for select to authenticated
using (true);

create policy routes_admin_manage
on public.routes for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy stops_authenticated_read
on public.stops for select to authenticated
using (true);

create policy stops_admin_manage
on public.stops for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy route_schedules_authenticated_read
on public.route_schedules for select to authenticated
using (true);

create policy route_schedules_admin_manage
on public.route_schedules for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy bus_assignments_driver_or_admin_read
on public.bus_assignments for select to authenticated
using (
  (select private.is_admin())
  or driver_id = (select private.current_driver_id())
);

create policy bus_assignments_admin_manage
on public.bus_assignments for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy route_assignments_driver_or_admin_read
on public.route_assignments for select to authenticated
using (
  (select private.is_admin())
  or (select private.is_driver_assigned_to_bus(bus_id))
);

create policy route_assignments_admin_manage
on public.route_assignments for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy trips_authenticated_active_read
on public.trips for select to authenticated
using (
  status = 'active'
  or driver_id = (select private.current_driver_id())
  or (select private.is_admin())
);

create policy trips_driver_start_assigned
on public.trips for insert to authenticated
with check (
  driver_id = (select private.current_driver_id())
  and status = 'active'
  and ended_at is null
  and (select private.is_driver_assigned_to_route(bus_id, route_id))
);

create policy trips_driver_end_own
on public.trips for update to authenticated
using (
  (
    (select private.is_driver_for_trip(id))
    and status = 'active'
  )
  or (select private.is_admin())
)
with check (
  (
    (select private.is_driver_for_trip(id))
    and driver_id = (select private.current_driver_id())
    and status in ('completed', 'cancelled')
    and ended_at is not null
  )
  or (select private.is_admin())
);

create policy trips_admin_manage
on public.trips for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy bus_locations_authenticated_active_read
on public.bus_locations for select to authenticated
using (
  exists (
    select 1
    from public.trips as t
    where t.id = trip_id
      and t.status = 'active'
  )
  or (select private.is_driver_for_trip(trip_id))
  or (select private.is_admin())
);

create policy bus_locations_driver_insert_own_active_trip
on public.bus_locations for insert to authenticated
with check (
  (select private.is_driver_for_trip(trip_id))
  and exists (
    select 1
    from public.trips as t
    where t.id = trip_id
      and t.status = 'active'
  )
);

create policy bus_locations_driver_update_own_active_trip
on public.bus_locations for update to authenticated
using (
  (select private.is_driver_for_trip(trip_id))
  and exists (
    select 1
    from public.trips as t
    where t.id = trip_id
      and t.status = 'active'
  )
)
with check (
  (select private.is_driver_for_trip(trip_id))
  and exists (
    select 1
    from public.trips as t
    where t.id = trip_id
      and t.status = 'active'
  )
);

create policy bus_locations_admin_manage
on public.bus_locations for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy student_alerts_own_manage
on public.student_alerts for all to authenticated
using (
  student_id = (select private.current_student_id())
)
with check (
  student_id = (select private.current_student_id())
);

create view public.driver_directory as
select
  d.id,
  p.full_name,
  d.status
from public.drivers as d
join public.profiles as p on p.id = d.profile_id
where d.status = 'active';

comment on view public.driver_directory is
  'Safe student-facing driver projection. Sensitive CNIC and phone columns are excluded.';

revoke all on public.driver_directory from anon;
grant select on public.driver_directory to authenticated;
