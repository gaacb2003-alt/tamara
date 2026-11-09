-- =====================================================================
-- Constanza · Asistente virtual tribunalicio
-- Base de datos (Supabase / Postgres) · versión 1 · 8-nov-2026
-- Usuarios con perfil asignado por el administrador, permisos por pantalla
-- y por acción, causas del tribunal, folios con huella SHA-256, resúmenes
-- con validación humana, calendario de despacho y bitácora encadenada.
-- Todos los datos de causas son FICTICIOS.
-- =====================================================================

-- 1. Esquema privado para las funciones de seguridad (no se expone en la API)
create schema if not exists privado;
revoke all on schema privado from public;
grant usage on schema privado to authenticated, service_role;

-- 2. Tablas -----------------------------------------------------------
create table public.perfiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  nombre      text not null default '',
  correo      text,
  uso         text check (uso in ('funcionario','abogado','ciudadano')),
  rol         text not null default 'tercero'
              check (rol in ('admin','juez','secretaria','abogado','justiciable','tercero')),
  activo      boolean not null default true,
  creado      timestamptz not null default now(),
  actualizado timestamptz not null default now()
);
comment on table public.perfiles is 'Personas registradas. El rol y el estado los cambia solo el administrador.';

create table public.modulos (
  clave  text primary key,
  nombre text not null,
  tipo   text not null check (tipo in ('pantalla','accion')),
  orden  int  not null default 0
);
comment on table public.modulos is 'Pantallas y acciones que el administrador puede activar o apagar.';

create table public.rol_permisos (
  rol    text not null check (rol in ('juez','secretaria','abogado','justiciable','tercero')),
  modulo text not null references public.modulos(clave) on delete cascade,
  primary key (rol, modulo)
);
create index rol_permisos_modulo_idx on public.rol_permisos (modulo);
comment on table public.rol_permisos is 'Permisos sugeridos de cada perfil (plantilla).';

create table public.usuario_permisos (
  usuario   uuid not null references public.perfiles(id) on delete cascade,
  modulo    text not null references public.modulos(clave) on delete cascade,
  permitido boolean not null,
  primary key (usuario, modulo)
);
create index usuario_permisos_modulo_idx on public.usuario_permisos (modulo);
comment on table public.usuario_permisos is 'Ajustes por persona que el administrador hace sobre la plantilla del perfil.';

create table public.causas (
  id        text primary key,
  tribunal  text not null,
  corta     text not null,
  materia   text not null,
  actora    text not null,
  demandada text not null,
  etapa     text not null,
  inicio    date,
  lapso     int check (lapso > 0),
  datos     jsonb not null default '{}'::jsonb,
  activa    boolean not null default true,
  creado    timestamptz not null default now()
);
comment on table public.causas is 'Causas del tribunal (ficticias). inicio + lapso alimentan el motor de reglas de lapsos.';

create table public.causas_identificacion (
  causa        text primary key references public.causas(id) on delete cascade,
  actora_id    text not null,
  demandada_id text not null
);
comment on table public.causas_identificacion is 'Datos sensibles separados: solo los ve quien tiene el permiso ver_identificacion.';

create table public.causa_usuarios (
  causa   text not null references public.causas(id) on delete cascade,
  usuario uuid not null references public.perfiles(id) on delete cascade,
  primary key (causa, usuario)
);
create index causa_usuarios_usuario_idx on public.causa_usuarios (usuario);
comment on table public.causa_usuarios is 'Qué causas puede ver cada abogado o justiciable.';

create table public.folios (
  causa  text not null references public.causas(id) on delete cascade,
  numero int  not null,
  titulo text not null,
  texto  text not null,
  huella text not null default '',
  primary key (causa, numero)
);
comment on table public.folios is 'Documentos del expediente. La huella SHA-256 se calcula sola al guardar.';

create table public.resumen (
  id              bigint generated always as identity primary key,
  causa           text not null references public.causas(id) on delete cascade,
  folio           int  not null,
  orden           int  not null default 0,
  tecnico         text not null,
  claro           text not null,
  estado          text not null default 'pendiente' check (estado in ('validado','pendiente')),
  corregido       boolean not null default false,
  actualizado     timestamptz not null default now(),
  actualizado_por uuid references public.perfiles(id) on delete set null
);
create index resumen_causa_idx on public.resumen (causa);
create index resumen_actualizado_por_idx on public.resumen (actualizado_por);
comment on table public.resumen is 'Afirmaciones del resumen, cada una con su folio de origen y su validación humana.';

