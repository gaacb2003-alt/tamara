-- Ajuste del asesor de seguridad: la bitácora solo acepta entradas de usuarios con sesión
drop policy if exists "bitacora: registrar" on public.bitacora;
create policy "bitacora: registrar" on public.bitacora for insert to authenticated
  with check ((select auth.uid()) is not null and char_length(accion) <= 300);
