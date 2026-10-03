# frozen_string_literal: true

module HealthMonitor
  # Status geral do dia, no estilo semáforo:
  #   vermelho = alguma checagem falhou ou existe bug crítico
  #   amarelo  = só alertas (lentidão ou erros abaixo do limite crítico)
  #   verde    = tudo certo
  module Status
    module_function

    def overall(results, classification)
      return :fail if results.any?(&:fail?) || classification.critical?
      return :warn if results.any?(&:warn?) || classification.noise?

      :ok
    end

    def label(status)
      { ok: '🟢 Tudo ok', warn: '🟡 Atenção', fail: '🔴 Atenção necessária' }.fetch(status)
    end
  end
end
