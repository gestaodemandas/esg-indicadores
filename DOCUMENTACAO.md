# Aplicativo ESG — Documentação Completa

> Documento de referência do aplicativo **ESG — Gestão de Indicadores** do Grupo Ferreira Costa.
> Atualizado em **15/07/2026**. Para o guia rápido de instalação/arquivos veja o `LEIA-ME.md`; este arquivo é a visão completa (arquitetura, módulos, modelo de dados e plano de integração com o painel executivo).

---

## 1. Visão geral

Aplicativo web para **registro e acompanhamento de indicadores de Saúde & Segurança do Trabalho (SST)** das filiais do Grupo Ferreira Costa. Substitui um conjunto de planilhas espalhadas (uma por filial, com fórmulas que quebravam) por uma base única no Supabase, com dashboards por módulo e controle de acesso por filial.

- **Publicado em:** https://gestaodemandas.github.io/esg-indicadores/ (GitHub Pages)
- **Repositório:** https://github.com/gestaodemandas/esg-indicadores (conta `gestaodemandas`)
- **Banco:** Supabase, projeto `nkijyuartfyxrawkivmm`
- **Público-alvo:** técnicos de segurança do trabalho (alimentam o dia a dia) e ESG corporativo (visão consolidada).

### Módulos

| # | Módulo | Status | Como é alimentado |
|---|---|---|---|
| 01 | Visão Geral | Em breve | — |
| 02 | **Acidentes/Incidentes** | Produção | Formulário no app |
| 03 | **CIPA** | Produção | Edição direta no app |
| 04 | **Brigada** | Produção | Edição direta no app |
| 05 | **ASO** | Produção | Importação de planilha (snapshot) |
| 06 | **Treinamentos** | Produção | App + importação inicial de planilha |

---

## 2. Arquitetura

- **Single-file:** todo o app é um único `index.html` (HTML + CSS + JS embutidos). **Sem framework, sem build, sem backend próprio.**
- **Bibliotecas via CDN:** `@supabase/supabase-js@2` (dados/auth) e `xlsx@0.18.5` / SheetJS (leitura de planilhas no navegador). Os gráficos são **HTML/CSS/SVG puro**, sem biblioteca de charting.
- **ETL no cliente:** toda importação de planilha é parseada **no navegador** e gravada no Supabase via API. Não há função server-side.
- **Dois modos de operação** (constante `MODE` no topo do `<script>`):
  - `MODE='supabase'` (produção): dados no banco, login obrigatório, RLS por filial.
  - `MODE='local'`: dados no `localStorage`, sem login, só para teste isolado.

### Deploy e versionamento

- Publicado por GitHub Pages a partir do branch `main`.
- ⚠️ **O `.git` fica FORA do OneDrive** (`~/git-repos/aplicativo-esg.git`, via `--separate-git-dir`). O OneDrive "desidrata" arquivos internos do `.git` em placeholders de nuvem e corrompe o repositório. **Nunca recriar o `.git` dentro do OneDrive.**
- A pasta `dados/` está no `.gitignore`: contém nomes, e-mails, matrículas e observações com dados pessoais (LGPD) — **nunca versionar**.

---

## 3. Acesso e segurança (RLS)

### Login por matrícula

O login é feito **por matrícula**, mas a conta no Supabase Auth usa o **e-mail real** de cada pessoa. Fluxo:

1. Usuário digita a matrícula (ou um e-mail direto, se tiver `@`).
2. O app chama a função pública `esg_email_por_matricula(matricula)` (liberada ao papel `anon`, pois precisa rodar **antes** do login) para descobrir o e-mail.
3. Autentica com esse e-mail + senha.

Contas sem e-mail corporativo usam e-mail sintético `<matrícula>@esg.ferreiracosta.com.br`. **Troca de senha obrigatória** no 1º login via `user_metadata.needs_password_change`.

### Escopo de acesso

| Perfil | Enxerga | `ver_todas` |
|---|---|---|
| **Por filial** (técnico de segurança / supervisor) | Só a própria filial **+ os locais-satélite do seu grupo** | `false` |
| **Corporativo** (analistas/coordenação ESG, admin) | Todas as filiais | `true` |

O escopo é aplicado por **Row Level Security** em cada tabela de dado, sempre pela função `esg_pode_ver(filial)`. Importações e edições de catálogo/base de referência ficam restritas a `esg_e_corporativo()`.

### Funções do banco (SECURITY DEFINER)

