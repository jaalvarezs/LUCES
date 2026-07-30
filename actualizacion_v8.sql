-- ============================================================================
-- ACTUALIZACIÓN v8 — Evitar duplicados accidentales en luz nocturna
-- Ejecutar en el SQL Editor de Supabase (después de v1..v7).
--
-- No impide volver a medir la misma cama más tarde (basta con que la hora
-- registrada sea distinta, aunque sea un minuto después) — solo evita que
-- un doble toque en "Guardar" o un reintento de sincronización creen dos
-- filas idénticas para el mismo bloque, cama, lado y minuto exacto.
-- ============================================================================

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'lecturas_luz_unica_por_minuto'
  ) then
    alter table public.lecturas_luz
      add constraint lecturas_luz_unica_por_minuto unique (bloque_id, cama, lado, medido_en);
  end if;
end $$;

-- ============================================================================
-- FIN v8. Si este paso falla con "could not create unique index... duplicate
-- key" significa que ya existen registros duplicados de pruebas anteriores.
-- En ese caso avísame y los identificamos con:
--   select bloque_id, cama, lado, medido_en, count(*)
--   from public.lecturas_luz group by 1,2,3,4 having count(*) > 1;
-- ============================================================================
