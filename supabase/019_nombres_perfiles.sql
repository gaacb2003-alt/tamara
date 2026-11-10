-- =====================================================================
-- Tamara · nombres nuevos de los perfiles en la bitácora:
-- Juez(a), Secretaria(o), Abogado(a), Justiciable y Asistente (antes Tercero).
-- Solo cambia cómo se anota a quien hace algo desde ahora; lo ya anotado
-- no se toca (la cadena de huellas sigue íntegra).
-- =====================================================================
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
           case p.rol when 'admin' then 'Administrador' when 'juez' then 'Juez(a)'
                      when 'secretaria' then 'Secretaria(o)' when 'abogado' then 'Abogado(a)'
                      when 'justiciable' then 'Justiciable' else 'Asistente' end || ')'
      into new.actor
      from public.perfiles p where p.id = v_uid;
  end if;
  new.actor  := coalesce(nullif(new.actor, ''), 'Sistema');
  new.huella := privado.huella_bitacora(new.prev, new.hora, new.actor, new.accion);
  return new;
end $$;

-- la cuenta de prueba «Tercero sin vínculo» pasa a llamarse como su perfil
update public.perfiles set nombre = 'Asistente del tribunal' where correo = 'tercero@tamara.app' and nombre = 'Tercero sin vínculo';

select (select count(*) from pg_proc where proname = 'encadenar_bitacora') as funcion,
       (select nombre from public.perfiles where correo = 'tercero@tamara.app') as cuenta_asistente;
