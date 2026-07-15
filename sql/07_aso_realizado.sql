-- ═══════════════════════════════════════════════════════════════════════════
-- APLICATIVO ESG — ASO: exames periódicos REALIZADOS
-- Executar no SQL Editor do Supabase, DEPOIS de 01/03/04.
--
-- Complemento do módulo ASO: enquanto esg_aso_exame traz as PENDÊNCIAS (Relação
-- de Próximos Exames), esta tabela traz quem JÁ REALIZOU o exame médico periódico
-- (Relatório de Exames Periódicos Realizados). Alimenta o lado "Realizados" do
-- gráfico "Pessoas por Unidade". Snapshot: cada importação SUBSTITUI o conteúdo.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.esg_aso_realizado (
  id            bigint generated always as identity primary key,
  ficha         text,        -- identificador do COLABORADOR (mesma chave do ASO)
  colaborador   text,
  exame         text,        -- hoje só "EXAME MEDICO"
  filial        text,
  origem        text,        -- "Periodico"
  periodo       text,        -- rótulo do relatório, ex.: "Janeiro a Junho/26"
  importado_em  timestamptz not null default now(),
  importado_por text
);
comment on table public.esg_aso_realizado is 'ESG/ASO — exames periódicos realizados (snapshot; substituído a cada importação). Lado "Realizados" do gráfico por unidade.';
create index if not exists idx_esg_aso_real_filial on public.esg_aso_realizado (filial);

-- ── RLS: leitura por filial/grupo; importação só corporativo ──
alter table public.esg_aso_realizado enable row level security;

drop policy if exists esg_aso_real_select on public.esg_aso_realizado;
create policy esg_aso_real_select on public.esg_aso_realizado for select to authenticated
  using (public.esg_pode_ver(filial));
drop policy if exists esg_aso_real_insert on public.esg_aso_realizado;
create policy esg_aso_real_insert on public.esg_aso_realizado for insert to authenticated
  with check (public.esg_e_corporativo());
drop policy if exists esg_aso_real_delete on public.esg_aso_realizado;
create policy esg_aso_real_delete on public.esg_aso_realizado for delete to authenticated
  using (public.esg_e_corporativo());

-- Conferência:
-- select filial, count(*) from public.esg_aso_realizado group by filial order by 2 desc;
