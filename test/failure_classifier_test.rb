# frozen_string_literal: true

require_relative 'test_helper'

class FailureClassifierTest < Minitest::Test
  include TestHelpers

  def test_vira_critico_quando_atinge_o_volume_minimo
    events = Array.new(20) { |i| event('Pagamentos', 'NoMethodError', customer: "CLI-#{i}") }

    result = classifier.classify(events)

    assert result.critical?
    bug = result.critical_bugs.first
    assert_equal ['Pagamentos', 'NoMethodError', 20, 20], [bug.service, bug.error_class, bug.total, bug.customers]
  end

  def test_abaixo_do_limite_nao_e_critico_mas_fica_registrado
    events = Array.new(19) { event('Pagamentos', 'NoMethodError') }

    result = classifier.classify(events)

    refute result.critical?
    assert result.noise?
  end

  def test_ignora_operacao_que_sinaliza_regra_de_negocio
    events = Array.new(50) { event('Cadastro', 'RuntimeError', operation: 'ValidarRegraDeNegocio') }

    result = classifier.classify(events)

    refute result.critical?
    assert_equal 50, result.ignored
  end

  def test_erro_externo_nao_e_tratado_como_bug_do_codigo
    events = Array.new(100) { event('Parceiro Externo', 'Timeout::Error') }

    result = classifier.classify(events)

    assert_empty result.critical_bugs
    assert_empty result.below_threshold
  end

  def test_agrupa_por_servico_e_classe_e_conta_clientes_distintos
    events = Array.new(25) { |i| event('Pagamentos', 'TypeError', customer: "CLI-#{i % 5}") } +
             Array.new(25) { event('Cadastro', 'TypeError') }

    bugs = classifier.classify(events).critical_bugs

    assert_equal 2, bugs.size
    assert_equal 5, bugs.find { |b| b.service == 'Pagamentos' }.customers
  end

  def test_descricao_do_bug_traz_contexto_para_o_relatorio
    events = Array.new(20) { event('Pagamentos', 'NoMethodError', operation: 'CalcularParcelas', message: 'nil') }

    texto = classifier.classify(events).critical_bugs.first.to_s

    assert_equal "Pagamentos: NoMethodError (20x, 1 cliente) na operação 'CalcularParcelas' — nil", texto
  end
end
