-- ═══════════════════════════════════════════════════════════════════════════
-- APLICATIVO ESG — Módulo Treinamentos (NRs)
-- Executar no SQL Editor do Supabase (projeto nkijyuartfyxrawkivmm),
-- DEPOIS de 01_schema.sql / 03_migracao_form.sql / 04_aso.sql
-- (usa esg_pode_ver e esg_e_corporativo já criados).
--
-- Modelo: o pessoal da filial preenche DIRETO NO APP (decisão 2026-07-14).
-- Só 3 dados são "de verdade": colaborador, treinamento exigido e a DATA em que
-- realizou. Vencimento, dias a vencer e situação (Em dia / A renovar / Vencido /
-- Não realizado) são DERIVADOS na leitura — nunca armazenados.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Catálogo de treinamentos (único p/ todas as filiais; escrita só corporativo)
create table if not exists public.esg_trein_catalogo (
  id                 bigint generated always as identity primary key,
  codigo             text not null unique,   -- ex.: 'NR-35 Altura' (= nome da aba na planilha de origem)
  nome               text not null,          -- ex.: 'NR35 — Trabalho em Altura'
  periodicidade_dias int not null,           -- 365 (anual) / 730 (bienal)
  funcoes_obrigadas  text,                   -- texto de referência exibido como dica
  ativo              boolean not null default true,
  ordem              int not null default 0
);
comment on table public.esg_trein_catalogo is 'ESG/Treinamentos — catálogo único de treinamentos normativos (periodicidade, funções obrigadas). Escrita restrita ao corporativo.';

-- ── 2. Registros: 1 linha = colaborador × treinamento exigido ────────────────
create table if not exists public.esg_trein_registro (
  id                  bigint generated always as identity primary key,
  filial              text not null,
  nome                text not null,
  matricula           text not null default 'N/A',
  funcao              text,
  setor               text,
  treinamento_id      bigint not null references public.esg_trein_catalogo(id),
  data_realizacao     date,        -- null = NÃO REALIZADO
  vencimento_override date,        -- só via importação, quando o fim do prazo da planilha difere do calculado
  obs                 text,
  created_at          timestamptz not null default now(),
  created_by          uuid default auth.uid(),
  updated_at          timestamptz not null default now()
);
comment on table public.esg_trein_registro is 'ESG/Treinamentos — colaborador × treinamento exigido, com data da última realização. Situação é derivada na leitura.';

create index if not exists idx_esg_trein_reg_filial on public.esg_trein_registro (filial);
create index if not exists idx_esg_trein_reg_trein  on public.esg_trein_registro (treinamento_id);

drop trigger if exists trg_esg_trein_reg_updated on public.esg_trein_registro;
create trigger trg_esg_trein_reg_updated
  before update on public.esg_trein_registro
  for each row execute function public.esg_set_updated_at();

-- ── 3. RLS ────────────────────────────────────────────────────────────────────
alter table public.esg_trein_catalogo enable row level security;
alter table public.esg_trein_registro enable row level security;

-- Catálogo: todo autenticado lê; só corporativo escreve
drop policy if exists esg_trein_cat_select on public.esg_trein_catalogo;
create policy esg_trein_cat_select on public.esg_trein_catalogo for select to authenticated using (true);
drop policy if exists esg_trein_cat_insert on public.esg_trein_catalogo;
create policy esg_trein_cat_insert on public.esg_trein_catalogo for insert to authenticated with check (public.esg_e_corporativo());
drop policy if exists esg_trein_cat_update on public.esg_trein_catalogo;
create policy esg_trein_cat_update on public.esg_trein_catalogo for update to authenticated using (public.esg_e_corporativo()) with check (public.esg_e_corporativo());
drop policy if exists esg_trein_cat_delete on public.esg_trein_catalogo;
create policy esg_trein_cat_delete on public.esg_trein_catalogo for delete to authenticated using (public.esg_e_corporativo());

