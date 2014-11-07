require 'find'
require 'optparse'
require 'rainbow'
require 'rainbow/ext/string'

module SCSSLint
  # Responsible for parsing command-line options and executing the appropriate
  # application logic based on the options specified.
  class CLI
    attr_reader :config, :options

    # Subset of semantic exit codes conforming to `sysexits` documentation.
    EXIT_CODES = {
      ok:        0,
      warning:   1,  # One or more warnings (but no errors) were reported
      error:     2,  # One or more errors were reported
      usage:     64, # Command line usage error
      no_input:  66, # Input file did not exist or was not readable
      software:  70, # Internal software error
      config:    78, # Configuration error
    }

    DEFAULT_REPORTER = [SCSSLint::Reporter::DefaultReporter, :stdout]

    # @param args [Array]
    def initialize(args = [])
      @args    = args
      @options = { reporters: [DEFAULT_REPORTER] }
      @config  = Config.default
    end

    def parse_arguments
      begin
        options_parser.parse!(@args)

        # Take the rest of the arguments as files/directories

        if @args.empty?
          @options[:files] = @config.scss_files
        else
          @options[:files] = @args
        end

      rescue OptionParser::InvalidOption => ex
        print_help options_parser.help, ex
      end

      begin
        setup_configuration
      rescue InvalidConfiguration, NoSuchLinter => ex
        puts ex.message
        halt :config
      end
    end

    # @return [OptionParser]
    def options_parser # rubocop:disable MethodLength
      @options_parser ||= OptionParser.new do |opts|
        opts.banner = "Usage: #{opts.program_name} [options] [scss-files]"

        opts.separator ''
        opts.separator 'Common options:'

        opts.on('-c', '--config file', 'Specify configuration file', String) do |file|
          @options[:config_file] = file
        end

        opts.on('-e', '--exclude file,...', Array,
                'List of file names to exclude') do |files|
          @options[:excluded_files] = files
        end

        opts.on('-f', '--format Formatter', 'Specify how to display lints', String) do |format|
          define_output_format(format)
        end

        opts.on('-o', '--out path', 'Write output to a file instead of STDOUT', String) do |path|
          define_output_path(path)
        end

        opts.on('-r', '--require path', 'Require Ruby file', String) do |path|
          require path
        end

        opts.on_tail('--show-formatters', 'Shows available formatters') do
          print_formatters
        end

        opts.on('-i', '--include-linter linter,...', Array,
                'Specify which linters you want to run') do |linters|
          @options[:included_linters] = linters
        end

        opts.on('-x', '--exclude-linter linter,...', Array,
                "Specify which linters you don't want to run") do |linters|
          @options[:excluded_linters] = linters
        end

        opts.on_tail('--show-linters', 'Shows available linters') do
          print_linters
        end

        opts.on_tail('-h', '--help', 'Show this message') do
          print_help opts.help
        end

        opts.on_tail('-v', '--version', 'Show version') do
          print_version opts.program_name, VERSION
        end
      end
    end

    def run # rubocop:disable MethodLength
      runner = Runner.new(@config)
      runner.run(files_to_lint)
      report_lints(runner.lints)

      if runner.lints.any?(&:error?)
        halt :error
      elsif runner.lints.any?
        halt :warning
      end
    rescue InvalidConfiguration => ex
      puts ex
      halt :config
    rescue NoFilesError, Errno::ENOENT => ex
      puts ex.message
      halt :no_input
    rescue NoSuchLinter => ex
      puts ex.message
      halt :usage
    rescue => ex
      puts ex.message
      puts ex.backtrace
      puts 'Report this bug at '.color(:yellow) + BUG_REPORT_URL.color(:cyan)
      halt :software
    end

  private

    def setup_configuration
      if @options[:config_file]
        @config = Config.load(@options[:config_file])
        @config.preferred = true
      end

      merge_command_line_flags_with_config(@config)
    end

    # @param config [Config]
    # @return [Config]
    def merge_command_line_flags_with_config(config)
      if @options[:excluded_files]
        @options[:excluded_files].each do |file|
          config.exclude_file(file)
        end
      end

      if @options[:included_linters]
        config.disable_all_linters
        LinterRegistry.extract_linters_from(@options[:included_linters]).each do |linter|
          config.enable_linter(linter)
        end
      end

      if @options[:excluded_linters]
        LinterRegistry.extract_linters_from(@options[:excluded_linters]).each do |linter|
          config.disable_linter(linter)
        end
      end

      config
    end

    def files_to_lint
      extract_files_from(@options[:files]).reject do |file|
        config =
          if !@config.preferred && (config_for_file = Config.for_file(file))
            merge_command_line_flags_with_config(config_for_file.dup)
          else
            @config
          end

        config.excluded_file?(file)
      end
    end

    # @param list [Array]
    def extract_files_from(list)
      files = []
      list.each do |file|
        Find.find(file) do |f|
          files << f if scssish_file?(f)
        end
      end
      files.uniq
    end

    VALID_EXTENSIONS = %w[.css .scss]
    # @param file [String]
    # @return [Boolean]
    def scssish_file?(file)
      return false unless FileTest.file?(file)

      VALID_EXTENSIONS.include?(File.extname(file))
    end

    # @param lints [Array<Lint>]
    def report_lints(lints)
      sorted_lints = lints.sort_by { |l| [l.filename, l.location] }
      @options.fetch(:reporters).each do |reporter, output|
        results = reporter.new(sorted_lints).report_lints
        io = (output == :stdout ? $stdout : File.new(output, 'w+'))
        io.print results if results
      end
    end

    # @param format [String]
    def define_output_format(format)
      unless @options[:reporters] == [DEFAULT_REPORTER] && format == 'Default'
        @options[:reporters].reject! { |i| i == DEFAULT_REPORTER }
        reporter = SCSSLint::Reporter.const_get(format + 'Reporter')
        @options[:reporters] << [reporter, :stdout]
      end
    rescue NameError
      puts "Invalid output format specified: #{format}"
      halt :config
    end

    # @param path [String]
    def define_output_path(path)
      last_reporter, _output = @options[:reporters].pop
      @options[:reporters] << [last_reporter, path]
    end

    def print_formatters
      puts 'Installed formatters:'

      reporter_names = SCSSLint::Reporter.descendants.map do |reporter|
        reporter.name.split('::').last.split('Reporter').first
      end

      reporter_names.sort.each do |reporter_name|
        puts " - #{reporter_name}"
      end

      halt
    end

    def print_linters
      puts 'Installed linters:'

      linter_names = LinterRegistry.linters.map do |linter|
        linter.name.split('::').last
      end

      linter_names.sort.each do |linter_name|
        puts " - #{linter_name}"
      end

      halt
    end

    # @param help_message [String]
    # @param err [Exception]
    def print_help(help_message, err = nil)
      puts err, '' if err
      puts help_message
      halt(err ? :usage : :ok)
    end

    # @param program_name [String]
    # @param version [String]
    def print_version(program_name, version)
      puts "#{program_name} #{version}"
      halt
    end

    # Used for ease-of testing
    # @param exit_status [Symbol]
    def halt(exit_status = :ok)
      exit(EXIT_CODES[exit_status])
    end
  end
end
