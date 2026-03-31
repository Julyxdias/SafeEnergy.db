-- =================================================================
--  EnergySafe — Dados de Teste + Queries de Análise
--  Execute APÓS banco.sql
-- =================================================================


-- ═════════════════════════════════════════════════════════════════
--  BLOCO 1 — DADOS BASE
-- ═════════════════════════════════════════════════════════════════

INSERT INTO locais (nome, andar, descricao) VALUES
('Prédio ADM',       1, 'Administração geral'),
('Prédio ADM',       2, 'Financeiro e RH'),
('Prédio ADM',       3, 'TI e Infraestrutura'),
('Bloco Hospitalar', 1, 'Recepção e triagem'),
('Bloco Hospitalar', 2, 'Ala cirúrgica'),
('Bloco Hospitalar', 3, 'UTI');

INSERT INTO areas (nome, local_id, descricao) VALUES
('Administrativo',   1, 'Salas administrativas'),
('Financeiro',       2, 'Setor financeiro e RH'),
('TI',               3, 'Servidores e infraestrutura'),
('Recepção',         4, 'Entrada e triagem hospitalar'),
('Ala Cirúrgica',    5, 'Centro cirúrgico'),
('UTI',              6, 'Unidade de terapia intensiva');

INSERT INTO quadros (nome, local_id, area_id, quadro_pai_id, descricao) VALUES
('QD-ADM-1',  1, 1, NULL, 'Quadro principal ADM andar 1'),
('QD-ADM-2',  2, 2, 1,    'Quadro ADM andar 2'),
('QD-ADM-3',  3, 3, 1,    'Quadro TI andar 3'),
('QD-HOSP-1', 4, 4, NULL, 'Quadro principal hospitalar'),
('QD-HOSP-2', 5, 5, 4,    'Quadro ala cirúrgica'),
('QD-HOSP-3', 6, 6, 4,    'Quadro UTI');

INSERT INTO dispositivos (nome, quadro_id, ativo, data_instalacao) VALUES
('ESP32_ADM1_A',  1, TRUE, '2025-01-10 08:00:00'),
('ESP32_ADM1_B',  1, TRUE, '2025-01-10 08:00:00'),
('ESP32_ADM2_A',  2, TRUE, '2025-01-11 08:00:00'),
('ESP32_ADM3_A',  3, TRUE, '2025-01-12 08:00:00'),
('ESP32_HOSP1_A', 4, TRUE, '2025-02-01 08:00:00'),
('ESP32_HOSP2_A', 5, TRUE, '2025-02-01 08:00:00'),
('ESP32_HOSP2_B', 5, TRUE, '2025-02-02 08:00:00'),
('ESP32_UTI_A',   6, TRUE, '2025-02-03 08:00:00'),
('ESP32_UTI_B',   6, FALSE,'2025-02-03 08:00:00');  -- inativo (falhou)

INSERT INTO canais_medicao (dispositivo_id, fase, tipo, descricao) VALUES
-- Dispositivo 1 — ADM1 (3 fases)
(1, 'A', 'corrente', 'ADM1 Fase A'),
(1, 'B', 'corrente', 'ADM1 Fase B'),
(1, 'C', 'corrente', 'ADM1 Fase C'),
-- Dispositivo 2 — ADM1 extra
(2, 'A', 'corrente', 'ADM1-B Fase A'),
(2, 'B', 'corrente', 'ADM1-B Fase B'),
-- Dispositivo 3 — ADM2
(3, 'A', 'corrente', 'ADM2 Fase A'),
(3, 'B', 'corrente', 'ADM2 Fase B'),
(3, 'C', 'corrente', 'ADM2 Fase C'),
-- Dispositivo 4 — TI (carga alta)
(4, 'A', 'corrente', 'TI Fase A'),
(4, 'B', 'corrente', 'TI Fase B'),
(4, 'C', 'corrente', 'TI Fase C'),
-- Dispositivo 5 — HOSP recepção
(5, 'A', 'corrente', 'Recepção Fase A'),
(5, 'B', 'corrente', 'Recepção Fase B'),
-- Dispositivo 6 — Cirúrgico
(6, 'A', 'corrente', 'Cirúrgico Fase A'),
(6, 'B', 'corrente', 'Cirúrgico Fase B'),
(6, 'C', 'corrente', 'Cirúrgico Fase C'),
-- Dispositivo 7 — Cirúrgico extra
(7, 'A', 'corrente', 'Cirúrgico-B Fase A'),
-- Dispositivo 8 — UTI (carga crítica 24h)
(8, 'A', 'corrente', 'UTI Fase A'),
(8, 'B', 'corrente', 'UTI Fase B'),
(8, 'C', 'corrente', 'UTI Fase C');
-- canal_id vai de 1 a 20


