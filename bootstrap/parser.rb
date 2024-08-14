require_relative './lexer.rb'
require_relative './tokenizer.rb'

module DenverBS

  class Parser

    Cons = Data.define(:car, :cdr) do
      def to_s(cont: false)
        if cdr.class == Cons
          "#{cont ? "" : "("}#{car.to_s} #{cdr.to_s(cont: true)}"

        elsif cdr == Null
          "#{cont ? "" : "("}#{car.to_s})"

        else
          "#{cont ? "" : "("}#{car.to_s} . #{cdr.to_s})"
        end
      end
    end

    Atom = Data.define(:tag, :value, :token) do
      def to_s
        case tag
        when :null
          "()"
        else
          "#{tag.to_s}|#{value.inspect}"
        end
      end
    end

    True  = Atom.new(:true, true, nil)
    False = Atom.new(:false, false, nil)
    Null  = Atom.new(:null, nil, nil)

    def initialize(tokens)
      @tokens = tokens.is_a?(Tokenizer) ? tokens : Tokenizer.new(tokens)
    end

    def each
      Enumerator.new do |yielder|
        # ignore comments and whitespace
        tokens = @tokens.each.lazy.reject do |token|
          token.tag == :comment or token.tag == :ws or token.tag == :eol
        end

        # otherwise, parse each token as an expression
        tokens.each do |token|
          yielder << parse_expr(token, tokens)
        end
      end
    end

    def parse_expr(token, tokenizer, state: nil)
      return nil if token.nil?

      case token
      in { tag: :ident, value: v }
        Atom.new(:symbol, v, token)

      in { tag: :number, value: v }
        Atom.new(:number, v, token)

      in { tag: :string, value: v }
        Atom.new(:string, v, token)

      in { tag: :sharp }
        parse_sharp(tokenizer.next, tokenizer, state:)

      in { tag: :quote }
        quote = Atom.new(:symbol, "quote", nil)
        value = parse_expr(tokenizer.next, tokenizer, state: :quoted)
        Cons.new(quote, value)

      in { tag: :comma }
        quote = Atom.new(:symbol, "comma", nil)
        value = parse_expr(tokenizer.next, tokenizer, state: :quoted)
        Cons.new(quote, value)

      in { tag: :paren_o }
        parse_cons(tokenizer.next, tokenizer, state:)

      else
        "oh no invalid: #{token}"
      end
    end

    def parse_sharp(token, tokenizer, state: nil)
      case state
      when :quoted
        quote = Atom.new(:symbol, "sharp", nil)
        value = parse_expr(token, tokenizer, state:)
        Cons.new(quote, value)

      else
        case token
        in { tag: :ident, value: "t" }
          True
        in { tag: :ident, value: "f" }
          False
        else
          quote = Atom.new(:symbol, "sharp", nil)
          value = parse_expr(token, tokenizer, state:)
          Cons.new(quote, value)
        end
      end
    end

    def parse_cons(token, tokenizer, state: nil)
      return "oh no invalid" if token.nil?

      # ()
      return Null if token.tag == :paren_c

      # otherwise, parse the head as an expr and build a cons list
      car   = parse_expr(token, tokenizer, state:)
      token = tokenizer.next
      return "oh no invalid" if token.nil?

      case token
      in { tag: :paren_c }
        Cons.new(car, Null)

      in { tag: :dot }
        token = tokenizer.next rescue nil
        cdr   = parse_expr(token, tokenizer, state:)

        token = tokenizer.next rescue nil
        case token
        in { tag: paren_c }
          Cons.new(car, cdr)
        else
          puts "expected paren_c, got: #{token}"
          Cons.new(car, "oh no invalid")
        end

      else
        cdr = parse_cons(token, tokenizer, state:)
        Cons.new(car, cdr)

      end
    end

  end
end
