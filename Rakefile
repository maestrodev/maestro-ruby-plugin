require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rake/clean'

require File.expand_path('../lib/maestro_plugin/version', __FILE__)

CLEAN.include('pkg')
CLOBBER.include('.bundle', '.config', 'coverage', 'InstalledFiles', 'spec/reports', 'rdoc', 'test', 'tmp')

task :default => [:clean, :bundle, :spec, :build]

RSpec::Core::RakeTask.new

desc 'Get dependencies with Bundler'
task :bundle do
  sh %{bundle install}
end