-- ═════════════════════════════════════════════════════════════════
--  BLOCO 2 — MEDIÇÕES EM MASSA (estresse)
--  ~3.600 registros — 30 dias × 24h × 5 canais representativos
--  com variação realista de corrente por hora e área
-- ═════════════════════════════════════════════════════════════════

-- Padrões por área:
--   ADM:       baixo à noite (2-5A), médio de dia (15-30A)
--   TI:        constante alto (25-35A) 24h
--   Hospitalar:constante médio (20-28A) 24h
--   UTI:       constante crítico (30-38A) 24h

INSERT INTO medicoes (timestamp, canal_id, corrente, tensao, potencia)
SELECT
    gs                                         AS timestamp,
    canal_id,
    -- Corrente simulada com variação por hora e canal
    ROUND(CAST(
        CASE
            -- ADM (canais 1-8): baixo à noite, alto de dia
            WHEN canal_id BETWEEN 1  AND 8  THEN
                CASE
                    WHEN EXTRACT(HOUR FROM gs) BETWEEN 6 AND 17
                    THEN 15 + (canal_id * 1.3) + (RANDOM() * 12)
                    ELSE 2  + (RANDOM() * 4)
                END
            -- TI (canais 9-11): carga alta constante
            WHEN canal_id BETWEEN 9  AND 11 THEN
                28 + (RANDOM() * 8)
            -- Hospitalar recepção (canais 12-13)
            WHEN canal_id BETWEEN 12 AND 13 THEN
                CASE
                    WHEN EXTRACT(HOUR FROM gs) BETWEEN 7 AND 20
                    THEN 18 + (RANDOM() * 10)
                    ELSE 8  + (RANDOM() * 5)
                END
            -- Cirúrgico (canais 14-17): picos durante horário cirúrgico
            WHEN canal_id BETWEEN 14 AND 17 THEN
                CASE
                    WHEN EXTRACT(HOUR FROM gs) BETWEEN 8 AND 16
                    THEN 22 + (RANDOM() * 18)   -- pode chegar a 40A
                    ELSE 5  + (RANDOM() * 6)
                END
            -- UTI (canais 18-20): carga crítica 24h
            WHEN canal_id BETWEEN 18 AND 20 THEN
                32 + (RANDOM() * 6)
        END
    AS NUMERIC), 2)                            AS corrente,
    220.0                                      AS tensao,
    ROUND(CAST(
        CASE
            WHEN canal_id BETWEEN 1  AND 8  THEN
                CASE
                    WHEN EXTRACT(HOUR FROM gs) BETWEEN 6 AND 17
                    THEN (15 + (canal_id * 1.3) + (RANDOM() * 12)) * 220
                    ELSE (2  + (RANDOM() * 4)) * 220
                END
            WHEN canal_id BETWEEN 9  AND 11 THEN (28 + (RANDOM() * 8))  * 220
            WHEN canal_id BETWEEN 12 AND 13 THEN
                CASE
                    WHEN EXTRACT(HOUR FROM gs) BETWEEN 7 AND 20
                    THEN (18 + (RANDOM() * 10)) * 220
                    ELSE (8  + (RANDOM() * 5))  * 220
                END
            WHEN canal_id BETWEEN 14 AND 17 THEN
                CASE
                    WHEN EXTRACT(HOUR FROM gs) BETWEEN 8 AND 16
                    THEN (22 + (RANDOM() * 18)) * 220
                    ELSE (5  + (RANDOM() * 6))  * 220
                END
            WHEN canal_id BETWEEN 18 AND 20 THEN (32 + (RANDOM() * 6)) * 220
        END
    AS NUMERIC), 1)                            AS potencia
