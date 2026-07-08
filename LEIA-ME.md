# Aplicativo ESG — Gestão de Indicadores

Aplicativo HTML para registro e análise de indicadores de ESG / SST. **Totalmente independente** dos demais painéis e projetos Supabase existentes.

## Estrutura

| Arquivo | Descrição |
|---|---|
| `index.html` | Aplicativo completo (capa + módulo Acidentes) |
| `cid10.json` | Base CID-10 usada pelo autocomplete no modo local (amostra de ~30 códigos SST) |
| `dados/` | Pasta para guardar os backups JSON exportados — **ignorada pelo git** (LGPD) |
| `sql/01_schema.sql` | Criação futura das tabelas `esg_acidentes` e `esg_cid10` no Supabase |
| `sql/02_seed_cid10_amostra.sql` | Amostra CID-10 para o Supabase (etapa futura) |

## Como funciona hoje — modo LOCAL

O app abre **sem login** e salva os registros no navegador (`localStorage`). O chip amarelo "Dados locais" no topo indica o modo ativo.

- **Exportar** (botão ⬇ na tabela): baixa um JSON com todos os registros — salve na pasta `dados/`. Faça isso com frequência: é o seu backup.
- **Importar** (botão ⬆): restaura um backup JSON (substitui a base atual).
- Atenção: os dados ficam **por navegador/máquina**. Outro computador (ou o site publicado no GitHub) começa vazio — use exportar/importar para levar os dados junto.

## Etapa 2 — Deploy no GitHub Pages

O repositório git local já está pronto. Para publicar:

1. Crie um repositório novo em github.com (ex.: `esg-indicadores`).
2. Na pasta do app, rode:
   ```
   git remote add origin https://github.com/SEU-USUARIO/esg-indicadores.git
   git push -u origin main
   ```
3. No GitHub: Settings → Pages → Branch `main` / root → Save.
4. O app estará em `https://SEU-USUARIO.github.io/esg-indicadores/`.

O `.gitignore` impede que a pasta `dados/` (backups com nomes de colaboradores) suba para o GitHub.

## Etapa 3 — Migração futura para Supabase

Quando quiser centralizar os dados num banco:

1. Crie um **projeto Supabase novo** (não reutilize os existentes).
2. No SQL Editor, execute `sql/01_schema.sql` e `sql/02_seed_cid10_amostra.sql`.
3. Cadastre os usuários em Authentication → Users.
4. No `index.html`, altere no início do `<script>`:
   ```js
   const MODE = 'supabase'
   const SB_URL = 'https://seu-projeto.supabase.co'
   const SB_KEY = 'sua-publishable-key'
   ```
5. Faça login no app e use **Importar** com o último backup JSON — os registros locais são inseridos no banco.
6. Para o CID-10 completo (~14 mil códigos do DATASUS), importe o CSV pelo Table Editor na tabela `esg_cid10`.

## Módulos

- **Acidentes** — ativo: cartões (Total, Trajeto, Típicos, Pendentes), tabela com filtros (ano, filial, status, busca) e formulário "+ Novo".
- Visão Geral, CIPA, Brigada, ASO e Treinamentos — "Em breve".

## Regras automáticas do formulário

- **Nome** → convertido para MAIÚSCULO enquanto digita.
- **Matrícula / Qtd. Atestados / Qtd. Dias** → aceitam apenas número ou `N/A`.
- **Tipo de Ocorrência ≠ Acidente** → Tipo de Acidente trava em `N/A`.
- **Colaborador Próprio** → Empresa trava em `FC`; **não-Próprio** → Função trava em `N/A`.
- **Atestado = Não** → quantidades travam em `0`; **Atestado = N/A** → quantidades travam em `N/A`.
- **CID informado = Sim** → abre o campo CID com autocomplete (cid10.json no modo local; tabela `esg_cid10` no modo Supabase); é preciso selecionar o código na lista para confirmar.
- **Status** (`Pendente`/`Finalizado`) → alimenta o cartão "Pendentes de Finalização".
