module SCSSLint
  # Checks for a property declared twice in a rule set.
  class Linter::DuplicateProperty < Linter
    include LinterRegistry

    def visit_rule(node)
      properties = node.children
                       .select { |child| child.is_a?(Sass::Tree::PropNode) }
                       .reject { |prop| prop.name.any? { |item| item.is_a?(Sass::Script::Node) } }

      prop_names = {}

      properties.each do |prop|
        name = prop.name.join

        prop_hash = name
        prop_value = prop.value.is_a?(Sass::Script::Funcall)? prop.value.name : prop.value.value

        prop_value.to_s.scan(/^([\-ms\-|\-o\-|\-moz\-|\-webkit\-].+)/) do |vendor_keyword|
          prop_hash << vendor_keyword.first
        end

        if existing_prop = prop_names[prop_hash]
          add_lint(prop, "Property '#{name}' already defined on line #{existing_prop.line}")
        else
          prop_names[prop_hash] = prop
        end
      end
    end
  end
end
