// supabase/functions/reporte-semanal/index.ts
//
// Genera el informe semanal de fotoperiodo (horas de luz por bloque y
// horómetro, alertas, días sin registrar/justificar, y luz nocturna bajo
// referencia) y lo envía por correo con Resend.
//
// Se despliega pegando este código en:
//   Supabase → Edge Functions → Deploy a new function → Via Editor
// Nombre de la función: reporte-semanal
//
// Variables que hay que configurar en Edge Functions → Secrets:
//   RESEND_API_KEY          -> la API key de tu cuenta de Resend
//   REPORTE_DESTINATARIOS   -> correos separados por coma, ej:
//                              juan.alvarezs@floreseltrigal.com
// (SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY ya vienen automáticos, no se
//  configuran a mano.)

import { createClient } from 'jsr:@supabase/supabase-js@2'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const DESTINATARIOS = (Deno.env.get('REPORTE_DESTINATARIOS') ?? '')
  .split(',').map(s => s.trim()).filter(Boolean)
// Mientras no haya dominio verificado en Resend, se envía desde su dirección
// de pruebas. Cuando verifiques floreseltrigal.com, cambia este secreto:
const REMITENTE = Deno.env.get('REPORTE_REMITENTE') ?? 'Fotoperiodo Trigal <onboarding@resend.dev>'

const UMBRAL_HORAS = 2
const UMBRAL_LUZ = 1.5

function fmtFechaCO(d: Date) {
  return d.toLocaleDateString('es-CO', { day: '2-digit', month: '2-digit', year: 'numeric', timeZone: 'America/Bogota' })
}
function isoDia(d: Date) {
  return d.toISOString().slice(0, 10)
}

