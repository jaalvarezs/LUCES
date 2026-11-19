# LUCES · Horómetros de fotoperiodo 🌼💡

Flores El Trigal S.A.S. · Sede Olas — Mantenimiento

App web instalable (PWA) para registrar y validar los horómetros de las guirnaldas
de fotoperiodo en los bloques de crisantemo. Funciona **sin internet** en campo y
sincroniza sola al recuperar conexión.

- App publicada: https://jaalvarezs.github.io/LUCES/
- Base de datos: Supabase (proyecto `horometros_fotoperiodo`)
- Versión actual: **v2026.11.19-1** (se ve en la pantalla de inicio de sesión)

---

## Qué hace

| Función | Detalle |
|---|---|
| Registro de horómetros | Lectura diaria por horómetro, de 6:00 a.m. a 2:00 p.m. (supervisor/administrador sin límite de horario). A la 1:00 p.m. avisa los bloques sin registrar. |
| Semáforo de horas | Compara con la lectura anterior (ciclo normal: 9 p.m.–3 a.m., 10/20 min = 2.0 h por noche). Ver tabla abajo. |
| Lecturas altas y saltos | Más de 10 h entre dos días seguidos pide confirmar la lectura. Tras varios días sin lectura, un salto de más de 10 h pregunta si es el **inicio de la siembra**; si no, exige justificarlo. |
| Noches de luz | En **Lecturas**, panel con las noches de luz de cada horómetro (1 noche ≈ 2 h) desde el inicio de siembra. Los **bancos** se muestran solo en horas. |
| Novedades eléctricas | Al medir la luz, el operario puede reportar lo que vea en el sistema eléctrico del bloque. Aparece en **Pendientes** desde las 6:00 a.m. siguientes hasta que alguien la marca como intervenida. |
| Luz nocturna | Tipo de cama (Producción/Propagación), bloque, cama, lado A/B, fecha y hora, 5 mediciones (inicio, mitad, final, entre 2 guirnaldas, entre 4 bombillos). Hora automática. Bajo la referencia exige observación. Ver protocolo abajo. |
| Sin internet | Lecturas, luz, justificaciones y GPS quedan en el equipo y suben solos. Si algo no sube, aparece en un panel rojo en **Pendientes**. |
| Pendientes | Novedades eléctricas por intervenir, bloques sin registrar, tiempo estimado de recorrido y justificación de los no recorridos. |
| Lecturas (dashboard) | Filtros por fecha, bloque, horómetro y nivel; mapa del recorrido del operario. En pantalla se ven las 500 lecturas más recientes; el **CSV trae el rango completo** con los mismos filtros (sin fecha "Desde": los últimos 6 meses). |
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

### Lecturas altas, saltos e inicio de siembra

| Caso | Qué pide la app |
|---|---|
| Más de **10 h** respecto a la lectura del día anterior | Marcar "Confirmo que la lectura es correcta" (observación opcional) |
| Más de **10 h** después de **2 o más días** sin lectura | Responder si es el **inicio de la siembra**. Si es "No", la justificación es obligatoria |

- La lectura marcada como inicio de siembra sale con 🌱 en Lecturas y no entra al semáforo.
- Las **noches de luz** de cada horómetro se cuentan desde la última lectura de siembra, incluyendo
  las horas del salto (se asume que las luces arrancaron con la siembra). Si no hay ninguna marcada,
  se cuentan desde la primera lectura.
- Una lectura de hoy se puede corregir con ✎ Editar, incluida la marca de siembra.
- **Bancos:** se marcan en la pestaña Bloques (columna "Banco"). Sus horómetros se muestran en horas,
  no en noches. Los bloques cuyo código dice "banco" quedaron marcados solos.

### Novedades del sistema eléctrico

- Se reportan desde **Registro → Luz nocturna**, en la tarjeta "⚡ Novedad del sistema eléctrico",
  con su botón o junto con la lectura de luz (queda con la hora de la medición).
- Aparecen en **Pendientes** desde las **6:00 a.m. siguientes** al reporte (lo reportado de noche,
  esa misma mañana). Lo reportado hoy se ve abajo en "Reportadas para mañana".
- "✔ Marcar intervenida" pide escribir qué se hizo; queda guardado quién y cuándo.
- Funciona sin internet: el reporte y el cierre se suben solos al recuperar señal.

### Luz nocturna — protocolo de medición

- **Inicio, mitad y final:** 3 mediciones a lo largo de la cama, en el sitio más oscuro.
- **Entre 2 guirnaldas:** punto intermedio entre dos guirnaldas.
- **Entre 4 bombillos:** punto intermedio entre cuatro bombillos.
- **Sensor:** horizontal, con extensor para no hacer sombra, a la altura del dosel de las plantas.

| Tipo de cama | Referencia mínima en cada punto |
|---|---|
| 🌼 Producción | 1.2 µmol/m²/s (≈ 10 foot-candles) |
| 🌱 Propagación | 1.5 µmol/m²/s (≈ 10 foot-candles) |

El tipo de cama se elige en el formulario y el equipo lo recuerda por bloque (la primera
vez en cada bloque hay que elegirlo). Las lecturas anteriores de 5 puntos se conservan
y se muestran como "Formato anterior" (referencia 1.5).

**Valores fuera de lo normal (atípicos):** con bombillos de 15 W · 220 V · 1700 lm, en los puntos
de medición no se esperan valores sobre ~5 µmol/m²/s (un bombillo da ≈ 1.5 µmol/m²/s a 1 m justo
debajo). La app marca en **morado** un valor si:
- supera **5.0 µmol/m²/s**, o
- es más de **3 veces** la mediana de los otros puntos de la misma cama, o menos de **la cuarta parte**.