create table public.calendario_sin_despacho (
  fecha      date primary key,
  motivo     text,
  creado     timestamptz not null default now(),
  creado_por uuid references public.perfiles(id) on delete set null
);
create index calendario_creado_por_idx on public.calendario_sin_despacho (creado_por);
comment on table public.calendario_sin_despacho is 'Días hábiles en que el tribunal no despacha. Es del tribunal: afecta a todas las causas.';

create table public.bitacora (
  id      bigint generated always as identity primary key,
  hora    timestamptz not null default now(),
  usuario uuid references public.perfiles(id) on delete set null,
  actor   text not null default '',
  accion  text not null,
  causa   text,
  prev    text not null default '',
  huella  text not null default ''
);
create index bitacora_usuario_idx on public.bitacora (usuario);
comment on table public.bitacora is 'Bitácora inalterable: cada entrada guarda la huella de la anterior. No admite cambios ni borrado desde la app.';

-- 3. Funciones de seguridad (privado) ----------------------------------
create or replace function privado.es_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.perfiles p
    where p.id = (select auth.uid()) and p.rol = 'admin' and p.activo
  );
$$;

create or replace function privado.permiso(p_modulo text) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case
      when not p.activo then false
      when p.rol = 'admin' then true
      else coalesce(
        (select up.permitido from public.usuario_permisos up
          where up.usuario = p.id and up.modulo = p_modulo),
        exists (select 1 from public.rol_permisos rp
                 where rp.rol = p.rol and rp.modulo = p_modulo))
    end
    from public.perfiles p
    where p.id = (select auth.uid())
  ), false);
$$;

create or replace function privado.puede_ver_causa(p_causa text) returns boolean
language sql stable security definer set search_path = '' as $$
  select privado.permiso('causas')
      or exists (
        select 1 from public.causa_usuarios cu
        join public.perfiles p on p.id = cu.usuario
        where cu.causa = p_causa and cu.usuario = (select auth.uid()) and p.activo
      );
$$;

create or replace function privado.huella_bitacora(p_prev text, p_hora timestamptz, p_actor text, p_accion text)
returns text language sql stable set search_path = '' as $$
  select encode(sha256(convert_to(
    p_prev || to_char(p_hora at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') || p_actor || p_accion,
    'UTF8')), 'hex');
$$;

-- Al registrarse: crea su perfil con acceso mínimo (Tercero)
create or replace function privado.nuevo_usuario() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.perfiles (id, nombre, correo, uso)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data->>'nombre'), ''), split_part(new.email, '@', 1)),
    new.email,
    case when new.raw_user_meta_data->>'uso' in ('funcionario','abogado','ciudadano')
         then new.raw_user_meta_data->>'uso' end
  );
  return new;
end $$;

-- Nadie cambia su propio rol o estado: solo el administrador
create or replace function privado.proteger_perfil() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if current_user = 'authenticated'
     and (new.rol is distinct from old.rol or new.activo is distinct from old.activo
          or new.id is distinct from old.id or new.correo is distinct from old.correo)
     and not privado.es_admin() then
    raise exception 'Solo el administrador puede cambiar el perfil o el estado de una cuenta';
  end if;
  new.actualizado := now();
  return new;
end $$;

-- Huella SHA-256 de cada folio
create or replace function privado.calcular_huella_folio() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.huella := encode(sha256(convert_to(new.texto, 'UTF8')), 'hex');
  return new;
end $$;

-- Quién validó o corrigió un resumen
create or replace function privado.marcar_resumen() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.actualizado := now();
  new.actualizado_por := (select auth.uid());
  return new;
end $$;

-- Bitácora encadenada: cada entrada guarda la huella de la anterior
create or replace function privado.encadenar_bitacora() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_prev text;
  v_uid  uuid := (select auth.uid());
begin
  perform pg_advisory_xact_lock(hashtext('constanza_bitacora'));
  select b.huella into v_prev from public.bitacora b order by b.id desc limit 1;
  new.prev    := coalesce(v_prev, repeat('0', 64));
  new.hora    := clock_timestamp();
  new.usuario := v_uid;
  if v_uid is not null then
    select coalesce(nullif(p.nombre, ''), 'Usuario') || ' (' ||
           case p.rol when 'admin' then 'Administrador' when 'juez' then 'Juez'
                      when 'secretaria' then 'Secretaría' when 'abogado' then 'Abogado'
                      when 'justiciable' then 'Justiciable' else 'Tercero' end || ')'
      into new.actor
      from public.perfiles p where p.id = v_uid;
  end if;
  new.actor  := coalesce(nullif(new.actor, ''), 'Sistema');
  new.huella := privado.huella_bitacora(new.prev, new.hora, new.actor, new.accion);
  return new;
