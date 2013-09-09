# Copyright 2013© MaestroDev.  All rights reserved.

# Mock logging methods to redirect all output to stdout
# DO NOT use in deployed plugins, just in specs
# ie. in spec_helper.rb
# require 'maestro_plugin/logging_mock'
require 'logging'

module Maestro

  class << self
    # add a check just in case it is included in a deployed plugin
    unless Maestro.respond_to?(:log)
      def log
        ::Logging::Logger.new(STDOUT)
      end
    end
  end

end
