-- ============================================================================
-- ACTUALIZACIÓN v10 — Semáforo de horas entre lecturas (3 niveles)
--   VERDE    : delta >= 2.0 h
--   AMARILLO : 1.5 h <= delta < 2.0 h  (sin observación obligatoria)
--   ROJO     : delta < 1.5 h           (alerta, observación obligatoria)
-- La columna "alerta" ahora significa solo ROJO. El amarillo lo calcula la app.
-- Ejecutar en el SQL Editor de Supabase ANTES de subir el nuevo index.html.
-- La parte del semáforo va en una transacción: si algo falla, no queda nada a medias.
-- Al final quita el informe semanal (si existía) y muestra una verificación.
-- ============================================================================

begin;

create or replace function public.umbral_alerta_horas()
returns numeric language sql immutable as $$ select 1.5::numeric $$;

create or replace function public.calcular_delta_lectura()
returns trigger
language plpgsql
as $$
declare
  v_prev numeric(12,1);
begin
  select valor into v_prev
  from public.lecturas
  where horometro_id = new.horometro_id
    and fecha < new.fecha
    and (tg_op = 'INSERT' or id <> new.id)
  order by fecha desc
  limit 1;

  if v_prev is null then
    new.delta := null;
    new.alerta := false;
  else
    if new.valor < v_prev then
      raise exception 'La lectura (%) no puede ser menor a la anterior (%). El horómetro es acumulativo.', new.valor, v_prev;
    end if;
    new.delta := new.valor - v_prev;
    new.alerta := (new.delta < public.umbral_alerta_horas());
  end if;

  -- Solo el ROJO (< 1.5 h) exige observación; el amarillo (1.5–2.0 h) no.
  if new.alerta and (new.observacion is null or btrim(new.observacion) = '') then
    raise exception 'ALERTA: el registro indica % horas de luz (menor a 1.5 h). Debe escribir una observación.', round(new.delta, 1);
  end if;

  return new;
end;
$$;

-- Recalcular históricos: lo que estaba en alerta con delta entre 1.5 y 2.0 pasa a amarillo
alter table public.lecturas disable trigger trg_calcular_delta;
update public.lecturas set alerta = (delta < 1.5)
where delta is not null and alerta is distinct from (delta < 1.5);
alter table public.lecturas enable trigger trg_calcular_delta;

commit;

-- ----------------------------------------------------------------------------
-- Quitar el informe semanal automático si alguna vez se programó con v9.
-- (Si nunca se programó, este bloque no hace nada.)
-- ----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'informe-semanal-fotoperiodo';
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- VERIFICACIÓN FINAL: las tres columnas deben salir en "true".
-- Si alguna sale "false", ejecute el archivo indicado y vuelva a correr esto.
-- ----------------------------------------------------------------------------
select
  to_regclass('public.lecturas_luz') is not null                                           as "v7_luz_nocturna",
  exists (select 1 from pg_constraint where conname = 'lecturas_luz_unica_por_minuto')     as "v8_antiduplicado_luz",
  public.umbral_alerta_horas() = 1.5                                                       as "v10_semaforo";
