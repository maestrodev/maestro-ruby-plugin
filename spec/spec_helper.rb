require 'rubygems'
require 'rspec'
require 'maestro_plugin/logging_stdout'
require 'maestro_plugin/rspec'

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib') unless $LOAD_PATH.include?(File.dirname(__FILE__) + '/../lib')

require 'maestro_plugin'

RSpec.configure do |config|
  # Only run focused specs:
  config.filter_run :focus => true
  config.filter_run_excluding :disabled => true

  # Yet, if there is nothing filtered, run the whole thing.
  config.run_all_when_everything_filtered = true
end
