-- =====================================================================
-- Tamara · el administrador crea cuentas desde su panel (emergencias:
-- alguien no puede registrarse solo). La cuenta queda lista para entrar
-- con su usuario y la contraseña que ponga el administrador, con el
-- perfil elegido. Solo una cuenta de administrador activa puede hacerlo
-- y queda en la bitácora.
-- =====================================================================
create extension if not exists pgcrypto with schema extensions;

create or replace function privado.admin_crear_usuario(p_usuario text, p_nombre text, p_clave text, p_rol text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v text := lower(trim(p_usuario)); n text := trim(p_nombre); v_dir text; uid uuid := gen_random_uuid();
begin
  if not privado.es_admin() then raise exception 'Solo el administrador puede crear cuentas'; end if;
  if v is null or v !~ '^[a-z0-9._-]{3,30}$' then raise exception 'El usuario debe tener de 3 a 30 letras o números, sin espacios ni tildes'; end if;
  if n is null or char_length(n) not between 2 and 80 then raise exception 'Escriba el nombre de la persona (2 a 80 letras)'; end if;
  if p_clave is null or char_length(p_clave) < 4 then raise exception 'La contraseña debe tener al menos 4 caracteres'; end if;
  if p_rol is null or p_rol not in ('juez', 'secretaria', 'abogado', 'justiciable', 'tercero') then raise exception 'Perfil no válido'; end if;
  v_dir := v || '@tamara.app';
  if exists (select 1 from auth.users u where u.email = v_dir) then raise exception 'Ese usuario ya existe'; end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change)
  values (
    '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', v_dir,
    extensions.crypt(p_clave, extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre', n),
    now(), now(), '', '', '', '');
  insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (uid::text, uid, jsonb_build_object('sub', uid::text, 'email', v_dir, 'email_verified', true), 'email', now(), now(), now());

  -- el perfil lo crea el disparador al registrarse; aquí se le pone nombre y perfil
  update public.perfiles set rol = p_rol, nombre = n, activo = true where id = uid;
  insert into public.bitacora (accion) values ('Administración: cuenta creada para ' || n || ' (usuario ' || v || ')');
  return uid;
end $$;
revoke all on function privado.admin_crear_usuario(text, text, text, text) from public, anon;
grant execute on function privado.admin_crear_usuario(text, text, text, text) to authenticated;

create or replace function public.admin_crear_usuario(p_usuario text, p_nombre text, p_clave text, p_rol text) returns uuid
language sql security invoker set search_path = '' as $$ select privado.admin_crear_usuario(p_usuario, p_nombre, p_clave, p_rol); $$;
revoke all on function public.admin_crear_usuario(text, text, text, text) from public, anon;
grant execute on function public.admin_crear_usuario(text, text, text, text) to authenticated;

select proname from pg_proc where proname = 'admin_crear_usuario';
