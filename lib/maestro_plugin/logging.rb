# Copyright 2013© MaestroDev.  All rights reserved.

require 'logging'

module Maestro

  unless Maestro.const_defined?('Logging')

    module Logging

      def log
        log = Logger.new(STDOUT)
        log.level = Logger::DEBUG
        log
      end

    end
  end
end
