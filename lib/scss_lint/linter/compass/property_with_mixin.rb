module SCSSLint
  # Checks for uses of properties where a Compass mixin would be preferred.
  class Linter::Compass::PropertyWithMixin < Linter::Compass
    include LinterRegistry

    def visit_prop(node)
      prop_name = node.name.join

      if PROPERTIES_WITH_MIXINS.include?(prop_name)
        add_lint node, "Use the Compass `#{prop_name}` mixin instead of the property"
      end
    end

    # Set of properties where the Compass mixin version is preferred
    PROPERTIES_WITH_MIXINS = %w[
      background-clip
      background-origin
      border-radius
      box-shadow
      box-sizing
      opacity
      text-shadow
      transform
    ].to_set
  end
end
