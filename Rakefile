# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.warning = false
end

desc 'Roda o monitor (checagens + relatórios)'
task :monitor do
  ruby 'bin/monitor'
end

task default: :test
