-- ============================================================================
-- SISTEMA DE SEGUIMIENTO DE HORÓMETROS — ILUMINACIÓN POR FOTOPERIODO
-- Flores El Trigal S.A.S.
-- Base de datos: Supabase / PostgreSQL
-- Ejecutar completo en: SQL Editor de Supabase
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABLA DE PERFILES (roles de usuario)
--    El usuario se crea en Authentication de Supabase; el perfil se genera
--    automáticamente con rol 'operario'. El administrador cambia el rol aquí.
-- ----------------------------------------------------------------------------
create table if not exists public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null default '',
  rol text not null default 'operario'
    check (rol in ('operario', 'supervisor', 'administrador')),
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

-- Trigger: crear perfil automáticamente al registrar usuario en Auth
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre, rol)
  values (new.id, coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email,'@',1)), 'operario')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Función auxiliar: rol del usuario autenticado (evita recursión en RLS)
create or replace function public.rol_actual()
returns text
language sql
security definer set search_path = public
stable
as $$
  select rol from public.perfiles where id = auth.uid();
$$;

-- ----------------------------------------------------------------------------
-- 2. TABLA DE BLOQUES
-- ----------------------------------------------------------------------------
create table if not exists public.bloques (
  id serial primary key,
  codigo text not null unique,          -- '1', '2', ... '15-1', '15-2'
  naves integer not null check (naves > 0),
  medias_naves numeric(4,1) not null default 0,
  activo boolean not null default true
);

-- ----------------------------------------------------------------------------
-- 3. TABLA DE HORÓMETROS
--    Cada bloque tiene 1 o más horómetros. Al crear uno nuevo se indica el
--    rango de naves que cubre (desde–hasta), validado contra el bloque.
-- ----------------------------------------------------------------------------
create table if not exists public.horometros (
  id serial primary key,
  bloque_id integer not null references public.bloques(id) on delete restrict,
  nombre text not null,                 -- ej. 'H1', 'H2 refuerzo'
  nave_desde integer not null check (nave_desde >= 1),
  nave_hasta integer not null,
  activo boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  constraint rango_valido check (nave_hasta >= nave_desde),
  constraint horometro_unico_por_bloque unique (bloque_id, nombre)
);

-- Trigger: validar que el rango de naves no supere las naves del bloque
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
  return new;
end;
$$;

drop trigger if exists trg_validar_rango on public.horometros;
create trigger trg_validar_rango
  before insert or update on public.horometros
  for each row execute function public.validar_rango_horometro();

-- ----------------------------------------------------------------------------
-- 4. TABLA DE LECTURAS
--    Una lectura por horómetro por fecha. El trigger calcula el delta contra
--    la lectura anterior y marca alerta si delta < 2 horas. Si hay alerta,
--    la observación es OBLIGATORIA.
-- ----------------------------------------------------------------------------
create table if not exists public.lecturas (
  id bigserial primary key,
  horometro_id integer not null references public.horometros(id) on delete restrict,
  fecha date not null,
  valor numeric(12,1) not null check (valor >= 0),   -- valor acumulado del horómetro
  delta numeric(12,1),                                -- horas desde la lectura anterior (calculado)
  alerta boolean not null default false,              -- true si delta < 2 h (calculado)
  observacion text,
  usuario_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  constraint lectura_unica_por_dia unique (horometro_id, fecha)
);

create index if not exists idx_lecturas_horometro_fecha on public.lecturas (horometro_id, fecha desc);
create index if not exists idx_lecturas_alerta on public.lecturas (alerta) where alerta = true;

-- Umbral de alerta (horas mínimas esperadas entre lecturas consecutivas)
create or replace function public.umbral_alerta_horas()
returns numeric language sql immutable as $$ select 2.0::numeric $$;

-- Trigger: calcular delta, marcar alerta y exigir observación
create or replace function public.calcular_delta_lectura()
returns trigger
language plpgsql
as $$
declare
  v_prev numeric(12,1);
begin
  -- Lectura anterior más reciente del mismo horómetro
  select valor into v_prev
  from public.lecturas
  where horometro_id = new.horometro_id
    and fecha < new.fecha
    and (tg_op = 'INSERT' or id <> new.id)
  order by fecha desc
  limit 1;

  if v_prev is null then
    -- Primera lectura del horómetro: sin delta ni alerta
    new.delta := null;
    new.alerta := false;
  else
    if new.valor < v_prev then
      raise exception 'La lectura (%) no puede ser menor a la anterior (%). El horómetro es acumulativo.', new.valor, v_prev;
    end if;
    new.delta := new.valor - v_prev;
    new.alerta := (new.delta < public.umbral_alerta_horas());
  end if;

  -- Si hay alerta, la observación es obligatoria
  if new.alerta and (new.observacion is null or btrim(new.observacion) = '') then
    raise exception 'ALERTA: el registro indica %.1f horas de luz (menor a 2 h). Debe escribir una observación.', new.delta;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_calcular_delta on public.lecturas;
create trigger trg_calcular_delta
  before insert or update on public.lecturas
  for each row execute function public.calcular_delta_lectura();

-- ----------------------------------------------------------------------------
-- 5. SEGURIDAD: RLS + GRANTS
--    Nota: desde mayo 2026 Supabase exige GRANTs explícitos para exponer
--    tablas por la API, además de las políticas RLS.
-- ----------------------------------------------------------------------------
alter table public.perfiles   enable row level security;
alter table public.bloques    enable row level security;
alter table public.horometros enable row level security;
alter table public.lecturas   enable row level security;