end $$;

revoke all on all functions in schema privado from public, anon;
grant execute on all functions in schema privado to authenticated, service_role;

create trigger al_registrarse after insert on auth.users
  for each row execute function privado.nuevo_usuario();
create trigger proteger_perfil before update on public.perfiles
  for each row execute function privado.proteger_perfil();
create trigger huella_folio before insert or update of texto on public.folios
  for each row execute function privado.calcular_huella_folio();
create trigger marcar_resumen before update on public.resumen
  for each row execute function privado.marcar_resumen();
create trigger encadenar_bitacora before insert on public.bitacora
  for each row execute function privado.encadenar_bitacora();

-- 4. Funciones que llama la app ----------------------------------------
create or replace function public.mis_permisos() returns table (modulo text)
language sql stable security invoker set search_path = '' as $$
  select m.clave from public.modulos m where privado.permiso(m.clave) order by m.orden;
$$;

create or replace function public.verificar_bitacora() returns bigint
language plpgsql stable security invoker set search_path = '' as $$
declare
  r record;
  v_prev text := repeat('0', 64);
begin
  for r in select * from public.bitacora order by id loop
    if r.prev <> v_prev or r.huella <> privado.huella_bitacora(r.prev, r.hora, r.actor, r.accion) then
      return r.id;
    end if;
    v_prev := r.huella;
  end loop;
  return -1;
end $$;
comment on function public.verificar_bitacora() is 'Devuelve -1 si la cadena está íntegra, o el id de la primera entrada alterada.';

revoke all on function public.mis_permisos(), public.verificar_bitacora() from public, anon;
grant execute on function public.mis_permisos(), public.verificar_bitacora() to authenticated, service_role;

-- 5. Acceso a la API: nada para visitantes anónimos, lo justo para usuarios
revoke all on public.perfiles, public.modulos, public.rol_permisos, public.usuario_permisos,
  public.causas, public.causas_identificacion, public.causa_usuarios, public.folios,
  public.resumen, public.calendario_sin_despacho, public.bitacora from anon, authenticated;
grant all on public.perfiles, public.modulos, public.rol_permisos, public.usuario_permisos,
  public.causas, public.causas_identificacion, public.causa_usuarios, public.folios,
  public.resumen, public.calendario_sin_despacho, public.bitacora to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;

grant select, update                 on public.perfiles                to authenticated;
grant select, insert, update, delete on public.modulos                 to authenticated;
grant select, insert, update, delete on public.rol_permisos            to authenticated;
grant select, insert, update, delete on public.usuario_permisos        to authenticated;
grant select, insert, update, delete on public.causas                  to authenticated;
grant select, insert, update, delete on public.causas_identificacion   to authenticated;
grant select, insert, update, delete on public.causa_usuarios          to authenticated;
grant select, insert, update, delete on public.folios                  to authenticated;
grant select, insert, update, delete on public.resumen                 to authenticated;
grant select, insert, delete         on public.calendario_sin_despacho to authenticated;
grant select, insert                 on public.bitacora                to authenticated;

-- 6. Seguridad por fila (RLS) -------------------------------------------
alter table public.perfiles                enable row level security;
alter table public.modulos                 enable row level security;
alter table public.rol_permisos            enable row level security;
alter table public.usuario_permisos        enable row level security;
alter table public.causas                  enable row level security;
alter table public.causas_identificacion   enable row level security;
alter table public.causa_usuarios          enable row level security;
alter table public.folios                  enable row level security;
alter table public.resumen                 enable row level security;
alter table public.calendario_sin_despacho enable row level security;
alter table public.bitacora                enable row level security;

-- perfiles: cada quien ve y edita su nombre; el administrador ve y edita a todos
create policy "perfiles: ver la propia o admin" on public.perfiles for select to authenticated
  using (id = (select auth.uid()) or (select privado.es_admin()));
create policy "perfiles: editar la propia o admin" on public.perfiles for update to authenticated
  using (id = (select auth.uid()) or (select privado.es_admin()))
  with check (id = (select auth.uid()) or (select privado.es_admin()));

