-- ═════════════════════════════════════════════════════════════════
--  BLOCO 5 — QUERIES DE ANÁLISE E CONSULTA
-- ═════════════════════════════════════════════════════════════════

-- ─── 1. Rateio final da fatura — quanto cada área paga ───────────
SELECT
    f.mes,
    l.nome                          AS local,
    a.nome                          AS area,
    r.kwh                           AS "kWh consumido",
    r.percentual                    AS "% do total",
    r.valor_rs                      AS "R$ a pagar"
FROM rateio r
JOIN faturas f ON r.fatura_id = f.id
JOIN areas   a ON r.area_id   = a.id
JOIN locais  l ON f.local_id  = l.id
ORDER BY f.mes, r.valor_rs DESC;


-- ─── 2. Consumo diário por área (série temporal) ─────────────────
SELECT
    cd.data,
    a.nome                          AS area,
    ROUND(SUM(cd.kwh)::NUMERIC, 2)  AS kwh_dia
FROM consumo_diario cd
JOIN canais_medicao cm ON cd.canal_id  = cm.id
JOIN dispositivos   d  ON cm.dispositivo_id = d.id
JOIN quadros        q  ON d.quadro_id  = q.id
JOIN areas          a  ON q.area_id    = a.id
WHERE cd.data BETWEEN '2026-03-01' AND '2026-03-31'
GROUP BY cd.data, a.nome
ORDER BY cd.data, a.nome;


-- ─── 3. Pico de potência por canal no mês ────────────────────────
SELECT
    cm.descricao                    AS canal,
    a.nome                          AS area,
    ROUND(MAX(m.potencia)::NUMERIC, 1) AS "pico W",
    ROUND(AVG(m.potencia)::NUMERIC, 1) AS "média W",
    COUNT(*)                        AS leituras
FROM medicoes m
JOIN canais_medicao cm ON m.canal_id    = cm.id
JOIN dispositivos   d  ON cm.dispositivo_id = d.id
JOIN quadros        q  ON d.quadro_id   = q.id
JOIN areas          a  ON q.area_id     = a.id
WHERE m.timestamp BETWEEN '2026-03-01' AND '2026-03-31'
GROUP BY cm.descricao, a.nome
ORDER BY "pico W" DESC;


-- ─── 4. Corrente média por fase e área ───────────────────────────
SELECT
    a.nome                          AS area,
    cm.fase,
    ROUND(AVG(m.corrente)::NUMERIC, 2) AS "corrente média (A)",
    ROUND(MAX(m.corrente)::NUMERIC, 2) AS "corrente pico (A)"
FROM medicoes m
JOIN canais_medicao cm ON m.canal_id    = cm.id
JOIN dispositivos   d  ON cm.dispositivo_id = d.id
JOIN quadros        q  ON d.quadro_id   = q.id
JOIN areas          a  ON q.area_id     = a.id
GROUP BY a.nome, cm.fase
ORDER BY a.nome, cm.fase;


-- ─── 5. Alertas ativos — painel de manutenção ────────────────────
SELECT
    al.timestamp,
    al.tipo,
    al.nivel,
    cm.descricao                    AS canal,
    a.nome                          AS area,
    al.valor,
    al.limite,
    al.mensagem
FROM alertas al
JOIN canais_medicao cm ON al.canal_id   = cm.id
JOIN dispositivos   d  ON cm.dispositivo_id = d.id
JOIN quadros        q  ON d.quadro_id   = q.id
JOIN areas          a  ON q.area_id     = a.id
WHERE al.resolvido = FALSE
ORDER BY
    CASE al.nivel
        WHEN 'critico' THEN 1
        WHEN 'aviso'   THEN 2
        ELSE 3
    END,
    al.timestamp DESC;


-- ─── 6. Resumo de alertas por tipo e área no mês ─────────────────
SELECT
    a.nome                          AS area,
    al.tipo,
    al.nivel,
    COUNT(*)                        AS ocorrencias,
    COUNT(*) FILTER (WHERE al.resolvido = FALSE) AS pendentes
FROM alertas al
JOIN canais_medicao cm ON al.canal_id   = cm.id
JOIN dispositivos   d  ON cm.dispositivo_id = d.id
JOIN quadros        q  ON d.quadro_id   = q.id
JOIN areas          a  ON q.area_id     = a.id
WHERE al.timestamp BETWEEN '2026-03-01' AND '2026-03-31'
GROUP BY a.nome, al.tipo, al.nivel
ORDER BY ocorrencias DESC;


