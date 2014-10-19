module SCSSLint
  # Checks the order of nested items within a rule set.
  class Linter::DeclarationOrder < Linter
    include LinterRegistry

    def visit_rule(node)
      check_node(node)
      yield # Continue linting children
    end

  private

    MESSAGE =
      'Rule sets should be ordered as follows: '\
      '@extends, @includes without @content, ' \
      'properties, @includes with @content, ' \
      'nested rule sets'

    MIXIN_WITH_CONTENT = 'mixin_with_content'

    DECLARATION_ORDER = [
      Sass::Tree::ExtendNode,
      Sass::Tree::MixinNode,
      Sass::Tree::PropNode,
      MIXIN_WITH_CONTENT,
      Sass::Tree::RuleNode,
    ]

    def important_node?(node)
      DECLARATION_ORDER.include? node.class
    end

    def check_node(node)
      children = node.children.select { |n| important_node?(n) }
                              .map { |n| check_for_children(n) }

      sorted_children = children.sort do |a, b|
        DECLARATION_ORDER.index(a) <=> DECLARATION_ORDER.index(b)
      end

      return unless children != sorted_children
      add_lint(node.children.first, MESSAGE)
    end

    def check_for_children(node)
      # If the node has no children, return the class.
      return node.class unless node.has_children
      # Check the node's children just as the node is checked.
      check_node(node)
      # If the node is a mixin with children, indicate that;
      # otherwise, just return the class.
      return node.class unless node.is_a?(Sass::Tree::MixinNode)
      MIXIN_WITH_CONTENT
    end
  end
end
