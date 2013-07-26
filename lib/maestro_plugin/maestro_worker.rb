require 'json'

module Maestro


  # Helper Class for Maestro Plugins written in Ruby. The lifecycle of the plugin
  # starts with a call to the main entry point perform called by the Maestro agent, all the
  # other methods are helpers that can be used to deal with parsing, errors, etc. The lifecycle ends with a call to
  # run_callbacks which can be customized by specifying an on_complete_handler_method, or on_complete_handler_block.
  #
  class MaestroWorker
    # General plugin problem.  A plugin can raise errors of this type and have the 'message' portion of the error
    # automatically logged, and have the plugin-response set to the same (message) and have the execution end
    class PluginError < StandardError
    end

    # Configuration error detected - usually as a result of the validation method determining bad/invalid data.
    # This is treated same as PluginError for now... but maybe one day it'll get wings and fly, so only raise
    # this error if the plugin cannot execute the task owing to poor parameters.
    class ConfigError < PluginError
    end

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
      run_callbacks
    rescue PluginError => e
      # Ensure error is written to output file
      write_output(e.message)
      set_error(e.message)
    rescue Exception => e
      msg = "Unexpected error executing task: #{e.class} #{e}"
      write_output(msg)
      Maestro.log.warn("#{msg} " + e.backtrace.join("\n"))

      # Let user-supplied exception handler do its thing
      handle_exception(e)
      set_error(msg)
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

    private

    def send_workitem_message
      ruote_participants.send_workitem_message(workitem) unless MaestroWorker.mock?
    end

    def ruote_participants
      Maestro::RuoteParticipants.instance
    end


  end
end