-- GRANTS explícitos
grant usage on schema public to authenticated, anon;
grant select on public.perfiles, public.bloques, public.horometros, public.lecturas to authenticated;
grant insert, update on public.lecturas to authenticated;
grant insert, update on public.horometros to authenticated;
grant update on public.perfiles to authenticated;
grant insert, update on public.bloques to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- PERFILES: cada quien ve el suyo; el admin ve y edita todos
drop policy if exists perfiles_select on public.perfiles;
create policy perfiles_select on public.perfiles for select
  to authenticated
  using (id = auth.uid() or public.rol_actual() = 'administrador');

drop policy if exists perfiles_update_admin on public.perfiles;
create policy perfiles_update_admin on public.perfiles for update
  to authenticated
  using (public.rol_actual() = 'administrador');

-- BLOQUES: todos leen; solo administrador modifica
drop policy if exists bloques_select on public.bloques;
create policy bloques_select on public.bloques for select
  to authenticated using (true);

drop policy if exists bloques_admin_write on public.bloques;
create policy bloques_admin_write on public.bloques for all
  to authenticated
  using (public.rol_actual() = 'administrador')
  with check (public.rol_actual() = 'administrador');

-- HORÓMETROS: todos leen; supervisor y administrador crean/editan
drop policy if exists horometros_select on public.horometros;
create policy horometros_select on public.horometros for select
  to authenticated using (true);

drop policy if exists horometros_insert on public.horometros;
create policy horometros_insert on public.horometros for insert
  to authenticated
  with check (public.rol_actual() in ('supervisor','administrador'));

drop policy if exists horometros_update on public.horometros;
create policy horometros_update on public.horometros for update
  to authenticated
  using (public.rol_actual() in ('supervisor','administrador'));

-- LECTURAS: todos leen; cualquier usuario autenticado registra (operario+).
-- Solo puede editar su propia lectura del día; supervisor/admin editan cualquiera.
drop policy if exists lecturas_select on public.lecturas;
create policy lecturas_select on public.lecturas for select
  to authenticated using (true);

drop policy if exists lecturas_insert on public.lecturas;
create policy lecturas_insert on public.lecturas for insert
  to authenticated
  with check (usuario_id = auth.uid());

drop policy if exists lecturas_update on public.lecturas;
create policy lecturas_update on public.lecturas for update
  to authenticated
  using (
    (usuario_id = auth.uid() and fecha = current_date)
    or public.rol_actual() in ('supervisor','administrador')
  );

-- ----------------------------------------------------------------------------
-- 6. SEED: 50 BLOQUES (según documento BLOQUES.pdf)
-- ----------------------------------------------------------------------------
insert into public.bloques (codigo, naves, medias_naves) values
  ('1', 12, 0), ('2', 13, 0), ('3', 14, 0), ('4', 12, 2), ('5', 13, 0),
  ('6', 14, 1), ('7', 16, 1), ('8', 19, 0), ('9', 20, 0), ('10', 21, 1),
  ('11', 22, 1), ('12', 24, 0), ('13', 25, 0), ('14', 26, 1),
  ('15-1', 8, 0), ('15-2', 10, 0),
  ('16', 17, 0), ('17', 12, 0), ('18', 12, 0), ('19', 12, 0), ('20', 12, 0),
  ('21', 11, 0), ('22', 16, 0), ('23', 12, 0), ('24', 12, 0), ('25', 12, 0),
  ('26', 12, 0), ('27', 11, 0), ('28', 12, 6), ('29', 12, 0), ('30', 12, 0),
  ('31', 12, 0), ('32', 6, 0), ('33', 12, 0), ('34', 12, 0), ('35', 12, 0),
  ('36', 8, 0), ('37', 12, 0), ('38', 12, 0), ('39', 12, 0.5), ('40', 18, 0.5),
  ('41', 10, 0), ('42', 9, 1), ('43', 8, 0), ('44', 10, 0), ('45', 11, 0),
  ('46', 12, 0), ('47', 10, 1), ('48', 18, 7), ('49', 8, 5), ('50', 6, 13)
on conflict (codigo) do nothing;

-- Horómetro principal por defecto en cada bloque (nave 1 hasta la última)
insert into public.horometros (bloque_id, nombre, nave_desde, nave_hasta)
select b.id, 'H1', 1, b.naves
from public.bloques b
where not exists (
  select 1 from public.horometros h where h.bloque_id = b.id and h.nombre = 'H1'
);

-- ----------------------------------------------------------------------------
-- 7. VISTA DE APOYO: última lectura por horómetro (para la app)
-- ----------------------------------------------------------------------------
create or replace view public.v_ultima_lectura as
select distinct on (l.horometro_id)
  l.horometro_id, l.fecha, l.valor, l.delta, l.alerta
from public.lecturas l
order by l.horometro_id, l.fecha desc;

grant select on public.v_ultima_lectura to authenticated;

-- ============================================================================
-- FIN. Pasos siguientes:
-- 1) Crear usuarios en Authentication → Users (email + contraseña).
-- 2) Asignar roles: update public.perfiles set rol='administrador' where id='<uuid>';
-- 3) Copiar URL y anon key del proyecto en la sección CONFIG de la app HTML.
-- ============================================================================
