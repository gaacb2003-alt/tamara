-- =====================================================================
-- Tamara · las contraseñas solo las maneja el administrador.
-- El Juez deja de tener "Restablecer contraseñas" por defecto (el
-- administrador puede dárselo a alguien en una emergencia). En la página
-- ya no existe "Cambiar mi contraseña" ni "Crear cuenta".
-- =====================================================================
delete from public.rol_permisos where modulo = 'restablecer_claves';
select count(*) as perfiles_con_restablecer from public.rol_permisos where modulo = 'restablecer_claves';
