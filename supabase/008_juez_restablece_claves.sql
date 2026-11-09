-- =====================================================================
-- Tamara · el Juez puede restablecer contraseñas (solo eso).
-- Cambiar nombre, usuario, perfil, suspender y eliminar cuentas sigue
-- siendo solo del administrador. Es un permiso más: el administrador
-- puede quitárselo al juez o dárselo a otra persona desde su panel.
-- Nadie que no sea administrador puede tocar la cuenta de un administrador.
-- =====================================================================

-- 1. Permiso nuevo, activado solo para el perfil Juez
insert into public.modulos (clave, nombre, tipo, orden)
values ('restablecer_claves', 'Restablecer contraseñas de otras personas', 'accion', 14)
on conflict (clave) do nothing;
insert into public.rol_permisos (rol, modulo) values ('juez', 'restablecer_claves')
on conflict do nothing;

-- 2. Restablecer contraseña: administrador, o quien tenga el permiso (nunca a un administrador)
create or replace function privado.admin_cambiar_clave(p_usuario uuid, p_clave text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_rol text; v_nombre text;
begin
  if (select auth.uid()) is null then raise exception 'Debe iniciar sesión'; end if;
  select p.rol, p.nombre into v_rol, v_nombre from public.perfiles p where p.id = p_usuario;
  if not privado.es_admin() then
    if not privado.permiso('restablecer_claves') then raise exception 'No tiene permiso para restablecer contraseñas'; end if;
    if v_rol is null then raise exception 'No existe esa cuenta'; end if;
    if v_rol = 'admin' then raise exception 'Solo el administrador puede cambiar la contraseña de un administrador'; end if;
  end if;
  if p_clave is null or char_length(p_clave) < 4 then raise exception 'La contraseña debe tener al menos 4 caracteres'; end if;
  update auth.users set encrypted_password = extensions.crypt(p_clave, extensions.gen_salt('bf')), updated_at = now()
  where id = p_usuario;
  if not found then raise exception 'No existe esa cuenta'; end if;
  insert into public.bitacora (accion)
  values ('Contraseña restablecida para ' || coalesce(v_nombre, 'una cuenta'));
end $$;

-- 3. Lista de personas para quien restablece (sin administradores, solo nombre, usuario y perfil)
create or replace function privado.personas_para_clave()
returns table (id uuid, nombre text, usuario text, rol text, activo boolean)
language sql stable security definer set search_path = '' as $$
  select p.id, p.nombre, replace(p.correo, '@tamara.app', ''), p.rol, p.activo
  from public.perfiles p
  where p.rol <> 'admin'
    and (privado.es_admin() or privado.permiso('restablecer_claves'))
  order by p.nombre;
$$;
revoke all on function privado.personas_para_clave() from public, anon;
grant execute on function privado.personas_para_clave() to authenticated;

create or replace function public.personas_para_clave()
returns table (id uuid, nombre text, usuario text, rol text, activo boolean)
language sql stable security invoker set search_path = '' as $$ select * from privado.personas_para_clave(); $$;
revoke all on function public.personas_para_clave() from public, anon;
grant execute on function public.personas_para_clave() to authenticated;

-- Comprobación: quién tiene el permiso nuevo
select rol, modulo from public.rol_permisos where modulo = 'restablecer_claves';
