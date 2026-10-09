-- ============================================================================
-- ACTUALIZACIÓN v11 — Nuevo protocolo de medición de luz nocturna
--
-- Protocolo:
--   * Punto de medición: intermedio entre dos guirnaldas y entre cuatro
--     bombillas (sitio más oscuro de la cama).
--   * 3 mediciones por cama: INICIO, MITAD y FINAL.
--   * 2 mediciones adicionales: ENTRE DOS GUIRNALDAS y ENTRE CUATRO BOMBILLOS.
--   * Sensor horizontal, con extensor (quien mide no hace sombra),
--     a la altura del dosel de las plantas.
--
-- Referencia mínima en cada punto (≈ 10 foot-candles):
--   * PRODUCCIÓN  : 1.2 µmol/m²/s
--   * PROPAGACIÓN : 1.5 µmol/m²/s
--
-- Las lecturas antiguas (5 puntos: anterior, posterior, bajo bombillo, entre
-- bombillo, borde) se CONSERVAN tal cual, con su referencia de 1.5.
-- Los registros viejos que estén en cola en algún equipo también se aceptan.
--
-- Ejecutar en el SQL Editor de Supabase ANTES de subir el nuevo index.html.
-- Se puede ejecutar más de una vez sin dañar nada (si ya ejecutó la versión
-- anterior de este archivo, ejecútelo de nuevo: solo agrega los 2 puntos nuevos).
-- ============================================================================

begin;

-- 1) Columnas nuevas
alter table public.lecturas_luz add column if not exists tipo_cultivo text;
alter table public.lecturas_luz add column if not exists referencia  numeric(4,2);
alter table public.lecturas_luz add column if not exists inicio      numeric(6,2);
alter table public.lecturas_luz add column if not exists mitad       numeric(6,2);
alter table public.lecturas_luz add column if not exists final       numeric(6,2);
alter table public.lecturas_luz add column if not exists entre_guirnaldas       numeric(6,2);
alter table public.lecturas_luz add column if not exists entre_cuatro_bombillos numeric(6,2);

-- 2) Los 5 puntos antiguos dejan de ser obligatorios (solo aplican a registros viejos)
alter table public.lecturas_luz alter column anterior       drop not null;
alter table public.lecturas_luz alter column posterior      drop not null;
alter table public.lecturas_luz alter column bajo_bombillo  drop not null;
alter table public.lecturas_luz alter column entre_bombillo drop not null;
alter table public.lecturas_luz alter column borde          drop not null;

-- 3) Reglas de consistencia: o es una lectura nueva (tipo + 3 puntos) o una antigua (5 puntos)
alter table public.lecturas_luz drop constraint if exists lecturas_luz_tipo_valido;
alter table public.lecturas_luz add constraint lecturas_luz_tipo_valido
  check (tipo_cultivo is null or tipo_cultivo in ('produccion','propagacion'));

alter table public.lecturas_luz drop constraint if exists lecturas_luz_puntos_validos;
alter table public.lecturas_luz add constraint lecturas_luz_puntos_validos
  check ((inicio is null or (inicio >= 0 and mitad >= 0 and final >= 0))
     and (entre_guirnaldas is null or entre_guirnaldas >= 0)
     and (entre_cuatro_bombillos is null or entre_cuatro_bombillos >= 0));

alter table public.lecturas_luz drop constraint if exists lecturas_luz_formato_valido;
alter table public.lecturas_luz add constraint lecturas_luz_formato_valido check (
  (tipo_cultivo is not null and inicio is not null and mitad is not null and final is not null)
  or
  (tipo_cultivo is null and anterior is not null and posterior is not null
   and bajo_bombillo is not null and entre_bombillo is not null and borde is not null)
);

-- 4) Referencia según el tipo de cama
create or replace function public.referencia_luz(p_tipo text)
returns numeric language sql immutable as $$
  select case p_tipo
           when 'propagacion' then 1.5
           when 'produccion'  then 1.2
           else 1.5                      -- registros antiguos (5 puntos)
         end::numeric
$$;

-- 5) Trigger: fija la referencia, marca "bajo referencia" y exige observación
create or replace function public.calcular_bajo_umbral_luz()
returns trigger
language plpgsql
as $$
begin
  new.referencia := public.referencia_luz(new.tipo_cultivo);

  if new.tipo_cultivo is not null then
    -- Protocolo nuevo: inicio, mitad, final + entre guirnaldas + entre cuatro bombillos
    -- (least() ignora los vacíos, por si llega un registro de la versión de 3 puntos)
    new.bajo_umbral := least(new.inicio, new.mitad, new.final,
                             new.entre_guirnaldas, new.entre_cuatro_bombillos) < new.referencia;
  else
    -- Formato antiguo: 5 puntos
    new.bajo_umbral := least(new.anterior, new.posterior, new.bajo_bombillo,
                             new.entre_bombillo, new.borde) < new.referencia;
  end if;

  if new.bajo_umbral and (new.observacion is null or btrim(new.observacion) = '') then
    raise exception 'Hay mediciones por debajo de % µmol/m²/s. Debe escribir una observación.', new.referencia;
  end if;
  return new;
end;
$$;

-- 6) Registros antiguos: dejar anotada la referencia con la que se evaluaron (1.5)
update public.lecturas_luz set referencia = 1.5 where referencia is null;

commit;

-- ============================================================================
-- VERIFICACIÓN: debe salir "true" en las tres columnas.
-- ============================================================================
select
  public.referencia_luz('produccion')  = 1.2 as "produccion_1_2",
  public.referencia_luz('propagacion') = 1.5 as "propagacion_1_5",
  (select count(*) = 2 from information_schema.columns
    where table_schema = 'public' and table_name = 'lecturas_luz'
      and column_name in ('entre_guirnaldas','entre_cuatro_bombillos')) as "puntos_adicionales";
