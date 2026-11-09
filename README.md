# Tamara · Asistente virtual tribunalicio

(Antes llamada Constanza; `original.html` conserva la versión original con ese nombre.)

Prototipo académico del Grupo 1 (Hackatón USM, Facultad de Derecho). Casos y datos ficticios.

## Abrir

- **Sistema (con cuentas):** https://gaacb2003-alt.github.io/tamara/
- **Versión original (referencia):** https://gaacb2003-alt.github.io/tamara/original.html

## Cómo funciona

1. **Crear cuenta:** cada persona se registra con un nombre de usuario y una contraseña. Entra con acceso de orientación general.
2. **Administrador:** asigna a cada persona su perfil (Juez, Secretaría, Abogado, Justiciable o Tercero), enciende o apaga pantallas y acciones por persona, vincula causas a abogados y justiciables, y puede suspender cuentas.
3. **Juez y Secretaría** ven todas las causas del tribunal y pasan de una a otra.
4. **Todo queda guardado** en una base de datos SQL (Supabase / Postgres) con seguridad por fila: cada usuario solo puede leer lo que sus permisos le dejan. La bitácora está encadenada con SHA-256 y no se puede editar ni borrar.

Para presentar: entre como administrador y abra la **Guía de demostración**. El recorrido de 14 pasos abre cada perfil con **Ver la app como...**. En **Usuarios y permisos** hay dos pestañas: Personas (ajustes por persona) y Permisos por perfil (tabla para cada perfil completo).

## Archivos

| Archivo | Qué es |
|---|---|
| `index.html` | El sistema: un solo archivo, se conecta a la base de datos |
| `original.html` | Versión original, sin cambios, como referencia |
| `supabase/001_esquema.sql` | Tablas, funciones de seguridad y reglas de acceso (RLS) |
| `supabase/002_datos.sql` | Datos iniciales ficticios: perfiles, 6 causas, folios y resúmenes |
| `supabase/000_limpiar.sql`, `003_ajuste_bitacora.sql` | Limpieza para recrear desde cero y un ajuste de seguridad |

La página solo contiene la clave pública del proyecto; los permisos los hace cumplir la base de datos.