FROM
    generate_series(
        '2026-03-01 00:00:00'::TIMESTAMP,
        '2026-03-31 23:30:00'::TIMESTAMP,
        INTERVAL '30 minutes'
    ) AS gs,
    generate_series(1, 20) AS canal_id;


-- ═════════════════════════════════════════════════════════════════
--  BLOCO 3 — ALERTAS SIMULADOS
--  sobrecorrente, consumo_fora_horario, queda_brusca
-- ═════════════════════════════════════════════════════════════════

-- Sobrecorrentes (canal cirúrgico e TI)
INSERT INTO alertas (canal_id, tipo, nivel, mensagem, valor, limite, timestamp, resolvido) VALUES
(14, 'sobrecorrente', 'critico', 'Corrente acima do limite',          42.3, 40, '2026-03-05 10:14:00', TRUE),
(15, 'sobrecorrente', 'critico', 'Corrente acima do limite',          41.1, 40, '2026-03-07 11:30:00', TRUE),
(9,  'sobrecorrente', 'critico', 'Corrente acima do limite no setor TI', 40.8, 40, '2026-03-12 03:22:00', FALSE),
(16, 'sobrecorrente', 'critico', 'Corrente acima do limite',          44.5, 40, '2026-03-18 09:05:00', FALSE),
(14, 'sobrecorrente', 'critico', 'Corrente acima do limite',          43.0, 40, '2026-03-25 14:50:00', FALSE);

-- Consumo fora do horário (ADM à noite)
INSERT INTO alertas (canal_id, tipo, nivel, mensagem, valor, limite, timestamp, resolvido) VALUES
(1,  'consumo_fora_horario', 'aviso', 'Consumo detectado fora do horário', 18.2, 10, '2026-03-03 01:30:00', TRUE),
(3,  'consumo_fora_horario', 'aviso', 'Consumo detectado fora do horário', 14.7, 10, '2026-03-09 23:15:00', TRUE),
(6,  'consumo_fora_horario', 'aviso', 'Consumo detectado fora do horário', 22.1, 10, '2026-03-14 02:00:00', FALSE),
(2,  'consumo_fora_horario', 'aviso', 'Consumo detectado fora do horário', 11.3, 10, '2026-03-20 00:45:00', FALSE),
(7,  'consumo_fora_horario', 'aviso', 'Consumo detectado fora do horário', 13.8, 10, '2026-03-28 03:10:00', FALSE);

-- Quedas bruscas (possível falha de sensor ou equipamento)
INSERT INTO alertas (canal_id, tipo, nivel, mensagem, valor, limite, timestamp, resolvido) VALUES
(18, 'queda_brusca', 'aviso', 'Queda brusca de corrente na UTI',       4.1, 33.2, '2026-03-08 07:22:00', TRUE),
(10, 'queda_brusca', 'aviso', 'Queda brusca detectada no setor TI',    6.3, 29.8, '2026-03-15 16:45:00', FALSE),
(20, 'queda_brusca', 'aviso', 'Queda brusca de corrente na UTI',       3.8, 34.1, '2026-03-22 11:10:00', FALSE);


-- ═════════════════════════════════════════════════════════════════
--  BLOCO 4 — CONSUMO DIÁRIO, TARIFAS, FATURA E RATEIO
-- ═════════════════════════════════════════════════════════════════

