-- =====================================================================
-- Tamara · el administrador gestiona cuentas: restablecer contraseña,
-- cambiar usuario y eliminar cuenta. Funciones seguras: revisan que quien
-- llama sea administrador y dejan registro en la bitácora.
-- =====================================================================
create extension if not exists pgcrypto with schema extensions;

create or replace function privado.admin_cambiar_clave(p_usuario uuid, p_clave text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not privado.es_admin() then raise exception 'Solo el administrador puede cambiar contraseñas'; end if;
  if p_clave is null or char_length(p_clave) < 4 then raise exception 'La contraseña debe tener al menos 4 caracteres'; end if;
  update auth.users set encrypted_password = extensions.crypt(p_clave, extensions.gen_salt('bf')), updated_at = now()
  where id = p_usuario;
  if not found then raise exception 'No existe esa cuenta'; end if;
  insert into public.bitacora (accion)
  values ('Administración: contraseña restablecida para ' || coalesce((select p.nombre from public.perfiles p where p.id = p_usuario), 'una cuenta'));
end $$;

create or replace function privado.admin_cambiar_usuario(p_usuario uuid, p_nuevo text) returns void
language plpgsql security definer set search_path = '' as $$
declare v text := lower(trim(p_nuevo)); v_dir text;
begin
  if not privado.es_admin() then raise exception 'Solo el administrador puede cambiar usuarios'; end if;
  if v is null or v !~ '^[a-z0-9._-]{3,30}$' then raise exception 'El usuario debe tener de 3 a 30 letras o números, sin espacios ni tildes'; end if;
  v_dir := v || '@tamara.app';
  if exists (select 1 from auth.users u where u.email = v_dir and u.id <> p_usuario) then raise exception 'Ese usuario ya existe'; end if;
  update auth.users set email = v_dir, updated_at = now() where id = p_usuario;
  if not found then raise exception 'No existe esa cuenta'; end if;
  update auth.identities set identity_data = identity_data || jsonb_build_object('email', v_dir)
  where user_id = p_usuario and provider = 'email';
  update public.perfiles set correo = v_dir where id = p_usuario;
  insert into public.bitacora (accion)
  values ('Administración: usuario de ' || coalesce((select p.nombre from public.perfiles p where p.id = p_usuario), 'una cuenta') || ' cambiado a ' || v);
end $$;

create or replace function privado.admin_borrar_usuario(p_usuario uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_nombre text;
begin
  if not privado.es_admin() then raise exception 'Solo el administrador puede eliminar cuentas'; end if;
  if p_usuario = (select auth.uid()) then raise exception 'No puede eliminar su propia cuenta'; end if;
  select p.nombre into v_nombre from public.perfiles p where p.id = p_usuario;
  delete from auth.users where id = p_usuario;
  if not found then raise exception 'No existe esa cuenta'; end if;
  insert into public.bitacora (accion) values ('Administración: cuenta eliminada: ' || coalesce(v_nombre, 'sin nombre'));
end $$;

revoke all on function privado.admin_cambiar_clave(uuid, text), privado.admin_cambiar_usuario(uuid, text), privado.admin_borrar_usuario(uuid) from public, anon;
grant execute on function privado.admin_cambiar_clave(uuid, text), privado.admin_cambiar_usuario(uuid, text), privado.admin_borrar_usuario(uuid) to authenticated;

-- Puertas que llama la app (sin privilegios propios: usan las funciones de arriba)
create or replace function public.admin_cambiar_clave(p_usuario uuid, p_clave text) returns void
language sql security invoker set search_path = '' as $$ select privado.admin_cambiar_clave(p_usuario, p_clave); $$;
create or replace function public.admin_cambiar_usuario(p_usuario uuid, p_nuevo text) returns void
language sql security invoker set search_path = '' as $$ select privado.admin_cambiar_usuario(p_usuario, p_nuevo); $$;
create or replace function public.admin_borrar_usuario(p_usuario uuid) returns void
language sql security invoker set search_path = '' as $$ select privado.admin_borrar_usuario(p_usuario); $$;
revoke all on function public.admin_cambiar_clave(uuid, text), public.admin_cambiar_usuario(uuid, text), public.admin_borrar_usuario(uuid) from public, anon;
grant execute on function public.admin_cambiar_clave(uuid, text), public.admin_cambiar_usuario(uuid, text), public.admin_borrar_usuario(uuid) to authenticated;

select proname from pg_proc where proname like 'admin_%' order by 1;