Deno.serve(async (req) => {
  try {
    const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Rango: los 7 días anteriores a hoy (si corre el lunes, cubre lunes a domingo pasados)
    const hoy = new Date()
    const ayer = new Date(hoy.getTime() - 24 * 60 * 60 * 1000)
    const desdeD = new Date(hoy.getTime() - 7 * 24 * 60 * 60 * 1000)
    const desdeStr = isoDia(desdeD)
    const hastaStr = isoDia(ayer)

    const { data: bloques } = await db.from('bloques').select('id, codigo')
    const { data: horometros } = await db.from('horometros').select('id, nombre, bloque_id')
    const bloquePorId = new Map((bloques || []).map(b => [b.id, b]))
    const horoPorId = new Map((horometros || []).map(h => [h.id, h]))
    const idsHoro = (horometros || []).map(h => h.id)
    const bloquesActivos = new Set(
      (horometros || []).filter((h: any) => h).map((h: any) => h.bloque_id)
    )

    const { data: lecturas } = await db.from('lecturas')
      .select('horometro_id, fecha, valor, delta, alerta, observacion')
      .in('horometro_id', idsHoro.length ? idsHoro : [-1])
      .gte('fecha', desdeStr).lte('fecha', hastaStr)

    const { data: justificaciones } = await db.from('justificaciones_bloque')
      .select('bloque_id, fecha, motivo')
      .gte('fecha', desdeStr).lte('fecha', hastaStr)

    const { data: luz } = await db.from('lecturas_luz')
      .select('bloque_id, cama, lado, medido_en, bajo_umbral, observacion')
      .gte('medido_en', `${desdeStr}T00:00:00-05:00`).lte('medido_en', `${hastaStr}T23:59:59-05:00`)

    // ---- Agregación por horómetro ----
    const porHoro = new Map<number, any>()
    for (const h of horometros || []) {
      porHoro.set(h.id, { bloqueCodigo: bloquePorId.get(h.bloque_id)?.codigo ?? '?', horoNombre: h.nombre, totalHoras: 0, noches: 0, alertas: 0 })
    }
    const alertasDetalle: any[] = []
    for (const l of lecturas || []) {
      const agr = porHoro.get(l.horometro_id)
      if (!agr) continue
      agr.noches++
      if (l.delta != null) agr.totalHoras += Number(l.delta)
      if (l.alerta) {
        agr.alertas++
        alertasDetalle.push({ bloque: agr.bloqueCodigo, horo: agr.horoNombre, fecha: l.fecha, delta: l.delta, observacion: l.observacion })
      }
    }

    // ---- Días sin registrar ni justificar, por bloque ----
    const registrado = new Set<string>()
    for (const l of lecturas || []) {
      const h = horoPorId.get(l.horometro_id)
      if (h) registrado.add(`${h.bloque_id}|${l.fecha}`)
    }
    const justificado = new Set((justificaciones || []).map((j: any) => `${j.bloque_id}|${j.fecha}`))
    const diasSemana: string[] = []
    for (let i = 0; i < 7; i++) diasSemana.push(isoDia(new Date(desdeD.getTime() + i * 24 * 60 * 60 * 1000)))
    const incumplimientos: any[] = []
    for (const bId of bloquesActivos) {
      for (const f of diasSemana) {
        const key = `${bId}|${f}`
        if (!registrado.has(key) && !justificado.has(key)) {
          incumplimientos.push({ bloque: bloquePorId.get(bId)?.codigo ?? '?', fecha: f })
        }
      }
    }

    // ---- Luz nocturna bajo referencia ----
    const luzBajos = (luz || []).filter((l: any) => l.bajo_umbral).map((l: any) => ({
      bloque: bloquePorId.get(l.bloque_id)?.codigo ?? '?',
      cama: l.cama, lado: l.lado,
      fecha: new Date(l.medido_en).toLocaleString('es-CO', { timeZone: 'America/Bogota', day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }),
      observacion: l.observacion
    }))

    // ---- HTML del informe ----
    const filasHoro = [...porHoro.values()]
      .filter(a => a.noches > 0)
      .sort((a, b) => a.bloqueCodigo.localeCompare(b.bloqueCodigo, 'es', { numeric: true }))
      .map(a => {
        const esperado = 7 * UMBRAL_HORAS
        const pct = Math.min(100, Math.round((a.totalHoras / esperado) * 100))
        const color = a.alertas > 0 ? '#ff6b57' : '#5fd68a'
        return `<tr>
          <td style="padding:8px 6px;border-bottom:1px solid #e5e5e5">Bloque ${a.bloqueCodigo}</td>
          <td style="padding:8px 6px;border-bottom:1px solid #e5e5e5">${a.horoNombre}</td>
          <td style="padding:8px 6px;border-bottom:1px solid #e5e5e5;text-align:center">${a.noches}/7</td>
          <td style="padding:8px 6px;border-bottom:1px solid #e5e5e5;text-align:center">${a.totalHoras.toFixed(1)} h</td>
          <td style="padding:8px 6px;border-bottom:1px solid #e5e5e5"><div style="background:#eee;border-radius:4px;overflow:hidden;height:14px;width:120px"><div style="background:${color};height:100%;width:${pct}%"></div></div></td>
          <td style="padding:8px 6px;border-bottom:1px solid #e5e5e5;text-align:center;color:${a.alertas > 0 ? '#c92f1c' : '#1e7d45'};font-weight:700">${a.alertas || '—'}</td>
        </tr>`
      }).join('') || '<tr><td colspan="6" style="padding:10px;color:#777">Sin lecturas esta semana.</td></tr>'

    const filasAlertas = alertasDetalle.length ? alertasDetalle.map(a => `<tr>
        <td style="padding:6px;border-bottom:1px solid #eee">${a.fecha}</td>
        <td style="padding:6px;border-bottom:1px solid #eee">Bloque ${a.bloque} · ${a.horo}</td>
        <td style="padding:6px;border-bottom:1px solid #eee;color:#c92f1c;font-weight:700">${a.delta != null ? Number(a.delta).toFixed(1) : '—'} h</td>
        <td style="padding:6px;border-bottom:1px solid #eee">${a.observacion ?? '—'}</td>
      </tr>`).join('') : '<tr><td colspan="4" style="padding:10px;color:#777">Sin alertas de horómetro esta semana. 🌼</td></tr>'

    const filasIncumplimientos = incumplimientos.length ? incumplimientos
      .sort((a, b) => a.fecha.localeCompare(b.fecha))
      .map(i => `<tr><td style="padding:6px;border-bottom:1px solid #eee">${i.fecha}</td><td style="padding:6px;border-bottom:1px solid #eee">Bloque ${i.bloque}</td></tr>`).join('')
      : '<tr><td colspan="2" style="padding:10px;color:#777">Todos los bloques se registraron o justificaron todos los días. ✔</td></tr>'

    const filasLuz = luzBajos.length ? luzBajos.map((l: any) => `<tr>
        <td style="padding:6px;border-bottom:1px solid #eee">${l.fecha}</td>
        <td style="padding:6px;border-bottom:1px solid #eee">Bloque ${l.bloque} · Cama ${l.cama}${l.lado}</td>
        <td style="padding:6px;border-bottom:1px solid #eee">${l.observacion ?? '—'}</td>
      </tr>`).join('') : '<tr><td colspan="3" style="padding:10px;color:#777">Sin lecturas de luz bajo la referencia esta semana. 🌼</td></tr>'

    const rango = `${fmtFechaCO(desdeD)} a ${fmtFechaCO(ayer)}`
    const html = `<div style="font-family:Arial,sans-serif;max-width:760px;margin:0 auto;color:#222">
      <h2 style="color:#c47d00;margin-bottom:2px">🌼 Informe semanal de fotoperiodo</h2>
      <p style="color:#555;margin-top:0">Flores El Trigal S.A.S. · Sede Olas — ${rango}</p>

      <h3>Horas de luz por bloque y horómetro</h3>
      <table style="border-collapse:collapse;width:100%;font-size:13px">
        <thead><tr style="text-align:left;color:#777;font-size:11px;text-transform:uppercase">
          <th style="padding:6px">Bloque</th><th style="padding:6px">Horómetro</th><th style="padding:6px">Noches</th><th style="padding:6px">Total</th><th style="padding:6px">Cumplimiento</th><th style="padding:6px">Alertas</th>
        </tr></thead>
        <tbody>${filasHoro}</tbody>
      </table>

      <h3 style="margin-top:26px">⚠️ Alertas de horómetro (menos de 2 h)</h3>
      <table style="border-collapse:collapse;width:100%;font-size:13px">
        <thead><tr style="text-align:left;color:#777;font-size:11px;text-transform:uppercase"><th style="padding:6px">Fecha</th><th style="padding:6px">Horómetro</th><th style="padding:6px">Horas</th><th style="padding:6px">Observación</th></tr></thead>
        <tbody>${filasAlertas}</tbody>
      </table>

      <h3 style="margin-top:26px">📋 Días sin registrar ni justificar</h3>
      <table style="border-collapse:collapse;width:100%;font-size:13px">
        <thead><tr style="text-align:left;color:#777;font-size:11px;text-transform:uppercase"><th style="padding:6px">Fecha</th><th style="padding:6px">Bloque</th></tr></thead>
        <tbody>${filasIncumplimientos}</tbody>
      </table>

      <h3 style="margin-top:26px">💡 Luz nocturna bajo referencia (1.5 µmol/m²/s)</h3>
      <table style="border-collapse:collapse;width:100%;font-size:13px">
        <thead><tr style="text-align:left;color:#777;font-size:11px;text-transform:uppercase"><th style="padding:6px">Fecha</th><th style="padding:6px">Ubicación</th><th style="padding:6px">Observación</th></tr></thead>
        <tbody>${filasLuz}</tbody>
      </table>

      <p style="color:#999;font-size:11px;margin-top:30px">Generado automáticamente por la app de Horómetros · Fotoperiodo.</p>
    </div>`

    if (!DESTINATARIOS.length) {
      return new Response(JSON.stringify({ error: 'No hay destinatarios configurados (secreto REPORTE_DESTINATARIOS vacío).' }), { status: 400 })
    }

    const resendResp = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: REMITENTE,
        to: DESTINATARIOS,
        subject: `Informe semanal fotoperiodo — ${rango}`,
        html
      })
    })
    const resendData = await resendResp.json()
    if (!resendResp.ok) {
      return new Response(JSON.stringify({ error: resendData }), { status: 500, headers: { 'Content-Type': 'application/json' } })
    }

    return new Response(JSON.stringify({ ok: true, enviado_a: DESTINATARIOS, rango, id: resendData.id }), { headers: { 'Content-Type': 'application/json' } })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json' } })
  }
})
