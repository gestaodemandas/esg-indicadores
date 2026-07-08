-- ═══════════════════════════════════════════════════════════════════════════
-- APLICATIVO ESG — Módulo Acidentes
-- Executar no SQL Editor do Supabase (projeto configurado no index.html)
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Tabela de registros de acidentes/ocorrências ─────────────────────────
create table if not exists public.esg_acidentes (
  id                bigint generated always as identity primary key,
  filial            text not null check (filial in ('GUS','IMB','PAL','TAM','AJU','JPA','PNG','CAU','BAR','CABO')),
  nome              text not null,
  matricula         text not null default 'N/A',          -- número ou 'N/A' (validado no app)
  data_acidente     date not null,
  tipo_ocorrencia   text not null check (tipo_ocorrencia in ('Acidente','Emergência','Incidente')),
  tipo_acidente     text not null default 'N/A' check (tipo_acidente in ('N/A','Típico','Trajeto','Prestador')),
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
  tipo_equipamento  text not null default 'N/A' check (tipo_equipamento in ('N/A','Carro','Moto','Paleteira','Outros')),
  causa             text,
  parte_corpo       text,
  acao_corretiva    text,
  status            text not null default 'Pendente' check (status in ('Pendente','Finalizado')),
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
