-- ============================================================================
-- ACTUALIZACIÓN v4 — Supervisores ven la lista de usuarios
-- Ejecutar en el SQL Editor de Supabase (después de v1, v2 y v3).
-- Necesario para que el supervisor pueda elegir el operario en el mapa
-- de recorridos del dashboard. (Antes solo el administrador veía perfiles.)
-- ============================================================================

drop policy if exists perfiles_select on public.perfiles;
create policy perfiles_select on public.perfiles for select
  to authenticated
  using (
    id = auth.uid()
    or public.rol_actual() in ('supervisor','administrador')
  );

-- ============================================================================
-- FIN v4
-- ============================================================================