El operario debe corregir el dato o volver a medir. Si parece un error de coma (17.90 → 1.79), la app
lo sugiere con un botón. Si el valor es real (por ejemplo, un bombillo fundido), marca "Volví a medir en
ese punto y el valor es correcto" y escribe una observación. En el dashboard esos valores salen en morado
con "?", y el CSV trae la columna "Valores atipicos".

**Hora de la lectura:** se llena sola con la hora del equipo y se actualiza mientras se
digitan las mediciones. El operario solo la corrige si registra una medición tomada antes;
en ese caso se respeta su hora hasta guardar. La base de datos guarda además, por aparte,
el momento real en que llegó el registro (`created_at`).

### Roles

| Rol | Puede |
|---|---|
| operario | Registrar lecturas y luz, justificar, pausar/reactivar horómetros, reportar y cerrar novedades eléctricas |
| supervisor | Lo anterior + crear/editar horómetros y bloques (incluida la marca de banco), capturar GPS, corregir cualquier lectura |
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
| `actualizacion_v11.sql` | Luz nocturna: 5 puntos y referencia por tipo de cama | Supabase |
| `actualizacion_v12.sql` | Inicio de siembra, días entre lecturas, bancos, noches por horómetro, novedades eléctricas | Supabase |
| `README.md` | Este documento | — |

> No existe `actualizacion_v9.sql`: era el informe semanal por correo, que se descartó.

---

## Instalación desde cero (solo si hubiera que montar todo de nuevo)

1. **Supabase → SQL Editor**, ejecutar en orden: `horometros_schema.sql`, `actualizacion_v2.sql`
   hasta `actualizacion_v8.sql`, `actualizacion_v10.sql`, `actualizacion_v11.sql` y `actualizacion_v12.sql`.
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
| `HORAS_POR_NOCHE` | 2 | Horas de horómetro que equivalen a una noche de luz (no aplica a bancos) |
| `MAX_HORAS_NOCHE` | 10 | Más de esto pide confirmar la lectura (días seguidos) o preguntar por la siembra (tras varios días) |
| `HORA_VISIBLE_NOVEDADES` | 6 | Hora desde la que una novedad eléctrica aparece en Pendientes |
| `LIMITE_PANTALLA` | 500 | Lecturas que se muestran en el dashboard |
| `MESES_CSV` | 6 | Meses que exporta el CSV cuando no se elige fecha "Desde" |
| `LUZ_MAX_PLAUSIBLE` / `LUZ_FACTOR_ALTO` / `LUZ_FACTOR_BAJO` | 5.0 / 3 / 4 | Reglas de valor atípico en luz nocturna |
| `REF_LUZ` | producción 1.2 · propagación 1.5 | µmol/m²/s mínimo en luz nocturna. Si se cambia, cambiar también `referencia_luz()` en Supabase |
| `HORA_INICIO_REGISTRO` / `HORA_FIN_REGISTRO` | 6 / 14 | Ventana de registro (6 a.m. – 2 p.m.) |
| `HORA_AVISO_PENDIENTES` | 13 | Aviso de bloques sin registrar (1 p.m.) |
| `VEL_CAMINATA_KMH` / `MIN_POR_BLOQUE` | 4 / 3 | Estimación del tiempo de recorrido |

## Historial

- **v2026.11.19** — Lectura de más de 10 h en una noche: confirmación del operario. Salto tras varios
  días sin lectura: pregunta si es inicio de siembra o pide justificarlo. Panel de noches de luz por
  horómetro en Lecturas; bancos marcados en Bloques. Novedades del sistema eléctrico desde el registro
  de luz, visibles en Pendientes al día siguiente. CSV con "Dias desde anterior" y "Noches aprox.".
  Corregido: al editar la lectura de hoy, la vista previa se comparaba contra la misma lectura.

- **v2026.11.03** — Luz nocturna: detección de valores fuera de lo normal (morado), sugerencia de
  corrección por error de coma y confirmación de re-medición. Dashboard: se corrigió que una carga lenta
  de Horómetros pudiera tapar la vista de Luz nocturna.

- **v2026.10.13** — CSV de horómetros: las naves salen en dos columnas numéricas ("Nave desde" y
  "Nave hasta"); antes, en una sola columna "1-5", Excel las convertía en fechas (01-may).

- **v2026.10.09-3** — El CSV ya no se corta en 500: descarga por paquetes de 1.000 todo el rango
  filtrado (por defecto los últimos 6 meses). Aviso en pantalla cuando se llega al tope de 500.

- **v2026.10.09** — Luz nocturna con el protocolo nuevo: inicio, mitad, final, entre 2 guirnaldas y
  entre 4 bombillos; referencia 1.2 (producción) o 1.5 (propagación); hora automática que se
  actualiza al digitar. CSV con tipo de cama y referencia.

- **v2026.10.08** — Semáforo verde/amarillo/rojo (amarillo sin observación). Cálculo exacto
  en décimas. Filtro y contador de amarillos en el dashboard. CSV con columna "Nivel".
  Se retiró el informe semanal por correo.
- **v2026.08.20** — Corregido el error que dejaba lecturas atascadas sin subir; panel rojo de
  registros con error en Pendientes; aviso preventivo al registrar sin internet; versión visible.
- **Ago 2026** — Luz nocturna, anti-duplicados, rol consulta, edición de lecturas y horómetros.
