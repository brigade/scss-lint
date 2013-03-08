require 'find'

module SCSSLint
  autoload :Engine, 'scss_lint/engine'
  autoload :Lint, 'scss_lint/lint'
  autoload :LinterRegistry, 'scss_lint/linter_registry'
  autoload :Linter, 'scss_lint/linter'
  autoload :Runner, 'scss_lint/runner'
  autoload :CLI, 'scss_lint/cli'

  # Load all linters
  Dir[File.expand_path('scss_lint/linter/*.rb', File.dirname(__FILE__))].each do |file|
    require file
  end

  class << self
    def extract_files_from(list, exclude)
      files = []
      list.each do |file|
        Find.find(file) do |f|
          fn = File.basename(f)
          files << f if scssish_file?(f) and not exclude.include?(fn)
        end
      end
      files.uniq
    end

  private

    VALID_EXTENSIONS = %w[.css .scss]
    def scssish_file?(file)
      return false unless FileTest.file?(file)

      VALID_EXTENSIONS.include?(File.extname(file))
    end
  end
end
