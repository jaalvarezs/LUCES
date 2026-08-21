-- ============================================================================
-- ACTUALIZACIÓN v9 — Programar el informe semanal (lunes 7:00 a.m. Colombia)
-- Ejecutar en el SQL Editor de Supabase, DESPUÉS de:
--   1) desplegar la Edge Function "reporte-semanal"
--      (Edge Functions → Deploy a new function → Via Editor, pegar el código
--       de supabase-edge-function-reporte-semanal.ts)
--   2) configurar sus secretos (Edge Functions → reporte-semanal → Secrets):
--        RESEND_API_KEY = tu API key de Resend
--        REPORTE_DESTINATARIOS = juan.alvarezs@floreseltrigal.com
-- ============================================================================

create extension if not exists pg_net;

select cron.schedule(
  'informe-semanal-fotoperiodo',
  '0 12 * * 1',   -- 12:00 UTC = 7:00 a.m. hora Colombia, todos los lunes
  $$
  select net.http_post(
    url := 'https://wkdxuastrkhurikobcoj.supabase.co/functions/v1/reporte-semanal',
    headers := '{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndrZHh1YXN0cmtodXJpa29iY29qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxNTkxMjcsImV4cCI6MjA5OTczNTEyN30.Hc80Z68FfBPMNBLu_vr51aFRU6DqyKBD_qMqn-zXhdA", "Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);

-- ============================================================================
-- Verificar que quedó programado:
--   select jobname, schedule, active from cron.job;
--
-- Ver si ya corrió y cómo le fue (después del primer lunes, o de una prueba):
--   select jobname, status, return_message, start_time
--   from cron.job_run_details order by start_time desc limit 5;
--
-- Para pausar el envío automático más adelante:
--   select cron.unschedule('informe-semanal-fotoperiodo');
-- ============================================================================
