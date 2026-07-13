-- ============================================================================
-- ESG — Migração do formulário de Acidentes (revisão jul/2026)
-- Cole no SQL Editor do Supabase (projeto nkijyuartfyxrawkivmm) e execute.
-- Idempotente: pode rodar mais de uma vez sem quebrar.
-- Só mexe em tabelas esg_* (não toca no app de Demandas).
-- ============================================================================

-- 1) Coluna para "Tipo de Equipamento = Outros" (descrição livre)
alter table public.esg_acidentes add column if not exists tipo_equipamento_outro text;

-- 2) Domínio de tipo_equipamento ampliado
alter table public.esg_acidentes drop constraint if exists esg_acidentes_tipo_equipamento_check;
alter table public.esg_acidentes add constraint esg_acidentes_tipo_equipamento_check
  check (tipo_equipamento in ('N/A','Veículo','Empilhadeira','Paleteira','Transpaleteira','PEMT','Prensa','Equipamento de Limpeza','Outros'));

-- 3) Filial: remove o CHECK fixo — os locais passam a ser dinâmicos (validados por esg_filial_grupo + RLS)
alter table public.esg_acidentes drop constraint if exists esg_acidentes_filial_check;

-- 4) Grupos de local por filial-sede (um técnico atende todos os locais do seu grupo)
create table if not exists public.esg_filial_grupo (
  local text primary key,   -- código do local (filial-sede ou satélite)
  sede  text not null        -- filial-sede responsável
);
comment on table public.esg_filial_grupo is 'ESG — mapeia cada local à sua filial-sede, definindo o grupo de locais que um técnico atende.';
alter table public.esg_filial_grupo enable row level security;
drop policy if exists esg_filial_grupo_read on public.esg_filial_grupo;
create policy esg_filial_grupo_read on public.esg_filial_grupo for select to authenticated using (true);
insert into public.esg_filial_grupo (local, sede) values
  ('GUS','GUS'),('IMB','IMB'),('PAL','PAL'),('TAM','TAM'),('AJU','AJU'),('JPA','JPA'),
  ('PNG','PNG'),('CAU','CAU'),('BAR','BAR'),('CABO','CABO'),
  ('CD ALH','JPA'),('DEP JPA','JPA'),('MESTRE NILO','GUS'),('CD LAU','PAL'),('CD ST DRU','BAR')
on conflict (local) do update set sede = excluded.sede;

-- 5) esg_pode_ver considerando o GRUPO: a filial-sede do usuário cobre os locais satélites
create or replace function public.esg_pode_ver(_filial text)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.esg_usuarios u
    where lower(u.email) = lower(auth.jwt()->>'email')
      and (
        u.ver_todas
        or u.filial = _filial
        or u.filial = (select g.sede from public.esg_filial_grupo g where g.local = _filial)
      )
  );
$$;
revoke all on function public.esg_pode_ver(text) from public;
grant execute on function public.esg_pode_ver(text) to authenticated;

-- Conferência:
-- select * from public.esg_filial_grupo order by sede, local;
-- select public.esg_pode_ver('CD ALH');  -- true para o técnico de JPA logado
