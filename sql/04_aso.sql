-- ═══════════════════════════════════════════════════════════════════════════
-- APLICATIVO ESG — Módulo ASO (Atestado de Saúde Ocupacional)
-- Executar no SQL Editor do Supabase (projeto nkijyuartfyxrawkivmm)
--
-- Modelo: cada upload da planilha "Relação de Próximos Exames" é um SNAPSHOT.
-- Um upload nunca atualiza o anterior — ele cria uma nova versão. O dashboard
-- sempre lê a versão mais recente (maior enviado_em); as anteriores ficam no
-- banco como histórico, sem interface dedicada por enquanto.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Cabeçalho de cada importação ─────────────────────────────────────────
create table if not exists public.esg_aso_upload (
  id           bigint generated always as identity primary key,
  arquivo_nome text,
  periodo_de   date,
  periodo_ate  date,
  total_linhas int not null default 0,
  enviado_por  text,
  enviado_em   timestamptz not null default now()
);
comment on table public.esg_aso_upload is 'ESG/ASO — cabeçalho de cada importação da planilha "Relação de Próximos Exames"; cada linha é uma versão/snapshot.';

-- ── 2. Uma linha por exame obrigatório de cada colaborador, no snapshot ─────
create table if not exists public.esg_aso_exame (
  id            bigint generated always as identity primary key,
  upload_id     bigint not null references public.esg_aso_upload(id) on delete cascade,
  codfil        text,       -- código bruto da planilha (numérico, às vezes composto — ex.: 4016)
  filial        text,       -- sigla mapeada quando conhecida (GUS/IMB/PAL/TAM/AJU/JPA/PNG/CAU/BAR); senão = codfil
  ficha         text,
  colaborador   text,
  sexo          text,
  cargo         text,
  cod_exame     text,
  tipo_exame    text,
  ultimo_exame  date,
  proximo_exame date,
  cod_local     text,
  local         text,
  matricula     text,
  avaliador     text
);
comment on table public.esg_aso_exame is 'ESG/ASO — uma linha por exame obrigatório de cada colaborador, no snapshot de um upload.';

create index if not exists idx_esg_aso_exame_upload  on public.esg_aso_exame (upload_id);
create index if not exists idx_esg_aso_exame_filial  on public.esg_aso_exame (filial);
create index if not exists idx_esg_aso_exame_proximo on public.esg_aso_exame (proximo_exame);

-- ── 3. RLS ───────────────────────────────────────────────────────────────────
alter table public.esg_aso_upload enable row level security;
alter table public.esg_aso_exame  enable row level security;

-- Leitura: cabeçalho de upload não tem dado sensível (só data/nome do arquivo) — todo autenticado lê.
drop policy if exists esg_aso_upload_select on public.esg_aso_upload;
create policy esg_aso_upload_select on public.esg_aso_upload for select to authenticated using (true);

-- Leitura dos exames: mesma regra de escopo por filial/grupo já usada em esg_acidentes.
-- Filiais não mapeadas (código bruto sem sigla, ex.: '99') só aparecem para quem tem ver_todas=true,
-- porque esg_pode_ver só casa com a sigla exata do usuário ou com o grupo em esg_filial_grupo.
drop policy if exists esg_aso_exame_select on public.esg_aso_exame;
create policy esg_aso_exame_select on public.esg_aso_exame for select to authenticated
  using (public.esg_pode_ver(filial));

-- Função auxiliar: usuário logado é corporativo (ver_todas=true)?
create or replace function public.esg_e_corporativo()
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.esg_usuarios u
    where lower(u.email) = lower(auth.jwt()->>'email') and u.ver_todas
  );
$$;
revoke all on function public.esg_e_corporativo() from public;
grant execute on function public.esg_e_corporativo() to authenticated;

-- Upload (insert): o snapshot vale para todo mundo, então só quem já enxerga tudo pode substituí-lo.
drop policy if exists esg_aso_upload_insert on public.esg_aso_upload;
create policy esg_aso_upload_insert on public.esg_aso_upload for insert to authenticated
  with check (public.esg_e_corporativo());

drop policy if exists esg_aso_exame_insert on public.esg_aso_exame;
create policy esg_aso_exame_insert on public.esg_aso_exame for insert to authenticated
  with check (public.esg_e_corporativo());

-- Conferência:
-- select * from public.esg_aso_upload order by enviado_em desc;
-- select count(*) from public.esg_aso_exame where upload_id = (select max(id) from public.esg_aso_upload);
