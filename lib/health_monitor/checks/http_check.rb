# frozen_string_literal: true

require 'net/http'
require 'uri'

module HealthMonitor
  module Checks
    # Checagem de API: status HTTP esperado + tempo de resposta.
    class HttpCheck
      def initialize(config, warn_ms:)
        @name = config.fetch('name')
        @url = config.fetch('url')
        @expect_status = config.fetch('expect_status', 200)
        @warn_ms = config.fetch('warn_ms', warn_ms)
      end

      def run
        started = now_ms
        response = request
        duration = now_ms - started

        if response.code.to_i != @expect_status
          result(:fail, duration, "HTTP #{response.code} (esperado #{@expect_status})")
        elsif duration > @warn_ms
          result(:warn, duration, "lento: #{duration} ms (limite #{@warn_ms} ms)")
        else
          result(:ok, duration, "HTTP #{response.code} em #{duration} ms")
        end
      rescue StandardError => e
        result(:fail, now_ms - started, "#{e.class}: #{e.message[0, 120]}")
      end

      private

      def request
        uri = URI(@url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10, read_timeout: 20) do |http|
          http.get(uri.request_uri)
        end
      end

      def result(status, duration, detail)
        Result.new(type: 'API', name: @name, status: status, duration_ms: duration, detail: detail, link: @url)
      end

      def now_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end
end
