-- ============================================================================
-- ACTUALIZACIÓN v2 — HORÓMETROS FOTOPERIODO
-- Ejecutar DESPUÉS de horometros_schema.sql, en el SQL Editor de Supabase.
-- Agrega: coordenadas GPS por bloque, justificaciones de bloques no
-- recorridos, y seguimiento de ubicación del operario.
-- ============================================================================

-- 1. Coordenadas GPS de cada bloque (se capturan desde la app parado en el bloque)
alter table public.bloques
  add column if not exists lat double precision,
  add column if not exists lng double precision;

-- 2. Justificaciones: si un bloque no se recorrió en el día, se registra el motivo
create table if not exists public.justificaciones_bloque (
  id bigserial primary key,
  bloque_id integer not null references public.bloques(id) on delete restrict,
  fecha date not null,
  motivo text not null check (btrim(motivo) <> ''),
  usuario_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  constraint justificacion_unica unique (bloque_id, fecha)
);

-- 3. Recorridos: posiciones GPS del operario (se registra al guardar lecturas
--    y en pings periódicos mientras la app está abierta)
create table if not exists public.recorridos (
  id bigserial primary key,
  usuario_id uuid not null references auth.users(id),
  lat double precision not null,
  lng double precision not null,
  precision_m numeric(8,1),
  evento text not null default 'ping'    -- 'ping' | 'lectura' | 'justificacion'
    check (evento in ('ping','lectura','justificacion')),
  registrado_en timestamptz not null default now()
);

create index if not exists idx_recorridos_usuario_fecha
  on public.recorridos (usuario_id, registrado_en desc);

-- 4. RLS + GRANTS
alter table public.justificaciones_bloque enable row level security;
alter table public.recorridos enable row level security;

grant select, insert on public.justificaciones_bloque to authenticated;
grant select, insert on public.recorridos to authenticated;
grant usage, select on all sequences in schema public to authenticated;

drop policy if exists just_select on public.justificaciones_bloque;
create policy just_select on public.justificaciones_bloque for select
  to authenticated using (true);

drop policy if exists just_insert on public.justificaciones_bloque;
create policy just_insert on public.justificaciones_bloque for insert
  to authenticated with check (usuario_id = auth.uid());

drop policy if exists rec_insert on public.recorridos;
create policy rec_insert on public.recorridos for insert
  to authenticated with check (usuario_id = auth.uid());

-- Los recorridos los ve el propio usuario; supervisor/admin ven todos
drop policy if exists rec_select on public.recorridos;
create policy rec_select on public.recorridos for select
  to authenticated
  using (usuario_id = auth.uid() or public.rol_actual() in ('supervisor','administrador'));

-- 5. Vista: estado del día por bloque (registrado / justificado / pendiente)
create or replace view public.v_estado_dia as
select
  b.id as bloque_id,
  b.codigo,
  d.fecha,
  exists (
    select 1 from public.lecturas l
    join public.horometros h on h.id = l.horometro_id
    where h.bloque_id = b.id and l.fecha = d.fecha
  ) as registrado,
  exists (
    select 1 from public.justificaciones_bloque j
    where j.bloque_id = b.id and j.fecha = d.fecha
  ) as justificado
from public.bloques b
cross join (select current_date as fecha) d
where b.activo;

grant select on public.v_estado_dia to authenticated;

-- ============================================================================
-- FIN v2
-- ============================================================================
