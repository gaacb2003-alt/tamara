-- =====================================================================
-- Tamara · la página del tribunal se edita desde la administración.
-- Portada (textos, foto, personaje, tarjeta) y avisos para leer.
-- Todos la pueden VER (incluso antes de entrar); solo el administrador
-- la puede CAMBIAR. Cada cambio queda en la bitácora.
-- =====================================================================

-- 1. Portada: una sola fila con los textos y las fotos
create table if not exists public.pagina (
  clave           text primary key check (clave = 'tribunal'),
  datos           jsonb not null default '{}'::jsonb,
  actualizado     timestamptz not null default now(),
  actualizado_por uuid references public.perfiles(id) on delete set null,
  constraint pagina_datos check (jsonb_typeof(datos) = 'object' and pg_column_size(datos) < 20000),
  constraint pagina_fotos check (
    (coalesce(datos->>'foto', '') = '' or datos->>'foto' like 'https://kgbwofkyonbrwajkyrke.supabase.co/storage/v1/object/public/pagina/%')
    and (coalesce(datos->>'avatar', '') = '' or datos->>'avatar' like 'https://kgbwofkyonbrwajkyrke.supabase.co/storage/v1/object/public/pagina/%'))
);
comment on table public.pagina is 'Portada de la página del tribunal. La lee cualquiera; solo el administrador la cambia.';
insert into public.pagina (clave) values ('tribunal') on conflict do nothing;

alter table public.pagina enable row level security;
revoke all on public.pagina from anon, authenticated;
grant select on public.pagina to anon, authenticated;
grant update on public.pagina to authenticated;
grant all on public.pagina to service_role;
drop policy if exists "pagina: todos la ven" on public.pagina;
create policy "pagina: todos la ven" on public.pagina for select to anon, authenticated using (true);
drop policy if exists "pagina: solo el administrador la cambia" on public.pagina;
create policy "pagina: solo el administrador la cambia" on public.pagina for update to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));

-- 2. Avisos para leer
create table if not exists public.avisos (
  id         bigint generated always as identity primary key,
  titulo     text not null check (char_length(titulo) between 2 and 140),
  texto      text not null default '' check (char_length(texto) <= 5000),
  imagen     text check (imagen is null or imagen like 'https://kgbwofkyonbrwajkyrke.supabase.co/storage/v1/object/public/pagina/%'),
  visible    boolean not null default true,
  orden      int not null default 0,
  creado     timestamptz not null default now(),
  creado_por uuid references public.perfiles(id) on delete set null
);
create index if not exists avisos_creado_por_idx on public.avisos (creado_por);
comment on table public.avisos is 'Avisos para leer en la página del tribunal. Los publicados los ve cualquiera; solo el administrador los escribe.';

alter table public.avisos enable row level security;
revoke all on public.avisos from anon, authenticated;
grant select on public.avisos to anon, authenticated;
grant insert, update, delete on public.avisos to authenticated;
grant all on public.avisos to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;

drop policy if exists "avisos: publicados para todos" on public.avisos;
create policy "avisos: publicados para todos" on public.avisos for select to anon using (visible);
drop policy if exists "avisos: ver" on public.avisos;
create policy "avisos: ver" on public.avisos for select to authenticated using (visible or (select privado.es_admin()));
drop policy if exists "avisos: el administrador escribe" on public.avisos;
create policy "avisos: el administrador escribe" on public.avisos for insert to authenticated with check ((select privado.es_admin()));
drop policy if exists "avisos: el administrador cambia" on public.avisos;
create policy "avisos: el administrador cambia" on public.avisos for update to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));
drop policy if exists "avisos: el administrador borra" on public.avisos;
create policy "avisos: el administrador borra" on public.avisos for delete to authenticated using ((select privado.es_admin()));

-- 3. Quién y cuándo lo pone la base; todo cambio va a la bitácora
create or replace function privado.preparar_pagina() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.actualizado := now();
  new.actualizado_por := (select auth.uid());
  return new;
end $$;
create or replace function privado.registrar_pagina() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  insert into public.bitacora (accion) values ('Página del tribunal: portada actualizada');
  return new;
end $$;
create or replace function privado.preparar_aviso() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.creado := now();
  new.creado_por := (select auth.uid());
  return new;
end $$;
create or replace function privado.registrar_aviso() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    insert into public.bitacora (accion) values ('Página del tribunal: aviso publicado · ' || left(new.titulo, 120));
  elsif tg_op = 'UPDATE' then
    insert into public.bitacora (accion) values ('Página del tribunal: aviso actualizado · ' || left(new.titulo, 120));
  else
    insert into public.bitacora (accion) values ('Página del tribunal: aviso eliminado · ' || left(old.titulo, 120));
  end if;
  return coalesce(new, old);
end $$;
revoke all on function privado.preparar_pagina(), privado.registrar_pagina(), privado.preparar_aviso(), privado.registrar_aviso() from public, anon;
grant execute on function privado.preparar_pagina(), privado.registrar_pagina(), privado.preparar_aviso(), privado.registrar_aviso() to authenticated, service_role;

drop trigger if exists preparar_pagina on public.pagina;
create trigger preparar_pagina before update on public.pagina for each row execute function privado.preparar_pagina();
drop trigger if exists registrar_pagina on public.pagina;
create trigger registrar_pagina after update on public.pagina for each row execute function privado.registrar_pagina();
drop trigger if exists preparar_aviso on public.avisos;
create trigger preparar_aviso before insert on public.avisos for each row execute function privado.preparar_aviso();
drop trigger if exists registrar_aviso on public.avisos;
create trigger registrar_aviso after insert or update or delete on public.avisos for each row execute function privado.registrar_aviso();

-- 4. Carpeta pública de fotos de la página (todos ven; solo el administrador sube)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pagina', 'pagina', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "pagina: el administrador sube fotos" on storage.objects;
create policy "pagina: el administrador sube fotos" on storage.objects for insert to authenticated
  with check (bucket_id = 'pagina' and (select privado.es_admin()));
drop policy if exists "pagina: el administrador cambia fotos" on storage.objects;
create policy "pagina: el administrador cambia fotos" on storage.objects for update to authenticated
  using (bucket_id = 'pagina' and (select privado.es_admin())) with check (bucket_id = 'pagina' and (select privado.es_admin()));
drop policy if exists "pagina: el administrador borra fotos" on storage.objects;
create policy "pagina: el administrador borra fotos" on storage.objects for delete to authenticated
  using (bucket_id = 'pagina' and (select privado.es_admin()));

-- Comprobación
select (select count(*) from public.pagina) as portada,
       (select count(*) from pg_policies where tablename in ('pagina','avisos')) as reglas,
       (select public from storage.buckets where id = 'pagina') as carpeta_publica;
