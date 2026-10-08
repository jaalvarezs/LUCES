# LUCES · Horómetros de fotoperiodo 🌼💡

Flores El Trigal S.A.S. · Sede Olas — Mantenimiento

App web instalable (PWA) para registrar y validar los horómetros de las guirnaldas
de fotoperiodo en los bloques de crisantemo. Funciona **sin internet** en campo y
sincroniza sola al recuperar conexión.

- App publicada: https://jaalvarezs.github.io/LUCES/
- Base de datos: Supabase (proyecto `horometros_fotoperiodo`)
- Versión actual: **v2026.10.08-2** (se ve en la pantalla de inicio de sesión)

---

## Qué hace

| Función | Detalle |
|---|---|
| Registro de horómetros | Lectura diaria por horómetro, de 6:00 a.m. a 2:00 p.m. (supervisor/administrador sin límite de horario). A la 1:00 p.m. avisa los bloques sin registrar. |
| Semáforo de horas | Compara con la lectura anterior (ciclo normal: 9 p.m.–3 a.m., 10/20 min = 2.0 h por noche). Ver tabla abajo. |
| Luz nocturna | Bloque, cama, lado A/B, fecha y hora, 5 puntos de medición. Bajo 1.5 µmol/m²/s exige observación. |
| Sin internet | Lecturas, luz, justificaciones y GPS quedan en el equipo y suben solos. Si algo no sube, aparece en un panel rojo en **Pendientes**. |
| Pendientes | Bloques sin registrar, tiempo estimado de recorrido y justificación de los no recorridos. |
| Lecturas (dashboard) | Filtros por fecha, bloque, horómetro y nivel; mapa del recorrido del operario; exportación CSV. |
| Horómetros y bloques | Crear, editar rango de naves (sin solapes), pausar/reactivar, capturar GPS del bloque. |
| Tema día / noche | Botón ☀/☾ en la cabecera. |

### Semáforo de horas entre lecturas

| Nivel | Horas entre lecturas | ¿Observación obligatoria? |
|---|---|---|
| 🟢 Verde | 2.0 h o más | No |
| 🟡 Amarillo | 1.5 h hasta menos de 2.0 h | No (solo queda marcado) |
| 🔴 Rojo | menos de 1.5 h | **Sí** (cuenta como alerta) |

La regla se valida en la app **y** en la base de datos. En la base de datos la
columna `alerta` = rojo; el amarillo se calcula a partir de `delta`.

### Roles

| Rol | Puede |
|---|---|
| operario | Registrar lecturas y luz, justificar, pausar/reactivar horómetros |
| supervisor | Lo anterior + crear/editar horómetros y bloques, capturar GPS, corregir cualquier lectura |
| administrador | Todo |
| consulta | Solo ver la pestaña Lecturas y exportar CSV |

---

## Archivos de este repositorio

| Archivo | Para qué sirve | ¿Dónde se usa? |
|---|---|---|
| `index.html` | La app completa | GitHub Pages |
| `sw.js` | Permite que la app abra sin internet | GitHub Pages |
| `manifest.json` | Permite instalarla en el celular/tablet | GitHub Pages |
| `icono-192.png`, `icono-512.png` | Iconos de la app | GitHub Pages |
| `horometros_schema.sql` | Esquema base de la base de datos | Supabase (solo instalación desde cero) |
| `actualizacion_v2.sql` … `actualizacion_v8.sql` | Actualizaciones de la base de datos | Supabase (ya ejecutadas) |
| `actualizacion_v10.sql` | Semáforo verde/amarillo/rojo | Supabase |
| `README.md` | Este documento | — |

> No existe `actualizacion_v9.sql`: era el informe semanal por correo, que se descartó.

---

## Instalación desde cero (solo si hubiera que montar todo de nuevo)

1. **Supabase → SQL Editor**, ejecutar en orden: `horometros_schema.sql`, `actualizacion_v2.sql`
   hasta `actualizacion_v8.sql`, y `actualizacion_v10.sql`.
2. **Supabase → Authentication → Users**: crear cada usuario como `usuario@trigal.local`
   con **Auto Confirm User** ✅. En la app se ingresa solo con `usuario` y clave.
3. Asignar roles:
   ```sql
   update public.perfiles set rol = 'supervisor' where nombre = 'supervisor';
   ```
4. **GitHub**: subir los archivos a la raíz del repositorio y activar
   **Settings → Pages → Deploy from a branch → main / (root)**.
5. En cada equipo: abrir la app con internet, iniciar sesión una vez, aceptar ubicación y
   notificaciones, y "Agregar a pantalla de inicio".

## Cómo publicar una actualización

1. Si hay un `.sql` nuevo, ejecutarlo **primero** en Supabase.
2. Subir a GitHub los archivos cambiados (normalmente `index.html` y `sw.js`).
3. En los equipos, la versión nueva aparece al abrir la app **dos veces** con internet.
   Se confirma mirando el número de versión en la pantalla de inicio de sesión.

## Parámetros ajustables (`index.html`, sección CONFIG)

| Constante | Valor | Significado |
|---|---|---|
| `UMBRAL_VERDE` | 2 | Desde este valor la noche es verde |
| `UMBRAL_ROJO` | 1.5 | Por debajo es rojo (alerta + observación). Si se cambia, cambiar también `umbral_alerta_horas()` en Supabase |
| `HORAS_ESPERADAS` | 2 | Noche completa (barra al 100 %) |
| `UMBRAL_LUZ` | 1.5 | µmol/m²/s mínimo en luz nocturna |
| `HORA_INICIO_REGISTRO` / `HORA_FIN_REGISTRO` | 6 / 14 | Ventana de registro (6 a.m. – 2 p.m.) |
| `HORA_AVISO_PENDIENTES` | 13 | Aviso de bloques sin registrar (1 p.m.) |
| `VEL_CAMINATA_KMH` / `MIN_POR_BLOQUE` | 4 / 3 | Estimación del tiempo de recorrido |

## Historial

- **v2026.10.08** — Semáforo verde/amarillo/rojo (amarillo sin observación). Cálculo exacto
  en décimas. Filtro y contador de amarillos en el dashboard. CSV con columna "Nivel".
  Se retiró el informe semanal por correo.
- **v2026.08.20** — Corregido el error que dejaba lecturas atascadas sin subir; panel rojo de
  registros con error en Pendientes; aviso preventivo al registrar sin internet; versión visible.
- **Ago 2026** — Luz nocturna, anti-duplicados, rol consulta, edición de lecturas y horómetros.
