require_relative './lexer.rb'

module DenverBS

  # generates a stream of tokens out of an input stream
  #
  # @see Lexer
  # @example
  #
  # tok = Tokenizer.tokenize("(some input)")
  # tok.next #=> <Token tag:paren_o>
  # tok.next #=> <Token tag:ident value:"some">
  # tok.next #=> <Token tag:ws>
  # tok.next #=> <Token tag:ident value:"input">
  # tok.next #=> <Token tag:paren_c>
  # tok.next #=> StopIteration error
  class Tokenizer

    NEWLINE       = /^\n/
    WHITESPACE    = /^\p{Zs}/

    DIGITS_BASE2  = /^[0-1]/
    DIGITS_BASE10 = /^[0-9]/
    DIGITS_BASE16 = /^[0-9a-fA-F]/

    IDENT_START   = /^\p{IDS}|[-!$%@&<=>?~_+\\*^]/
    IDENT_CONT    = /^\p{IDC}|[\/:#]/

    SYMBOL_TOKENS = {
      '('  => :paren_o,
      ')'  => :paren_c,
      '`'  => :quasiquote,
      '\'' => :quote,
      '#'  => :sharp,
      '.'  => :dot
    }

    # a single token produced by the Tokenizer
    #
    # @param tag [Symbol] the tag for a token, eg. `:string`, `:identifier`, etc.
    # @param value [any] the value of the token; eg. numbers have already been parsed
    # @param slice [String] the slice out of the input represented by this token
    # @param pos [Number] the position in the input slice of this token
    # @param line [Number] the line number of the token
    # @param point [Number] the point offset on the given line for the token
    Token = Data.define(:tag, :value, :slice, :pos, :line, :point)

    # @private
    # simple cursor to track line numbers and points
    Cursor = Struct.new(:line, :point) do
      def clone = Cursor.new(*deconstruct)

      def newline!
        self.line += 1
        self.point = 0
      end

      def right!(amount)
        self.point += amount
      end
    end

    attr_reader :input

    def initialize(input)
      @input = input.is_a?(Lexer) ? input : Lexer.new(input)
    end

    # allow rewinding the iterator
    def rewind = @input.rewind

    # tokenize the input
    # this can't be rerun without resetting the input
    #
    # @param line [number] the line number we're starting from
    # @param point [number] the line offset we're starting from
    # @return an enumerator of tokens from the input
    def each(line: 0, point: 0)
      Enumerator.new do |yielder|
        buffer = []
        cursor = Cursor.new(line, point)

        until input.eof?
          yielder << buffer.pop until buffer.empty?

          # consume moves the pointer
          offset = input.pos

          # newlines
          if (current = input.consume { NEWLINE.match? _1 })
            yielder << Token.new(:eol, nil, current, offset, cursor.line, cursor.point)

            cursor.newline!
            next
          end

          # runs of whitespace
          if (current = input.consume_while { WHITESPACE.match? _1 })
            yielder << Token.new(:ws, nil, current, offset, cursor.line, cursor.point)

            cursor.right! current.length
            next
          end

          # comments go to the end of the line
          if (current = input.consume { _1 == ';' })
            current = input.consume_until(prefix: current) { NEWLINE.match? _1 } || ""
            yielder << Token.new(:comment, nil, current, offset, cursor.line, cursor.point)

            cursor.right! current.length
            next
          end

          # strings
          if (current = input.consume { _1 == '"' })
            strbuffer  = ""
            breakpoint = nil

            loop do
              strbuffer += input.consume_until { _1 == '"' or _1 == '\\' } || ""
              breakpoint = input.consume

              case breakpoint
              when nil, "\""
                # eof or end of the string, we're done
                break

              when "\\"
                escape     = input.consume
                strbuffer += breakpoint + escape

                # todo: give escapes lexical meaning
                # todo: multichar escapes (\u74FF, etc)
                next

              end
            end

            if breakpoint.nil? # eof?
              yielder << Token.new(:invalid, "eof in string", "\"#{strbuffer}", offset, cursor.line, cursor.point)
              cursor.right!(strbuffer.length + 1) # for open quote
            else
              yielder << Token.new(:string, strbuffer, "\"#{strbuffer}\"", offset, cursor.line, cursor.point)
              cursor.right!(strbuffer.length + 2) # for quotes
            end

            next
          end

          # #b reads binary digits
          if (current = input.consume_string("#b"))
            if (digits = input.consume_while { DIGITS_BASE2.match? _1 })
              yielder << Token.new(:number, digits.to_i(2), current + digits, offset, cursor.line, cursor.point)

              cursor.right!(current.length)
              cursor.right!(digits.length)
              next
            end

            yielder << Token.new(:invalid, "expected base2 digits", current, offset, cursor.line, cursor.point)
            cursor.right!(current.length)

            next
          end

          # #u reads decimal digits
          if (current = input.consume_string("#u"))
            if (digits = input.consume_while { DIGITS_BASE10.match? _1 })
              yielder << Token.new(:number, digits.to_i(10), current + digits, offset, cursor.line, cursor.point)

              cursor.right!(current.length)
              cursor.right!(digits.length)
              next
            end

            yielder << Token.new(:invalid, "expected base10 digits", current, offset, cursor.line, cursor.point)
            cursor.right!(current.length)

            next
          end

          # #x reads hexidecimal digits
          if (current = input.consume_string("#x"))
            if (digits = input.consume_while { DIGITS_BASE16.match? _1 })
              yielder << Token.new(:number, digits.to_i(16), current + digits, offset, cursor.line, cursor.point)

              cursor.right!(current.length)
              cursor.right!(digits.length)
              next
            end

            yielder << Token.new(:invalid, "expected base16 digits", current, offset, cursor.line, cursor.point)
            cursor.right!(current.length)

            next
          end

          # identifiers
          if (current = input.consume_while { IDENT_START.match? _1 })
            suffix    = input.consume_while { IDENT_START.match? _1 or IDENT_CONT.match? _1 }
            ident     = current + (suffix || "")

            yielder << Token.new(:ident, ident, ident, offset, cursor.line, cursor.point)
            cursor.right! ident.length

            next
          end

          # char by char tokenize
          if (input.consume { "," == _1 })
            if (input.consume { "@" == _1 })
              yielder << Token.new(:comma_splice, nil, ",@", offset, cursor.line, cursor.point)
              cursor.right! 2

              next
            end

            yielder << Token.new(:comma, nil, ",", offset, cursor.line, cursor.point)
            cursor.right! 1

            next
          end

          # possibly in the symbol token map
          char = input.getc
          if (token = SYMBOL_TOKENS[char])
            yielder << Token.new(token, nil, char, offset, cursor.line, cursor.point)
            cursor.right! char.length

            next
          end

          # otherwise it's invalid, and we should move right
          yielder << Token.new(:invalid, nil, char, input.pos, cursor.line, cursor.point)
          cursor.right!(1)
        end
      end
    end

  end
end
