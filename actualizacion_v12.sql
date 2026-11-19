-- ============================================================================
-- ACTUALIZACIÓN v12 — Saltos de lectura, inicio de siembra, noches de luz,
--                     bancos y novedades del sistema eléctrico
--
--  1. lecturas.dias_desde_anterior : días entre esta lectura y la anterior
--     (la calcula la base de datos).
--  2. lecturas.inicio_siembra      : el operario confirmó que un salto de varios
--     días corresponde al inicio de la siembra. Desde esa lectura se cuentan
--     las noches de luz del cultivo.
--  3. bloques.es_banco             : los bancos no se cuentan a 2 h por noche.
--  4. Vista v_noches_horometro     : horas y noches de luz por horómetro desde
--     el último inicio de siembra (o desde la primera lectura si no hay).
--  5. Tabla novedades_electricas   : lo que el operario ve en el sistema
--     eléctrico de un bloque al medir la luz. Aparece en "Pendientes" desde
--     las 6:00 a. m. siguientes para que se intervenga.
--
-- Ejecutar en el SQL Editor de Supabase ANTES de subir el nuevo index.html.
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1 y 2. Lecturas
-- ----------------------------------------------------------------------------
alter table public.lecturas add column if not exists dias_desde_anterior integer;
alter table public.lecturas add column if not exists inicio_siembra boolean not null default false;

create or replace function public.calcular_delta_lectura()
returns trigger
language plpgsql
as $$
declare
  v_prev numeric(12,1);
  v_prev_fecha date;
begin
  select valor, fecha into v_prev, v_prev_fecha
  from public.lecturas
  where horometro_id = new.horometro_id
    and fecha < new.fecha
    and (tg_op = 'INSERT' or id <> new.id)
  order by fecha desc
  limit 1;

  if v_prev is null then
    new.delta := null;
    new.alerta := false;
    new.dias_desde_anterior := null;
  else
    if new.valor < v_prev then
      raise exception 'La lectura (%) no puede ser menor a la anterior (%). El horómetro es acumulativo.', new.valor, v_prev;
    end if;
    new.delta := new.valor - v_prev;
    new.alerta := (new.delta < public.umbral_alerta_horas());
    new.dias_desde_anterior := new.fecha - v_prev_fecha;
  end if;

  -- Solo el ROJO (< 1.5 h) exige observación; el amarillo (1.5–2.0 h) no.
  if new.alerta and (new.observacion is null or btrim(new.observacion) = '') then
    raise exception 'ALERTA: el registro indica % horas de luz (menor a 1.5 h). Debe escribir una observación.', round(new.delta, 1);
  end if;

  return new;
end;
$$;

-- Días desde la anterior para las lecturas que ya existen
alter table public.lecturas disable trigger trg_calcular_delta;
with d as (
  select id, fecha - lag(fecha) over (partition by horometro_id order by fecha) as dias
  from public.lecturas
)
update public.lecturas l set dias_desde_anterior = d.dias
from d where d.id = l.id and l.dias_desde_anterior is distinct from d.dias;
alter table public.lecturas enable trigger trg_calcular_delta;

-- ----------------------------------------------------------------------------
-- 3. Bancos
-- ----------------------------------------------------------------------------
alter table public.bloques add column if not exists es_banco boolean not null default false;
update public.bloques set es_banco = true where codigo ilike '%banco%' and not es_banco;

-- ----------------------------------------------------------------------------
-- 4. Noches de luz por horómetro
--    horas = última lectura − valor antes del último inicio de siembra
--    (incluye las horas del salto). Sin inicio de siembra: desde la primera lectura.
-- ----------------------------------------------------------------------------
drop view if exists public.v_noches_horometro;
create view public.v_noches_horometro with (security_invoker = true) as
with ult as (
  select distinct on (horometro_id) horometro_id, fecha as ultima_fecha, valor as ultimo_valor
  from public.lecturas order by horometro_id, fecha desc
), sie as (
  select distinct on (horometro_id) horometro_id, fecha as fecha_siembra,
         valor - coalesce(delta, 0) as base_siembra
  from public.lecturas where inicio_siembra order by horometro_id, fecha desc
), pri as (
  select distinct on (horometro_id) horometro_id, fecha as primera_fecha, valor as primer_valor
  from public.lecturas order by horometro_id, fecha asc
)
select u.horometro_id,
       u.ultima_fecha,
       u.ultimo_valor,
       (s.horometro_id is not null)                 as desde_siembra,
       coalesce(s.fecha_siembra, p.primera_fecha)   as desde_fecha,
       round(u.ultimo_valor - coalesce(s.base_siembra, p.primer_valor), 1) as horas
