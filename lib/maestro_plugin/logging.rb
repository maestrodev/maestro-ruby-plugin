# Copyright 2013© MaestroDev.  All rights reserved.
require 'logging'

module Maestro

  unless Maestro.const_defined?('Logging')

    module Logging

      def log
        ::Logging::Logger.new(STDOUT)
      end

    end
  end

  class << self
    include Maestro::Logging unless Maestro.include?(Maestro::Logging)
  end

end
