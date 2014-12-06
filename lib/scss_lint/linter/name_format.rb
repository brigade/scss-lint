module SCSSLint
  # Checks that the declared names of functions, mixins, and variables are all
  # lowercase and use hyphens instead of underscores.
  class Linter::NameFormat < Linter
    include LinterRegistry

    def visit_extend(node)
      check_placeholder(node)
    end

    def visit_function(node)
      check_name(node, 'function')
      yield # Continue into content block of this function definition
    end

    def visit_mixin(node)
      check_name(node, 'mixin') unless FUNCTION_WHITELIST.include?(node.name)
      yield # Continue into content block of this mixin's block
    end

    def visit_mixindef(node)
      check_name(node, 'mixin')
      yield # Continue into content block of this mixin definition
    end

    def visit_script_funcall(node)
      check_name(node, 'function') unless FUNCTION_WHITELIST.include?(node.name)
    end

    def visit_script_variable(node)
      check_name(node, 'variable')
    end

    def visit_variable(node)
      check_name(node, 'variable')
      yield # Continue into expression tree for this variable definition
    end

  private

    FUNCTION_WHITELIST = %w[
      rotateX rotateY rotateZ
      scaleX scaleY scaleZ
      skewX skewY
      translateX translateY translateZ
    ].to_set

    def check_name(node, node_type, node_text = node.name)
      return unless violation = violated_convention(node_text)

      add_lint(node, "Name of #{node_type} `#{node_text}` should be " \
                     "written #{violation[:explanation]}")
    end

    def check_placeholder(node)
      extract_string_selectors(node.selector).any? do |selector_str|
        check_name(node, 'placeholder', selector_str.gsub('%', ''))
      end
    end

    CONVENTIONS = {
      'hyphenated_lowercase' => {
        explanation: 'in all lowercase letters with hyphens instead of underscores',
        validator: ->(name) { name !~ /[_A-Z]/ },
      },
      'leading_underscore' => {
        explanation: 'hyphenated_lowercase with leading underscores permitted',
        validator: ->(name) { name !~ /[^_][_A-Z]/ },
      },
      'BEM' => {
        explanation: 'in BEM (Block Element Modifier) format',
        validator: ->(name) { name !~ /[A-Z]|-{3}|_{3}|[^_]_[^_]/ },
      },
    }

    # Checks the given name and returns the violated convention if it failed.
    def violated_convention(name_string)
      convention_name = config['convention'] || 'hyphenated_lowercase'

      convention = CONVENTIONS[convention_name] || {
        explanation: "must match regex /#{convention_name}/",
        validator: ->(name) { name =~ /#{convention_name}/ }
      }

      convention unless convention[:validator].call(name_string)
    end
  end
end
