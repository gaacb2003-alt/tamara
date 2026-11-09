-- =====================================================================
-- Tamara · la foto de perfil la pone el administrador.
-- Nadie puede cambiar su propio perfil, estado, usuario ni foto: solo el
-- administrador. (Cada persona sigue pudiendo ver su perfil.)
-- =====================================================================
create or replace function privado.proteger_perfil() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if current_user = 'authenticated'
     and (new.rol is distinct from old.rol or new.activo is distinct from old.activo
          or new.id is distinct from old.id or new.correo is distinct from old.correo
          or new.foto is distinct from old.foto)
     and not privado.es_admin() then
    raise exception 'Solo el administrador puede cambiar el perfil, la foto o el estado de una cuenta';
  end if;
  new.actualizado := now();
  return new;
end $$;
select 'listo' as estado;
