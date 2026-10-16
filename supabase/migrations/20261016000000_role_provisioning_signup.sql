-- Self-service registration with role provisioning.
--
-- Goals:
--   * Students may self-register with a MUET student email address.
--   * Driver and admin roles require a single-use/limited provisioning code.
--   * The role is decided by the database, never trusted from the client.
--
-- Applying this migration is required before the app's sign-up screen works.

create table if not exists public.provisioning_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  role text not null,
  description text,
  is_active boolean not null default true,
  max_uses integer,
  times_used integer not null default 0,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  constraint provisioning_codes_role_check check (role in ('driver', 'admin')),
  constraint provisioning_codes_uses_check
    check (max_uses is null or times_used <= max_uses)
);

comment on table public.provisioning_codes is
  'Invite codes that authorise self-service sign-up as driver or admin. Admin-managed only.';

alter table public.provisioning_codes enable row level security;

drop policy if exists provisioning_codes_admin_manage on public.provisioning_codes;
create policy provisioning_codes_admin_manage
on public.provisioning_codes for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- Bootstrap codes so the first administrator and drivers can register.
-- Change or delete these once real onboarding begins.
insert into public.provisioning_codes (code, role, description, max_uses, expires_at)
values
  ('MUET-ADMIN-2026', 'admin', 'Bootstrap administrator code', 5, now() + interval '120 days'),
  ('MUET-DRIVER-2026', 'driver', 'Bootstrap driver code', 500, now() + interval '120 days')
on conflict (code) do nothing;

-- Public (anon) pre-check so the app can show a friendly error before creating
-- the account. It only reveals whether a specific code is valid.
create or replace function public.is_provisioning_code_valid(
  p_code text,
  p_role text
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.provisioning_codes
    where code = p_code
      and role = p_role
      and is_active
      and (expires_at is null or expires_at > now())
      and (max_uses is null or times_used < max_uses)
  );
$$;

revoke all on function public.is_provisioning_code_valid(text, text) from public;
grant execute on function public.is_provisioning_code_valid(text, text)
  to anon, authenticated;

-- Replaces the Phase 5 handler that always assigned 'student'.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := lower(coalesce(new.raw_user_meta_data ->> 'requested_role', 'student'));
  v_code text := nullif(trim(coalesce(new.raw_user_meta_data ->> 'invite_code', '')), '');
  v_full_name text := nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), '');
  v_student_id text := nullif(trim(coalesce(new.raw_user_meta_data ->> 'student_id', '')), '');
  v_cnic text := nullif(trim(coalesce(new.raw_user_meta_data ->> 'cnic', '')), '');
  v_phone text := nullif(trim(coalesce(new.raw_user_meta_data ->> 'phone', '')), '');
  v_code_id uuid;
begin
  if v_role not in ('student', 'driver', 'admin') then
    v_role := 'student';
  end if;

  if v_full_name is null then
    v_full_name := split_part(new.email, '@', 1);
  end if;

  -- Students must use a MUET student email address.
  if v_role = 'student'
     and new.email not ilike '%@students.muet.edu.pk' then
    raise exception 'Student accounts require a @students.muet.edu.pk email address'
      using errcode = 'check_violation';
  end if;

  -- Driver and admin accounts require a valid provisioning code.
  if v_role in ('driver', 'admin') then
    if v_code is null then
      raise exception 'A provisioning code is required for % accounts', v_role
        using errcode = 'check_violation';
    end if;

    select id into v_code_id
    from public.provisioning_codes
    where code = v_code
      and role = v_role
      and is_active
      and (expires_at is null or expires_at > now())
      and (max_uses is null or times_used < max_uses)
    for update;

    if v_code_id is null then
      raise exception 'Invalid, expired, or exhausted provisioning code'
        using errcode = 'check_violation';
    end if;

    update public.provisioning_codes
    set times_used = times_used + 1
    where id = v_code_id;
  end if;

  insert into public.profiles (id, full_name, email, role)
  values (new.id, v_full_name, new.email, v_role)
  on conflict (id) do update
    set email = excluded.email,
        full_name = excluded.full_name;

  if v_role = 'student' then
    if v_student_id is null then
      v_student_id := split_part(new.email, '@', 1);
    end if;

    -- Keep student_id unique even when two addresses share a local part.
    if exists (
      select 1 from public.students where student_id = v_student_id
    ) then
      v_student_id := v_student_id || '-' || upper(
        substr(replace(new.id::text, '-', ''), 1, 6)
      );
    end if;

    insert into public.students (profile_id, student_id)
    values (new.id, v_student_id)
    on conflict do nothing;
  elsif v_role = 'driver' then
    if v_cnic is null then
      raise exception 'A CNIC is required for driver accounts'
        using errcode = 'check_violation';
    end if;
    insert into public.drivers (profile_id, cnic, phone)
    values (new.id, v_cnic, v_phone)
    on conflict do nothing;
  end if;

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
