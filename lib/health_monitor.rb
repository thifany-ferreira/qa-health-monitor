# frozen_string_literal: true

require 'yaml'
require 'json'

require_relative 'health_monitor/result'
require_relative 'health_monitor/status'
require_relative 'health_monitor/failure_classifier'
require_relative 'health_monitor/event_simulator'
require_relative 'health_monitor/checks/http_check'
require_relative 'health_monitor/checks/ui_check'
require_relative 'health_monitor/reporters/slack'
require_relative 'health_monitor/reporters/spreadsheet'
require_relative 'health_monitor/reporters/markdown'

module HealthMonitor
  # Orquestra a rodada: checagens → classificação do log → relatórios.
  class Runner
    def initialize(config_path: File.expand_path('../config/monitor.yml', __dir__), out: $stdout)
      @config = YAML.load_file(config_path)
      @settings = @config.fetch('settings')
      @out = out
    end

    def call
      @out.puts '▶ Rodando checagens...'
      results = run_checks
      results.each { |r| @out.puts "  #{r.emoji} [#{r.type}] #{r.name} — #{r.detail}" }

      @out.puts "\n▶ Analisando log de erros..."
      classification = classifier.classify(load_events)
      classification.critical_bugs.each { |bug| @out.puts "  🐛 #{bug}" }

      overall = Status.overall(results, classification)
      @out.puts "\n#{Status.label(overall)}"

      report(results, classification, overall)
      overall
    end

    private

    def run_checks
      api = @config.fetch('api_checks', []).map do |c|
        Checks::HttpCheck.new(c, warn_ms: @settings.fetch('api_warn_ms')).run
      end
      ui = @config.fetch('ui_checks', []).map do |c|
        Checks::UiCheck.new(c, warn_ms: @settings.fetch('ui_warn_ms'), session_factory: method(:browser_session)).run
      end
      api + ui + demo_failure
    end

    # DEMO_FAILURE=true adiciona uma checagem que sempre falha, para mostrar o alerta vermelho.
    def demo_failure
      return [] unless ENV['DEMO_FAILURE'] == 'true'

      demo = { 'name' => 'Demo de falha (página com erro 500)',
               'url' => 'https://the-internet.herokuapp.com/status_codes/500', 'expect_status' => 200 }
      [Checks::HttpCheck.new(demo, warn_ms: @settings.fetch('api_warn_ms')).run]
    end

    def browser_session
      @browser_session ||= begin
        require 'capybara'
        require 'selenium-webdriver'
        Capybara.register_driver(:chrome_headless) do |app|
          options = Selenium::WebDriver::Chrome::Options.new
          %w[--headless=new --no-sandbox --disable-dev-shm-usage --window-size=1440,900
             --disable-features=PasswordLeakDetection].each { |a| options.add_argument(a) }
          # Desliga o gerenciador de senhas: o alerta de "senha vazada" do Chrome atrapalha
          # logins com as credenciais públicas dos sites de treino.
          options.add_preference('credentials_enable_service', false)
          options.add_preference('profile.password_manager_enabled', false)
          options.add_preference('profile.password_manager_leak_detection', false)
          Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
        end
        Capybara.default_max_wait_time = @settings.fetch('ui_wait_seconds', 15)
        session = Capybara::Session.new(:chrome_headless)
        # Abre o navegador antes de cronometrar, para o tempo de inicialização
        # do Chrome não contar como lentidão do primeiro fluxo.
        session.visit('about:blank')
        session
      end
    end

    def classifier
      FailureClassifier.new(
        bug_classes: @settings.fetch('bug_classes'),
        ignored_operations: @settings.fetch('ignored_operations'),
        min_occurrences: @settings.fetch('min_occurrences')
      )
    end

    def load_events
      file = ENV['EVENTS_FILE']
      file ? JSON.parse(File.read(file)) : EventSimulator.new.events
    end

    def report(results, classification, overall)
      markdown = Reporters::Markdown.new
      markdown.publish(markdown.render(results, classification, overall))

      path = Reporters::Spreadsheet.new.write(results, classification)
      @out.puts "📄 Planilha atualizada: #{path}"

      slack = Reporters::Slack.new(out: @out)
      slack.deliver(slack.message(results, classification, overall))
    ensure
      @browser_session&.quit
    end
  end
end
