# frozen_string_literal: true

module HealthMonitor
  # Resultado de uma checagem: :ok (verde), :warn (amarelo) ou :fail (vermelho).
  Result = Struct.new(:type, :name, :status, :duration_ms, :detail, :link, keyword_init: true) do
    def ok?   = status == :ok
    def warn? = status == :warn
    def fail? = status == :fail

    def emoji
      { ok: '🟢', warn: '🟡', fail: '🔴' }.fetch(status)
    end
  end
end
