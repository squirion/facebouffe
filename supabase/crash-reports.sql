-- Crash / problem reports (app v2.7.0). Run ONCE in the Supabase dashboard →
-- SQL editor (schema is managed by hand; there are no migrations in this repo).
--
-- Access model:
--   * INSERT is open to anon + authenticated (crash reports must work for
--     users who never signed in). Size limits in the policy keep abuse cheap.
--   * There is NO select/update/delete policy — the public API can only write.
--   * The app reads back only the status of reports it sent, via the
--     security-definer RPC below: possessing a report's uuid IS the capability
--     (ids are client-minted v4 — unguessable).
--   * Devs read/answer reports with the service-role key (bypasses RLS) via
--     tool/crash_reports.dart.

create table if not exists crash_reports (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  user_id      uuid references auth.users (id) on delete set null,
  username     text,
  app_version  text not null default '',
  build        int  not null default 0,
  platform     text not null default '',
  os_version   text not null default '',
  device_model text not null default '',
  kind         text not null default 'crash' check (kind in ('crash','manual')),
  notes        text not null default '',
  log          text not null default '',
  status       text not null default 'new',   -- convention: new | investigating | fixed | closed
  dev_note     text,                          -- shown to the user under the status
  updated_at   timestamptz not null default now()
);

alter table crash_reports enable row level security;

drop policy if exists crash_reports_insert_any on crash_reports;
create policy crash_reports_insert_any on crash_reports
  for insert to anon, authenticated
  with check (
    char_length(log) <= 131072
    and char_length(notes) <= 4000
    and (user_id is null or user_id = auth.uid())
  );

-- Keep updated_at honest when the dev CLI patches status/dev_note.
create or replace function crash_reports_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists crash_reports_touch on crash_reports;
create trigger crash_reports_touch before update on crash_reports
  for each row execute function crash_reports_touch();

-- Status readback for the app: batch lookup by uuid capability. Definer +
-- explicit column projection + limit avoids ever exposing a listing.
create or replace function crash_report_statuses(ids uuid[])
returns table (id uuid, status text, dev_note text, updated_at timestamptz)
language sql stable security definer set search_path = public
as $$
  select cr.id, cr.status, cr.dev_note, cr.updated_at
    from crash_reports cr
   where cr.id = any (ids)
   limit 20;
$$;

revoke all on function crash_report_statuses(uuid[]) from public;
grant execute on function crash_report_statuses(uuid[]) to anon, authenticated;
