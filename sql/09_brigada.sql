-- ═══════════════════════════════════════════════════════════════════════════
-- APLICATIVO ESG — Módulo Brigada de Incêndio (NR-23 / NBR 14276)
-- Executar no SQL Editor do Supabase, DEPOIS de 01/03/04 (usa esg_pode_ver e
-- esg_e_corporativo).
--
-- Consolida a planilha "Controle_Brigada" (18 abas → 2 tabelas):
--   • esg_brigada_membro  = a lista de brigadistas (consolida as 16 abas de filial)
--   • esg_brigada_filial  = config por filial (dimensionamento NBR + reunião/ata)
-- O EXIGIDO e a conformidade são DERIVADOS na leitura (nunca armazenados), como
-- nos demais módulos — o que corrige inconsistências da planilha (ex.: ALH aparecia
-- com exigido 39 no PAINEL, mas o dimensionamento calcula 13).
--
-- Carga inicial em dados/brigada_seed.sql (FORA do git — contém nomes de pessoas).
-- PENDÊNCIAS (aguardando Dani): matrícula dos brigadistas (coluna já existe, nula
-- por ora) e se "DEP GUS" é unidade própria ou parte de GUS (hoje entra como local
-- próprio; virar satélite depois é só um insert em esg_filial_grupo, sem mudar schema).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Config por filial: dimensionamento NBR 14276 + documentos ─────────────
create table if not exists public.esg_brigada_filial (
  filial             text primary key,
  classificacao      text,                 -- ex.: 'C2 - Comércio', 'J - Depósito'
  num_funcionarios   int,                  -- entrada do dimensionamento
  base               int not null default 4,   -- brigadistas até 10 func. (varia por classe)
  divisor            int not null default 15,  -- 1 brigadista por excedente/divisor
  margem_seguranca   int not null default 0,   -- previsão de afastamentos/saídas
  reuniao_trimestral text,                 -- SIM/NÃO/N/A
  ata_reuniao        text,                 -- SIM/NÃO/N/A
  obs                text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
comment on table public.esg_brigada_filial is
  'ESG/Brigada — config por filial. EXIGIDO derivado: base + ceil(max(num_funcionarios-10,0)/divisor); +margem = exigido + margem_seguranca.';

-- ── 2. Brigadistas (1 linha por pessoa × papel na brigada) ───────────────────
create table if not exists public.esg_brigada_membro (
  id             bigint generated always as identity primary key,
  filial         text not null,
  nome           text not null,
  matricula      text,                     -- nulo por ora (planilha só tem nome; Dani vai confirmar)
  ativo          boolean not null default true,
  cargo_brigada  text,                     -- canônico (ver dados/brigada_seed.sql)
  treinamento    text,                     -- 'Concluído' / 'Pendente' / null
  turno          text,
  setor          text,                     -- LOTAÇÃO na planilha
  apto_altura    text,                     -- SIM/NÃO/SEM EXAME/null
  data_renovacao date,                     -- vencido/vigente é DERIVADO vs. hoje
  identificado   boolean,                  -- recebeu identificação (crachá/colete)
  obs            text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
comment on table public.esg_brigada_membro is 'ESG/Brigada — brigadistas por filial (consolida as abas de filial da planilha). Vaga em aberto = cargo_brigada ''Cargo Vago'' e ativo=false.';
create index if not exists idx_esg_brig_membro_filial on public.esg_brigada_membro (filial);

drop trigger if exists trg_esg_brig_filial_upd on public.esg_brigada_filial;
create trigger trg_esg_brig_filial_upd before update on public.esg_brigada_filial
  for each row execute function public.esg_set_updated_at();
drop trigger if exists trg_esg_brig_membro_upd on public.esg_brigada_membro;
create trigger trg_esg_brig_membro_upd before update on public.esg_brigada_membro
  for each row execute function public.esg_set_updated_at();

-- ── 3. RLS ────────────────────────────────────────────────────────────────────
alter table public.esg_brigada_filial enable row level security;
alter table public.esg_brigada_membro enable row level security;

-- Membros: técnico gerencia o próprio grupo (esg_pode_ver); corporativo tudo.
drop policy if exists esg_brig_membro_select on public.esg_brigada_membro;
create policy esg_brig_membro_select on public.esg_brigada_membro for select to authenticated using (public.esg_pode_ver(filial));
drop policy if exists esg_brig_membro_insert on public.esg_brigada_membro;
create policy esg_brig_membro_insert on public.esg_brigada_membro for insert to authenticated with check (public.esg_pode_ver(filial));
drop policy if exists esg_brig_membro_update on public.esg_brigada_membro;
create policy esg_brig_membro_update on public.esg_brigada_membro for update to authenticated using (public.esg_pode_ver(filial)) with check (public.esg_pode_ver(filial));
drop policy if exists esg_brig_membro_delete on public.esg_brigada_membro;
create policy esg_brig_membro_delete on public.esg_brigada_membro for delete to authenticated using (public.esg_pode_ver(filial));

-- Config/dimensionamento por filial: leitura por grupo; escrita só corporativo (dado de RH/estrutura).
drop policy if exists esg_brig_filial_select on public.esg_brigada_filial;
create policy esg_brig_filial_select on public.esg_brigada_filial for select to authenticated using (public.esg_pode_ver(filial));
drop policy if exists esg_brig_filial_write on public.esg_brigada_filial;
create policy esg_brig_filial_write on public.esg_brigada_filial for all to authenticated using (public.esg_e_corporativo()) with check (public.esg_e_corporativo());

-- Conferência:
-- select filial, count(*) filter (where ativo) ativos, count(*) total from public.esg_brigada_membro group by filial order by filial;
-- select filial, base + ceil(greatest(num_funcionarios-10,0)::numeric/divisor) as exigido from public.esg_brigada_filial order by filial;
