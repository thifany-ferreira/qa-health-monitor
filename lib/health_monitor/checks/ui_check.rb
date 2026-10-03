# frozen_string_literal: true

require 'fileutils'

module HealthMonitor
  module Checks
    # Checagem de interface com Capybara + Selenium (Chrome headless).
    # Os passos vêm do config/monitor.yml, então um fluxo novo não exige código novo.
    class UiCheck
      STEPS = %w[visit fill click expect_text expect_css].freeze

      def initialize(config, warn_ms:, session_factory:, screenshot_dir: 'reports/screenshots')
        @name = config.fetch('name')
        @screenshot_dir = screenshot_dir
        @url = config.fetch('url')
        @steps = config.fetch('steps')
        @warn_ms = config.fetch('warn_ms', warn_ms)
        @session_factory = session_factory
      end

      def run
        session = @session_factory.call
        started = now_ms
        @steps.each { |step| perform(session, step) }
        duration = now_ms - started

        if duration > @warn_ms
          result(:warn, duration, "fluxo ok, mas lento: #{duration} ms (limite #{@warn_ms} ms)")
        else
          result(:ok, duration, "fluxo concluído em #{duration} ms")
        end
      rescue StandardError => e
        detail = "#{e.class}: #{e.message.lines.first.to_s.strip[0, 120]}"
        detail += " (em #{session.current_url})" if session.respond_to?(:current_url)
        shot = screenshot(session)
        detail += " · print: #{shot}" if shot
        result(:fail, started ? now_ms - started : 0, detail)
      ensure
        session&.reset_session!
      end

      private

      def perform(session, step)
        action, arg = step.first
        raise ArgumentError, "passo desconhecido: #{action}" unless STEPS.include?(action)

        case action
        when 'visit'       then session.visit(arg.start_with?('http') ? arg : "#{@url}#{arg}")
        when 'fill'        then session.find(arg.fetch('field')).set(resolve(arg.fetch('with')))
        when 'click'       then session.find(arg).click
        when 'expect_text' then session.assert_text(arg)
        when 'expect_css'  then session.assert_selector(arg)
        end
      end

      # Guarda um print da tela no momento da falha (vai junto da planilha no GitHub Actions).
      def screenshot(session)
        return unless session.respond_to?(:save_screenshot)

        path = File.join(@screenshot_dir, "#{@name.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')}.png")
        FileUtils.mkdir_p(@screenshot_dir)
        session.save_screenshot(path)
        path
      rescue StandardError
        nil
      end

      # Permite usar variáveis de ambiente no YAML: "ENV:NOME_DA_VARIAVEL"
      def resolve(value)
        value.to_s.start_with?('ENV:') ? ENV.fetch(value.delete_prefix('ENV:')) : value
      end

      def result(status, duration, detail)
        Result.new(type: 'UI', name: @name, status: status, duration_ms: duration, detail: detail, link: @url)
      end

      def now_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end
end
