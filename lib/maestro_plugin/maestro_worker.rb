require 'json'

module MaestroDev
  module Plugin
    # General plugin problem.  A plugin can raise errors of this type and have the 'message' portion of the error
    # automatically logged, and have the plugin-response set to the same (message) and have the execution end
    class PluginError < StandardError
    end

    # Configuration error detected - usually as a result of the validation method determining bad/invalid data.
    # This is treated same as PluginError for now... but maybe one day it'll get wings and fly, so only raise
    # this error if the plugin cannot execute the task owing to poor parameters.
    class ConfigError < PluginError
    end
  end
end

module Maestro

  # Helper Class for Maestro Plugins written in Ruby. The lifecycle of the plugin
  # starts with a call to the main entry point perform called by the Maestro agent, all the
  # other methods are helpers that can be used to deal with parsing, errors, etc. The lifecycle ends with a call to
  # run_callbacks which can be customized by specifying an on_complete_handler_method, or on_complete_handler_block.
  #
  class MaestroWorker
    # Workitem constants
    CONTEXT_OUTPUTS_META = '__context_outputs__'
    OUTPUT_META = '__output__'
    PREVIOUS_CONTEXT_OUTPUTS_META = '__previous_context_outputs__'
    STREAMING_META = '__streaming__'
    ERROR_META = '__error__'
    WAITING_META = '__waiting__'
    CANCEL_META = '__cancel__'
    NOT_NEEDED = '__not_needed__'
    LINKS_META = '__links__'
    PERSIST_META = '__persist__'
    MODEL_META = '__model__'
    RECORD_ID_META = '__record_id__'
    RECORD_FIELD_META = '__record_field__'
    RECORD_VALUE_META = '__record_value__'
    RECORD_FIELDS_META = '__record_fields__'
    RECORD_VALUES_META = '__record_values__'
    FILTER_META = '__filter__'
    NAME_META = '__name__'
    CREATE_META = '__create__'
    UPDATE_META = '__update__'
    DELETE_META = '__delete__'

    class << self

      attr_reader :exception_handler_method, :exception_handler_block, :on_complete_handler_method, :on_complete_handler_block

      # Register a callback method or block that gets called when an exception
      # occurs during the processing of an action. +handler+ can be a symbol or
      # string with a method name, or a block. Both will get the exception as
      # the first parameter, and the block handler will receive the participant
      # instance as the second parameter
      def on_exception(handler = nil, &block)
        @exception_handler_method = handler
        @exception_handler_block = block
      end

      # Register a callback method or block that gets called when the action
      # was successfully completed. Block callbacks get the workitem as
      # parameter.
      def on_complete(handler = nil, &block)
        @on_complete_handler_method = handler
        @on_complete_handler_block = block
      end

      # Call this to mock calls to outbound systems.
      def mock!
        @mock = true
      end

      # Call this to unmock calls to outbound systems.
      def unmock!
        @mock = false
      end

      def mock?
        @mock
      end

    end

    attr_accessor :workitem, :action

    def is_json?(string)
      JSON.parse string
      true
    rescue Exception
      false
    end

    alias :is_json :is_json?

    # Perform the specified action with the provided workitem. Invokes the method specified by the action parameter.
    #
    def perform(action, workitem)
      @action, @workitem = action, workitem
      send(action)
      write_output('') # Triggers any remaining buffered output to be sent
      run_callbacks
    rescue MaestroDev::Plugin::PluginError => e
      write_output('') # Triggers any remaining buffered output to be sent
      set_error(e.message)
    rescue Exception => e
      write_output('') # Triggers any remaining buffered output to be sent
      lowerstack = e.backtrace.find_index(caller[0])
      stack = lowerstack ? e.backtrace[0..lowerstack - 1] : e.backtrace
      msg = "Unexpected error executing task: #{e.class} #{e} at\n" + stack.join("\n")
      Maestro.log.warn("#{msg}\nFull stack:\n" + e.backtrace.join("\n"))

      # Let user-supplied exception handler do its thing
      handle_exception(e)
      set_error(msg)
    ensure
      # Older agents expected this method to *maybe* return something
      # .. something that no longer exists, but if we return anything
      # it will be *wrong* :P
      return nil
    end

    # Fire supplied exception handlers if supplied, otherwise do nothing
    def handle_exception(e)
      if self.class.exception_handler_method
        send(self.class.exception_handler_method, e)
      elsif self.class.exception_handler_block
        self.class.exception_handler_block.call(e, self)
      end
    end

    def run_callbacks
      return if self.class.on_complete_handler_block.nil? && self.class.on_complete_handler_method.nil?

      if self.class.on_complete_handler_method
        send(self.class.on_complete_handler_method)
      else
        self.class.on_complete_handler_block.call(workitem)
      end
    end

    # Set a value in the context output
    def save_output_value(name, value)
      set_field(CONTEXT_OUTPUTS_META, {}) if get_field(CONTEXT_OUTPUTS_META).nil?
      get_field(CONTEXT_OUTPUTS_META)[name] = value
    end

    # Read a value from the context output
    def read_output_value(name)
      if get_field(PREVIOUS_CONTEXT_OUTPUTS_META).nil?
        set_field(CONTEXT_OUTPUTS_META, {}) if get_field(CONTEXT_OUTPUTS_META).nil?
        get_field(CONTEXT_OUTPUTS_META)[name]
      else
        get_field(PREVIOUS_CONTEXT_OUTPUTS_META)[name]
      end
    end

    # Sends the specified ouput string to the server for persistence
    # If called with :buffer as an option, the output will be queued up until a number of writes has occurred, or
    # a reasonable period since the last sent occurred.
    # Any call without the :buffer option will cause any buffered output to be sent immediately.
    #
    # Example:
    #   write_output("I am Sam\n")                      <-- send immediately
    #   write_output("Sam I am\n", :buffer => true)     <-- buffer for later
    #   write_output("I like Ham\n")                    <-- sends 'Sam I am\nI like Ham\n'
    def write_output(output, options = {})
      # First time thru?  We need to do some setup!
      reset_buffered_output if @buffered_output.nil?

      @buffered_output += output

      # If a) we have data to write, and
      #    b) its been > 2 seconds since we last sent
      #
      # The 2 second factor is there to allow slowly accumulating data to be sent out more regularly.
      if !@buffered_output.empty? && (!options[:buffer] || Time.now - @last_write_output > 2)
        # Ensure the output is json-able.
        # It seems some code doesn't wholly respect encoding rules.  We've found some http responses that
        # don't have the correct encoding, despite the response headers stating 'utf-8', etc.  Same goes
        # for shell output streams, that don't seem to respect the apps encoding.
        # What this code does is to try to json encode the @buffered_output.  First a direct conversion,
        # if that fails, try to force-encoding to utf-8, if that fails, try to remove all chars with
        # code > 127.  If that fails - we gave it a good shot, and maybe just insert a 'redacted' string
        # so at least the task doesn't fail :)
        begin
          @buffered_output.to_json
        rescue Exception => e1
          Maestro.log.warn("Unable to 'to_json' output [#{e1}]: #{@buffered_output}")
          begin
            test = @buffered_output
            test.force_encoding('UTF-8')
            test.to_json
            # If forcing encoding worked, updated buffered_output
            Maestro.log.warn("Had to force encoding to utf-8 for workitem stream")
            @buffered_output = test
          rescue Exception
            begin
              test = @buffered_output.gsub(/[^\x00-\x7f]/, '?')
              test.to_json
              # If worked, updated buffered_output
              Maestro.log.warn("Had to strip top-bit-set chars for workitem stream")
              @buffered_output = test
            rescue Exception
              Maestro.log.warn("Had to redact block of output, unable to 'to_json' it for workitem stream")
              @buffered_output = '?_?'
            end
          end
        end

        if !MaestroWorker.mock?
          workitem[OUTPUT_META] = @buffered_output
        else
          # Test mode, we want to retain output - normal operation clears out
          # data after it is sent
          workitem[OUTPUT_META] = '' if !workitem[OUTPUT_META]
          workitem[OUTPUT_META] = workitem[OUTPUT_META] + @buffered_output
        end

        workitem[STREAMING_META] = true
        send_workitem_message
        reset_buffered_output
      end
    rescue Exception => e
      Maestro.log.warn "Unable To Write Output To Server #{e.class} #{e}: #{e.backtrace.join("\n")}"
    ensure
      workitem.delete(STREAMING_META)
    end

    def reset_buffered_output
      @buffered_output = ''
      @last_write_output = Time.now
    end

    def output
      if MaestroWorker.mock?
        workitem[OUTPUT_META]
      else
        Maestro.log.warn "Output is only accessible when mock is enabled in tests. Otherwise is directly sent to Maestro"
        nil
      end
    end

    def error
      fields[ERROR_META]
    end

    def error?
      !(error.nil? or error.empty?)
    end

    def set_error(error)
      set_field(ERROR_META, error)
    end

    #control

    # Sets the current task as waiting
    def set_waiting(should_wait)
      workitem[WAITING_META] = should_wait
      send_workitem_message
    rescue Exception => e
      Maestro.log.warn "Failed To Send Waiting Message To Server #{e.class} #{e}: #{e.backtrace.join("\n")}"
    ensure
      workitem.delete(WAITING_META) unless should_wait
    end

    # Send the "cancel" message to the server
    def cancel
      workitem[CANCEL_META] = true
      send_workitem_message
    rescue Exception => e
      Maestro.log.warn "Failed To Send Cancel Message To Server #{e.class} #{e}: #{e.backtrace.join("\n")}"
    ensure
      workitem.delete(CANCEL_META)
    end


    # Send the "not needed" message to the server.
    def not_needed
      workitem[NOT_NEEDED] = true
      send_workitem_message
    rescue Exception => e
      Maestro.log.warn "Failed To Send Not Needed Message To Server #{e.class} #{e}: #{e.backtrace.join("\n")}"
    ensure
      workitem.delete(NOT_NEEDED)
    end

    # end control

    # persistence
    def update_fields_in_record(model, name_or_id, record_field, record_value)
      workitem[PERSIST_META] = true
      workitem[UPDATE_META] = true
      workitem[MODEL_META] = model
      workitem[RECORD_ID_META] = name_or_id.to_s
      workitem[RECORD_FIELD_META] = record_field
      workitem[RECORD_VALUE_META] = record_value

      send_workitem_message

      workitem.delete(PERSIST_META)
      workitem.delete(UPDATE_META)
    end


    def create_record_with_fields(model, record_fields, record_values = nil)
      workitem[PERSIST_META] = true
      workitem[CREATE_META] = true
      workitem[MODEL_META] = model
      unless record_fields.is_a? Hash
        Maestro.log.warn 'deprecation: create_record_with_fields should be called with a Hash'
        record_fields = record_fields.join(',') if record_fields.respond_to? 'join'
        record_values = record_values.join(',') if record_values.respond_to? 'join'
      end

      workitem[RECORD_FIELDS_META] = record_fields
      workitem[RECORD_VALUES_META] = record_values
      send_workitem_message

      workitem.delete(PERSIST_META)
      workitem.delete(CREATE_META)
    end


    def delete_record(model, filter)
      workitem[PERSIST_META] = true
      workitem[DELETE_META] = true
      workitem[MODEL_META] = model

      if filter.is_a? Hash
        workitem[FILTER_META] = filter
      else
        Maestro.log.warn 'deprecation: delete_record should be called with a Hash'
        workitem[NAME_META] = filter.to_s
      end

      send_workitem_message

      workitem.delete(PERSIST_META)
      workitem.delete(DELETE_META)
    end

    # end persistence

    # Get a field from workitem, supporting default value
    def get_field(field, default = nil)
      value = fields[field]
      value = default if !default.nil? && (value.nil? || (value.respond_to?(:empty?) && value.empty?))
      value
    end

    # Helper that renders a field as an int
    def get_int_field(field, default = 0)
      as_int(get_field(field), default)
    end

    # Helper that renders a field as a boolean
    def get_boolean_field(field)
      as_boolean(get_field(field))
    end
 
    def fields
      workitem['fields']
    end

    alias_method :get_fields, :fields


    def set_field(field, value)
      fields[field] = value
    end

    # Adds a link to be displayed in the Maestro UI.
    def add_link(name, url)
      set_field(LINKS_META, []) if fields[LINKS_META].nil?
      fields[LINKS_META] << {'name' => name, 'url' => url}
    end

    # Field Utility methods

    # Return numeric version of value
    def as_int(value, default = 0)
      res = default

      if value
        if value.is_a?(Fixnum)
          res = value
        elsif value.respond_to?(:to_i)
          res = value.to_i
        end
      end

      res
    end

    # Return boolean version of a value
    def as_boolean(value)
      res = false

      if value
        if value.is_a?(TrueClass) || value.is_a?(FalseClass)
          res = value
        elsif value.is_a?(Fixnum)
          res = value != 0
        elsif value.respond_to?(:to_s)
          value = value.to_s.downcase

          res = (value == 't' || value == 'true')
        end
      end

      res
    end

    private

    def send_workitem_message
      ruote_participants.send_workitem_message(workitem) unless MaestroWorker.mock?
    end

    def ruote_participants
      Maestro::RuoteParticipants.instance
    end


  end
end