-- consumo_diario: kWh estimado por canal (simplificado para tester)
-- Fórmula real: SOMA(potencia_i × Δt_i) / 1000
-- Aqui: média_potencia × 24h / 1000 por canal por dia
INSERT INTO consumo_diario (canal_id, data, kwh)
SELECT
    canal_id,
    DATE(timestamp)          AS data,
    ROUND(CAST(
        AVG(potencia) * 24.0 / 1000.0
    AS NUMERIC), 3)          AS kwh
FROM medicoes
GROUP BY canal_id, DATE(timestamp)
ON CONFLICT (canal_id, data) DO NOTHING;

-- Tarifa vigente
INSERT INTO tarifas (local_id, valor_kwh, vigencia, descricao) VALUES
(1, 0.95, '2026-01-01', 'Tarifa CEMIG jan/2026 — Prédio ADM'),
(4, 1.12, '2026-01-01', 'Tarifa CEMIG jan/2026 — Bloco Hospitalar');

-- Fatura de março/2026
INSERT INTO faturas (local_id, mes, valor_total, kwh_total, descricao) VALUES
(1, '2026-03-01', 18420.00, 19389.47, 'Fatura março 2026 — Prédio ADM'),
(4, '2026-03-01', 34750.00, 31026.79, 'Fatura março 2026 — Bloco Hospitalar');

-- Rateio (calculado a partir do consumo_diario agrupado por área)
-- Prédio ADM (fatura_id = 1): areas 1, 2, 3
INSERT INTO rateio (fatura_id, area_id, kwh, percentual, valor_rs)
WITH consumo_area AS (
    SELECT
        q.area_id,
        SUM(cd.kwh) AS kwh_total
    FROM consumo_diario cd
    JOIN canais_medicao cm ON cd.canal_id = cm.id
    JOIN dispositivos d    ON cm.dispositivo_id = d.id
    JOIN quadros q         ON d.quadro_id = q.id
    WHERE q.local_id = 1
      AND cd.data BETWEEN '2026-03-01' AND '2026-03-31'
    GROUP BY q.area_id
),
total AS (
    SELECT SUM(kwh_total) AS total FROM consumo_area
)
SELECT
    1                                               AS fatura_id,
    ca.area_id,
    ROUND(ca.kwh_total::NUMERIC, 2)                AS kwh,
    ROUND((ca.kwh_total / t.total * 100)::NUMERIC, 2) AS percentual,
    ROUND((ca.kwh_total / t.total * 18420)::NUMERIC, 2) AS valor_rs
FROM consumo_area ca, total t
ON CONFLICT (fatura_id, area_id) DO NOTHING;

-- Rateio — Bloco Hospitalar (fatura_id = 2): areas 4, 5, 6
INSERT INTO rateio (fatura_id, area_id, kwh, percentual, valor_rs)
WITH consumo_area AS (
    SELECT
        q.area_id,
        SUM(cd.kwh) AS kwh_total
    FROM consumo_diario cd
    JOIN canais_medicao cm ON cd.canal_id = cm.id
    JOIN dispositivos d    ON cm.dispositivo_id = d.id
    JOIN quadros q         ON d.quadro_id = q.id
    WHERE q.local_id = 4
      AND cd.data BETWEEN '2026-03-01' AND '2026-03-31'
    GROUP BY q.area_id
),
total AS (
    SELECT SUM(kwh_total) AS total FROM consumo_area
)
SELECT
    2                                               AS fatura_id,
    ca.area_id,
    ROUND(ca.kwh_total::NUMERIC, 2)                AS kwh,
    ROUND((ca.kwh_total / t.total * 100)::NUMERIC, 2) AS percentual,
    ROUND((ca.kwh_total / t.total * 34750)::NUMERIC, 2) AS valor_rs
FROM consumo_area ca, total t
ON CONFLICT (fatura_id, area_id) DO NOTHING;
