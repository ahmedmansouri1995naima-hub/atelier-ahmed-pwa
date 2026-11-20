-- Atelier Ahmed — unified client registration and customer PDF
-- Apply manually in Supabase SQL Editor after reviewing this migration.
-- This migration preserves existing client/project records.

begin;

create sequence if not exists public.client_number_seq start with 1;

alter table public.clients
  add column if not exists client_number bigint,
  add column if not exists source text;

-- Assign stable sequential numbers to existing clients, oldest first.
with numbered as (
  select id, row_number() over (order by created_at asc, id asc) as rn
  from public.clients
  where client_number is null
)
update public.clients c
set client_number = numbered.rn
from numbered
where c.id = numbered.id;

select setval(
  'public.client_number_seq',
  greatest(coalesce((select max(client_number) from public.clients), 0), 1),
  coalesce((select max(client_number) from public.clients), 0) > 0
);

alter table public.clients
  alter column client_number set default nextval('public.client_number_seq'),
  alter column client_number set not null;

create unique index if not exists clients_client_number_uidx
  on public.clients(client_number);

grant usage, select on sequence public.client_number_seq to authenticated;

alter table public.projects
  alter column start_date drop not null,
  add column if not exists pickup_date date,
  add column if not exists pickup_time time,
  add column if not exists ready_time time;

-- New registrations create the client and its first scheduled project atomically.
create or replace function public.create_client_with_project(
  p_name text,
  p_phone text,
  p_address text,
  p_email text,
  p_source text,
  p_internal_notes text,
  p_service text,
  p_pickup_date date,
  p_pickup_time time,
  p_ready_date date,
  p_ready_time time,
  p_final_price numeric,
  p_deposit numeric
)
returns table(client_id uuid, project_id uuid, client_number bigint)
language plpgsql
set search_path = ''
as $$
declare
  v_client_id uuid;
  v_project_id uuid;
  v_client_number bigint;
begin
  if not public.can_write() then
    raise exception 'Accès non autorisé.';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'Le nom du client est obligatoire.';
  end if;
  if p_pickup_date is null or p_pickup_time is null
     or p_ready_date is null or p_ready_time is null then
    raise exception 'Les deux dates et heures sont obligatoires.';
  end if;
  if (p_ready_date, p_ready_time) < (p_pickup_date, p_pickup_time) then
    raise exception 'La disponibilité ne peut pas précéder la récupération.';
  end if;
  if p_final_price is null or p_deposit is null
     or p_final_price < 0 or p_deposit < 0
     or p_deposit > p_final_price then
    raise exception 'Vérifiez le prix total et l’acompte.';
  end if;

  insert into public.clients as new_client(name, phone, address, email, source, notes)
  values (
    trim(p_name),
    nullif(trim(coalesce(p_phone, '')), ''),
    nullif(trim(coalesce(p_address, '')), ''),
    nullif(trim(coalesce(p_email, '')), ''),
    nullif(trim(coalesce(p_source, '')), ''),
    nullif(trim(coalesce(p_internal_notes, '')), '')
  )
  returning new_client.id, new_client.client_number
  into v_client_id, v_client_number;

  insert into public.projects(
    client_id, service, start_date, due_date, pickup_date, pickup_time,
    ready_time, final_price, deposit, status, notes
  )
  values (
    v_client_id,
    coalesce(nullif(trim(coalesce(p_service, '')), ''), 'Travail à définir'),
    null,
    p_ready_date,
    p_pickup_date,
    p_pickup_time,
    p_ready_time,
    p_final_price,
    p_deposit,
    'pending',
    null
  )
  returning id into v_project_id;

  return query select v_client_id, v_project_id, v_client_number;
end;
$$;

grant execute on function public.create_client_with_project(
  text,text,text,text,text,text,text,date,time,date,time,numeric,numeric
) to authenticated;

commit;
