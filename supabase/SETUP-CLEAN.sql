-- Atelier Ahmed — clean installation for a NEW, EMPTY Supabase project.
-- Run this file only in the dedicated empty Atelier-Ahmed project.
-- Do not run on the legacy prototype database.
-- No passwords, service-role keys, or secret keys belong in this file.

begin;

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  address text,
  email text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  service text not null,
  start_date date not null,
  due_date date,
  deposit numeric(10,3) not null default 0,
  final_price numeric(10,3) not null default 0,
  status text not null default 'progress'
    check (status in ('pending','progress','done','delivered')),
  notes text,
  created_at timestamptz not null default now(),
  constraint projects_financial_values_nonnegative
    check (deposit >= 0 and final_price >= 0),
  constraint projects_deposit_not_over_final_price
    check (deposit <= final_price)
);

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  appointment_date date not null,
  appointment_time time,
  estimated_amount numeric(10,3) not null default 0
    check (estimated_amount >= 0),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.project_measurements (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  label text not null,
  value numeric(10,2) not null check (value >= 0),
  unit text not null default 'cm',
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.project_photos (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  phase text not null check (phase in ('before','after')),
  position smallint not null check (position between 1 and 4),
  storage_path text not null unique,
  created_at timestamptz not null default now(),
  constraint project_photos_unique_position unique(project_id, phase, position)
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'tv' check (role in ('admin','worker','tv'))
);

create index if not exists projects_client_id_idx on public.projects(client_id);
create index if not exists projects_status_due_date_idx on public.projects(status,due_date);
create index if not exists appointments_client_id_idx on public.appointments(client_id);
create index if not exists appointments_date_idx on public.appointments(appointment_date,appointment_time);
create index if not exists project_measurements_project_id_idx on public.project_measurements(project_id);
create index if not exists project_photos_project_phase_idx on public.project_photos(project_id,phase,position);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id, role) values (new.id, 'tv');
  return new;
end;
$$;

drop trigger if exists on_signup on auth.users;
create trigger on_signup
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.can_write()
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and role in ('admin','worker')
  );
$$;

revoke all on function public.can_write() from public;
grant execute on function public.can_write() to authenticated;

alter table public.clients enable row level security;
alter table public.projects enable row level security;
alter table public.appointments enable row level security;
alter table public.project_measurements enable row level security;
alter table public.project_photos enable row level security;
alter table public.profiles enable row level security;

drop policy if exists staff_read_clients on public.clients;
drop policy if exists staff_write_clients on public.clients;
create policy staff_read_clients on public.clients
  for select to authenticated using ((select public.can_write()));
create policy staff_write_clients on public.clients
  for all to authenticated using ((select public.can_write()))
  with check ((select public.can_write()));

drop policy if exists staff_read_projects on public.projects;
drop policy if exists staff_write_projects on public.projects;
create policy staff_read_projects on public.projects
  for select to authenticated using ((select public.can_write()));
create policy staff_write_projects on public.projects
  for all to authenticated using ((select public.can_write()))
  with check ((select public.can_write()));

drop policy if exists staff_read_appointments on public.appointments;
drop policy if exists staff_write_appointments on public.appointments;
create policy staff_read_appointments on public.appointments
  for select to authenticated using ((select public.can_write()));
create policy staff_write_appointments on public.appointments
  for all to authenticated using ((select public.can_write()))
  with check ((select public.can_write()));

drop policy if exists staff_read_project_measurements on public.project_measurements;
drop policy if exists staff_write_project_measurements on public.project_measurements;
create policy staff_read_project_measurements on public.project_measurements
  for select to authenticated using ((select public.can_write()));
create policy staff_write_project_measurements on public.project_measurements
  for all to authenticated using ((select public.can_write()))
  with check ((select public.can_write()));

drop policy if exists staff_read_project_photos on public.project_photos;
drop policy if exists staff_write_project_photos on public.project_photos;
create policy staff_read_project_photos on public.project_photos
  for select to authenticated using ((select public.can_write()));
create policy staff_write_project_photos on public.project_photos
  for all to authenticated using ((select public.can_write()))
  with check ((select public.can_write()));

drop policy if exists own_profile_read on public.profiles;
create policy own_profile_read on public.profiles
  for select to authenticated using (id = (select auth.uid()));

grant select, insert, update, delete on public.clients to authenticated;
grant select, insert, update, delete on public.projects to authenticated;
grant select, insert, update, delete on public.appointments to authenticated;
grant select, insert, update, delete on public.project_measurements to authenticated;
grant select, insert, update, delete on public.project_photos to authenticated;
grant select on public.profiles to authenticated;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('atelier-project-photos','atelier-project-photos',false,10485760,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public=false,file_size_limit=10485760,
    allowed_mime_types=array['image/jpeg','image/png','image/webp'];

drop policy if exists atelier_staff_read_project_photos on storage.objects;
create policy atelier_staff_read_project_photos on storage.objects
  for select to authenticated
  using (bucket_id='atelier-project-photos' and (select public.can_write()));

drop policy if exists atelier_staff_upload_project_photos on storage.objects;
create policy atelier_staff_upload_project_photos on storage.objects
  for insert to authenticated
  with check (bucket_id='atelier-project-photos' and (select public.can_write()));

drop policy if exists atelier_staff_update_project_photos on storage.objects;
create policy atelier_staff_update_project_photos on storage.objects
  for update to authenticated
  using (bucket_id='atelier-project-photos' and (select public.can_write()))
  with check (bucket_id='atelier-project-photos' and (select public.can_write()));

drop policy if exists atelier_staff_delete_project_photos on storage.objects;
create policy atelier_staff_delete_project_photos on storage.objects
  for delete to authenticated
  using (bucket_id='atelier-project-photos' and (select public.can_write()));

commit;

-- FIRST ADMIN:
-- 1) Create the owner account in Supabase Authentication > Users.
-- 2) Replace the email below and run this separately in SQL Editor:
--
-- update public.profiles
-- set role='admin'
-- where id=(select id from auth.users where lower(email)=lower('OWNER_EMAIL_HERE'));
--
-- Verify the profile role is admin before signing into the app.
