-- ═══════════════════════════════════════════════════════════════════════════
-- ESG — Views que alimentam o Painel Executivo de Auditoria a partir dos dados
-- do APP (fonte de verdade). Projeto Supabase nkijyuartfyxrawkivmm.
--
-- ⚠️ NÃO renomeia nem apaga nada. Cria views `*_appview` (aditivas) + concede leitura.
-- O painel executivo (02. Auditoria Corporativa - Indicadores.html) foi REPONTADO para
-- ler destas views (from('esg_cipa') → from('esg_cipa_appview'), etc.). As tabelas
-- originais esg_* do painel ficam intactas como backup — reverter = desfazer o HTML.
--
-- Cobre 7 das 9 tabelas: cipa, acidentes_filial, acidentes_mensal, aso, treinamento_filial,
-- treinamento_nr, brigada. Afastamentos e Meio Ambiente NÃO têm fonte no app (o painel
-- segue lendo as tabelas estáticas nesses dois). Ver DOCUMENTACAO.md §8.
--
-- RLS: as views são AGREGADOS (contagens por filial, sem dado pessoal). Views comuns
-- (sem security_invoker) rodam com os direitos do dono e IGNORAM o RLS das tabelas-base,
-- então retornam todas as linhas — por isso o painel lê mesmo sem o usuário estar em
-- esg_usuarios. Os GRANTs no fim expõem as views à API (PostgREST).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── CIPA: 1 linha por local (esg_cipa_conformidade → formato do painel) ──────
create or replace view public.esg_cipa_appview as
select
  2026                          as ano,          -- CIPA vigente; painel filtra .eq('ano',2026)
  c.local                       as filial,
  c.previsao                    as previstos,
  c.treinados                   as treinados,
  case
    when c.cipa_ativa = 'N/A'   then 'Desobrigada'
    when c.conforme  = 'SIM'    then 'Conforme'
    else                             'Documentação pendente'
  end                           as status,
  c.observacao                  as pendencia_doc
from public.esg_cipa_conformidade c;

-- ── Acidentes por filial (só tipo_ocorrencia = Acidente; trajeto × típico) ───
create or replace view public.esg_acidentes_filial_appview as
select
  extract(year from a.data_acidente)::int as ano,
  a.filial,
  count(*) filter (where a.tipo_acidente = 'Trajeto')::int              as trajeto,
  count(*) filter (where a.tipo_acidente in ('Típico','Tipico'))::int   as tipico
from public.esg_acidentes a
where a.tipo_ocorrencia = 'Acidente' and a.data_acidente is not null
group by 1, 2;

-- ── Acidentes mês a mês (ocorrências por tipo + trajeto/típico) ──────────────
create or replace view public.esg_acidentes_mensal_appview as
select
  extract(year from a.data_acidente)::int  as ano,
  extract(month from a.data_acidente)::int as mes,
  (array['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'])
    [extract(month from a.data_acidente)::int]                          as mes_label,
  count(*) filter (where a.tipo_ocorrencia = 'Acidente')::int           as acidentes,
  count(*) filter (where a.tipo_ocorrencia = 'Emergência')::int         as emergencias,
  count(*) filter (where a.tipo_ocorrencia = 'Incidente')::int          as incidentes,
  count(*) filter (where a.tipo_ocorrencia = 'Acidente' and a.tipo_acidente = 'Trajeto')::int            as trajeto,
  count(*) filter (where a.tipo_ocorrencia = 'Acidente' and a.tipo_acidente in ('Típico','Tipico'))::int as tipico
from public.esg_acidentes a
where a.data_acidente is not null
group by 1, 2, 3;

-- ── ASO por filial: exame médico realizados × pendentes (pessoas distintas) ──
create or replace view public.esg_aso_appview as
with real as (
  select filial, count(distinct ficha) as n
  from public.esg_aso_realizado
  where filial is not null
  group by filial
),
pend as (
  select filial, count(distinct coalesce(nullif(trim(ficha),''), colaborador)) as n
  from public.esg_aso_exame
  where filial is not null and tipo_exame ~* 'M[EÉ]DICO'
  group by filial
)
select
  2026                                     as ano,
  'Exame médico periódico'                 as periodo,
  coalesce(r.filial, p.filial)             as filial,
  coalesce(r.n, 0)::int                    as realizados,
  coalesce(p.n, 0)::int                    as pendentes
