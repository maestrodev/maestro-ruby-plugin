require 'json'

module Maestro
  class MaestroWorker

    class << self

      attr_reader :exception_handler_method, :exception_handler_block, :on_complete_handler_method, :on_complete_handler_block

      # Register a callback method or block that gets called when an exception
      # occurs during the processing of an action. +handler+ can be a symbol or
      # string with a method name, or a block. Both will get the exception as
      # the first parameter, and the block handler will receive the participant
      # instance as the second parameter
      def on_exception( handler = nil, &block )
        @exception_handler_method = handler
        @exception_handler_block = block
      end

      # Register a callback method or block that gets called when the action
      # was successfully completed. Block callbacks get the workitem as
      # parameter.
      def on_complete( handler = nil, &block )
        @on_complete_handler_method = handler
        @on_complete_handler_block = block
      end
    end

    attr_accessor :workitem, :action

    def send_workitem_message
      Maestro::RuoteParticipants.send_workitem_message(workitem)
    end

    def is_json(string)
      begin
        JSON.parse string
        return true
      rescue Exception
        return false
      end
    end

    # Perform the specified action with the provided workitem
    def perform( action, workitem)
      @action, @workitem = action, workitem

      begin
        send( action )
        run_callbacks
      rescue => e
        handle_exception( e )
      end
    end

    def handle_exception( e )
      raise e if self.class.exception_handler_method.nil? && self.class.exception_handler_block.nil?

      if self.class.exception_handler_method
        send( self.class.exception_handler_method, e )
      else
        self.class.exception_handler_block.call( e, self )
      end
    end

    def run_callbacks
      return if self.class.on_complete_handler_block.nil? && self.class.on_complete_handler_method.nil?

      if self.class.on_complete_handler_method
        send( self.class.on_complete_handler_method )
      else
        self.class.on_complete_handler_block.call( workitem )
      end
    end
    
    #output
    def save_output_value(name, value)
      set_field('__context_outputs__', {}) if get_field('__context_outputs__').nil?
      get_field('__context_outputs__')[name] = value
    end
    
    def read_output_value(name)
      if get_field('__previous_context_outputs__').nil?
        set_field('__context_outputs__', {}) if get_field('__context_outputs__').nil?
        get_field('__context_outputs__')[name]
      else
        get_field('__previous_context_outputs__')[name]
      end
    end
    
    def write_output(output)
      return if output.gsub(/\n/, '').empty?

      workitem['__output__'] = output
      workitem['__streaming__'] = true

      begin
        send_workitem_message
      rescue Exception => e
        Maestro.log.warn "Unable To Write Output To Server #{e.class} #{e}: #{e.backtrace.join("\n")}"
      end
      workitem.delete('__streaming__')
    end
    
    def error
      fields['__error__']
    end
    def error?
      !(error.nil? or error.empty?)
    end
    def set_error(error)
      set_field('__error__', error)
    end
    
    # end output
    
    #control
    
    def set_waiting(should_wait)
      workitem['__waiting__'] = should_wait
      begin
        send_workitem_message
      rescue Exception => e
        Maestro.log.warn "Failed To Send Waiting Message To Server #{e.class} #{e}: #{e.backtrace.join("\n")}"
      end
      workitem.delete('__waiting__') unless should_wait
    end
        
    def cancel
      workitem['__cancel__'] = true
      begin
        send_workitem_message
      rescue Exception => e
        Maestro.log.warn "Failed To Send Cancel Message To Server #{e.class} #{e}: #{e.backtrace.join("\n")}"
      end
      workitem.delete('__cancel__')
    end

    def not_needed
      workitem['__not_needed__'] = true
      begin
        send_workitem_message
      rescue Exception => e
        Maestro.log.warn "Failed To Send Not Needed Message To Server #{e.class} #{e}: #{e.backtrace.join("\n")}"
      end
      workitem.delete('__not_needed__')
    end
    # end control
    
    # persistence
    def update_fields_in_record(model, name_or_id, record_field, record_value)
      workitem['__persist__'] = true
      workitem['__update__'] = true
      workitem['__model__'] = model
      workitem['__record_id__'] = name_or_id.to_s
      workitem['__record_field__'] = record_field
      workitem['__record_value__'] = record_value
      
      send_workitem_message
      
      workitem.delete('__persist__')
      workitem.delete('__update__')
    end
    
    def create_record_with_fields(model, record_fields, record_values = nil)
      workitem['__persist__'] = true
      workitem['__create__'] = true
      workitem['__model__'] = model
      unless record_fields.is_a? Hash
        Maestro.log.warn 'deprecation: create_record_with_fields should be called with a Hash'
        record_fields = record_fields.join(',') if record_fields.respond_to? 'join'
        record_values = record_values.join(',') if record_values.respond_to? 'join'
      end
      
      workitem['__record_fields__'] = record_fields
      workitem['__record_values__'] = record_values
      send_workitem_message
      
      workitem.delete('__persist__')
      workitem.delete('__create__')
    end
    
    def delete_record(model, filter)
      workitem['__persist__'] = true
      workitem['__delete__'] = true
      workitem['__model__'] = model

      if filter.is_a? Hash
        workitem['__filter__'] = filter
      else
        Maestro.log.warn 'deprecation: delete_record should be called with a Hash'
        workitem['__name__'] = filter.to_s
      end
      
      send_workitem_message
      
      workitem.delete('__persist__')
      workitem.delete('__delete__')
    end
    
    # end persistence
    
    def get_field(field)
      fields[field]
    end
    
    
    def fields
      workitem['fields']
    end
    alias_method :get_fields, :fields
    
    
    def set_field(field, value)
      fields[field] = value
    end

    def add_link(name, url)
      set_field('__links__', []) if fields['__links__'].nil?
      fields['__links__'] << {'name' => name, 'url' => url}
    end

  end
end
