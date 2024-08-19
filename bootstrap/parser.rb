# frozen_string_literal: true

require_relative 'data'
require_relative 'lexer'
require_relative 'tokenizer'

module DenverBS
  class Parser
    def initialize(tokens)
      @source = tokens.is_a?(Tokenizer) ? tokens : Tokenizer.new(tokens)
    end

    def each(&)
      return each.each(&) if block_given?

      Enumerator.new do |yielder|
        @source.rewind
        @tokens = @source.each
        @token  = @tokens.next

        while skip_over_wsc!
          yielder << parse_expr(state: :top)
          next_token!
        end
      end
    end

    private

    # token advances always
    def next_token!
      @token = @tokens.next
    rescue StopIteration
      @token = nil
    end

    # token advances only if it's currently one of the given tags
    def skip_over!(*tags)
      next_token! while tags.include?(@token&.tag)
      @token
    end

    # token advances if it's ws, eol or comment
    def skip_over_wsc! = skip_over!(:ws, :eol, :comment)

    # pull an expression out from the current token on
    def parse_expr(state:)
      case skip_over_wsc!

      in { tag: :paren_o }
        next_token!
        parse_cons(state:)

      in { tag: :quote } |
        { tag: :quasiquote } |
        { tag: :unquote } |
        { tag: :unquote_splice }
        quote = Data.symbol(@token.tag.to_s, @token)

        next_token!
        value = parse_expr(state: @token&.tag&.to_s)
        Data.cons(quote, value, @token)

      in { tag: :sharp }
        parse_sharp(state:)

      in { tag: :ident, value: v }
        Data::Atom.new(:symbol, v, nil, @token)

      in { tag: :number, value: v }
        Data::Atom.new(:number, v, nil, @token)

      in { tag: :string, value: v }
        Data::Atom.new(:string, v, nil, @token)

      end
    end

    def parse_cons(state:)
      case skip_over_wsc!
      in { tag: :paren_c }
        Data.null(@token)

      else
        car = parse_expr(state:)

        next_token!
        case skip_over_wsc!
        in { tag: :paren_c }
          Data.cons(car, Data.null(@token), @token)

        in { tag: :dot }
          next_token!
          cdr = parse_expr(state:)

          next_token!
          case skip_over_wsc!
          in { tag: :paren_c }
            Data.cons(car, cdr, @token)
          else
            Data.error('expected end of dotted pair', @token)
          end

        else
          cdr = parse_cons(state:)
          Data.cons(car, cdr, @token)

        end
      end
    end

    def parse_sharp(state: nil)
      case state
      when :quoted
        quote = Data.symbol('sharp', @token)

        next_token!
        value = parse_expr(state:)
        Data.cons(quote, value, @token)

      else
        next_token!
        case @token
        in { tag: :ident, value: 't' }
          Data.true(@token)
        in { tag: :ident, value: 'f' }
          Data.false(@token)
        else
          quote = Data.symbol('sharp', nil)
          value = parse_expr(state:)
          Data.cons(quote, value, @token)
        end
      end
    end
  end
end
