-- =====================================================================
-- Tamara · anexos dentro de cada folio.
-- Quien puede modificar folios (Juez, Secretaría, administrador) sube
-- anexos (PDF o fotos) a un folio. Los ven quienes tengan el permiso
-- "ver_anexos" (Juez, Secretaría y Abogado por defecto). El justiciable
-- y el tercero solo ven el texto y el resumen.
-- Cada anexo queda en la nube con su huella SHA-256 y en la bitácora.
-- =====================================================================

-- 1. Permiso nuevo
insert into public.modulos (clave, nombre, tipo, orden)
values ('ver_anexos', 'Ver los anexos de los folios', 'accion', 18)
on conflict (clave) do nothing;
insert into public.rol_permisos (rol, modulo) values ('juez', 'ver_anexos'), ('secretaria', 'ver_anexos'), ('abogado', 'ver_anexos')
on conflict do nothing;

-- 2. Tabla de anexos
create table if not exists public.folio_anexos (
  id            bigint generated always as identity primary key,
  causa         text not null references public.causas(id) on delete cascade,
  folio         int  not null check (folio > 0),
  titulo        text not null check (char_length(titulo) between 2 and 200),
  archivo       text not null unique,
  tipo          text not null,
  tamano        int  not null check (tamano > 0 and tamano <= 10485760),
  huella        text not null check (huella ~ '^[0-9a-f]{64}$'),
  subido_por    uuid references public.perfiles(id) on delete set null,
  subido_nombre text,
  subido_en     timestamptz not null default now()
);
create index if not exists folio_anexos_causa_idx on public.folio_anexos (causa, folio);
create index if not exists folio_anexos_subido_por_idx on public.folio_anexos (subido_por);
comment on table public.folio_anexos is 'Anexos de cada folio. El archivo está en Storage (expedientes/<causa>/anexos/...). No se modifican.';

alter table public.folio_anexos enable row level security;
revoke all on public.folio_anexos from anon, authenticated;
grant select, insert on public.folio_anexos to authenticated;
grant all on public.folio_anexos to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;

drop policy if exists "anexos: ver con permiso" on public.folio_anexos;
create policy "anexos: ver con permiso" on public.folio_anexos for select to authenticated
  using (privado.puede_ver_causa(causa) and (select privado.permiso('ver_anexos')));
drop policy if exists "anexos: subir con permiso" on public.folio_anexos;
create policy "anexos: subir con permiso" on public.folio_anexos for insert to authenticated
  with check (privado.puede_ver_causa(causa)
              and (select privado.permiso('editar_folios'))
              and subido_por = (select auth.uid())
              and archivo like causa || '/anexos/%');

create or replace function privado.preparar_anexo() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.subido_por    := (select auth.uid());
  new.subido_en     := now();
  new.subido_nombre := (select p.nombre from public.perfiles p where p.id = (select auth.uid()));
  return new;
end $$;
create or replace function privado.registrar_anexo() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  insert into public.bitacora (accion, causa)
  values ('Anexo agregado al folio ' || new.folio || ' del Exp. ' || new.causa || ': ' || left(new.titulo, 120), new.causa);
  return new;
end $$;
revoke all on function privado.preparar_anexo(), privado.registrar_anexo() from public, anon;
grant execute on function privado.preparar_anexo(), privado.registrar_anexo() to authenticated, service_role;
drop trigger if exists preparar_anexo on public.folio_anexos;
create trigger preparar_anexo before insert on public.folio_anexos for each row execute function privado.preparar_anexo();
drop trigger if exists registrar_anexo on public.folio_anexos;
create trigger registrar_anexo after insert on public.folio_anexos for each row execute function privado.registrar_anexo();

-- 3. Si el folio cambia de número, sus anexos (y resúmenes) lo siguen
create or replace function privado.renumerar_resumen(p_causa text, p_viejo int, p_nuevo int) returns void
language sql security definer set search_path = '' as $$
  update public.resumen set folio = p_nuevo where causa = p_causa and folio = p_viejo;
  update public.folio_anexos set folio = p_nuevo where causa = p_causa and folio = p_viejo;
$$;

-- 4. Archivos en la nube: la carpeta de anexos solo para quien tiene permiso
drop policy if exists "expedientes: ver archivos de sus causas" on storage.objects;
create policy "expedientes: ver archivos de sus causas" on storage.objects for select to authenticated
  using (bucket_id = 'expedientes'
         and privado.puede_ver_causa((storage.foldername(name))[1])
         and ((storage.foldername(name))[2] is distinct from 'anexos' or (select privado.permiso('ver_anexos'))));
drop policy if exists "expedientes: subir con permiso" on storage.objects;
create policy "expedientes: subir con permiso" on storage.objects for insert to authenticated
  with check (bucket_id = 'expedientes'
              and privado.puede_ver_causa((storage.foldername(name))[1])
              and (case when (storage.foldername(name))[2] = 'anexos'
                        then (select privado.permiso('editar_folios'))
                        else (select privado.permiso('subir_documentos')) end));

select (select count(*) from pg_policies where tablename = 'folio_anexos') as reglas_anexos,
       (select string_agg(rol, ', ' order by rol) from public.rol_permisos where modulo = 'ver_anexos') as ven_anexos;