-- Registros: mesmo escopo por filial/grupo do Acidentes (técnico vê e edita só o seu grupo)
drop policy if exists esg_trein_reg_select on public.esg_trein_registro;
create policy esg_trein_reg_select on public.esg_trein_registro for select to authenticated using (public.esg_pode_ver(filial));
drop policy if exists esg_trein_reg_insert on public.esg_trein_registro;
create policy esg_trein_reg_insert on public.esg_trein_registro for insert to authenticated with check (public.esg_pode_ver(filial));
drop policy if exists esg_trein_reg_update on public.esg_trein_registro;
create policy esg_trein_reg_update on public.esg_trein_registro for update to authenticated using (public.esg_pode_ver(filial)) with check (public.esg_pode_ver(filial));
drop policy if exists esg_trein_reg_delete on public.esg_trein_registro;
create policy esg_trein_reg_delete on public.esg_trein_registro for delete to authenticated using (public.esg_pode_ver(filial));

-- ── 4. Seed do catálogo (extraído da planilha CONTROLE DE TREINAMENTOS - LOJA, GUS 2026)
insert into public.esg_trein_catalogo (codigo, nome, periodicidade_dias, funcoes_obrigadas, ordem) values
  ('NR-05 CIPA',           'NR05 — CIPA',                     730, 'Membros eleitos da CIPA', 1),
  ('NR-10 Básico',         'NR10 — Básico',                   730, 'Eletricista / Supervisor de Manutenção / Marceneiro / Serralheiro / Pintor / Encanador / Téc. Segurança', 2),
  ('NR-10 SEP',            'NR10 — SEP',                      730, 'Eletricista / Supervisor de Manutenção / Téc. Segurança', 3),
  ('NR-11 Transpaleteira', 'NR11 — Transpaleteira Elétrica',  365, 'Conferente de Mercadoria / Aux. de Depósito / Separador', 4),
  ('NR-12 Prensa',         'NR12 — Prensa',                   365, 'Aux. de Serviços Gerais / Aux. de Limpeza Sanitária', 5),
  ('NR-12 Máquinas',       'NR12 — Máquinas e Equipamentos',  365, 'Marceneiro / Montador de Móveis / Serralheiro / Pintor / Encanador / Aux. SG / Aux. Limpeza / Téc. Segurança', 6),
  ('NR-18 PEMT',           'NR18 — PEMT',                     730, 'Trade Marketing / Op. Computador / Marceneiro / Eletricista / Limpeza / Encanador / Pintor / Auditoria / TI / Designer / Supervisor Conservação', 7),
  ('NR-23 Brigada',        'NR23 — Brigada de Incêndio',      365, 'Brigada de Incêndio e Emergência — designados', 8),
  ('NR-26 Sinalização',    'NR26 — Sinalização',              365, 'Aux. de Serviços Gerais / Aux. de Limpeza Sanitária / Supervisor de Conservação', 9),
  ('NR-34 Trab. Quente',   'NR34 — Trabalho a Quente',        365, 'Serralheiro / Soldador / Aux. de Serralheiro', 10),
  ('NR-35 Altura',         'NR35 — Trabalho em Altura',       730, 'Trade Marketing / Op. Computador / Marceneiro / Eletricista / Limpeza / Encanador / Auditoria / TI / Pintor / Designer / Supervisor Conservação', 11),
  ('Direção Defensiva',    'Direção Defensiva',               365, 'Cobrador / Conferente de Mercadoria', 12)
on conflict (codigo) do update set
  nome = excluded.nome,
  periodicidade_dias = excluded.periodicidade_dias,
  funcoes_obrigadas = excluded.funcoes_obrigadas,
  ordem = excluded.ordem;

-- Conferência:
-- select codigo, periodicidade_dias from public.esg_trein_catalogo order by ordem;
-- select count(*) from public.esg_trein_registro;
