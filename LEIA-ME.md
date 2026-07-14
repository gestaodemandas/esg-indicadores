# Aplicativo ESG — Gestão de Indicadores

Aplicativo web (HTML/CSS/JS puro, sem framework nem build) para registro e análise de indicadores de ESG / Saúde e Segurança do Trabalho do Grupo Ferreira Costa. Módulos em produção: **Acidentes** e **ASO**. Os demais (Visão Geral, CIPA, Brigada, Treinamentos) aparecem na capa como "Em breve".

- **Publicado em**: https://gestaodemandas.github.io/esg-indicadores/
- **Repositório**: https://github.com/gestaodemandas/esg-indicadores
- **Banco**: Supabase, projeto `nkijyuartfyxrawkivmm` (mesmo do painel executivo de Auditoria Corporativa — ver seção [Convivência com o painel de Auditoria](#convivência-com-o-painel-de-auditoria))

## Estrutura de arquivos

| Caminho | Descrição |
|---|---|
| `index.html` | Aplicativo inteiro (HTML+CSS+JS num arquivo só) |
| `cid10.json` | Base CID-10 usada no autocomplete quando `MODE='local'` (amostra ~30 códigos) |
| `sql/01_schema.sql` | Cria `esg_acidentes` + `esg_cid10` (schema base) |
| `sql/02_seed_cid10_amostra.sql` | Popula `esg_cid10` com a amostra |
| `sql/03_migracao_form.sql` | Migração da revisão de formulário (jul/2026): coluna `tipo_equipamento_outro`, domínio ampliado de equipamentos, tabela `esg_filial_grupo` + `esg_pode_ver()` por grupo de locais |
| `sql/04_aso.sql` | Cria `esg_aso_upload` + `esg_aso_exame` (módulo ASO) e RLS — **depende de `esg_pode_ver()`, já criado por `01`/`03`; rodar depois desses** |
| `dados/` | **Fora do git** (`.gitignore` — contém nomes/e-mails/matrículas, LGPD). Scripts de carga histórica, controle de acesso e backups |
| `.claude/launch.json` *(fora desta pasta, na raiz de Sessões Claude)* | Config do preview local (`esg-app`, porta 8734) |

### Conteúdo de `dados/` (não versionado)

| Arquivo | Descrição |
|---|---|
| `norm.py` | Normaliza a planilha `ACIDENTES.xlsx` (formato bagunçado) → gera os 3 arquivos abaixo |
| `acidentes_import.json` | Carga histórica normalizada, pronta pra importar no app (modo local) |
| `acidentes_insert.sql` / `carga_supabase.sql` | Mesma carga em SQL (o segundo já inclui schema+seed) |
| `RELATORIO.txt` | Relatório da normalização: de/para de função, contagens por domínio, correções aplicadas |
| `gen_rls.py` | Lê `Perfis de Acesso App.xlsx` → gera os 3 arquivos abaixo |
| `esg_rls_e_acesso.sql` | Cria `esg_usuarios`, `esg_tecnico_filial`, funções de RLS, troca as políticas de `esg_acidentes` para escopo por filial |
| `flag_troca_senha.sql` | Marca contas com senha provisória para troca obrigatória no 1º login |
| `contas_auth.txt` | Lista de contas a criar em Authentication → Users (e-mail, senha, filial) |

## Modo de operação

Definido no topo do `<script>` em `index.html`:

```js
const MODE = 'supabase'
const SB_URL = 'https://nkijyuartfyxrawkivmm.supabase.co'
const SB_KEY = 'sb_publishable_...'   // chave publishable (anon) — RLS protege os dados
```

- **`MODE='supabase'`** (atual): dados no banco, exige login, RLS por filial.
- **`MODE='local'`**: dados no `localStorage` do navegador, sem login, exportação/importação manual via JSON. Só serve pra testar isolado — não usar em produção com dados reais.

## Login e controle de acesso (RLS)

Login é feito **por matrícula**, não por e-mail — mas por baixo dos panos a conta no Supabase usa o **e-mail real** de cada pessoa (o cadastrado na planilha `Perfis de Acesso App.xlsx`). Fluxo:

1. Usuário digita a matrícula (ou um e-mail direto — funciona também).
2. Se o campo digitado já parece um e-mail (contém `@`), usa direto.
3. Senão, o app chama a função pública `esg_email_por_matricula(matricula)` no Supabase, que devolve o e-mail correspondente.
4. Autentica com esse e-mail + a senha digitada.

Um número pequeno de contas usa e-mail sintético (`<matrícula>@esg.ferreiracosta.com.br`) por não ter e-mail corporativo cadastrado na planilha de acesso.

### Escopo de acesso — duas categorias

| Perfil | Quem | Enxerga |
|---|---|---|
| **Por filial** | Técnico de Segurança + Supervisor de Auditoria de cada filial (1 de cada) | Só os registros da própria filial |
| **Corporativo** (`ver_todas=true`) | Analistas/Coordenação de ESG + perfis administrativos definidos na planilha de acesso | Todas as filiais |

CABO = MDC Distribuidora na planilha (mesma filial, nomes diferentes). A lista nominal de quem tem acesso a este app (e com qual perfil) está em `dados/contas_auth.txt` e na própria tabela `esg_usuarios` — não versionada por conter dados pessoais.

### Tabelas de acesso

- **`esg_usuarios`** (PK `matricula`): email (login), nome, filial, perfil, ver_todas. RLS: cada um só lê a própria linha (`auth.jwt()->>'email' = email`).
- **`esg_tecnico_filial`** (PK `filial`): técnico responsável por cada filial — referência pública (qualquer autenticado lê), usada para autopreencher o campo "Técnico de Segurança" no formulário.
- **Função `esg_pode_ver(filial)`** (`security definer`): usada nas políticas de `esg_acidentes` — verifica se o usuário logado tem `ver_todas=true` ou se a filial bate com a dele.
- **Função `esg_email_por_matricula(matricula)`** (`security definer`, `grant to anon`): só devolve o e-mail correspondente a uma matrícula — precisa ser chamável **antes** do login, por isso liberada pro papel `anon`.

### Comportamento no app

- Usuário de filial: campo **Filial travado** na própria filial ao criar registro novo (não consegue criar para outra).
- Corporativo: Filial livre; ao escolher, o campo Técnico de Segurança autopreenche via `esg_tecnico_filial`.
- Chip no topo mostra o escopo ("Filial GUS" / "Todas as filiais").
- **Troca de senha obrigatória**: contas marcadas com `user_metadata.needs_password_change=true` (via `flag_troca_senha.sql`) caem numa tela de troca antes de entrar no app — mesmo padrão do painel de Auditoria.

⚠️ **Nunca tocar no app de Gestão de Demandas** — é outro projeto Supabase (`xtpirxyjmqwcvjlcajsz`), com seu próprio RLS/hierarquia. Qualquer alteração de acesso deste projeto (`nkijyuartfyxrawkivmm`) fica restrita às tabelas `esg_*`.

## Convivência com o painel de Auditoria

O projeto Supabase `nkijyuartfyxrawkivmm` também hospeda o **painel executivo de Auditoria Corporativa** (`02. Auditoria Corporativa - Indicadores.html`), que já tinha, antes deste app, seu próprio conjunto de tabelas ESG pré-agregadas: `esg_acidentes_filial`, `esg_acidentes_mensal`, `esg_cipa`, `esg_brigada`, `esg_aso`, `esg_treinamento_filial`, `esg_treinamento_nr`, `esg_ma_dashboard`, `esg_afastamentos`.

**Essas tabelas são um sistema separado e não são alimentadas por este app.** Decisão registrada (10/07/2026): `esg_acidentes` (a tabela deste app) é a **fonte de verdade única** para dados de acidentes daqui pra frente; as tabelas agregadas do painel executivo ficam intocadas até decisão explícita futura (o próximo passo natural seria virar views calculadas sobre `esg_acidentes`, ainda não feito).

## Módulo Acidentes

### Dashboard
- Barra de filtros: Ano, Mês, Filial, Status, Busca.
- 2 cartões: **Acidentes Registrados** (com gráfico de barras por filial) e **Pendentes de Finalização** (com velocímetro de % de conclusão do formulário — não confundir com o campo Status).
- Gráfico de barras mês a mês.
- Todos os gráficos são HTML/CSS/SVG puro, sem biblioteca externa.
- Cada filtro se aplica a tudo, exceto o próprio eixo que o gráfico detalha (gráfico por filial ignora o filtro de Filial; gráfico mensal ignora o filtro de Mês) — assim nada fica inconsistente entre si.

### Tabela de registros
- Colunas ordenáveis por clique no cabeçalho (A-Z/Z-A ou numérico).
- Coluna **Conclusão**: barra de % (vermelho <50%, amarelo ≥50%, verde =100%) — mede quantos campos do formulário estão preenchidos, não o Status manual.
- Seta expande uma linha de detalhe listando os campos ainda pendentes.
- Exportar Excel (.xls) e Novo registro.

### Formulário
Organizado em abas na lateral (Comunicado, Identificação, Classificação, Atestado & CAT, Relato & Lesão, Análise & Plano), cada uma com seu % de conclusão. Barra de progresso geral no rodapé.

**Campos obrigatórios** (únicos que contam no % de conclusão — const `REQUIRED` no código): Filial, Data do Acidente, Nome, Matrícula, Cargo do Acidentado, Tipo de Colaborador, Tipo de Ocorrência, Tipo de Acidente, Descrição Sumária, Situação Geradora, Natureza da Lesão, Parte do Corpo Atingida, Atestado Médico, Emitida CAT, Causa, Ação Corretiva (16 campos).

**Regras automáticas**:
- Nome, Responsável, Liderança, Nome do Médico → maiúsculas ao digitar.
- Matrícula / quantidades / tempo na empresa-cargo (anos-meses) → só número ou `N/A`, filtrado **em tempo real** durante a digitação (não só na validação de envio).
- Ocorrência ≠ Acidente → Tipo de Acidente trava em `N/A`.
- Colaborador Próprio → Empresa trava em `FC` (Cargo do Acidentado permanece editável para todos os tipos, inclusive terceirizado/cliente).
- Atestado = Não → quantidades travam em `0`; Atestado = `N/A` → travam em `N/A`.
- CID = Sim → autocomplete (precisa confirmar o código na lista).
- Tipo de Equipamento = Outros → abre campo de descrição livre (obrigatório nesse caso).
- Data do Comunicado pré-preenchida com o dia atual; Responsável pelo Comunicado e Técnico de Segurança autopreenchidos com o usuário logado.
- **Filial**: sempre editável (não trava mais). Técnico de filial vê no dropdown apenas os locais do seu **grupo** (sede + satélites — ver seção RLS); corporativo vê todos os locais que já têm registro.
- **Status** não é mais um campo manual — é calculado ao salvar: `Finalizado` se completude = 100% dos obrigatórios, senão `Pendente`.
- Situação Geradora, Natureza da Lesão e Parte do Corpo Atingida são dropdowns com as listas oficiais eSocial (Tabela 15, lista de lesões e Tabela 13, respectivamente).
- Fechar com alterações não salvas → oferece Salvar rascunho / Descartar / Continuar editando.

### Domínios em aberto (não decididos, sinalizados no código)
- **Agente Causador** — dropdown vazio/desabilitado, aguardando lista oficial da SST (único domínio ainda pendente; Espécie foi removido do formulário e Situação Geradora/Natureza da Lesão/Parte do Corpo já têm lista oficial).
- Causa pode ser redundante com Situação Geradora + Agente Causador.
- Dias de Afastamento pode ser o mesmo dado que Qtd. Dias de Atestado.
- Escala de Gravidade (Leve/Moderada/Grave) sem confirmação oficial.
- "Cliente" em Tipo de Colaborador — aplicabilidade ao PGR em aberto.
- **Em standby**: Atestados/Afastamento/Internação como lista repetível (botão "+", soma automática de dias) — ainda não implementado, aguardando detalhamento do que cada ocorrência deve conter.

### Locais de grupo (filial-sede cobre satélites)
Um técnico de segurança atende, além da sua filial-sede, os locais satélites do grupo: JPA → CD ALH, DEP JPA · GUS → MESTRE NILO · PAL → CD LAU · BAR → CD ST DRU. Mapeamento em `esg_filial_grupo` (tabela nova, `sql/03_migracao_form.sql`); `esg_pode_ver()` foi reescrito para considerar o grupo (RLS), não só a filial exata.

## Módulo ASO

Diferente do Acidentes, o ASO **não é um formulário**: é um **snapshot** da planilha corporativa "Relação de Próximos Exames" (controle de exames ocupacionais por colaborador). O usuário corporativo importa a planilha `.xlsx`; o parsing (ETL) roda **no próprio navegador** via SheetJS (`xlsx@0.18.5`, CDN) — não existe backend/função server-side. Cada importação grava um **novo snapshot** no banco; a versão anterior não é sobrescrita, fica de histórico. O dashboard sempre lê a versão mais recente.

### Régua da análise: PESSOAS, não exames
A régua é **quantidade de pessoas** com pendência, não de linhas de exame (um colaborador aparece várias vezes, uma por tipo de exame — 566 linhas = 341 pessoas na base de teste). A chave de pessoa é a **Ficha** (1 ficha = 1 nome, sem colisão). A **Matrícula NÃO serve** como identificador: ela se repete entre as empresas do grupo (FC, ROYAL, AME, MDC…), então o mesmo número aponta para pessoas diferentes (74 combinações filial+matrícula com nomes distintos na base de teste). Helpers `asoPersonKey`/`contarPessoas`/`contarPessoasStatus`. KPIs = pessoas com pendência / com exame vencido / vencendo em 30 dias.

### Gestor = coluna "Avaliador"
Confirmado pelo usuário (2026-07-14): o **gestor** de cada colaborador é a coluna **Avaliador** da planilha (por isso técnicos de segurança aparecem ali). `asoGestor(r)` usa `r.gestor` se um de/para explícito existir no futuro, senão cai no avaliador. Há gráfico "Pessoas com pendência por Gestor" e filtro "Gestor" na barra; a coluna da tabela e do Excel foi rotulada "Gestor".

### Modelo de dados
- **`esg_aso_upload`**: cabeçalho de cada importação (nome do arquivo, período informado na planilha, total de linhas, quem importou, quando).
- **`esg_aso_exame`**: uma linha por exame obrigatório de cada colaborador naquele snapshot (Filial, Ficha, Colaborador, Sexo, Cargo, Tipo de Exame, Últ. Exame, Próx. Exame, Local, Matrícula, Avaliador/gestor). Coluna `gestor` nullable reservada para um de/para futuro.
- **Status** (Vencido / Vencendo em 30 dias / Em dia / Sem previsão) não é armazenado — é **calculado na leitura** a partir do Próx. Exame vs. hoje.

### Mapeamento de Filial (CODFIL)
A planilha traz a filial como código numérico (CODFIL), não como sigla. Tabela completa confirmada pelo usuário (2026-07-14, const `CODFIL_SIGLA` em `index.html`):

| CODFIL | Sigla/Empresa | CODFIL | Sigla/Empresa |
|---|---|---|---|
| 1 | GUS | 99 | CORP |
| 2 | IMB | 100–112 | ALH |
| 3 | PAL | 202 | CD JIQ |
| 4 | TAM | 302 | CD LAU |
| 5 | AJU | 4016 | RETAILX |
| 6 | JPA | 8090 | MDC |
| 7 | PNG | 9190, 9197 | AME |
| 8 | CAU | 9207 | ROYAL |
| 9 | BAR | | |
| 11 | FRT | | |
| 80 | MDC | | |
| 91 | CA2 | | |
| 92 | CAB | | |
| 93 | ALH | | |
| 94 | LAU | | |

Note que algumas siglas (ROYAL, AME, RETAILX, MDC) são **empresas do grupo**, não filiais físicas — mesmo padrão já mencionado no campo Empresa do módulo Acidentes. `93` e `100–112` mapeiam para o mesmo rótulo "ALH" (mas com grafia diferente de "CD ALH", usado no `esg_filial_grupo` do módulo Acidentes — ainda não reconciliado; um técnico de JPA não herda automaticamente visibilidade sobre linhas de ASO marcadas "ALH" por esse motivo).

Códigos fora desta tabela (confirmados nos dados reais: `601`, `701`) **ficam com o valor bruto**, sem sigla. Isso tem uma consequência direta no RLS: só usuários com `ver_todas=true` enxergam linhas com filial não mapeada, porque `esg_pode_ver()` só casa contra siglas conhecidas.

### Permissões
- **Leitura**: mesmo escopo por filial/grupo do módulo Acidentes (reusa `esg_pode_ver()` e `esg_filial_grupo`).
- **Importar nova planilha**: restrito a `ver_todas=true` (perfil corporativo) — o snapshot vale para todo mundo, então só quem já vê tudo pode substituí-lo. Usuários de filial não veem o botão de upload.

### Dashboard
- Banner com a data/hora da última importação, quem importou e o nome do arquivo.
- Filtros: Filial, Gestor, Tipo de Exame, Status, Busca (nome/matrícula).
- 3 cartões (contam PESSOAS): Pessoas com pendência, Com exame vencido, Vencendo em 30 dias.
- Gráfico "Pessoas por Unidade — Realizados vs. Pendentes" (filtro próprio unidade/status, barra horizontal empilhada, ordenado por pendência). Realizados fica em 0 até haver fonte de exames realizados (`asoRealizadosPorUnidade`).
- Gráfico "Pessoas com pendência por Gestor" (top 15) e "Exames pendentes por Tipo" (top 10, contagem de exames).
- Todos os gráficos são barra horizontal (`.hbarchart`), mais legíveis que coluna.
- Tabela ordenável + exportação Excel.

### Pendências conhecidas
- Códigos `601` e `701` (vistos nos dados reais) não têm sigla confirmada — ficam com o valor bruto.
- Reconciliar a grafia "ALH" (CODFIL 93, 100–112) com "CD ALH" do `esg_filial_grupo` do módulo Acidentes, se a intenção for que o mesmo técnico enxergue os dois.
- Sem interface para consultar snapshots antigos (ficam no banco, mas só a versão vigente aparece no app).

## Carga histórica

101 registros da planilha `ACIDENTES.xlsx` (23/04/2025–23/06/2026), normalizados e carregados no banco. Detalhes completos e decisões de padronização em `dados/RELATORIO.txt`. Todos entraram com **status='Finalizado'** por padrão (a planilha não tinha essa coluna) — pendente de validação real pelos técnicos via o % de conclusão do formulário.

## Regra de ouro para novo trabalho neste projeto

Todo dado deste app (acidentes, usuários, referências) vive em **tabelas novas prefixadas `esg_`**, nunca reaproveitando ou alterando estrutura pré-existente no projeto Supabase. O destino de tabelas antigas (as do painel de Auditoria) só é decidido pelo usuário, explicitamente, quando ele pedir.
