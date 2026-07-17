-- ============================================================================
-- ACTUALIZACIÓN v6 — Rol "consulta" (solo visualización de dashboard)
-- Ejecutar en el SQL Editor de Supabase (después de v1..v5).
-- El usuario con rol 'consulta' puede ver todo (lecturas, alertas, bloques,
-- horómetros, recorridos) pero NO puede registrar, justificar, pausar ni
-- editar nada. El bloqueo es real, a nivel de base de datos.
-- ============================================================================

-- 1. Permitir el nuevo rol en perfiles
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles add constraint perfiles_rol_check
  check (rol in ('operario', 'supervisor', 'administrador', 'consulta'));

-- 2. Bloquear escrituras del rol consulta en lecturas
drop policy if exists lecturas_insert on public.lecturas;
create policy lecturas_insert on public.lecturas for insert
  to authenticated
  with check (
    usuario_id = auth.uid()
    and public.rol_actual() in ('operario','supervisor','administrador')
  );

drop policy if exists lecturas_update on public.lecturas;
create policy lecturas_update on public.lecturas for update
  to authenticated
  using (
    (usuario_id = auth.uid() and fecha = current_date
      and public.rol_actual() in ('operario','supervisor','administrador'))
    or public.rol_actual() in ('supervisor','administrador')
  );

-- 3. Bloquear justificaciones y recorridos del rol consulta
drop policy if exists just_insert on public.justificaciones_bloque;
create policy just_insert on public.justificaciones_bloque for insert
  to authenticated
  with check (
    usuario_id = auth.uid()
    and public.rol_actual() in ('operario','supervisor','administrador')
  );

drop policy if exists rec_insert on public.recorridos;
create policy rec_insert on public.recorridos for insert
  to authenticated
  with check (
    usuario_id = auth.uid()
    and public.rol_actual() in ('operario','supervisor','administrador')
  );

-- Que el usuario de consulta también pueda ver los recorridos en el mapa
drop policy if exists rec_select on public.recorridos;
create policy rec_select on public.recorridos for select
  to authenticated
  using (
    usuario_id = auth.uid()
    or public.rol_actual() in ('supervisor','administrador','consulta')
  );

-- Y la lista de usuarios para el selector del mapa
drop policy if exists perfiles_select on public.perfiles;
create policy perfiles_select on public.perfiles for select
  to authenticated
  using (
    id = auth.uid()
    or public.rol_actual() in ('supervisor','administrador','consulta')
  );

-- 4. Bloquear pausa/reactivación de horómetros para el rol consulta
create or replace function public.alternar_horometro(h_id integer)
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare
  v_nuevo boolean;
begin
  if public.rol_actual() = 'consulta' then
    raise exception 'El usuario de consulta no puede modificar horómetros.';
  end if;
  update public.horometros set activo = not activo where id = h_id
  returning activo into v_nuevo;
  if v_nuevo is null then
    raise exception 'Horómetro no encontrado.';
  end if;
  return v_nuevo;
end;
$$;

-- ============================================================================
-- FIN v6. Luego de ejecutar, crear el usuario en Authentication → Users
-- (ej. dashboard@trigal.local + Auto Confirm) y asignarle el rol:
--   update public.perfiles set rol='consulta', nombre='Visualización'
--   where id = '<uuid-del-usuario>';
-- ============================================================================
