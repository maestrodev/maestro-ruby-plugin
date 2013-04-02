require "bundler/gem_tasks"
require 'rspec/core/rake_task'
require 'rake/clean'

require File.expand_path('../lib/maestro_plugin/version', __FILE__)

CLEAN.include([ 'pkg', '*.gem'])

task :default => [:build]

desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
  t.rspec_opts = "--fail-fast --format p --color"
  # Put spec opts in a file named .rspec in root
end


desc "Deploy gem to Gemfury"
task :deploy => :build do
  require 'gemfury'

  file_name = "pkg/maestro_plugin-#{Maestro::Plugin::VERSION}.gem"
  client = Gemfury::Client.new(:user_api_key => '19mFQpkpgWC8xqPZVizB', :account => 'maestrodev')
  # Gemfury will skip the file if it already exists. Gotta yank it first.
  begin
    client.yank_version("maestro_plugin", Maestro::Plugin::VERSION)
  rescue Gemfury::InvalidGemVersion
    # ignore if the gem does not exist.
  rescue Gemfury::NotFound
    # ignore if the gem does not exist.
  end
  puts "Uploading #{file_name} to Gemfury"
  client.push_gem(File.new(file_name))
end

desc "Get dependencies with Bundler"
task :bundle do
  system "bundle install"
end

task :build => [:clean, :bundle, :spec]
task :build do
  system "gem build maestro_plugin.gemspec"
end