from ult u
join pri p using (horometro_id)
left join sie s using (horometro_id);

grant select on public.v_noches_horometro to authenticated;

-- ----------------------------------------------------------------------------
-- 5. Novedades del sistema eléctrico
-- ----------------------------------------------------------------------------
create table if not exists public.novedades_electricas (
  id                bigserial primary key,
  id_cliente        text unique,                       -- evita duplicados al sincronizar sin red
  bloque_id         integer not null references public.bloques(id) on delete restrict,
  descripcion       text not null check (btrim(descripcion) <> ''),
  reportado_por     uuid not null default auth.uid() references auth.users(id),
  reportado_nombre  text,                              -- lo llena la base (el operario no puede leer otros perfiles)
  reportado_en      timestamptz not null default now(),
  estado            text not null default 'pendiente' check (estado in ('pendiente','intervenida')),
  intervenida_por   uuid references auth.users(id),
  intervenida_nombre text,
  intervenida_en    timestamptz,
  nota_intervencion text,
  created_at        timestamptz not null default now(),
  constraint novedad_cierre_completo check (
    estado = 'pendiente'
    or (intervenida_por is not null and intervenida_en is not null and btrim(coalesce(nota_intervencion, '')) <> '')
  )
);

-- Nombres de quien reporta / interviene: se copian de perfiles al guardar, porque la
-- política de perfiles no deja que un operario lea el nombre de sus compañeros.
create or replace function public.novedad_nombres()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.reportado_nombre := (select nombre from public.perfiles where id = new.reportado_por);
    if new.intervenida_por is not null then
      new.intervenida_nombre := (select nombre from public.perfiles where id = new.intervenida_por);
    end if;
  else
    new.reportado_nombre := old.reportado_nombre;   -- no se puede cambiar desde la app
    if new.intervenida_por is distinct from old.intervenida_por then
      new.intervenida_nombre := (select nombre from public.perfiles where id = new.intervenida_por);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_novedad_nombres on public.novedades_electricas;
create trigger trg_novedad_nombres
  before insert or update on public.novedades_electricas
  for each row execute function public.novedad_nombres();

create index if not exists idx_novedades_pendientes
  on public.novedades_electricas (estado, reportado_en);

alter table public.novedades_electricas enable row level security;
grant select, insert, update on public.novedades_electricas to authenticated;
grant usage, select on all sequences in schema public to authenticated;

drop policy if exists nov_select on public.novedades_electricas;
create policy nov_select on public.novedades_electricas for select
  to authenticated using (true);

drop policy if exists nov_insert on public.novedades_electricas;
create policy nov_insert on public.novedades_electricas for insert
  to authenticated
  with check (reportado_por = auth.uid() and public.rol_actual() in ('operario','supervisor','administrador'));

-- Cerrar (marcar intervenida): operario, supervisor o administrador
drop policy if exists nov_update on public.novedades_electricas;
create policy nov_update on public.novedades_electricas for update
  to authenticated
  using (public.rol_actual() in ('operario','supervisor','administrador'))
  with check (public.rol_actual() in ('operario','supervisor','administrador'));

commit;

-- ============================================================================
-- VERIFICACIÓN: las cuatro columnas deben salir en "true".
-- ============================================================================
select
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='lecturas' and column_name='inicio_siembra') as "lecturas_siembra",
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='bloques'  and column_name='es_banco')       as "bloques_banco",
  to_regclass('public.v_noches_horometro')   is not null as "vista_noches",
  to_regclass('public.novedades_electricas') is not null as "novedades_electricas";

-- Para marcar bancos a mano (si su código no dice "banco"):
--   update public.bloques set es_banco = true where codigo in ('51','52');
-- O desde la app: pestaña Bloques → botón "Banco".
