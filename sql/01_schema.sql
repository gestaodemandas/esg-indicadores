-- ═══════════════════════════════════════════════════════════════════════════
-- APLICATIVO ESG — Módulo Acidentes
-- Executar no SQL Editor do Supabase (projeto configurado no index.html)
--
-- PENDÊNCIAS A VALIDAR COM SST ANTES DE FIXAR REGRAS DE NEGÓCIO:
--   1. Causa (texto livre) x Situação Geradora + Agente Causador — possível redundância.
--   2. Dias de Afastamento x Qtd. Dias de Atestado — confirmar se é o mesmo dado.
--   3. Domínios pendentes (sem check constraint ainda): Espécie, Situação Geradora,
--      Agente Causador, Natureza da Lesão, Gravidade (escala Leve/Moderada/Grave).
--   4. Opção "Cliente" em Tipo de Ocorrência/Tipo de Colaborador — aplicabilidade ao PGR.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Tabela de registros de acidentes/ocorrências ─────────────────────────
create table if not exists public.esg_acidentes (
  id                bigint generated always as identity primary key,
  filial            text not null,   -- validado por esg_filial_grupo / RLS (locais dinâmicos, sem CHECK fixo)
  nome              text not null,
  matricula         text not null default 'N/A',          -- número ou 'N/A' (validado no app)
  data_acidente     date not null,
  tipo_ocorrencia   text not null check (tipo_ocorrencia in ('Acidente','Emergência','Incidente')),
  tipo_acidente     text not null default 'N/A' check (tipo_acidente in ('N/A','Típico','Trajeto','Prestador','Não Caracterizado')),
  tipo_colaborador  text not null check (tipo_colaborador in ('Próprio','Terceirizado','Cliente')),
  empresa           text not null default 'FC',
  funcao            text not null default 'N/A',
  atestado_medico   text not null default 'N/A' check (atestado_medico in ('Sim','Não','N/A')),
  qtd_atestados     text not null default 'N/A',           -- número ou 'N/A'
  qtd_dias_atestado text not null default 'N/A',           -- número ou 'N/A'
  cid_informado     text not null default 'N/A' check (cid_informado in ('Sim','Não','N/A')),
  cid_codigo        text,
  cid_descricao     text,
  descricao_sumaria text,
  emitida_cat       text not null default 'N/A' check (emitida_cat in ('Sim','Não','N/A')),
  recibo_cat        text not null default 'N/A' check (recibo_cat in ('Sim','Não','N/A')),
  local             text,
  tipo_equipamento  text not null default 'N/A' check (tipo_equipamento in ('N/A','Veículo','Empilhadeira','Paleteira','Transpaleteira','PEMT','Prensa','Equipamento de Limpeza','Outros')),
  tipo_equipamento_outro text,   -- descrição livre quando tipo_equipamento = 'Outros'
  causa             text,
  parte_corpo       text,
  acao_corretiva    text,
  status            text not null default 'Pendente' check (status in ('Pendente','Finalizado')),

  -- ── Dados do Comunicado ──
  tecnico_seguranca      text,
  matricula_tecnico      text,        -- número ou 'N/A'
  data_comunicado        date,
  responsavel_comunicado text,
  data_relatorio         date,
  informacao_preliminar  text,

  -- ── Identificação — complemento ──
  setor                  text,
  tempo_empresa_anos     text,   -- número ou 'N/A'
  tempo_empresa_meses    text,   -- número ou 'N/A'
  tempo_cargo_anos       text,   -- número ou 'N/A'
  tempo_cargo_meses      text,   -- número ou 'N/A'
  lideranca_imediata     text,
  matricula_lideranca    text,        -- número ou 'N/A'
  habilitacao            text,
  lateralidade_dominante text not null default 'N/A' check (lateralidade_dominante in ('N/A','Destro','Canhoto','Ambidestro')),

  -- ── Classificação — complemento ──
  horario_acidente  time,
  endereco          text,
  -- ABERTO: domínio oficial ainda não definido (Espécie, Situação Geradora, Agente Causador) — sem check constraint até então
  especie           text,
  situacao_geradora text,
  agente_causador   text,
  trabalho_habitual text not null default 'N/A' check (trabalho_habitual in ('N/A','Sim','Não')),
  utilizou_epi      text not null default 'N/A' check (utilizou_epi in ('N/A','Sim','Não')),

  -- ── Atestado — bloco médico ──
  nome_medico       text,
  crm_uf            text,
  data_atendimento  date,
  dias_afastamento  text,   -- número ou 'N/A' — ABERTO: confirmar se é o mesmo dado de qtd_dias_atestado
  dias_internacao   text,   -- número ou 'N/A'

  -- ── Lesão ──
  -- ABERTO: domínio oficial de Natureza da Lesão ainda não definido
  natureza_lesao     text,
  lateralidade_lesao text not null default 'N/A' check (lateralidade_lesao in ('N/A','Direito','Esquerdo','Bilateral')),
  gravidade          text check (gravidade is null or gravidade in ('Leve','Moderada','Grave')), -- ABERTO: escala pendente de confirmação com SST

  -- ── Análise — 5 Porquês ──
  problema_5p text,
  porque_1    text,
  porque_2    text,
  porque_3    text,
  porque_4    text,
  porque_5    text,

  -- ── Plano de Ação / Grupo de Análise (listas dinâmicas) ──
  plano_acao    jsonb not null default '[]'::jsonb,   -- [{acao, responsavel, prazo}]
  grupo_analise jsonb not null default '[]'::jsonb,   -- [{nome, setor, assinatura}]
  local_data    text,

  -- ── Conclusão do preenchimento (snapshot calculado ao salvar) ──
  completude       smallint,             -- % de campos preenchidos (0–100)
  campos_pendentes jsonb not null default '[]'::jsonb,  -- rótulos ainda em branco

  created_at        timestamptz not null default now(),
  created_by        uuid default auth.uid(),
  updated_at        timestamptz not null default now()
);

