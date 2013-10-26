module Sass::Script
  # Redefine some of the lexer helpers in order to store the original string
  # with the created object so that the original string can be inspected rather
  # than a typically normalized version.
  class Lexer
    def color
      return unless color_string = scan(REGULAR_EXPRESSIONS[:color])

      unless [4, 7].include?(color_string.length)
        raise ::Sass::SyntaxError,
              "Colors must have either three or six digits: '#{color_string}'"
      end

      [:color, Value::Color.from_string(color_string)]
    end

    def number
      return unless scan(REGULAR_EXPRESSIONS[:number])
      value = @scanner[2] ? @scanner[2].to_f : @scanner[3].to_i
      value = -value if @scanner[1]

      number = Value::Number.new(value, Array(@scanner[4])).tap do |num|
        num.original_string = @scanner[0]
      end
      [:number, number]
    end
  end

  class Parser
    # We redefine the ident parser to specially handle color keywords.
    def ident
      return funcall unless @lexer.peek && @lexer.peek.type == :ident
      return if @stop_at && @stop_at.include?(@lexer.peek.value)

      name = @lexer.next
      if (color = Value::Color::COLOR_NAMES[name.value.downcase])
        return literal_node(Value::Color.from_string(name.value, color), name.source_range)
      end
      literal_node(Value::String.new(name.value, :identifier), name.source_range)
    end
  end

  class Value::Base
    attr_accessor :node_parent

    def children
      []
    end

    def line
      @line || (node_parent && node_parent.line)
    end

    def source_range
      @source_range || (node_parent && node_parent.source_range)
    end
  end

  # When linting colors, it's convenient to be able to inspect the original
  # color string. This adds an attribute to the Color to keep track of the
  # original string and provides a method which the modified lexer can use to
  # set it.
  class Value::Color
    attr_accessor :original_string

    def self.from_string(string, rgb = nil)
      unless rgb
        rgb = string.scan(/^#(..?)(..?)(..?)$/).
                     first.
                     map { |hex| hex.ljust(2, hex).to_i(16) }
      end

      color = new(rgb, false)
      color.original_string = string
      color
    end
  end

  class Value::Number
    attr_accessor :original_string
  end

  # Contains extensions of Sass::Script::Tree::Nodes to add support for
  # accessing various parts of the parse tree not provided out-of-the-box.
  module Tree
    class Node
      attr_accessor :node_parent
    end

    class Literal
      # Literals wrap their underlying values. For sake of convenience, consider
      # the wrapped value a child of the Literal.
      def children
        [value]
      end
    end
  end
end
