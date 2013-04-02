# Copyright 2013© MaestroDev.  All rights reserved.
require 'maestro_plugin/version'
require 'maestro_plugin/logging'
require 'maestro_plugin/maestro_worker'

module Maestro

  class << self
    include Maestro::Logging unless Maestro.include?(Maestro::Logging)
  end

  if !Maestro.const_defined?("RuoteParticipants")
    # Stub out this class for testing. The real implentation is provided by the agent.
    class RuoteParticipants

      class << self

        def send_workitem_message(workitem)

          Maestro.log.debug "Sent Workitem Stream"

        end

      end
    end

  end
end




