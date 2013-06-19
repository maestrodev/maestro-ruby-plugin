# Copyright 2011© MaestroDev.  All rights reserved.

require 'open3'
require 'tempfile'
require 'rbconfig'

begin
  require File.expand_path(File.join(MAESTRO_AGENT_ROOT, 'jars', 'commons-exec-1.1.jar'))
rescue Exception => e
  Maestro.log.error "Failed To Load commons-exec-1.1.jar for Shell executions: #{e.class} #{e}: #{e.backtrace.join("\n")}"
end

CommandLine = org.apache.commons.exec.CommandLine
Executor = org.apache.commons.exec.DefaultExecutor
PumpStreamHandler = org.apache.commons.exec.PumpStreamHandler
DefaultExecuteResultHandler = org.apache.commons.exec.DefaultExecuteResultHandler
FileOutputStream = java.io.FileOutputStream
EnvironmentUtils = org.apache.commons.exec.environment.EnvironmentUtils



module Maestro
  module Util
    class Shell

      attr_accessor :file
      attr_accessor :shell
      attr_accessor :exit_code

      class ExitCode
        attr_accessor :exit_code

        def initialize(exit_code)
          @exit_code = exit_code
        end

        def success?
          @exit_code == 0
        end
      end

      SEPARATOR = RbConfig::CONFIG['host_os'] =~ /mswin/ ? "\\" : "/"

      def Shell.windows?
        RbConfig::CONFIG['host_os'] =~ /mswin/
      end

      def Shell.move_command
        if(RbConfig::CONFIG['host_os'] =~ /mswin/)
          "move"
        else
          "mv"
        end
      end

      def Shell.environment_export_command
        if(RbConfig::CONFIG['host_os'] =~ /mswin/)
          "set"
        else
          "export"
        end
      end

      def Shell.command_separator
        if(RbConfig::CONFIG['host_os'] =~ /mswin/)
          "&&"
        else
          "&&"
        end
      end

      def Shell.command_seperator
        Maestro.log.info("command_seperator is deprecated, use command_separator")
        Shell.command_separator
      end

      def Shell.run_command(command)
        shell = Shell.new
        shell.create_script(command)
        shell.run_script
        return shell.exit_code, shell.to_s
      end

      def initialize(path = nil, shell = "", output_file = nil)
        if !path.nil? || !output_file.nil?
          Maestro.log.warn("Maestro::Shell path, shell and output_file parameters are deprecated. Use Shell.file to get the temporary path of the script created")
        end
        if(RbConfig::CONFIG['host_os'] =~ /mswin/)
          @shell = ''
          @script_extension = '.bat'
        else
          @shell = 'bash '
          @script_extension = '.shell'
        end

        clean_files
      end

      def clean_files
        FileUtils.rm @file.path if !@file.nil? && File.exists?(@file.path)
        FileUtils.rm @output_file.path if !@output_file.nil? && File.exists?(@output_file.path)
        @output = ''
      end

      def create_script(contents)
        raise "Script Cannot Be Empty" if contents.nil? or contents.empty?

        @script_file = Tempfile.new(["script",@script_extension])
        @script_file.write(contents)
        @script_file.close
        Maestro.log.debug "Writing Script File To #{@script_file.path}"
        @commandLine = CommandLine.parse("#{@shell}#{@script_file.path}")
      end

      def run_script
        run_script_with_delegate(nil, nil)
      end

      def run_script_with_delegate(delegate, on_output, interval = 5)
        handler, exe = executor

        # Run any commands in the default system Ruby environment, rather
        # than the one the agent is currently using (which within the wrapper,
        # sets clean values for these to avoid RVM or System gems that might
        # conflict). If the caller needs a specific Ruby environment, it should
        # establish that itself (as the rake task does through rvm if chosen)
        env = EnvironmentUtils.getProcEnvironment()
        env.remove('GEM_HOME')
        env.remove('GEM_PATH')
        exe.execute(@commandLine, env, handler)

        File.open(@output_file.path, "r") do |io|
          while(!handler.hasResult())
            handler.waitFor(interval*1000)
            read_io(io, delegate, on_output)
          end
          File.open(@output_file.path, "a") do |file|
            file.write(handler.getException().getMessage())
          end unless handler.getExitValue == 0

          read_io(io, delegate, on_output, nil)
        end

        @exit_code = ExitCode.new(handler.getExitValue())
      end

      def to_s
        @output_file.read
      end
      alias :output :to_s

      private

      def read_io(io, delegate, on_output, available = nil)
        string = io.read(available)
        unless(string.nil?)
           delegate.send(on_output, string) unless delegate.nil?
        end
      end

      def executor
        @output_file = Tempfile.new(["shell_output.log",".log"])
        Maestro.log.debug "Writing Script Output To #{@output_file.path}"
        exe = Executor.new()
        fileOutputStream = FileOutputStream.new(java.io.File.new(@output_file.path))
        streamHandler =  PumpStreamHandler.new(fileOutputStream)
        exe.setStreamHandler(streamHandler)

        handler = DefaultExecuteResultHandler.new()
        return handler, exe
      end
    end
  end
end
