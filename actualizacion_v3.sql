-- ============================================================================
-- ACTUALIZACIÓN v3 — Permisos de bloques para supervisores
-- Ejecutar en el SQL Editor de Supabase (después de v1 y v2).
-- Antes: solo el administrador podía crear/editar bloques.
-- Ahora: supervisor y administrador crean y editan; solo el admin elimina.
-- ============================================================================

drop policy if exists bloques_admin_write on public.bloques;

drop policy if exists bloques_insert on public.bloques;
create policy bloques_insert on public.bloques for insert
  to authenticated
  with check (public.rol_actual() in ('supervisor','administrador'));

drop policy if exists bloques_update on public.bloques;
create policy bloques_update on public.bloques for update
  to authenticated
  using (public.rol_actual() in ('supervisor','administrador'));

drop policy if exists bloques_delete on public.bloques;
create policy bloques_delete on public.bloques for delete
  to authenticated
  using (public.rol_actual() = 'administrador');

grant delete on public.bloques to authenticated;

-- ============================================================================
-- FIN v3
-- ============================================================================
