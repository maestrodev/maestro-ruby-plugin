# Copyright 2013© MaestroDev.  All rights reserved.
require 'maestro_plugin/version'
require 'maestro_plugin/logging'
require 'maestro_plugin/maestro_worker'

module Maestro

  class << self
    include Maestro::Logging unless Maestro.include?(Maestro::Logging)
  end

end




