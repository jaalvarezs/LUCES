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
- **Roles:** operario (registra), supervisor (además crea horómetros y captura GPS de bloques), administrador (todo + gestión de bloques y usuarios), consulta (acceso único a la pestaña Lecturas: ver registros, alertas, mapa de recorridos y exportar CSV — sin poder registrar, justificar ni editar nada, bloqueado también a nivel de base de datos).
- **Dashboard de lecturas:** filtros por fecha (con chips rápidos Hoy/7 días/30 días/Todo el historial — vista por defecto), bloque y horómetro, más exportación a CSV.
- **Edición de lecturas de horómetro:** el operario puede corregir su propia lectura del día si se equivocó al digitar; supervisor/administrador pueden corregir cualquier lectura, de cualquier fecha. No requiere SQL nuevo (usa la misma validación de alerta/delta ya existente en el servidor).
- **Luz nocturna:** registro por bloque, cama y lado (A/B) con fecha y hora editables y 5 puntos de medición (anterior, posterior, bajo bombillo, entre bombillo, borde); si algún punto queda bajo la referencia de 1.5 µmol/m²/s se exige observación (validado en app y servidor). Funciona offline con la misma cola de sincronización, y se visualiza y exporta desde el dashboard de Lecturas con el conmutador Horómetros/Luz nocturna.
- **Edición de horómetros:** nombre y rango de naves editables (supervisor/administrador), con validación de solapamiento contra otros horómetros activos del mismo bloque.

## Instalación

### 1. Base de datos (Supabase)

En el SQL Editor de tu proyecto Supabase ejecuta **en orden**:

1. `horometros_schema.sql` (esquema base: tablas, triggers, RLS, 50 bloques)
2. `actualizacion_v2.sql` (GPS por bloque, justificaciones, recorridos)
3. `actualizacion_v3.sql` (supervisores pueden crear y editar bloques)
4. `actualizacion_v4.sql` (supervisores ven la lista de usuarios para el mapa de recorridos)
5. `actualizacion_v5.sql` (rangos de naves sin solapamiento; operarios pueden pausar/reactivar horómetros)
6. `actualizacion_v6.sql` (rol 'consulta' de solo visualización)
7. `actualizacion_v7.sql` (lecturas de luz nocturna: 5 puntos por cama/lado contra referencia de 1.5 µmol/m²/s)
8. `actualizacion_v8.sql` (evita duplicados accidentales en luz nocturna)

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
| `actualizacion_v4.sql` | Actualización: supervisores ven usuarios (mapa de recorridos) |
| `actualizacion_v5.sql` | Actualización: anti-solapamiento de naves + pausa por operarios |
| `actualizacion_v6.sql` | Actualización: rol consulta (solo dashboard) |
| `actualizacion_v7.sql` | Actualización: lecturas de luz nocturna (µmol/m²/s) |
| `actualizacion_v8.sql` | Actualización: restricción anti-duplicados en luz nocturna |
| `actualizacion_v9.sql` | Programa el envío semanal del informe (pg_cron) |
| `supabase-edge-function-reporte-semanal.ts` | Código de la función que arma y envía el informe (se pega en el panel de Supabase, no en GitHub Pages) |

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


## Informe semanal automático (horas de luz + novedades)

Cada lunes 7:00 a.m. (hora Colombia) se genera y envía por correo un informe
con: horas de luz por bloque y horómetro, alertas de la semana, bloques sin
registrar/justificar, y lecturas de luz nocturna bajo la referencia.

### Cómo activarlo

1. **Crear cuenta en Resend** (gratis, sin tarjeta): https://resend.com — regístrate
   con el correo al que quieres que lleguen las pruebas (ej. `juan.alvarezs@floreseltrigal.com`).
2. **Obtener la API key**: Resend → API Keys → Create API Key. Cópiala.
3. **Desplegar la función**: Supabase → Edge Functions → "Deploy a new function" →
   "Via Editor". Nómbrala `reporte-semanal` y pega el contenido de
   `supabase-edge-function-reporte-semanal.ts`. Guardar/Deploy.
4. **Configurar sus secretos**: dentro de la función → Secrets (o Settings → Edge
   Functions → Secrets, según la versión del panel):
   - `RESEND_API_KEY` = la API key del paso 2
   - `REPORTE_DESTINATARIOS` = correos separados por coma (ej. `juan.alvarezs@floreseltrigal.com`)
5. **Ejecutar `actualizacion_v9.sql`** en el SQL Editor — deja programado el envío
   automático de todos los lunes.
6. **Probar sin esperar al lunes**: en el panel de la función hay un botón de
   prueba ("Test"/"Send Request") donde puedes ejecutarla manualmente y revisar
   el correo de inmediato.

### Cuando quieras agregar más destinatarios

Mientras se envíe solo a correos que tú mismo verificaste en Resend, no hace
falta nada más. Para enviar a cualquier correo de la empresa sin verificarlo
uno por uno, verifica el dominio `floreseltrigal.com` en Resend (Domains →
Add Domain, agrega los registros DNS que te indique) y cambia el secreto
`REPORTE_REMITENTE` a una dirección de ese dominio, ej.
`Fotoperiodo Trigal <reportes@floreseltrigal.com>`.


## Corrección importante — cola de sincronización (20 ago 2026)

Se corrigió un error grave: cuando una lectura no se podía subir, la app
guardaba el mensaje de error dentro del propio registro antes de reintentarlo,
dejándolo con un campo que no correspondía a ninguna columna real. Esto hacía
que el reintento fallara **para siempre**, acumulando registros sin subir
indefinidamente (se detectó con 61 registros atascados en un dispositivo).

Ya corregido: los reintentos ahora envían el registro limpio, y la versión
nueva de la app limpia automáticamente cualquier registro que haya quedado
así de contaminado en versiones anteriores — no hace falta borrar nada a mano.

Además, en la pestaña **Pendientes** ahora aparece un panel rojo con el
detalle de cualquier registro que no se haya podido subir (bloque, horómetro,
fecha, motivo), con la opción de agregar la observación que falte y
reintentar sin perder el dato, o descartarlo si fue un error genuino.

También se agregó un aviso preventivo: si el operario registra **sin
conexión** y el dispositivo no tiene guardada la lectura anterior de ese
horómetro, la app no puede saber de antemano si el nuevo valor generará una
alerta — ahora pide una observación de precaución en ese caso, en vez de
dejar que el registro falle silenciosamente al sincronizar más tarde.