-- ─── 7. Consumo fora do horário comercial (06h–22h) ──────────────
SELECT
    a.nome                          AS area,
    COUNT(*)                        AS leituras_fora_horario,
    ROUND(AVG(m.corrente)::NUMERIC, 2) AS "corrente média (A)",
    ROUND(SUM(m.potencia * 0.5 / 1000)::NUMERIC, 3) AS "kWh estimado fora horário"
FROM medicoes m
JOIN canais_medicao cm ON m.canal_id    = cm.id
JOIN dispositivos   d  ON cm.dispositivo_id = d.id
JOIN quadros        q  ON d.quadro_id   = q.id
JOIN areas          a  ON q.area_id     = a.id
WHERE EXTRACT(HOUR FROM m.timestamp) NOT BETWEEN 6 AND 21
  AND m.timestamp BETWEEN '2026-03-01' AND '2026-03-31'
GROUP BY a.nome
ORDER BY "kWh estimado fora horário" DESC;


-- ─── 8. Evolução semanal do consumo por local ────────────────────
SELECT
    l.nome                                      AS local,
    DATE_TRUNC('week', cd.data)::DATE           AS semana,
    ROUND(SUM(cd.kwh)::NUMERIC, 2)              AS kwh_semana
FROM consumo_diario cd
JOIN canais_medicao cm ON cd.canal_id  = cm.id
JOIN dispositivos   d  ON cm.dispositivo_id = d.id
JOIN quadros        q  ON d.quadro_id  = q.id
JOIN locais         l  ON q.local_id   = l.id
GROUP BY l.nome, DATE_TRUNC('week', cd.data)
ORDER BY l.nome, semana;


-- ─── 9. Dispositivos offline / com atraso ────────────────────────
-- Considera offline: sem leitura há mais de 60 min
-- Considera atraso:  sem leitura há mais de 10 min
SELECT
    d.nome                          AS dispositivo,
    q.nome                          AS quadro,
    a.nome                          AS area,
    MAX(m.timestamp)                AS ultima_leitura,
    ROUND(EXTRACT(EPOCH FROM (NOW() - MAX(m.timestamp))) / 60) AS "minutos sem leitura",
    CASE
        WHEN MAX(m.timestamp) < NOW() - INTERVAL '60 minutes' THEN 'OFFLINE'
        WHEN MAX(m.timestamp) < NOW() - INTERVAL '10 minutes' THEN 'ATRASO'
        ELSE 'ONLINE'
    END                             AS status
FROM medicoes m
JOIN canais_medicao cm ON m.canal_id    = cm.id
JOIN dispositivos   d  ON cm.dispositivo_id = d.id
JOIN quadros        q  ON d.quadro_id   = q.id
JOIN areas          a  ON q.area_id     = a.id
GROUP BY d.nome, q.nome, a.nome
ORDER BY "minutos sem leitura" DESC;


-- ─── 10. Top 5 horários de maior consumo (heatmap) ───────────────
SELECT
    EXTRACT(HOUR FROM m.timestamp)::INTEGER AS hora,
    EXTRACT(DOW  FROM m.timestamp)::INTEGER AS dia_semana,  -- 0=Dom, 6=Sáb
    ROUND(AVG(m.potencia)::NUMERIC, 1)      AS "potência média (W)"
FROM medicoes m
WHERE m.timestamp BETWEEN '2026-03-01' AND '2026-03-31'
GROUP BY hora, dia_semana
ORDER BY "potência média (W)" DESC
LIMIT 20;


-- ─── 11. Comparação medido vs fatura (conferência kWh) ───────────
SELECT
    l.nome                                          AS local,
    TO_CHAR(f.mes, 'MM/YYYY')                       AS mes,
    f.kwh_total                                     AS "kWh fatura",
    ROUND(SUM(cd.kwh)::NUMERIC, 2)                  AS "kWh medido",
    ROUND((SUM(cd.kwh) - f.kwh_total)::NUMERIC, 2)  AS "diferença kWh",
    ROUND(((SUM(cd.kwh) - f.kwh_total) / f.kwh_total * 100)::NUMERIC, 1) AS "desvio %"
FROM faturas f
JOIN locais l ON f.local_id = l.id
JOIN quadros q ON q.local_id = l.id
JOIN dispositivos d ON d.quadro_id = q.id
JOIN canais_medicao cm ON cm.dispositivo_id = d.id
JOIN consumo_diario cd ON cd.canal_id = cm.id
    AND DATE_TRUNC('month', cd.data) = f.mes
GROUP BY l.nome, f.mes, f.kwh_total, f.id
ORDER BY f.mes;