| Função | Papel |
|---|---|
| `esg_pode_ver(filial text)` | Coração do RLS: retorna `true` se o usuário logado tem `ver_todas`, se a filial é a dele, **ou se a filial pertence ao grupo dele** (via `esg_filial_grupo`). |
| `esg_e_corporativo()` | `true` se o usuário logado tem `ver_todas=true`. Usada em políticas de escrita de catálogos/snapshots. |
| `esg_email_por_matricula(matricula text)` | Resolve matrícula → e-mail antes do login (`grant to anon`). |
| `esg_set_updated_at()` | Trigger que mantém `updated_at`. |

---

## 4. Filiais, grupos e a "torre de babel" de taxonomias

Este é o ponto mais delicado do projeto: **cada planilha de origem nomeia as filiais de um jeito diferente** (código numérico, sigla, nome por extenso, com/sem "CD"). O app normaliza tudo para um conjunto de **siglas canônicas**.

### Siglas canônicas e grupos (`esg_filial_grupo`)

Uma filial-sede "cobre" locais-satélite — o técnico da sede enxerga todos eles:

| Sede | Locais-satélite do grupo |
|---|---|
| JPA | CD ALH, DEP JPA |
| GUS | MESTRE NILO |
| PAL | CD LAU |
| BAR | CD ST DRU |

Demais filiais (IMB, TAM, AJU, PNG, CAU, CABO) cobrem só a si mesmas. `CORP`, e empresas do grupo (`ROYAL`, `AME`, `MDC`, `RETAILX`, etc.) e locais soltos (`CD PNG`, `CD CAJI`) não têm grupo — só o corporativo os enxerga.

### De/para de CODFIL → sigla (só no ASO — pendências)

A "Relação de Próximos Exames" (ASO) traz a filial como **código numérico**. Mapa em `CODFIL_SIGLA` (`index.html`):

| CODFIL | Sigla | CODFIL | Sigla |
|---|---|---|---|
| 1 | GUS | 93, 100–112 | **CD ALH** |
| 2 | IMB | 94 | LAU |
| 3 | PAL | 99 | CORP |
| 4 | TAM | 202 | CD JIQ |
| 5 | AJU | 302 | CD LAU |
| 6 | JPA | 4016 | RETAILX |
| 7 | PNG | 8090 | MDC |
| 8 | CAU | 9190, 9197 | AME |
| 9 | BAR | 9207 | ROYAL |
| 11 | FRT | 80 | MDC |
| 91 | CA2 | 92 | CAB |

> ⚠️ A **numeração de filial das planilhas de Treinamentos NÃO é a mesma do ASO** (ex.: `92` = CAB no ASO, mas = CD Santos Drumond nas de Treinamento). Por isso o importador de Treinamentos usa o **nome após o traço** ("92 - CD SANTOS DRUMOND"), nunca o número. Códigos sem sigla confirmada (`601`, `701`) ficam com o valor bruto.

### Aliases por importador (nome da planilha → sigla)

- **Treinamentos** (`TREIN_FILIAL_ALIAS`): DP JPA→DEP JPA, CD CABO→CABO, CD LAURO→CD LAU, CD SANTOS DRUMOND→CD ST DRU.
- **ASO realizados** (`REAL_FILIAL_ALIAS`): CD M.NILO→MESTRE NILO, CD S.DUMONT→CD ST DRU. CD PNG e CD CAJI ficam como estão.

---

## 5. Módulos

### 5.1 Acidentes/Incidentes (`esg_acidentes`)

**Registro de ocorrências via formulário** (o único módulo que é um formulário de digitação por registro).

- **Terminologia:** o rótulo geral é "Ocorrências" (que engloba Acidente, Incidente e Emergência).
- **Cartões segmentados:** Ocorrências Registradas (total) · Acidentes · Incidentes. Emergências entram só no total.
- **Formulário em abas** (Comunicado, Identificação, Classificação, Atestado & CAT, Relato & Lesão, Análise & Plano), cada uma com % de conclusão.
- **16 campos obrigatórios** (const `REQUIRED`) são os únicos que contam no % de conclusão. **Status** não é mais campo manual — é derivado: `Finalizado` se 100% dos obrigatórios, senão `Pendente`.
- **Listas eSocial** em dropdown: Situação Geradora (Tabela 15), Natureza da Lesão, Parte do Corpo (Tabela 13). Domínio ainda em aberto: **Agente Causador**.
- **Filial editável**, restrita ao grupo do técnico; corporativo vê todas.
- Dashboards: por filial, mensal, e velocímetro de conclusão do formulário. CID-10 com autocomplete.
- **Carga histórica:** 101 registros de `ACIDENTES.xlsx` (abr/2025–jun/2026).

### 5.2 ASO — exames ocupacionais

