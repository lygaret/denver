require_relative './data.rb'
require_relative './lexer.rb'
require_relative './tokenizer.rb'

module DenverBS
  class Parser

    def initialize(tokens)
      @tokens = tokens.is_a?(Tokenizer) ? tokens : Tokenizer.new(tokens)
    end

    def each(&)
      return each.each(&) if block_given?

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
        Data::Atom.new(:symbol, v, token)

      in { tag: :number, value: v }
        Data::Atom.new(:number, v, token)

      in { tag: :string, value: v }
        Data::Atom.new(:string, v, token)

      in { tag: :sharp }
        parse_sharp(tokenizer.next, tokenizer, state:)

      in { tag: :quote }
        quote = Data::Atom.new(:symbol, "quote", nil)
        value = parse_expr(tokenizer.next, tokenizer, state: :quoted)
        Data.cons(quote, value, token)

      in { tag: :comma }
        quote = Data::Atom.new(:symbol, "comma", nil)
        value = parse_expr(tokenizer.next, tokenizer, state: :quoted)
        Data.cons(quote, value, token)

      in { tag: :paren_o }
        parse_cons(tokenizer.next, tokenizer, state:)

      else
        "oh no invalid: #{token}"
      end
    end

    def parse_sharp(token, tokenizer, state: nil)
      case state
      when :quoted
        quote = Data::Atom.new(:symbol, "sharp", nil)
        value = parse_expr(token, tokenizer, state:)
        Data.cons(quote, value, token)

      else
        case token
        in { tag: :ident, value: "t" }
          Data.true(token)
        in { tag: :ident, value: "f" }
          Data.false(token)
        else
          quote = Data::Atom.new(:symbol, "sharp", nil)
          value = parse_expr(token, tokenizer, state:)
          Data.cons(quote, value, token)
        end
      end
    end

    def parse_cons(token, tokenizer, state: nil)
      return "oh no invalid" if token.nil?

      # ()
      return Data.null(token) if token.tag == :paren_c

      # otherwise, parse the head as an expr and build a cons list
      car   = parse_expr(token, tokenizer, state:)
      token = tokenizer.next
      return "oh no invalid" if token.nil?

      case token
      in { tag: :paren_c }
        Data.cons(car, Data.null(token), token)

      in { tag: :dot }
        token = tokenizer.next rescue nil
        cdr   = parse_expr(token, tokenizer, state:)

        token = tokenizer.next rescue nil
        case token
        in { tag: paren_c }
          Data.cons(car, cdr, token)
        else
          Data.cons(car, "oh no invalid", token)
        end

      else
        cdr = parse_cons(token, tokenizer, state:)
        Data.cons(car, cdr, token)

      end
    end

  end
end
