-- ============================================================================
-- ACTUALIZACIÓN v7 — LECTURAS DE LUZ NOCTURNA
-- Ejecutar en el SQL Editor de Supabase (después de v1..v6).
-- Valor de referencia: 1.5 µmol/m²/s (mínimo esperado en cada punto).
-- Registran: operario, supervisor y administrador. Consulta solo visualiza.
-- ============================================================================

create table if not exists public.lecturas_luz (
  id bigserial primary key,
  bloque_id integer not null references public.bloques(id) on delete restrict,
  cama integer not null check (cama > 0),
  lado text not null check (lado in ('A','B')),
  medido_en timestamptz not null default now(),
  anterior numeric(6,2) not null check (anterior >= 0),
  posterior numeric(6,2) not null check (posterior >= 0),
  bajo_bombillo numeric(6,2) not null check (bajo_bombillo >= 0),
  entre_bombillo numeric(6,2) not null check (entre_bombillo >= 0),
  borde numeric(6,2) not null check (borde >= 0),
  bajo_umbral boolean not null default false,
  observacion text,
  usuario_id uuid not null references public.perfiles(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_lecturas_luz_bloque_fecha on public.lecturas_luz (bloque_id, medido_en desc);
create index if not exists idx_lecturas_luz_bajo_umbral on public.lecturas_luz (bajo_umbral) where bajo_umbral = true;

create or replace function public.umbral_luz_minimo()
returns numeric language sql immutable as $$ select 1.5::numeric $$;

create or replace function public.calcular_bajo_umbral_luz()
returns trigger
language plpgsql
as $$
begin
  new.bajo_umbral := (
    new.anterior < public.umbral_luz_minimo() or
    new.posterior < public.umbral_luz_minimo() or
    new.bajo_bombillo < public.umbral_luz_minimo() or
    new.entre_bombillo < public.umbral_luz_minimo() or
    new.borde < public.umbral_luz_minimo()
  );
  if new.bajo_umbral and (new.observacion is null or btrim(new.observacion) = '') then
    raise exception 'Hay lecturas por debajo de %.1f µmol/m²/s. Debe escribir una observación.', public.umbral_luz_minimo();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_bajo_umbral_luz on public.lecturas_luz;
create trigger trg_bajo_umbral_luz
  before insert or update on public.lecturas_luz
  for each row execute function public.calcular_bajo_umbral_luz();

alter table public.lecturas_luz enable row level security;
grant select, insert on public.lecturas_luz to authenticated;
grant usage, select on all sequences in schema public to authenticated;

drop policy if exists luz_select on public.lecturas_luz;
create policy luz_select on public.lecturas_luz for select
  to authenticated using (true);

drop policy if exists luz_insert on public.lecturas_luz;
create policy luz_insert on public.lecturas_luz for insert
  to authenticated
  with check (usuario_id = auth.uid() and public.rol_actual() in ('operario','supervisor','administrador'));

-- ============================================================================
-- FIN v7
-- ============================================================================
