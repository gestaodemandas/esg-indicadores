-- ═══════════════════════════════════════════════════════════════════════════
-- ESG — Views que alimentam o Painel Executivo de Auditoria a partir dos dados
-- do APP (fonte de verdade). Projeto Supabase nkijyuartfyxrawkivmm.
--
-- ⚠️ NÃO altera nada existente. Cria views com sufixo _appview para você COMPARAR
-- com as tabelas atuais do painel antes de qualquer troca. A promoção (fazer o
-- painel ler destas views) está comentada no fim — só rodar após validar.
--
-- Cobre as 4 tabelas viáveis hoje: esg_cipa, esg_acidentes_filial,
-- esg_acidentes_mensal, esg_aso. As demais (treinamento, brigada, afastamentos,
-- meio ambiente) NÃO têm fonte equivalente no app — ver DOCUMENTACAO.md §8.
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
-- PROMOÇÃO — SÓ APÓS VALIDAR. Faz o painel ler das views SEM alterar o HTML dele.
-- Padrão reversível: renomeia a tabela antiga p/ _bkp e cria a view com o nome
-- original. Para reverter: drop view X; alter table X_bkp rename to X;
-- Rode UMA tabela por vez, conferindo o painel a cada passo.
--
-- alter table public.esg_cipa            rename to esg_cipa_bkp;
-- alter view  public.esg_cipa_appview    rename to esg_cipa;              -- (recrie a view sem o _appview)
--
-- Repetir para esg_acidentes_filial, esg_acidentes_mensal, esg_aso.
-- OBS: view herda RLS das tabelas-base; garanta que o usuário do painel tem
-- acesso de leitura às tabelas esg_* do app (política select para authenticated).
-- ═══════════════════════════════════════════════════════════════════════════
