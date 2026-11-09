-- =====================================================================
-- Tamara · Expediente digital: subir documentos a la nube (Supabase Storage)
-- Cada archivo queda guardado en la carpeta de su causa, registrado como
-- folio con su huella SHA-256, y anotado en la bitácora. No se puede
-- modificar ni borrar desde la app.
-- =====================================================================

-- 1. Carpeta privada en la nube
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('expedientes', 'expedientes', false, 10485760, array['application/pdf','image/jpeg','image/png'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- 2. Pantalla y acción nuevas, con sus permisos sugeridos
update public.modulos set orden = orden + 1 where tipo = 'pantalla' and orden >= 5 and clave <> 'expediente';
insert into public.modulos (clave, nombre, tipo, orden) values
  ('expediente',       'Expediente digital',             'pantalla', 5),
  ('subir_documentos', 'Subir documentos al expediente', 'accion',   13)
on conflict (clave) do nothing;
insert into public.rol_permisos (rol, modulo) values
  ('juez','expediente'), ('secretaria','expediente'), ('abogado','expediente'), ('justiciable','expediente'),
  ('secretaria','subir_documentos')
on conflict do nothing;

-- 3. Registro de documentos
create table if not exists public.documentos (
  id            bigint generated always as identity primary key,
  causa         text not null references public.causas(id) on delete cascade,
  folio         int  not null check (folio > 0),
  titulo        text not null check (char_length(titulo) between 3 and 200),
  archivo       text not null unique,
  tipo          text not null,
  tamano        int  not null check (tamano > 0 and tamano <= 10485760),
  huella        text not null check (huella ~ '^[0-9a-f]{64}$'),
  subido_por    uuid references public.perfiles(id) on delete set null,
  subido_nombre text,
  subido_en     timestamptz not null default now(),
  unique (causa, folio)
);
create index if not exists documentos_causa_idx on public.documentos (causa);
create index if not exists documentos_subido_por_idx on public.documentos (subido_por);
comment on table public.documentos is 'Documentos digitalizados del expediente. El archivo está en Storage (expedientes/<causa>/...). No se modifican ni se borran.';

alter table public.documentos enable row level security;
revoke all on public.documentos from anon, authenticated;
grant select, insert on public.documentos to authenticated;
grant all on public.documentos to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;

drop policy if exists "documentos: ver" on public.documentos;
create policy "documentos: ver" on public.documentos for select to authenticated
  using (privado.puede_ver_causa(causa));
drop policy if exists "documentos: subir" on public.documentos;
create policy "documentos: subir" on public.documentos for insert to authenticated
  with check (privado.puede_ver_causa(causa)
              and (select privado.permiso('subir_documentos'))
              and subido_por = (select auth.uid())
              and archivo like causa || '/%');

-- Quién y cuándo lo pone la base, no la página
create or replace function privado.preparar_documento() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.subido_por    := (select auth.uid());
  new.subido_en     := now();
  new.subido_nombre := (select p.nombre from public.perfiles p where p.id = (select auth.uid()));
  return new;
end $$;

-- Cada documento subido queda en la bitácora
create or replace function privado.registrar_documento() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  insert into public.bitacora (accion, causa)
  values ('Documento consignado: folio ' || new.folio || ' · ' || left(new.titulo, 120) || ' · Exp. ' || new.causa, new.causa);
  return new;
end $$;

revoke all on function privado.preparar_documento(), privado.registrar_documento() from public, anon;
grant execute on function privado.preparar_documento(), privado.registrar_documento() to authenticated, service_role;

drop trigger if exists preparar_documento on public.documentos;
create trigger preparar_documento before insert on public.documentos
  for each row execute function privado.preparar_documento();
drop trigger if exists registrar_documento on public.documentos;
create trigger registrar_documento after insert on public.documentos
  for each row execute function privado.registrar_documento();

-- 4. Seguridad de los archivos en la nube (carpeta = número de causa)
drop policy if exists "expedientes: ver archivos de sus causas" on storage.objects;
create policy "expedientes: ver archivos de sus causas" on storage.objects for select to authenticated
  using (bucket_id = 'expedientes' and privado.puede_ver_causa((storage.foldername(name))[1]));
drop policy if exists "expedientes: subir con permiso" on storage.objects;
create policy "expedientes: subir con permiso" on storage.objects for insert to authenticated
  with check (bucket_id = 'expedientes'
              and (select privado.permiso('subir_documentos'))
              and privado.puede_ver_causa((storage.foldername(name))[1]));

-- Comprobación
select (select count(*) from storage.buckets where id = 'expedientes') as carpeta_nube,
       (select count(*) from public.modulos where clave in ('expediente','subir_documentos')) as modulos_nuevos,
       (select count(*) from pg_policies where tablename = 'documentos') as reglas_documentos,
       (select count(*) from pg_policies where schemaname = 'storage' and policyname like 'expedientes:%') as reglas_archivos;
