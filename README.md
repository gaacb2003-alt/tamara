# Tamara · Asistente virtual tribunalicio

(Antes llamada Constanza; `original.html` conserva la versión original con ese nombre.)

Prototipo académico del Grupo 1 (Hackatón USM, Facultad de Derecho). Casos y datos ficticios.

## Abrir

- **Sistema (con cuentas):** https://gaacb2003-alt.github.io/tamara/
- **Versión original (referencia):** https://gaacb2003-alt.github.io/tamara/original.html

## Dos páginas separadas

- **Página del tribunal** (este enlace): para todas las personas. Portada, inicio de sesión, registro, avisos para leer y una burbuja de ayuda con orientación sin necesidad de entrar. No lleva el código de administración.
- **Página de administración**: aparte, solo entran cuentas de administrador. Desde ahí se manejan perfiles, permisos, causas y se edita la portada de la página del tribunal.

La seguridad la hace cumplir la base de datos (reglas por fila), no la página.

## Cómo funciona

1. **Crear cuenta:** cada persona se registra con un nombre de usuario y una contraseña. Entra con acceso de orientación general.
2. **Administrador:** asigna a cada persona su perfil (Juez, Secretaría, Abogado, Justiciable o Tercero), enciende o apaga pantallas y acciones por persona, vincula causas a abogados y justiciables, y gestiona las cuentas: cambiar nombre, usuario o contraseña (si alguien la olvida), suspender o eliminar. Cada persona puede cambiar su propia contraseña en Mi perfil. El Juez puede además restablecer la contraseña de quien la olvidó.
3. **Juez y Secretaría** ven todas las causas del tribunal y pasan de una a otra.
4. **Todo queda guardado** en una base de datos SQL (Supabase / Postgres) con seguridad por fila: cada usuario solo puede leer lo que sus permisos le dejan. La bitácora está encadenada con SHA-256 y no se puede editar ni borrar.

Para presentar: entre como administrador y abra la **Guía de demostración**. El recorrido de 15 pasos abre cada perfil con **Ver la app como...**. En **Usuarios y permisos** hay dos pestañas: Personas (ajustes por persona) y Permisos por perfil (tabla para cada perfil completo).

## Archivos

| Archivo | Qué es |
|---|---|
| `index.html` | El sistema: un solo archivo, se conecta a la base de datos |
| `original.html` | Versión original, sin cambios, como referencia |
| `supabase/001_esquema.sql` | Tablas, funciones de seguridad y reglas de acceso (RLS) |
| `supabase/002_datos.sql` | Datos iniciales ficticios: perfiles, 6 causas, folios y resúmenes |
| `supabase/000_limpiar.sql`, `003_ajuste_bitacora.sql` | Limpieza para recrear desde cero y un ajuste de seguridad |
| `supabase/005_foto_perfil.sql` | Foto de perfil que sube cada persona |
| `supabase/006_expediente_digital.sql` | Expediente digital: documentos en la nube con su huella SHA-256 |
| `supabase/007_admin_cuentas.sql` | El administrador restablece contraseñas, cambia usuarios y elimina cuentas |
| `supabase/008_juez_restablece_claves.sql` | El Juez también puede restablecer contraseñas (solo eso; nunca la del administrador) |
| `supabase/009_pagina_editable.sql` | Portada y avisos de la página del tribunal: todos los ven, solo el administrador los cambia |
| `supabase/010_editar_causas.sql` | Juez y Secretaría editan los datos de las causas (el administrador da o quita el permiso) |
| `supabase/011_admin_crea_cuentas.sql` | El administrador crea cuentas desde su panel (emergencias) |
| `supabase/012_crear_causas.sql` | Crear causas nuevas: el administrador siempre; a otros si les da el permiso |
| `supabase/013_editar_folios.sql` | Juez y Secretaría modifican folios; la bitácora guarda la huella anterior y la nueva |

La página solo contiene la clave pública del proyecto; los permisos los hace cumplir la base de datos.
