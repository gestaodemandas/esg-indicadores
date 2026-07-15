-- ═══════════════════════════════════════════════════════════════════════════
-- APLICATIVO ESG — Módulo CIPA (conformidade por filial)
-- Executar no SQL Editor do Supabase (projeto nkijyuartfyxrawkivmm),
-- DEPOIS de 01/03 (usa esg_pode_ver e esg_e_corporativo).
--
-- Modelo: 1 linha por local, editada DIRETO NO APP (sem planilha/import).
-- Espelha a planilha "CONFORMIDADE CIPA VIGENTE": status da CIPA, dimensionamento
-- (previsão da norma × ativos × treinados) e documentos necessários × existentes.
-- A carga inicial dos dados fica em dados/cipa_seed.sql (fora do git — observações
-- contêm nomes de pessoas).
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.esg_cipa (
  local          text primary key,             -- sigla do local (GUS, CABO, MESTRE NILO, CORP, RETAILX…)
  cipa_ativa     text not null default 'SIM' check (cipa_ativa in ('SIM','NÃO','N/A')),
  representacao  text default 'FUNCIONÁRIOS',
  previsao       int,                          -- membros que a norma (NR-5) pede
  ativos         int,                          -- membros ativos hoje
  treinados      int,                          -- membros com treinamento NR-5 em dia
  entrega_atas   text,                         -- atas/recibos entregues (nº ou OK/PENDENTE/NÃO/N/A)
  ata_eleicao    text check (ata_eleicao is null or ata_eleicao in ('OK','PENDENTE','NÃO','N/A')),
  cedulas        text check (cedulas is null or cedulas in ('OK','PENDENTE','NÃO','N/A')),
  conforme       text check (conforme is null or conforme in ('SIM','NÃO','N/A')),
  data_posse     date,
  data_renovacao date,                         -- vencida/a vencer é DERIVADO na leitura (vs. hoje)
  observacao     text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
comment on table public.esg_cipa is 'ESG/CIPA — conformidade por local: status, dimensionamento NR-5 e documentos. Editada direto no app.';

drop trigger if exists trg_esg_cipa_updated on public.esg_cipa;
create trigger trg_esg_cipa_updated
  before update on public.esg_cipa
  for each row execute function public.esg_set_updated_at();

-- ── RLS: leitura/edição por filial-grupo (técnico cuida da sua); insert/delete só corporativo
alter table public.esg_cipa enable row level security;

drop policy if exists esg_cipa_select on public.esg_cipa;
create policy esg_cipa_select on public.esg_cipa for select to authenticated using (public.esg_pode_ver(local));
drop policy if exists esg_cipa_update on public.esg_cipa;
create policy esg_cipa_update on public.esg_cipa for update to authenticated
  using (public.esg_pode_ver(local)) with check (public.esg_pode_ver(local));
drop policy if exists esg_cipa_insert on public.esg_cipa;
create policy esg_cipa_insert on public.esg_cipa for insert to authenticated with check (public.esg_e_corporativo());
drop policy if exists esg_cipa_delete on public.esg_cipa;
create policy esg_cipa_delete on public.esg_cipa for delete to authenticated using (public.esg_e_corporativo());

-- Conferência:
-- select local, cipa_ativa, previsao, ativos, conforme from public.esg_cipa order by local;
