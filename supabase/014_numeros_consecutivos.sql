-- =====================================================================
-- Tamara · Juez y Secretaría crean causas; números consecutivos.
-- 1. "Crear causas nuevas" activado para Juez y Secretaría (el
--    administrador lo puede quitar o dar a otros).
-- 2. Al subir un documento, el número de folio se puede cambiar, pero no
--    puede repetir un folio que ya exista en el expediente.
-- =====================================================================
insert into public.rol_permisos (rol, modulo) values ('juez', 'crear_causas'), ('secretaria', 'crear_causas')
on conflict do nothing;

create or replace function privado.preparar_documento() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if exists (select 1 from public.folios f where f.causa = new.causa and f.numero = new.folio)
     or exists (select 1 from public.documentos d where d.causa = new.causa and d.folio = new.folio) then
    raise exception 'El folio % ya existe en el expediente %: use otro número', new.folio, new.causa;
  end if;
  new.subido_por    := (select auth.uid());
  new.subido_en     := now();
  new.subido_nombre := (select p.nombre from public.perfiles p where p.id = (select auth.uid()));
  return new;
end $$;

select rol, modulo from public.rol_permisos where modulo = 'crear_causas' order by rol;
