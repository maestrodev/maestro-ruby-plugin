# Copyright 2011© MaestroDev.  All rights reserved.

require 'logging'

module Maestro

  if !Maestro.const_defined?("Logging")

    module Logging

      def log
        log = Logger.new(STDOUT)
        log.level = Logger::DEBUG
        return log
      end

    end
  end
end
