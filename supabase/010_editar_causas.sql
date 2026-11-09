-- =====================================================================
-- Tamara · editar los datos de las causas.
-- Permiso nuevo "editar_causas": activado para Juez y Secretaría; el
-- administrador siempre lo tiene y puede darlo o quitarlo a cualquiera.
-- Quien no es administrador solo cambia los datos visibles (nombre,
-- materia, partes, etapa, inicio y días del lapso) de causas que puede ver.
-- Cada cambio queda en la bitácora.
-- =====================================================================

-- 1. Permiso nuevo
insert into public.modulos (clave, nombre, tipo, orden)
values ('editar_causas', 'Editar los datos de las causas', 'accion', 15)
on conflict (clave) do nothing;
insert into public.rol_permisos (rol, modulo) values ('juez', 'editar_causas'), ('secretaria', 'editar_causas')
on conflict do nothing;

-- 2. Regla: cambia el administrador o quien tenga el permiso (en causas que puede ver)
drop policy if exists "causas: admin cambia" on public.causas;
drop policy if exists "causas: cambia con permiso" on public.causas;
create policy "causas: cambia con permiso" on public.causas for update to authenticated
  using ((select privado.es_admin()) or (privado.puede_ver_causa(id) and (select privado.permiso('editar_causas'))))
  with check ((select privado.es_admin()) or (privado.puede_ver_causa(id) and (select privado.permiso('editar_causas'))));

-- 3. Qué se puede cambiar y con qué forma
create or replace function privado.proteger_causa() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if not privado.es_admin() and (new.id is distinct from old.id or new.tribunal is distinct from old.tribunal
      or new.datos is distinct from old.datos or new.activa is distinct from old.activa or new.creado is distinct from old.creado) then
    raise exception 'Solo puede cambiar el nombre, la materia, las partes, la etapa y el lapso de la causa';
  end if;
  new.corta := trim(new.corta); new.materia := trim(new.materia); new.actora := trim(new.actora);
  new.demandada := trim(new.demandada); new.etapa := trim(new.etapa);
  if char_length(new.corta) not between 2 and 40 then raise exception 'El nombre corto debe tener de 2 a 40 letras'; end if;
  if char_length(new.materia) not between 3 and 120 then raise exception 'La materia debe tener de 3 a 120 letras'; end if;
  if char_length(new.actora) not between 2 and 120 or char_length(new.demandada) not between 2 and 120 then
    raise exception 'Cada parte debe tener de 2 a 120 letras'; end if;
  if char_length(new.etapa) not between 2 and 60 then raise exception 'La etapa debe tener de 2 a 60 letras'; end if;
  if (new.inicio is null) <> (new.lapso is null) then raise exception 'El inicio y los días del lapso van juntos: ponga los dos o deje los dos vacíos'; end if;
  if new.lapso is not null and new.lapso not between 1 and 365 then raise exception 'El lapso debe ser de 1 a 365 días de despacho'; end if;
  return new;
end $$;

create or replace function privado.registrar_causa() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare v text := '';
begin
  if new.corta is distinct from old.corta then v := v || ', nombre'; end if;
  if new.materia is distinct from old.materia then v := v || ', materia'; end if;
  if new.actora is distinct from old.actora or new.demandada is distinct from old.demandada then v := v || ', partes'; end if;
  if new.etapa is distinct from old.etapa then v := v || ', etapa (' || left(new.etapa, 60) || ')'; end if;
  if new.inicio is distinct from old.inicio or new.lapso is distinct from old.lapso then v := v || ', lapso'; end if;
  if v <> '' then
    insert into public.bitacora (accion, causa) values ('Causa actualizada: Exp. ' || new.id || ' · ' || substr(v, 3), new.id);
  end if;
  return new;
end $$;

revoke all on function privado.proteger_causa(), privado.registrar_causa() from public, anon;
grant execute on function privado.proteger_causa(), privado.registrar_causa() to authenticated, service_role;

drop trigger if exists proteger_causa on public.causas;
create trigger proteger_causa before update on public.causas for each row execute function privado.proteger_causa();
drop trigger if exists registrar_causa on public.causas;
create trigger registrar_causa after update on public.causas for each row execute function privado.registrar_causa();

-- Comprobación: quién tiene el permiso
select rol, modulo from public.rol_permisos where modulo = 'editar_causas' order by rol;
