# frozen_string_literal: true

require 'minitest/autorun'
require 'socket'
require_relative '../lib/health_monitor'

module TestHelpers
  def event(service, error_class, operation: 'Operacao', customer: 'CLI-0001', message: 'erro')
    { 'service' => service, 'error_class' => error_class, 'operation' => operation,
      'customer_id' => customer, 'message' => message }
  end

  def result(status, type: 'API', name: 'Checagem')
    HealthMonitor::Result.new(type: type, name: name, status: status, duration_ms: 100, detail: 'detalhe',
                              link: 'https://exemplo.test')
  end

  def classifier(min: 20)
    HealthMonitor::FailureClassifier.new(
      bug_classes: %w[NoMethodError TypeError RuntimeError],
      ignored_operations: %w[ValidarRegraDeNegocio],
      min_occurrences: min
    )
  end

  # Servidor HTTP local mínimo, para testar a checagem de API sem depender da internet.
  def with_fake_server(status:, delay: 0)
    server = TCPServer.new('127.0.0.1', 0)
    thread = Thread.new do
      client = server.accept
      client.gets
      sleep delay
      client.write("HTTP/1.1 #{status} X\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
      client.close
    rescue IOError
      nil
    end
    yield "http://127.0.0.1:#{server.addr[1]}/health"
  ensure
    thread&.join(2)
    server&.close
  end
end

# Sessão falsa que imita a API do Capybara usada pelas checagens de UI.
class FakeSession
  attr_reader :calls

  def initialize(fail_on: nil)
    @calls = []
    @fail_on = fail_on
  end

  def visit(url) = record(:visit, url)
  def assert_text(text) = record(:assert_text, text)
  def assert_selector(css) = record(:assert_selector, css)
  def reset_session! = nil

  def find(selector)
    record(:find, selector)
    FakeElement.new(self, selector)
  end

  def record(action, arg)
    raise StandardError, "falhou em #{action} #{arg}" if @fail_on == action

    @calls << [action, arg]
  end
end

FakeElement = Struct.new(:session, :selector) do
  def set(value) = session.record(:set, "#{selector}=#{value}")
  def click = session.record(:click, selector)
end
