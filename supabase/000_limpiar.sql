-- Borra solo los objetos de Constanza (para volver a crearlos desde cero)
drop trigger if exists al_registrarse on auth.users;
drop function if exists public.mis_permisos();
drop function if exists public.verificar_bitacora();
drop table if exists public.bitacora, public.calendario_sin_despacho, public.resumen, public.folios,
  public.causa_usuarios, public.causas_identificacion, public.causas, public.usuario_permisos,
  public.rol_permisos, public.modulos, public.perfiles cascade;
drop schema if exists privado cascade;