Não é formulário: são **dois relatórios importados** (snapshots).

- **Régua da análise = PESSOAS, não linhas de exame.** Um colaborador aparece várias vezes (uma por tipo de exame). A chave de pessoa é a **Ficha** (1 ficha = 1 nome). **A Matrícula NÃO serve** como identificador — ela se repete entre as empresas do grupo. *(Correção importante: a coluna "Matric." da Relação de Próximos Exames é a matrícula do **gestor**, não do colaborador — por isso a coluna exibida é a Ficha.)*
- **Gestor = coluna "Avaliador"** da planilha (confirmado; por isso técnicos aparecem ali).
- **Pendências** (`esg_aso_upload` + `esg_aso_exame`): a "Relação de Próximos Exames". Situação (Vencido / Vencendo em 30d / Em dia / Sem previsão) é **derivada** do Próx. Exame vs. hoje, nunca armazenada.
- **Realizados** (`esg_aso_realizado`): o "Relatório de Exames Periódicos Realizados" (quem já fez o exame médico).
- **Gráfico "Exame Médico por Unidade — Realizados vs. Pendentes"**: escopo **só exame médico** dos dois lados (verde = realizados, vermelho sólido = pendentes; sem degradê).
- Importação restrita ao corporativo (o snapshot vale para todos).

### 5.3 Treinamentos (`esg_trein_catalogo` + `esg_trein_registro`)

Substitui as planilhas "CONTROLE DE TREINAMENTOS" (uma por filial, uma aba por NR).

- **Preenchimento direto no app.** Só 3 dados são "de verdade": colaborador, qual treinamento e a **data em que realizou**. Vencimento, dias a vencer e situação são **derivados na leitura** (Em dia >30d / A renovar ≤30d / Vencido / Não realizado).
- **Catálogo único** de treinamentos (14 NRs), com periodicidade e funções obrigadas — editável só pelo corporativo. Mudar a periodicidade recalcula todos os registros.
- **Tela desenhada para o técnico** (foco no dia a dia): cartão de conformidade da equipe + **fila de ação** priorizada (Vencidos / Vencem em 30d / Nunca realizados) com botão **Registrar** que abre o modal já no campo de data. Botão "Somente pendentes".
- **Importação inicial** do formato de planilha das 13 filiais (robusta a variações de aba/cabeçalho/filial). Carga validada: 1.810 registros; totais batem com as capas das planilhas.

### 5.4 CIPA (`esg_cipa`)

Conformidade da CIPA por local, **editada direto no app** (sem planilha recorrente).

- 1 linha por local. **3 painéis** (3 visões da mesma tabela): Status (posse, renovação **derivada** vs. hoje, conforme?); Dimensionamento NR-5 (previsão × ativos × treinados, cobertura e déficit); Documentos necessários × existentes.
- KPIs: ativas, conformes, não conformes, desobrigadas (N/A).
- Carga inicial da planilha "CIPA 3" via `dados/cipa_seed.sql` (fora do git — observações com nomes).

---

## 6. Modelo de dados (tabelas `esg_*` deste app)

| Tabela | Papel | Chave | RLS |
|---|---|---|---|
| `esg_acidentes` | Ocorrências (formulário) | `id` | leitura/escrita por `esg_pode_ver(filial)` |
| `esg_cid10` | Referência CID-10 | `codigo` | leitura autenticada |
| `esg_usuarios` | Acesso (login→filial/perfil) | `matricula` | cada um lê só a própria linha |
| `esg_tecnico_filial` | Técnico responsável por filial | `filial` | leitura autenticada |
| `esg_filial_grupo` | local → filial-sede (grupos) | `local` | leitura autenticada |
| `esg_aso_upload` | Cabeçalho de cada snapshot de pendências | `id` | leitura autenticada; insert corporativo |
| `esg_aso_exame` | Linhas do snapshot de pendências | `id` | `esg_pode_ver(filial)`; insert corporativo |
| `esg_aso_realizado` | Exames periódicos realizados | `id` | `esg_pode_ver(filial)`; insert corporativo |
| `esg_trein_catalogo` | Catálogo de treinamentos (NRs) | `id` (`codigo` único) | leitura autenticada; escrita corporativo |
| `esg_trein_registro` | Colaborador × treinamento | `id` | `esg_pode_ver(filial)` |
| `esg_cipa_conformidade` | Conformidade CIPA por local | `local` | `esg_pode_ver(local)`; insert/delete corporativo |

> ⚠️ A tabela do módulo CIPA chama-se **`esg_cipa_conformidade`**, não `esg_cipa`. O nome `esg_cipa` já pertence a uma tabela **agregada do painel executivo** (ver seção 8).

