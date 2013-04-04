require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rake/clean'

require File.expand_path('../lib/maestro_plugin/version', __FILE__)

CLEAN.include([ 'pkg', '*.gem'])

task :default => [:build]

desc 'Run specs'
RSpec::Core::RakeTask.new do |t|
  t.pattern = './spec/**/*_spec.rb' # don't need this, it's default.
  t.rspec_opts = '--fail-fast --format p --color'
  # Put spec opts in a file named .rspec in root
end

desc 'Get dependencies with Bundler'
task :bundle do
  system 'bundle install'
end

task :build => [:clean, :bundle, :spec]
task :build do
  system 'gem build maestro_plugin.gemspec'
end

