# frozen_string_literal: true

require_relative 'test_helper'

class StatusTest < Minitest::Test
  include TestHelpers

  def sem_bugs = classifier.classify([])

  def test_verde_quando_tudo_ok
    assert_equal :ok, HealthMonitor::Status.overall([result(:ok), result(:ok)], sem_bugs)
  end

  def test_amarelo_quando_ha_lentidao
    assert_equal :warn, HealthMonitor::Status.overall([result(:ok), result(:warn)], sem_bugs)
  end

  def test_amarelo_quando_ha_erros_abaixo_do_limite
    poucos = classifier.classify(Array.new(3) { event('Pagamentos', 'TypeError') })

    assert_equal :warn, HealthMonitor::Status.overall([result(:ok)], poucos)
  end

  def test_vermelho_quando_uma_checagem_falha
    assert_equal :fail, HealthMonitor::Status.overall([result(:warn), result(:fail)], sem_bugs)
  end

  def test_vermelho_quando_ha_bug_critico_mesmo_com_checagens_ok
    critico = classifier.classify(Array.new(30) { event('Pagamentos', 'NoMethodError') })

    assert_equal :fail, HealthMonitor::Status.overall([result(:ok)], critico)
  end
end
