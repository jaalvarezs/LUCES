# Horómetros · Fotoperiodo 🌼💡

PWA para el registro y validación de horómetros de guirnaldas (iluminación por fotoperiodo) por bloque de cultivo. Funciona **sin internet** en campo y sincroniza automáticamente al recuperar conexión.

## Características

- **Offline-first:** las lecturas, justificaciones y posiciones GPS se guardan en el dispositivo y se suben solas al volver la conexión (banner con botón "Sincronizar").
- **Ciclo de fotoperiodo:** las guirnaldas operan de 9:00 p.m. a 3:00 a.m., cicladas 10 min de luz × 20 min de oscuridad = **2.0 horas acumuladas por noche** en el horómetro.
- **Alerta < 2 horas:** si el delta entre la lectura de ayer y la de hoy es menor a 2 h (noche de luz incompleta), se marca alerta y la observación del operario es obligatoria (validado en la app **y** en la base de datos).
- **Ventana laboral de registro:** el operario registra la lectura al día siguiente entre **6:00 a.m. y 2:00 p.m.**; fuera de ese horario la app bloquea el registro (supervisor/administrador sí pueden). A la **1:00 p.m.** la app alerta los bloques que aún no se han registrado.
- **Modo día / noche:** botón ☀/☾ en la cabecera; se recuerda la preferencia.
- **Ubicación del operario:** GPS en vivo, registro del recorrido (pings cada 5 min + posición al guardar cada lectura) y **tiempo estimado de recorrido** a los bloques pendientes (caminando a 4 km/h + 3 min de registro por bloque).
- **Bloques pendientes:** pestaña con los bloques del día sin registrar. Desde las 4 p.m. la app **notifica** los pendientes y exige registrar la lectura o **justificar por qué no se recorrió**.
- **Roles:** operario (registra), supervisor (además crea horómetros y captura GPS de bloques), administrador (todo + gestión de bloques y usuarios).

## Instalación

### 1. Base de datos (Supabase)

En el SQL Editor de tu proyecto Supabase ejecuta **en orden**:

1. `horometros_schema.sql` (esquema base: tablas, triggers, RLS, 50 bloques)
2. `actualizacion_v2.sql` (GPS por bloque, justificaciones, recorridos)
3. `actualizacion_v3.sql` (supervisores pueden crear y editar bloques)

Luego crea los usuarios en **Authentication → Users** con correos sintéticos internos
(`nombreusuario@trigal.local` + **Auto Confirm User** ✅). En la app, cada persona inicia
sesión escribiendo solo su nombre de usuario (ej. `jperez`) y su clave — la app completa
el dominio automáticamente. Después asigna roles:

```sql
update public.perfiles set rol = 'administrador' where id = '<uuid-del-usuario>';
update public.perfiles set rol = 'supervisor'    where id = '<uuid-del-usuario>';
```

### 2. Configurar la app

En `index.html`, sección `CONFIG` (inicio del `<script>`), reemplaza:

```js
const SUPABASE_URL = 'https://TU-PROYECTO.supabase.co';
const SUPABASE_ANON_KEY = 'TU_ANON_KEY';
```

(Los encuentras en Supabase → Settings → API.)

### 3. Publicar en GitHub Pages

```bash
git init
git add .
git commit -m "Horómetros fotoperiodo v2"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/horometros-fotoperiodo.git
git push -u origin main
```

En GitHub: **Settings → Pages → Source: Deploy from a branch → main / (root) → Save.**
La app queda en `https://TU_USUARIO.github.io/horometros-fotoperiodo/`.

> **Importante:** GitHub Pages sirve por HTTPS, requisito para GPS, notificaciones y service worker. Ábrela desde el celular y usa "Agregar a pantalla de inicio" para instalarla como app.

### 4. Primer uso en campo

1. Cada operario debe iniciar sesión **una vez con internet** en su dispositivo (así queda la sesión y los datos en caché para el modo offline).
2. Supervisor/administrador: en la pestaña **Bloques**, párate en cada bloque y toca **Capturar** para guardar su ubicación GPS (habilita las estimaciones de recorrido).
3. Acepta los permisos de **ubicación** y **notificaciones** cuando la app los pida.

## Estructura del repositorio

| Archivo | Descripción |
|---|---|
| `index.html` | Aplicación completa (una sola página) |
| `sw.js` | Service worker: cachea el cascarón de la app para uso sin internet |
| `manifest.json` | Manifiesto PWA (instalable en el celular) |
| `icono-192.png`, `icono-512.png` | Iconos de la app |
| `horometros_schema.sql` | Esquema base de la BD (ejecutar primero) |
| `actualizacion_v2.sql` | Actualización: GPS, justificaciones, recorridos |
| `actualizacion_v3.sql` | Actualización: permisos de bloques para supervisores |

## Parámetros ajustables (en `index.html`, sección CONFIG)

| Constante | Valor | Significado |
|---|---|---|
| `UMBRAL_HORAS` | 2 | Delta mínimo esperado por noche; por debajo genera alerta |
| `HORAS_ESPERADAS` | 2 | Delta de una noche completa de fotoperiodo (barra al 100%) |
| `VEL_CAMINATA_KMH` | 4 | Velocidad para estimar el recorrido |
| `MIN_POR_BLOQUE` | 3 | Minutos estimados de registro por bloque |
| `HORA_INICIO_REGISTRO` | 6 | Inicio de la ventana laboral de registro (6 a.m.) |
| `HORA_FIN_REGISTRO` | 14 | Fin de la ventana laboral de registro (2 p.m.) |
| `HORA_AVISO_PENDIENTES` | 13 | Hora de la alerta de bloques sin registrar (1 p.m.) |

> Si cambias `UMBRAL_HORAS`, cambia también la función `umbral_alerta_horas()` en la base de datos para que ambas validaciones coincidan.

---
Flores El Trigal S.A.S. — Mantenimiento
