# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'stringio'

class ReportersTest < Minitest::Test
  include TestHelpers

  def setup
    @results = [result(:ok, name: 'API ok'), result(:fail, type: 'UI', name: 'Login quebrado')]
    @classification = classifier.classify(Array.new(25) { event('Pagamentos', 'NoMethodError') })
    @time = Time.new(2026, 10, 2, 9, 0, 0)
  end

  def test_mensagem_do_slack_traz_status_falhas_e_bugs
    texto = HealthMonitor::Reporters::Slack.new(out: StringIO.new)
                                           .message(@results, @classification, :fail, timestamp: @time)

    assert_includes texto, '02/10/2026 09h00'
    assert_includes texto, '🔴 Atenção necessária'
    assert_includes texto, '<https://exemplo.test|Login quebrado>'
    assert_includes texto, '🐛 Bug crítico: Pagamentos: NoMethodError (25x'
  end

  def test_sem_webhook_nao_envia_e_mostra_no_terminal
    out = StringIO.new

    enviado = HealthMonitor::Reporters::Slack.new(webhook_url: nil, out: out).deliver('oi')

    refute enviado
    assert_includes out.string, 'Slack desativado'
  end

  def test_planilha_acumula_rodadas_do_mesmo_dia
    Dir.mktmpdir do |dir|
      sheet = HealthMonitor::Reporters::Spreadsheet.new(dir: dir)
      sheet.write(@results, @classification, timestamp: @time)
      path = sheet.write(@results, @classification, timestamp: @time + 3600)

      rows = CSV.read(path, col_sep: ';', encoding: 'bom|utf-8')
      assert_equal HealthMonitor::Reporters::Spreadsheet::HEADERS, rows.first
      assert_equal 1 + (2 * 3), rows.size # cabeçalho + 2 rodadas x (2 checagens + 1 bug)
    end
  end

  def test_markdown_tem_tabela_e_bugs
    md = HealthMonitor::Reporters::Markdown.new.render(@results, @classification, :fail, timestamp: @time)

    assert_includes md, '| 🔴 | UI | [Login quebrado](https://exemplo.test)'
    assert_includes md, '🐛 **Crítico:** Pagamentos'
  end
end

class EventSimulatorTest < Minitest::Test
  def test_mesmo_dia_gera_o_mesmo_log
    dia = Date.new(2026, 10, 2)

    assert_equal HealthMonitor::EventSimulator.new(date: dia).events,
                 HealthMonitor::EventSimulator.new(date: dia).events
  end

  def test_dias_diferentes_geram_cenarios_diferentes
    refute_equal HealthMonitor::EventSimulator.new(date: Date.new(2026, 10, 2)).events,
                 HealthMonitor::EventSimulator.new(date: Date.new(2026, 10, 3)).events
  end
end
