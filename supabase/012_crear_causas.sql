-- =====================================================================
-- Tamara · crear causas nuevas desde la página.
-- Permiso "crear_causas": el administrador siempre lo tiene; nadie más
-- por defecto. El administrador lo da a quien quiera (por persona o por
-- perfil). La causa nueva arranca con su expediente vacío y queda en la
-- bitácora. Si quien la crea no ve todas las causas, se le vincula.
-- =====================================================================

-- 1. Permiso nuevo (sin perfiles por defecto)
insert into public.modulos (clave, nombre, tipo, orden)
values ('crear_causas', 'Crear causas nuevas', 'accion', 16)
on conflict (clave) do nothing;

-- 2. Regla: crea el administrador o quien tenga el permiso
drop policy if exists "causas: admin agrega" on public.causas;
drop policy if exists "causas: crea con permiso" on public.causas;
create policy "causas: crea con permiso" on public.causas for insert to authenticated
  with check ((select privado.es_admin()) or (select privado.permiso('crear_causas')));

-- 3. Revisa los datos y completa lo que la causa necesita para verse bien
create or replace function privado.preparar_causa_nueva() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.id := upper(trim(new.id));
  if new.id is null or new.id !~ '^[A-Z0-9][A-Z0-9-]{2,24}$' then
    raise exception 'El número de expediente debe tener de 3 a 25 letras, números o guiones (ej.: EXP-2026-0007)'; end if;
  if exists (select 1 from public.causas c where c.id = new.id) then raise exception 'Ya existe una causa con ese número'; end if;
  new.tribunal := 'Juzgado Demo de Primera Instancia en lo Civil';
  new.corta := trim(new.corta); new.materia := trim(new.materia); new.actora := trim(new.actora);
  new.demandada := trim(new.demandada); new.etapa := trim(new.etapa);
  if char_length(new.corta) not between 2 and 40 then raise exception 'El nombre corto debe tener de 2 a 40 letras'; end if;
  if char_length(new.materia) not between 3 and 120 then raise exception 'La descripción debe tener de 3 a 120 letras'; end if;
  if char_length(new.actora) not between 2 and 120 or char_length(new.demandada) not between 2 and 120 then
    raise exception 'Cada parte debe tener de 2 a 120 letras'; end if;
  if char_length(new.etapa) not between 2 and 60 then raise exception 'La etapa debe tener de 2 a 60 letras'; end if;
  if (new.inicio is null) <> (new.lapso is null) then raise exception 'El inicio y los días del lapso van juntos: ponga los dos o deje los dos vacíos'; end if;
  if new.lapso is not null and new.lapso not between 1 and 365 then raise exception 'El lapso debe ser de 1 a 365 días de despacho'; end if;
  -- datos base para que todas las pantallas de la causa funcionen desde el primer día
  new.datos := '{"evF":1,"evT":"la demanda","evC":"La demanda fue presentada y la causa quedó registrada en el tribunal","evCalc":"Inicio del lapso","lapN":"contestación","art":"344","verbT":"contestar","verbC":"responder","accC":"responderla","accC2":"responder la demanda","startLab":"Inicio","startLeg":"Inicio del lapso","ultT":"Causa registrada. Todavía no hay actuaciones validadas.","ultC":"La causa se registró en el tribunal. Todavía no hay pasos validados.","tl":[["Demanda presentada",1,"done"],["Admisión",null,"next"],["Citación",null,"next"],["Contestación",null,"next"],["Pruebas",null,"next"],["Sentencia",null,"next"]]}'::jsonb;
  new.activa := true;
  new.creado := now();
  return new;
end $$;

create or replace function privado.registrar_causa_nueva() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not privado.permiso('causas') then
    insert into public.causa_usuarios (causa, usuario) values (new.id, (select auth.uid())) on conflict do nothing;
  end if;
  insert into public.bitacora (accion, causa) values ('Causa nueva: Exp. ' || new.id || ' · ' || left(new.materia, 120), new.id);
  return new;
end $$;

revoke all on function privado.preparar_causa_nueva(), privado.registrar_causa_nueva() from public, anon;
grant execute on function privado.preparar_causa_nueva(), privado.registrar_causa_nueva() to authenticated, service_role;

drop trigger if exists preparar_causa_nueva on public.causas;
create trigger preparar_causa_nueva before insert on public.causas for each row execute function privado.preparar_causa_nueva();
drop trigger if exists registrar_causa_nueva on public.causas;
create trigger registrar_causa_nueva after insert on public.causas for each row execute function privado.registrar_causa_nueva();

-- Comprobación
select clave, nombre from public.modulos where clave = 'crear_causas';
