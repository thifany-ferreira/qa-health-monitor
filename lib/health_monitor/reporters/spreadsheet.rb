# frozen_string_literal: true

require 'csv'
require 'fileutils'

module HealthMonitor
  module Reporters
    # Planilha da execução: um CSV por dia, que abre direto no Excel ou no Google Sheets.
    # Cada execução acrescenta linhas, então o arquivo do dia guarda o histórico de rodadas.
    class Spreadsheet
      HEADERS = %w[data_hora tipo nome status duracao_ms detalhe link].freeze

      def initialize(dir: 'reports')
        @dir = dir
      end

      def write(results, classification, timestamp: Time.now)
        FileUtils.mkdir_p(@dir)
        path = File.join(@dir, "health-#{timestamp.strftime('%Y-%m-%d')}.csv")
        new_file = !File.exist?(path)

        # BOM no início do arquivo: faz o Excel reconhecer acentos (UTF-8) ao abrir.
        File.write(path, "\uFEFF", encoding: 'UTF-8') if new_file
        CSV.open(path, 'a:UTF-8', col_sep: ';') do |csv|
          csv << HEADERS if new_file
          stamp = timestamp.strftime('%d/%m/%Y %H:%M:%S')
          results.each do |r|
            csv << [stamp, r.type, r.name, r.status, r.duration_ms, r.detail, r.link]
          end
          classification.critical_bugs.each do |bug|
            csv << [stamp, 'BUG', bug.service, 'fail', '', bug.to_s, '']
          end
        end
        path
      end
    end
  end
end
