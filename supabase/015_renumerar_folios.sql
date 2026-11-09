-- =====================================================================
-- Tamara · cambiar el número de un folio.
-- Quien puede modificar folios (Juez, Secretaría, administrador) también
-- puede cambiar su número, siempre que no repita otro folio del mismo
-- expediente. Los resúmenes que citaban el folio pasan al número nuevo y
-- la bitácora anota el cambio.
-- =====================================================================
create or replace function privado.proteger_folio() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.causa is distinct from old.causa then raise exception 'Un folio no se puede mover a otra causa'; end if;
  if new.numero is distinct from old.numero then
    if new.numero < 1 or new.numero > 99999 then raise exception 'El número de folio debe estar entre 1 y 99999'; end if;
    if exists (select 1 from public.folios f where f.causa = new.causa and f.numero = new.numero)
       or exists (select 1 from public.documentos d where d.causa = new.causa and d.folio = new.numero) then
      raise exception 'El folio % ya existe en el expediente %: use otro número', new.numero, new.causa; end if;
  end if;
  new.titulo := trim(new.titulo);
  if char_length(new.titulo) not between 2 and 200 then raise exception 'El título debe tener de 2 a 200 letras'; end if;
  if char_length(trim(new.texto)) < 1 or char_length(new.texto) > 20000 then raise exception 'El texto del folio no puede quedar vacío (máximo 20.000 letras)'; end if;
  new.huella := encode(sha256(convert_to(new.texto, 'UTF8')), 'hex');
  return new;
end $$;

-- Los resúmenes siguen al folio cuando cambia de número
create or replace function privado.renumerar_resumen(p_causa text, p_viejo int, p_nuevo int) returns void
language sql security definer set search_path = '' as $$
  update public.resumen set folio = p_nuevo where causa = p_causa and folio = p_viejo;
$$;
revoke all on function privado.renumerar_resumen(text, int, int) from public, anon;
grant execute on function privado.renumerar_resumen(text, int, int) to authenticated;

create or replace function privado.registrar_folio() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.numero is distinct from old.numero then
    perform privado.renumerar_resumen(new.causa, old.numero, new.numero);
    insert into public.bitacora (accion, causa)
    values ('Folio ' || old.numero || ' del Exp. ' || new.causa || ' renumerado como folio ' || new.numero, new.causa);
  end if;
  if new.titulo is distinct from old.titulo or new.texto is distinct from old.texto then
    insert into public.bitacora (accion, causa)
    values ('Folio ' || new.numero || ' del Exp. ' || new.causa || ' modificado · huella ' || left(old.huella, 12) || ' → ' || left(new.huella, 12), new.causa);
  end if;
  return new;
end $$;

select 'listo' as estado;