comment on table public.esg_acidentes is 'ESG/SST — registros de acidentes, incidentes e emergências por filial';

-- Atualiza updated_at automaticamente
create or replace function public.esg_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_esg_acidentes_updated on public.esg_acidentes;
create trigger trg_esg_acidentes_updated
  before update on public.esg_acidentes
  for each row execute function public.esg_set_updated_at();

-- ── 2. Tabela de referência CID-10 ──────────────────────────────────────────
create table if not exists public.esg_cid10 (
  codigo    text primary key,        -- ex.: 'S52', 'S52.5', 'M54.5'
  descricao text not null
);

comment on table public.esg_cid10 is 'Referência CID-10 para autocomplete do formulário de acidentes';

-- ── 3. RLS — acesso apenas a usuários autenticados ──────────────────────────
alter table public.esg_acidentes enable row level security;
alter table public.esg_cid10     enable row level security;

drop policy if exists "esg_acidentes_select" on public.esg_acidentes;
create policy "esg_acidentes_select" on public.esg_acidentes
  for select to authenticated using (true);

drop policy if exists "esg_acidentes_insert" on public.esg_acidentes;
create policy "esg_acidentes_insert" on public.esg_acidentes
  for insert to authenticated with check (true);

drop policy if exists "esg_acidentes_update" on public.esg_acidentes;
create policy "esg_acidentes_update" on public.esg_acidentes
  for update to authenticated using (true) with check (true);

drop policy if exists "esg_acidentes_delete" on public.esg_acidentes;
create policy "esg_acidentes_delete" on public.esg_acidentes
  for delete to authenticated using (true);

drop policy if exists "esg_cid10_select" on public.esg_cid10;
create policy "esg_cid10_select" on public.esg_cid10
  for select to authenticated using (true);

-- ── 4. Índices ───────────────────────────────────────────────────────────────
create index if not exists idx_esg_acidentes_data   on public.esg_acidentes (data_acidente desc);
create index if not exists idx_esg_acidentes_filial on public.esg_acidentes (filial);
create index if not exists idx_esg_acidentes_status on public.esg_acidentes (status);
create index if not exists idx_esg_cid10_codigo     on public.esg_cid10 (codigo text_pattern_ops);
