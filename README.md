# QA Health Monitor

[![Testes](https://github.com/thifany-ferreira/qa-health-monitor/actions/workflows/tests.yml/badge.svg)](https://github.com/thifany-ferreira/qa-health-monitor/actions/workflows/tests.yml)
[![Monitor](https://github.com/thifany-ferreira/qa-health-monitor/actions/workflows/monitor.yml/badge.svg)](https://github.com/thifany-ferreira/qa-health-monitor/actions/workflows/monitor.yml)
![Ruby](https://img.shields.io/badge/Ruby-3.1%2B-CC342D?logo=ruby&logoColor=white)
![Capybara](https://img.shields.io/badge/Capybara-Selenium-43B02A?logo=selenium&logoColor=white)
[![Licença MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-green)](LICENSE)

> 🇺🇸 *Automated system health monitor in Ruby + Capybara + Selenium: UI and API checks with a green/yellow/red status, an error-log classifier that separates real bugs from noise, and daily reports to Slack and a spreadsheet, scheduled on GitHub Actions.*

Monitor de saúde de sistemas que roda sozinho todo dia útil e responde a pergunta: **"está tudo funcionando hoje?"**

- **Checagens de interface** (login e fluxos) com Capybara + Selenium em Chrome headless
- **Checagens de API** com status esperado e tempo de resposta
- **Semáforo** 🟢 🟡 🔴 para cada checagem e para o dia
- **Classificador de log de erros** que separa bug real de ruído, com volume mínimo para evitar falso positivo
- **Relatórios** no Slack, numa planilha (CSV) e no painel do GitHub Actions
- **Agendamento** no GitHub Actions, de segunda a sexta às 8h

**Autora:** Thifany Ferreira · [LinkedIn](https://www.linkedin.com/in/thifanyferreira)

> Todos os sites monitorados são ambientes **públicos de treino de automação**, e o log de erros é **fictício**, gerado por simulação.

## Como funciona

```
config/monitor.yml
      │
      ▼
[Checagens de UI e API] ──► 🟢 ok · 🟡 lento · 🔴 falhou
      │
[Log de erros] ──► Classificador ──► bug crítico · abaixo do limite · regra de negócio (ignorado)
      │
      ▼
Status do dia ──► Slack · Planilha CSV · Painel do GitHub Actions
```

### Regras do semáforo

| Status | Quando |
|---|---|
| 🟢 Tudo ok | Todas as checagens passaram e não há bug crítico |
| 🟡 Atenção | Alguma checagem lenta ou erros abaixo do limite crítico |
| 🔴 Atenção necessária | Alguma checagem falhou ou existe bug crítico no log |

### Classificador de falhas

Nem todo erro no log é bug. O classificador aplica três regras, todas configuráveis:

1. **Só exceções de código contam como bug** (`NoMethodError`, `TypeError`...). Timeout de parceiro externo não é bug da aplicação.
2. **Operações que usam exceção genérica de propósito**, para sinalizar uma regra de negócio esperada, ficam numa lista de exclusão.
3. **Volume mínimo:** só vira crítico o que passa de N ocorrências do mesmo serviço e da mesma classe. Abaixo disso, costuma ser caso isolado.

Para cada bug crítico, o relatório mostra o volume, quantos clientes distintos foram afetados, a operação e a mensagem de erro.

## Exemplo de mensagem no Slack

```text
Monitor de saúde — 02/10/2026 08h00
🔴 Atenção necessária

Interface (UI) — 2/2 ok

APIs — 2/3 ok
🔴 Restful Booker — ping: HTTP 503 (esperado 201)

Log de erros — 92 eventos analisados
🐛 Bug crítico: Pagamentos: NoMethodError (31x, 25 clientes) na operação 'CalcularParcelas' — undefined method 'round' for nil
🟡 2 ocorrência(s) abaixo do limite crítico
⚪ 27 evento(s) ignorado(s) por serem regra de negócio
```

## Como rodar

Requer Ruby 3.1+ e Google Chrome.

```bash
bundle install
bundle exec rake test          # testes unitários
bundle exec ruby bin/monitor   # roda o monitor
```

Variáveis opcionais:

| Variável | Uso |
|---|---|
| `SLACK_WEBHOOK_URL` | Envia o resumo para o Slack (sem ela, o resumo só aparece no terminal) |
| `DRY_RUN=true` | Nunca envia ao Slack |
| `DEMO_FAILURE=true` | Adiciona uma checagem que falha de propósito, para ver o alerta vermelho |
| `EVENTS_FILE=arquivo.json` | Usa um log de erros real em vez do simulado |
| `STRICT=true` | Termina com erro quando o status do dia é vermelho (útil para travar um pipeline) |

A planilha é gravada em `reports/health-AAAA-MM-DD.csv` e acumula todas as rodadas do dia. Ela abre direto no Excel ou no Google Sheets.

## Adicionando uma checagem

Basta incluir um item em `config/monitor.yml`, sem mexer no código:

```yaml
ui_checks:
  - name: Minha aplicação — login
    url: https://minha-app.exemplo
    steps:
      - visit: /login
      - fill: { field: "#email", with: "ENV:APP_EMAIL" }      # lê de variável de ambiente
      - fill: { field: "#senha", with: "ENV:APP_PASSWORD" }
      - click: "#entrar"
      - expect_text: Bem-vinda

api_checks:
  - name: Minha API — saúde
    url: https://api.minha-app.exemplo/health
    expect_status: 200
```

Passos disponíveis: `visit`, `fill`, `click`, `expect_text` e `expect_css`. Senhas nunca ficam no YAML: use `ENV:NOME_DA_VARIAVEL`.

## CI (GitHub Actions)

- **Testes:** a cada envio de código, roda os testes unitários (classificador, semáforo, checagens e relatórios).
- **Monitor:** roda sozinho de segunda a sexta às 8h, publica o painel na página da execução e guarda a planilha como artefato. Também pode ser disparado manualmente, com a opção de demonstrar o alerta vermelho.

Para receber no Slack, crie um [Incoming Webhook](https://api.slack.com/messaging/webhooks) e salve a URL no secret `SLACK_WEBHOOK_URL` do repositório.

## Estrutura

```
bin/monitor                      # ponto de entrada
config/monitor.yml               # checagens e regras do classificador
lib/health_monitor/
  checks/ui_check.rb             # fluxos de tela (Capybara + Selenium)
  checks/http_check.rb           # APIs (status + tempo de resposta)
  failure_classifier.rb          # separa bug real de ruído
  status.rb                      # semáforo do dia
  event_simulator.rb             # log de erros fictício (reproduzível por data)
  reporters/                     # Slack, planilha CSV e Markdown
test/                            # testes unitários (Minitest), sem depender da internet
```

## Licença

[MIT](LICENSE) © Thifany Ferreira
