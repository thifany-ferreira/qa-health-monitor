# frozen_string_literal: true

module HealthMonitor
  module Reporters
    # Resumo em Markdown. No GitHub Actions ele aparece na página da execução
    # (GITHUB_STEP_SUMMARY), como um painel do dia.
    class Markdown
      def render(results, classification, overall, timestamp: Time.now)
        lines = []
        lines << "## Monitor de saúde — #{timestamp.strftime('%d/%m/%Y %H:%M')}"
        lines << ''
        lines << "**Status geral:** #{Status.label(overall)}"
        lines << ''
        lines << '| | Tipo | Checagem | Tempo | Detalhe |'
        lines << '|---|---|---|---|---|'
        results.each do |r|
          lines << "| #{r.emoji} | #{r.type} | [#{r.name}](#{r.link}) | #{r.duration_ms} ms | #{r.detail.to_s.tr('|', '/')} |"
        end
        lines << ''
        lines << "### Log de erros (#{classification.total_events} eventos)"
        if classification.critical?
          classification.critical_bugs.each { |bug| lines << "- 🐛 **Crítico:** #{bug}" }
        else
          lines << '- 🟢 Nenhum bug crítico'
        end
        classification.below_threshold.each { |bug| lines << "- 🟡 Abaixo do limite: #{bug}" }
        lines << "- ⚪ #{classification.ignored} evento(s) ignorado(s) (regra de negócio)" if classification.ignored.positive?
        lines.join("\n")
      end

      def publish(text)
        summary = ENV['GITHUB_STEP_SUMMARY']
        File.write(summary, "#{text}\n", mode: 'a') if summary && !summary.empty?
      end
    end
  end
end
