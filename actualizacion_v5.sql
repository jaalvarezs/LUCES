-- ============================================================================
-- ACTUALIZACIÓN v5 — Rangos de naves sin solapamiento + pausa por operarios
-- Ejecutar en el SQL Editor de Supabase (después de v1..v4).
-- 1) El trigger de horómetros ahora valida que los rangos de naves de los
--    horómetros ACTIVOS de un mismo bloque no se solapen.
-- 2) Función alternar_horometro(): permite a cualquier usuario autenticado
--    (incluido el operario) pausar/reactivar un horómetro, sin darle permiso
--    de edición sobre rangos ni nombres.
-- ============================================================================

-- 1. Trigger con validación de solapamiento
create or replace function public.validar_rango_horometro()
returns trigger
language plpgsql
as $$
declare
  v_naves integer;
begin
  select naves into v_naves from public.bloques where id = new.bloque_id;
  if new.nave_hasta > v_naves then
    raise exception 'El bloque solo tiene % naves. El rango debe estar entre 1 y %.', v_naves, v_naves;
  end if;

  -- Sin solapamiento entre horómetros ACTIVOS del mismo bloque
  if new.activo then
    if exists (
      select 1 from public.horometros h
      where h.bloque_id = new.bloque_id
        and h.activo
        and h.id <> coalesce(new.id, -1)
        and h.nave_desde <= new.nave_hasta
        and new.nave_desde <= h.nave_hasta
    ) then
      raise exception 'El rango de naves %–% se solapa con otro horómetro activo del bloque. Ajuste primero el rango del otro horómetro.', new.nave_desde, new.nave_hasta;
    end if;
  end if;

  return new;
end;
$$;

-- 2. Pausar/reactivar horómetro (cualquier usuario autenticado)
create or replace function public.alternar_horometro(h_id integer)
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare
  v_nuevo boolean;
begin
  update public.horometros set activo = not activo where id = h_id
  returning activo into v_nuevo;
  if v_nuevo is null then
    raise exception 'Horómetro no encontrado.';
  end if;
  return v_nuevo;
end;
$$;

grant execute on function public.alternar_horometro(integer) to authenticated;

-- ============================================================================
-- FIN v5
-- ============================================================================
