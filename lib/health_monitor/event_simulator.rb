# frozen_string_literal: true

require 'date'

module HealthMonitor
  # Gera um log de erros FICTÍCIO, como se viesse do backend de uma aplicação.
  # A semente é a data: o mesmo dia gera sempre o mesmo log (reproduzível),
  # e dias diferentes geram cenários diferentes (às vezes tem bug crítico, às vezes não).
  class EventSimulator
    # [serviço, operação, classe do erro, faixa de volume, mensagem]
    SCENARIOS = [
      ['Pagamentos',    'CalcularParcelas',      'NoMethodError',   0..40, "undefined method 'round' for nil"],
      ['Cadastro',      'ValidarRegraDeNegocio', 'RuntimeError',   10..40, 'cliente fora da política de crédito'],
      ['Cadastro',      'NormalizarTelefone',    'ArgumentError',   0..25, 'formato de telefone inválido'],
      ['Notificações',  'MontarMensagem',        'TypeError',       0..8,  'no implicit conversion of nil into String'],
      ['Parceiro Externo', 'SincronizarPedidos', 'Timeout::Error', 10..60, 'execution expired']
    ].freeze

    def initialize(date: Date.today)
      @random = Random.new(date.strftime('%Y%m%d').to_i)
    end

    def events
      SCENARIOS.flat_map do |service, operation, error_class, range, message|
        Array.new(@random.rand(range)) do
          {
            'service' => service,
            'operation' => operation,
            'error_class' => error_class,
            'message' => message,
            'customer_id' => "CLI-#{@random.rand(1..60).to_s.rjust(4, '0')}"
          }
        end
      end
    end
  end
end
