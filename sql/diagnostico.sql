-- ═══════════════════════════════════════════════════════════════════════════
-- ESG — Diagnóstico rápido do banco (cole no SQL Editor do Supabase e rode)
-- Não altera nada; só mostra o que já existe. Rode a PARTE 1 primeiro.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── PARTE 1: o que já está criado? (presente = false → falta rodar o SQL do módulo)
select item, tipo, presente from (
  select t as item, 'tabela' as tipo, (to_regclass('public.'||t) is not null) as presente
    from unnest(array[
      'esg_acidentes','esg_cid10','esg_filial_grupo','esg_usuarios','esg_tecnico_filial',
      'esg_aso_upload','esg_aso_exame','esg_trein_catalogo','esg_trein_registro',
      'esg_cipa_conformidade','esg_aso_realizado']) t
  union all
  select p, 'função', (to_regprocedure('public.'||p) is not null)
    from unnest(array['esg_pode_ver(text)','esg_e_corporativo()','esg_email_por_matricula(text)']) p
) x order by presente, tipo, item;
-- Esperado: todas as linhas com presente = true.
-- Mapa item → arquivo: esg_filial_grupo/esg_pode_ver=03 · esg_aso_*=04 ·
-- esg_trein_*=05 · esg_cipa=06 · esg_aso_realizado=07 · esg_e_corporativo=04.

-- ── PARTE 2: os dados foram carregados? (rode só se a Parte 1 estiver toda true)
-- select 'esg_acidentes' t, count(*) n from public.esg_acidentes
-- union all select 'esg_cipa_conformidade', count(*) from public.esg_cipa_conformidade  -- ~16
-- union all select 'esg_trein_catalogo', count(*) from public.esg_trein_catalogo  -- 14
-- union all select 'esg_trein_registro', count(*) from public.esg_trein_registro  -- ~1.800
-- union all select 'esg_aso_exame',      count(*) from public.esg_aso_exame
-- union all select 'esg_aso_realizado',  count(*) from public.esg_aso_realizado   -- ~1.427
-- order by 1;

-- ── PARTE 3: alinhar grafia da filial no ASO — "ALH" → "CD ALH" (decisão 2026-07-15)
-- Corrige registros antigos já importados (imports novos já entram como CD ALH).
-- update public.esg_aso_exame set filial = 'CD ALH' where filial = 'ALH';

-- ── PARTE 4: Brigada — "DEP GUS" é a mesma unidade que "MESTRE NILO" (decisão 2026-07-15)
-- Corrige a carga que entrou como DEP GUS (o brigada_seed.sql já foi ajustado p/ futuros imports).
-- update public.esg_brigada_membro set filial = 'MESTRE NILO' where filial = 'DEP GUS';
-- update public.esg_brigada_filial set filial = 'MESTRE NILO' where filial = 'DEP GUS';
