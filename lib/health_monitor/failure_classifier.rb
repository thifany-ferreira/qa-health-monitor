# frozen_string_literal: true

require 'set'

module HealthMonitor
  # Lê um log de erros e separa o que é bug real do que é ruído.
  #
  # Regras (configuráveis em config/monitor.yml):
  # - Só conta como "bug nosso" exceções de código (NoMethodError, TypeError...).
  #   Timeout e erro de API externa não entram: não são bug da aplicação.
  # - Operações que usam exceção genérica de propósito, para sinalizar uma regra
  #   de negócio esperada, ficam numa lista de exclusão (evita falso positivo).
  # - Só vira "crítico" o que passa de um volume mínimo de ocorrências
  #   (mesmo serviço + mesma classe). Abaixo disso, costuma ser caso isolado.
  class FailureClassifier
    Bug = Struct.new(:service, :error_class, :total, :customers, :operation, :message, keyword_init: true) do
      def to_s
        clientes = "#{customers} cliente#{'s' unless customers == 1}"
        texto = "#{service}: #{error_class} (#{total}x, #{clientes}) na operação '#{operation}'"
        message.to_s.empty? ? texto : "#{texto} — #{message}"
      end
    end

    Classification = Struct.new(:critical_bugs, :below_threshold, :ignored, :total_events, keyword_init: true) do
      def critical? = critical_bugs.any?
      def noise?    = below_threshold.any?
    end

    def initialize(bug_classes:, ignored_operations:, min_occurrences:)
      @bug_classes = bug_classes
      @ignored_operations = ignored_operations
      @min_occurrences = min_occurrences
    end

    def classify(events)
      ignored = 0
      groups = Hash.new { |h, k| h[k] = { total: 0, customers: Set.new, operation: nil, message: nil } }

      events.each do |event|
        next unless @bug_classes.include?(event['error_class'])

        if @ignored_operations.include?(event['operation'])
          ignored += 1
          next
        end

        group = groups[[event['service'], event['error_class']]]
        group[:total] += 1
        group[:customers] << event['customer_id'] if event['customer_id']
        group[:operation] ||= event['operation']
        group[:message] ||= event['message']
      end

      bugs = groups.map do |(service, error_class), g|
        Bug.new(service: service, error_class: error_class, total: g[:total], customers: g[:customers].size,
                operation: g[:operation], message: g[:message])
      end.sort_by { |b| -b.total }

      critical, below = bugs.partition { |b| b.total >= @min_occurrences }
      Classification.new(critical_bugs: critical, below_threshold: below, ignored: ignored, total_events: events.size)
    end
  end
end
