# Account sign-up and role provisioning

Everyone registers through the same **Create an account** screen on the login
page. The role you end up with is decided by the database, never by the app.

## How it works

1. The app sends a *requested* role plus a provisioning code as sign-up metadata.
2. The `handle_new_user` trigger (`supabase/migrations/20261016000000_role_provisioning_signup.sql`)
   validates everything server-side and only then creates the row in
   `public.profiles`, plus the matching `public.students` or `public.drivers`
   row so the account is usable immediately.
3. The provisioning code is consumed (`times_used + 1`), so a code can only be
   used as many times as `max_uses` allows.

Because the trigger runs as `security definer`, a client cannot grant itself
`admin` or `driver` — it cannot even read `public.provisioning_codes`.

| Role | Requirements |
| --- | --- |
| Student | Email must end with `@students.muet.edu.pk`. Roll number (`student_id`) defaults to the email local part, e.g. `23cs092@students.muet.edu.pk` → `23cs092`. |
| Driver | A valid `driver` provisioning code **and** a CNIC in `12345-1234567-1` form. Creates a `drivers` row with status `active`. |
| Administrator | A valid `admin` provisioning code. |

## Applying the migration

Run the contents of `supabase/migrations/20261016000000_role_provisioning_signup.sql`
in the Supabase SQL Editor, or push it with the Supabase CLI.

Until it is applied, the sign-up screen will fail to create accounts.

## Bootstrap codes

The migration seeds two codes so the first administrator can register:

| Code | Role | Max uses | Expires |
| --- | --- | --- | --- |
| `MUET-ADMIN-2026` | administrator | 5 | 120 days |
| `MUET-DRIVER-2026` | driver | 500 | 120 days |

Change or delete them once real onboarding begins.

Issue new codes from the SQL Editor or as an admin:

```sql
insert into public.provisioning_codes (code, role, description, max_uses, expires_at)
values ('DRIVER-INTAKE-MARCH', 'driver', 'Driver intake, March', 25, now() + interval '30 days');
```

## Email confirmation

If **Confirm email** is enabled in Supabase (Authentication → Providers →
Email), a newly created account must click the confirmation link before it can
sign in. The app tells you when this is the case. Turn it off for local
development if you want sign-up to sign you in immediately.
