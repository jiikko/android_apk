# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "rdoc/task"

require_relative "lib/version"

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  warn e.message
  warn "Run `bundle install` to install missing gems"
  exit e.status_code
end

RSpec::Core::RakeTask.new(:specs) do |task|
  task.pattern = "spec/**{,/*/**}/*_spec.rb"

  raise "you need to have aapt in PATH" unless File.executable?(`which aapt`.chomp)
end

task default: :specs

task :spec do
  Rake::Task["specs"].invoke
  Rake::Task["rubocop"].invoke
  Rake::Task["rdoc"].invoke
end

desc "Run RuboCop on the lib/specs directory"
RuboCop::RakeTask.new(:rubocop) do |task|
  task.patterns = %w(lib/**{,/*/**}/*.rb spec/**{,/*/**}/*.rb)
end

RSpec::Core::RakeTask.new(:rcov) do |task|
  task.pattern = "spec/**{,/*/**}/*_spec.rb"
  task.rcov = true
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "android_apk #{AndroidApk::VERSION}"
  rdoc.rdoc_files.include("README.md")
  rdoc.rdoc_files.include("lib/**{,/*/**}/*.rb")
end