**Princípio transversal:** o app guarda **fatos** (datas, contagens informadas) e **deriva na leitura** tudo que é status/vencimento — nunca armazena o resultado calculado. Isso evita o problema das planilhas antigas (fórmulas congeladas/quebradas).

---

## 7. Instalação (ordem dos SQL)

Rodar no SQL Editor do Supabase, **nesta ordem** (cada um depende dos anteriores):

| Ordem | Arquivo | Cria |
|---|---|---|
| 1 | `sql/01_schema.sql` | `esg_acidentes`, `esg_cid10` |
| 2 | `sql/02_seed_cid10_amostra.sql` | popula CID-10 |
| — | `dados/esg_rls_e_acesso.sql` | `esg_usuarios`, `esg_tecnico_filial`, `esg_pode_ver` (v1), políticas |
| — | `dados/flag_troca_senha.sql` | marca troca de senha obrigatória |
| 3 | `sql/03_migracao_form.sql` | `esg_filial_grupo`, reescreve `esg_pode_ver` (grupos), amplia `esg_acidentes` |
| 4 | `sql/04_aso.sql` | `esg_aso_upload`, `esg_aso_exame`, `esg_e_corporativo` |
| 5 | `sql/05_treinamentos.sql` | `esg_trein_catalogo` (seed), `esg_trein_registro` |
| 6 | `sql/06_cipa.sql` + `dados/cipa_seed.sql` | `esg_cipa_conformidade` + carga |
| 7 | `sql/07_aso_realizado.sql` | `esg_aso_realizado` |
| 8 | `sql/09_brigada.sql` + `dados/brigada_seed.sql` | `esg_brigada_filial` + `esg_brigada_membro` + carga (Brigada — em construção) |

> `sql/08_views_painel.sql` (views do painel executivo) é aplicado à parte, após validação — ver §8.

**Diagnóstico:** `sql/diagnostico.sql` (Parte 1) mostra quais tabelas/funções existem — qualquer `presente=false` indica o SQL que falta rodar. A Parte 2 confere contagens; a Parte 3 alinha `esg_aso_exame.filial` "ALH"→"CD ALH" nos registros antigos.

---

## 8. Integração com o Painel Executivo de Auditoria (proposta)

### Situação atual

O **mesmo** projeto Supabase (`nkijyuartfyxrawkivmm`) hospeda o painel executivo de Auditoria Corporativa (`02. Auditoria Corporativa - Indicadores.html`), que lê um conjunto de tabelas **pré-agregadas**, alimentadas manualmente/à parte:

`esg_acidentes_filial`, `esg_acidentes_mensal`, `esg_cipa`, `esg_brigada`, `esg_aso`, `esg_treinamento_filial`, `esg_treinamento_nr`, `esg_ma_dashboard`, `esg_afastamentos`.

Hoje esse painel e este app são **dois mundos desconectados**. O objetivo desta etapa é fazer o painel executivo **ler dos dados do app**, de forma que ele se atualize automaticamente conforme os técnicos alimentam.

### Estratégia proposta: **views** sobre as tabelas do app

As tabelas transacionais do app viram a **fonte de verdade**; para cada tabela que o painel espera, criamos uma **VIEW** com o mesmo nome e as mesmas colunas que o painel já consome — assim **o HTML do painel não precisa mudar**, ele passa a ler a view em vez da tabela estática.

### Mapeamento completo (análise do `loadAll()` do painel, 15/07/2026)

O painel lê 9 objetos ESG (todos com `.eq('ano',2026)`, exceto afastamentos e MA). Colunas exatas que ele consome × fonte no app:

| Painel lê | Colunas consumidas | Fonte no app | Viável |
|---|---|---|---|
| `esg_cipa` | ano, filial, previstos, treinados, status, pendencia_doc | `esg_cipa_conformidade` | ✅ |
| `esg_acidentes_filial` | ano, filial, trajeto, tipico | `esg_acidentes` (tipo_ocorrencia=Acidente) | ✅ |
| `esg_acidentes_mensal` | ano, mes, mes_label, acidentes, emergencias, incidentes, trajeto, tipico | `esg_acidentes` | ✅ |
| `esg_aso` | ano, periodo, filial, realizados, pendentes | `esg_aso_realizado` + `esg_aso_exame` (exame médico) | ✅ |
| `esg_treinamento_filial` | ano, filial, planejado, realizado | `esg_trein_registro` | ✅ (planejado=exigidos, realizado=já feitos) |
| `esg_treinamento_nr` | ano, nr, planejado, realizado, aderencia_pct, status | `esg_trein_registro` + catálogo | ✅ (`status` derivado da aderência) |
| `esg_brigada` | ano, filial, exigencia, ativos | `esg_brigada_membro` + `esg_brigada_filial` | ✅ (view `esg_brigada_appview`) |
| `esg_afastamentos` | ano, filial, cargo, motivo, data_inicio, data_termino, cid, dias | — **sem módulo de afastamentos** (auxílio-doença) | ❌ |
| `esg_ma_dashboard` | payload jsonb (chave='dashboard') | — Meio Ambiente, blob editado à parte | ❌ |