from real r
full join pend p on r.filial = p.filial;

-- ── Treinamento por filial: planejado (exigidos) × realizado (já feitos) ─────
-- Interpretação confirmada pelo usuário (2026-07-15): planejado = nº de
-- (colaborador × treinamento) exigidos; realizado = os que já têm data.
create or replace view public.esg_treinamento_filial_appview as
select
  2026                                                       as ano,
  t.filial,
  count(*)::int                                              as planejado,
  count(*) filter (where t.data_realizacao is not null)::int as realizado
from public.esg_trein_registro t
where t.filial is not null
group by t.filial;

-- ── Treinamento por NR (usa o nome do catálogo como "nr") ────────────────────
create or replace view public.esg_treinamento_nr_appview as
with base as (
  select c.nome as nr,
    count(*)::int                                              as planejado,
    count(*) filter (where t.data_realizacao is not null)::int as realizado
  from public.esg_trein_registro t
  join public.esg_trein_catalogo c on c.id = t.treinamento_id
  group by c.nome
)
select
  2026 as ano, nr, planejado, realizado,
  round(100.0 * realizado / nullif(planejado,0))::int as aderencia_pct,
  case
    when round(100.0*realizado/nullif(planejado,0)) >= 80 then 'Adequado'
    when round(100.0*realizado/nullif(planejado,0)) >= 50 then 'Atenção'
    else 'Crítico'
  end as status   -- vocabulário derivado; ajustar se o filtro do painel esperar outros valores
from base;

-- ── Brigada por filial: exigência (NBR) × ativos ────────────────────────────
create or replace view public.esg_brigada_appview as
with ativos as (
  select filial, count(*)::int as n
  from public.esg_brigada_membro where ativo group by filial
)
select
  2026                                                        as ano,
  f.filial,
  (f.base + ceil(greatest(f.num_funcionarios-10,0)::numeric / nullif(f.divisor,0)))::int as exigencia,
  coalesce(a.n,0)::int                                        as ativos
from public.esg_brigada_filial f
left join ativos a on a.filial = f.filial;

-- ── GRANTS: expõe as views à API para os papéis que abrem o painel ──────────
grant select on
  public.esg_cipa_appview, public.esg_acidentes_filial_appview,
  public.esg_acidentes_mensal_appview, public.esg_aso_appview,
  public.esg_treinamento_filial_appview, public.esg_treinamento_nr_appview,
  public.esg_brigada_appview
to anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- VALIDAÇÃO (rode e compare com as tabelas atuais do painel):
--   select * from public.esg_cipa_appview               order by filial;
--   select * from public.esg_cipa where ano=2026        order by filial;
--   select * from public.esg_acidentes_filial_appview   where ano=2026 order by filial;
--   select * from public.esg_aso_appview                order by pendentes desc;
--   select * from public.esg_treinamento_filial_appview order by filial;
--   select * from public.esg_treinamento_nr_appview     order by aderencia_pct;
--   select * from public.esg_brigada_appview            order by filial;
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- INTEGRAÇÃO ATIVADA (caminho B — repontar o HTML). Feito em 2026-07-20:
-- o painel foi alterado para ler destas 7 views (from('esg_X') → 'esg_X_appview').
-- As tabelas estáticas originais (esg_cipa, esg_aso, esg_acidentes_*, esg_brigada,
-- esg_treinamento_*) NÃO foram tocadas — ficam como backup.
--
-- Passos para o usuário:
--   1) Rodar este arquivo inteiro (create or replace + grants — idempotente).
--   2) Hard-refresh no painel; conferir cada seção ESG.
--   3) Se alguma seção vier vazia/errada: restaurar o painel do backup e me avisar.
--
-- Reverter só o painel: trocar de volta 'esg_X_appview' → 'esg_X' no HTML.
-- Afastamentos e Meio Ambiente seguem lendo as tabelas estáticas (sem fonte no app).
-- ═══════════════════════════════════════════════════════════════════════════
