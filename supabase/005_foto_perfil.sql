-- Foto de perfil: cada persona sube la suya (JPEG pequeño, la app la reduce a 320x320).
-- La ven solo la propia persona y el administrador (misma seguridad por fila de perfiles).
alter table public.perfiles add column if not exists foto text;
alter table public.perfiles drop constraint if exists perfiles_foto_formato;
alter table public.perfiles add constraint perfiles_foto_formato
  check (foto is null or (foto like 'data:image/jpeg;base64,%' and length(foto) <= 300000));
comment on column public.perfiles.foto is 'Foto de perfil (JPEG pequeño). La ven la propia persona y el administrador.';
select column_name, data_type from information_schema.columns
where table_schema = 'public' and table_name = 'perfiles' and column_name = 'foto';
