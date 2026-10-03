# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

class HttpCheckTest < Minitest::Test
  include TestHelpers

  def check(url, expect: 200, warn_ms: 2000)
    HealthMonitor::Checks::HttpCheck.new({ 'name' => 'API', 'url' => url, 'expect_status' => expect }, warn_ms: warn_ms)
  end

  def test_verde_com_status_esperado
    with_fake_server(status: 200) { |url| assert_equal :ok, check(url).run.status }
  end

  def test_vermelho_com_status_inesperado
    with_fake_server(status: 500) do |url|
      result = check(url).run
      assert_equal :fail, result.status
      assert_includes result.detail, 'HTTP 500'
    end
  end

  def test_amarelo_quando_responde_acima_do_limite
    with_fake_server(status: 200, delay: 0.3) { |url| assert_equal :warn, check(url, warn_ms: 100).run.status }
  end

  def test_vermelho_quando_servico_esta_fora
    assert_equal :fail, check('http://127.0.0.1:1/fora').run.status
  end
end

class UiCheckTest < Minitest::Test
  STEPS = [
    { 'visit' => '/login' },
    { 'fill' => { 'field' => '#user', 'with' => 'ENV:MONITOR_TEST_USER' } },
    { 'click' => '#entrar' },
    { 'expect_text' => 'Bem-vinda' }
  ].freeze

  def check(session, steps: STEPS, warn_ms: 60_000)
    HealthMonitor::Checks::UiCheck.new({ 'name' => 'Login', 'url' => 'https://app.test', 'steps' => steps },
                                       warn_ms: warn_ms, session_factory: -> { session })
  end

  def setup = ENV['MONITOR_TEST_USER'] = 'ana'
  def teardown = ENV.delete('MONITOR_TEST_USER')

  def test_executa_os_passos_na_ordem_e_le_variavel_de_ambiente
    session = FakeSession.new

    result = check(session).run

    assert_equal :ok, result.status
    assert_equal [:visit, 'https://app.test/login'], session.calls.first
    assert_includes session.calls, [:set, '#user=ana']
    assert_equal [:assert_text, 'Bem-vinda'], session.calls.last
  end

  def test_vermelho_quando_um_passo_falha
    result = check(FakeSession.new(fail_on: :assert_text)).run

    assert_equal :fail, result.status
    assert_includes result.detail, 'assert_text'
  end

  def test_falha_guarda_print_e_url_da_tela
    Dir.mktmpdir do |dir|
      session = ScreenshotSession.new(fail_on: :assert_text)
      check = HealthMonitor::Checks::UiCheck.new({ 'name' => 'Login — App', 'url' => 'https://app.test', 'steps' => STEPS },
                                                 warn_ms: 60_000, session_factory: -> { session }, screenshot_dir: dir)

      result = check.run

      assert_includes result.detail, '(em https://app.test/erro)'
      assert_includes result.detail, File.join(dir, 'login-app.png')
      assert File.exist?(File.join(dir, 'login-app.png'))
    end
  end

  def test_vermelho_com_passo_desconhecido
    result = check(FakeSession.new, steps: [{ 'arrastar' => '#x' }]).run

    assert_equal :fail, result.status
    assert_includes result.detail, 'passo desconhecido'
  end

  def test_amarelo_quando_fluxo_e_lento
    assert_equal :warn, check(FakeSession.new, warn_ms: -1).run.status
  end
end

# Sessão falsa que também sabe tirar print, como o Capybara real.
class ScreenshotSession < FakeSession
  def current_url = 'https://app.test/erro'
  def save_screenshot(path) = File.write(path, 'png')
end
