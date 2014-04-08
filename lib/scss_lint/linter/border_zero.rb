module SCSSLint
  # Reports when `border: 0` can be used instead of `border: none`.
  class Linter::BorderZero < Linter
    include LinterRegistry

    def visit_prop(node)
      return unless BORDER_PROPERTIES.include?(node.name.first.to_s)

      if node.value.to_sass.strip == 'none'
        add_lint(node, '`border: 0;` is preferred over `border: none;`')
      end
    end

    BORDER_PROPERTIES = %w[
      border
      border-top
      border-right
      border-bottom
      border-left
    ]
  end
end
