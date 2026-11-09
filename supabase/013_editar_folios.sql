-- =====================================================================
-- Tamara · modificar folios del expediente (título y texto).
-- Permiso "editar_folios": activado para Juez y Secretaría; el
-- administrador siempre lo tiene y puede darlo o quitarlo a cualquiera.
-- La huella SHA-256 se recalcula sola y la bitácora guarda la huella
-- anterior y la nueva, así queda constancia de cada corrección.
-- Los documentos subidos (PDF o fotos) no se modifican.
-- =====================================================================

-- 1. Permiso nuevo
insert into public.modulos (clave, nombre, tipo, orden)
values ('editar_folios', 'Modificar folios del expediente', 'accion', 17)
on conflict (clave) do nothing;
insert into public.rol_permisos (rol, modulo) values ('juez', 'editar_folios'), ('secretaria', 'editar_folios')
on conflict do nothing;

-- 2. Regla: cambia el administrador o quien tenga el permiso, en causas que puede ver
drop policy if exists "folios: admin cambia" on public.folios;
drop policy if exists "folios: cambia con permiso" on public.folios;
create policy "folios: cambia con permiso" on public.folios for update to authenticated
  using ((select privado.es_admin()) or (privado.puede_ver_causa(causa) and (select privado.permiso('editar_folios'))))
  with check ((select privado.es_admin()) or (privado.puede_ver_causa(causa) and (select privado.permiso('editar_folios'))));

-- 3. Solo título y texto; con forma correcta
create or replace function privado.proteger_folio() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.causa is distinct from old.causa or new.numero is distinct from old.numero then
    raise exception 'Solo se puede cambiar el título y el texto del folio'; end if;
  new.titulo := trim(new.titulo);
  if char_length(new.titulo) not between 2 and 200 then raise exception 'El título debe tener de 2 a 200 letras'; end if;
  if char_length(trim(new.texto)) < 1 or char_length(new.texto) > 20000 then raise exception 'El texto del folio no puede quedar vacío (máximo 20.000 letras)'; end if;
  new.huella := encode(sha256(convert_to(new.texto, 'UTF8')), 'hex');
  return new;
end $$;

create or replace function privado.registrar_folio() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.titulo is distinct from old.titulo or new.texto is distinct from old.texto then
    insert into public.bitacora (accion, causa)
    values ('Folio ' || new.numero || ' del Exp. ' || new.causa || ' modificado · huella ' || left(old.huella, 12) || ' → ' || left(new.huella, 12), new.causa);
  end if;
  return new;
end $$;

revoke all on function privado.proteger_folio(), privado.registrar_folio() from public, anon;
grant execute on function privado.proteger_folio(), privado.registrar_folio() to authenticated, service_role;

drop trigger if exists proteger_folio on public.folios;
create trigger proteger_folio before update on public.folios for each row execute function privado.proteger_folio();
drop trigger if exists registrar_folio on public.folios;
create trigger registrar_folio after update on public.folios for each row execute function privado.registrar_folio();

-- Comprobación
select rol, modulo from public.rol_permisos where modulo = 'editar_folios' order by rol;