-- catálogo de módulos y plantillas: todos leen, solo el administrador cambia
create policy "modulos: leer" on public.modulos for select to authenticated using (true);
create policy "modulos: admin agrega" on public.modulos for insert to authenticated with check ((select privado.es_admin()));
create policy "modulos: admin cambia" on public.modulos for update to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));
create policy "modulos: admin borra" on public.modulos for delete to authenticated using ((select privado.es_admin()));

create policy "rol_permisos: leer" on public.rol_permisos for select to authenticated using (true);
create policy "rol_permisos: admin agrega" on public.rol_permisos for insert to authenticated with check ((select privado.es_admin()));
create policy "rol_permisos: admin cambia" on public.rol_permisos for update to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));
create policy "rol_permisos: admin borra" on public.rol_permisos for delete to authenticated using ((select privado.es_admin()));

-- permisos por persona: cada quien ve los suyos; solo el administrador los cambia
create policy "usuario_permisos: ver propios o admin" on public.usuario_permisos for select to authenticated
  using (usuario = (select auth.uid()) or (select privado.es_admin()));
create policy "usuario_permisos: admin agrega" on public.usuario_permisos for insert to authenticated with check ((select privado.es_admin()));
create policy "usuario_permisos: admin cambia" on public.usuario_permisos for update to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));
create policy "usuario_permisos: admin borra" on public.usuario_permisos for delete to authenticated using ((select privado.es_admin()));

-- causas: el tribunal ve todas (permiso "causas"); abogado y justiciable, solo las suyas
create policy "causas: ver" on public.causas for select to authenticated using (privado.puede_ver_causa(id));
create policy "causas: admin agrega" on public.causas for insert to authenticated with check ((select privado.es_admin()));
create policy "causas: admin cambia" on public.causas for update to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));
create policy "causas: admin borra" on public.causas for delete to authenticated using ((select privado.es_admin()));

create policy "identificacion: ver con permiso" on public.causas_identificacion for select to authenticated
  using (privado.puede_ver_causa(causa) and (select privado.permiso('ver_identificacion')));
create policy "identificacion: admin agrega" on public.causas_identificacion for insert to authenticated with check ((select privado.es_admin()));
create policy "identificacion: admin cambia" on public.causas_identificacion for update to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));
create policy "identificacion: admin borra" on public.causas_identificacion for delete to authenticated using ((select privado.es_admin()));

create policy "causa_usuarios: ver" on public.causa_usuarios for select to authenticated
  using (usuario = (select auth.uid()) or (select privado.permiso('causas')));
create policy "causa_usuarios: admin agrega" on public.causa_usuarios for insert to authenticated with check ((select privado.es_admin()));
create policy "causa_usuarios: admin borra" on public.causa_usuarios for delete to authenticated using ((select privado.es_admin()));

create policy "folios: ver" on public.folios for select to authenticated using (privado.puede_ver_causa(causa));
create policy "folios: admin agrega" on public.folios for insert to authenticated with check ((select privado.es_admin()));
create policy "folios: admin cambia" on public.folios for update to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));
create policy "folios: admin borra" on public.folios for delete to authenticated using ((select privado.es_admin()));

-- resumen: lo ve quien ve la causa; valida o corrige quien tiene "validar_resumen"
create policy "resumen: ver" on public.resumen for select to authenticated using (privado.puede_ver_causa(causa));
create policy "resumen: validar o corregir" on public.resumen for update to authenticated
  using (privado.puede_ver_causa(causa) and (select privado.permiso('validar_resumen')))
  with check (privado.puede_ver_causa(causa) and (select privado.permiso('validar_resumen')));
create policy "resumen: admin agrega" on public.resumen for insert to authenticated with check ((select privado.es_admin()));
create policy "resumen: admin borra" on public.resumen for delete to authenticated using ((select privado.es_admin()));

-- calendario: todos lo leen; lo cambia quien tiene "editar_calendario"
create policy "calendario: leer" on public.calendario_sin_despacho for select to authenticated using (true);
create policy "calendario: marcar dia" on public.calendario_sin_despacho for insert to authenticated
  with check ((select privado.permiso('editar_calendario')));
create policy "calendario: quitar dia" on public.calendario_sin_despacho for delete to authenticated
  using ((select privado.permiso('editar_calendario')));

-- bitácora: todos escriben (la base pone quién y la huella); la leen quienes tienen "bitacora"
create policy "bitacora: registrar" on public.bitacora for insert to authenticated
  with check ((select auth.uid()) is not null and char_length(accion) <= 300);
create policy "bitacora: leer con permiso" on public.bitacora for select to authenticated
  using ((select privado.permiso('bitacora')));
