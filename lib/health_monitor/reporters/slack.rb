# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module HealthMonitor
  module Reporters
    # Monta o resumo no formato do Slack e envia via Incoming Webhook.
    # Sem SLACK_WEBHOOK_URL (ou com DRY_RUN=true), só imprime no terminal.
    class Slack
      def initialize(webhook_url: ENV['SLACK_WEBHOOK_URL'], dry_run: ENV['DRY_RUN'] == 'true', out: $stdout)
        @webhook_url = webhook_url
        @dry_run = dry_run
        @out = out
      end

      def message(results, classification, overall, timestamp: Time.now)
        [
          "*Monitor de saúde — #{timestamp.strftime('%d/%m/%Y %Hh%M')}*",
          "*#{Status.label(overall)}*",
          section('Interface (UI)', results.select { |r| r.type == 'UI' }),
          section('APIs', results.select { |r| r.type == 'API' }),
          bugs_section(classification)
        ].join("\n\n")
      end

      def deliver(text)
        if @dry_run || @webhook_url.to_s.empty?
          @out.puts "\n— Slack desativado (sem webhook ou DRY_RUN). Mensagem que seria enviada:\n\n#{text}"
          return false
        end

        uri = URI(@webhook_url)
        response = Net::HTTP.post(uri, { text: text }.to_json, 'Content-Type' => 'application/json')
        ok = response.code.to_i.between?(200, 299)
        @out.puts(ok ? '✅ Resumo enviado ao Slack' : "❌ Slack respondeu #{response.code}")
        ok
      end

      private

      def section(title, results)
        return "*#{title}* — nenhuma checagem" if results.empty?

        ok = results.count(&:ok?)
        lines = ["*#{title}* — #{ok}/#{results.size} ok"]
        results.reject(&:ok?).each { |r| lines << "#{r.emoji} <#{r.link}|#{r.name}>: #{r.detail}" }
        lines.join("\n")
      end

      def bugs_section(classification)
        lines = ["*Log de erros* — #{classification.total_events} eventos analisados"]
        if classification.critical?
          classification.critical_bugs.each { |bug| lines << "🐛 Bug crítico: #{bug}" }
        else
          lines << '🟢 Nenhum bug crítico'
        end
        lines << "🟡 #{classification.below_threshold.size} ocorrência(s) abaixo do limite crítico" if classification.noise?
        lines << "⚪ #{classification.ignored} evento(s) ignorado(s) por serem regra de negócio" if classification.ignored.positive?
        lines.join("\n")
      end
    end
  end
end