**7 views já estão escritas** em `sql/08_views_painel.sql` (cipa, acidentes_filial, acidentes_mensal, aso, treinamento_filial, treinamento_nr, brigada) como views `*_appview` (aditivas, não tocam em nada) — para você rodar e **comparar** com as tabelas atuais antes de promover. Só Afastamentos e Meio Ambiente ficam de fora (sem fonte no app — "faremos depois").

### 3 pontos que decidem o resto

1. **⚠️ RLS — o ponto mais crítico (precisa testar).** As tabelas `esg_*` do app têm RLS que só liberam quem está em `esg_usuarios`. **Os usuários que abrem o painel de Auditoria provavelmente NÃO estão em `esg_usuarios`** → ao ler as views, o RLS das tabelas-base pode devolver **vazio**. Como as views são **agregados** (contagens por filial, sem dado pessoal), a saída pode ser liberada com segurança — mas o mecanismo (view `security_invoker` vs. política de leitura ampla para os agregados) precisa ser definido e **testado no banco**. Isso não dá para validar sem rodar lá.

2. **Treinamento — semântica diferente.** O painel espera `planejado × realizado`; o app tem *status de reciclagem* (Em dia/Vencido/…). Interpretação proposta: **planejado = nº de (colaborador×treinamento) exigidos**; **realizado = os que já têm data**; **aderência = realizado/planejado**. É uma métrica de cobertura defensável, mas **confirme** se é o que o painel deve mostrar antes de eu escrever essas 2 views.

3. **Brigada, Afastamentos e Meio Ambiente — sem fonte no app.** Opções: (a) o painel mantém essas 3 tabelas como estão (alimentação manual) até virarem módulos; (b) criamos os módulos primeiro. Recomendo (a) por ora.

### Rollout seguro (reversível, uma tabela por vez)

1. Rodar `sql/08_views_painel.sql` (só cria as views `*_appview`, nada é alterado).
2. `select` em cada view e comparar com a tabela atual do painel — validar números.
3. Resolver o RLS (ponto 1) e confirmar que um usuário do painel lê as views.
4. **Promover** uma por vez: `alter table esg_X rename to esg_X_bkp` + criar a view com o nome `esg_X`. Conferir o painel. Reverter é `drop view` + `rename ... to`.
5. Depois de estável, decidir sobre treinamento (ponto 2) e os módulos sem fonte (ponto 3).

---

## 9. Decisões de design e convenções

- **Cor:** vermelho (`--acid`) = negativo/pendência; **verde reservado só para resultado positivo** (100% concluído, realizado, conforme). Nada de degradês nos gráficos — cor sólida por significado.
- **Régua por pessoa** onde faz sentido (ASO): contar colaboradores distintos, não linhas.
- **Derivar, não armazenar** status/vencimento — sempre calculado na leitura vs. a data de hoje.
- **Tela pela pergunta do usuário-alvo**, não pela estrutura dos dados (ex.: Treinamentos abre com "o que preciso fazer hoje?").
- **Importações paginam a leitura** (`sbFetchAll`) — o PostgREST devolve no máx. 1.000 linhas por resposta; sem paginar, dados acima disso ficam invisíveis.
- **Todo dado novo em tabelas `esg_*` novas** — nunca reaproveitar/alterar estrutura pré-existente sem decisão explícita.

---

## 10. Backlog e pendências conhecidas

- **Atestados/Afastamento/Internação repetíveis** (formulário de Acidentes): lista com botão "+" e soma automática de dias, exceto CAT. **Em standby** por decisão do usuário.
- **Agente Causador** (Acidentes): dropdown aguardando lista oficial da SST.
- **ASO sem histórico navegável:** só a versão vigente aparece; snapshots antigos ficam no banco sem tela.
- **Locais soltos** (`CD PNG`, `CD CAJI`, `601`, `701`): sem grupo — só o corporativo os enxerga.
- **Integração com o painel executivo:** ver seção 8 (aguardando o HTML do painel + confirmação da colisão de nome).
- **Módulos Visão Geral e Brigada:** ainda "Em breve".
