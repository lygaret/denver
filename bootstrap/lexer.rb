module DenverBS

  # A lexing buffer.
  #
  # Basically just a wrapper around an input stream, with helpful methods
  # for walking through and consuming input by predicates.
  #
  # @example Basic Usage
  #
  # lex = Lexer.new("some string")
  #
  # chunk = lex.consume_while { match_ident? _1 }
  # ws    = lex.consume_until { match_ident? _1 }
  # chunk = lex.consume_while(prefix: chunk) { match_ident _1 }
  #
  # expect(chunk).to eq("somestring")
  # expect(lex).to be_eof
  #
  class Lexer

    # @return [IO]
    attr_reader :input

    # @param input [IO, String] the input
    def initialize(input)
      @buffer = []
      @input  =
        if ([:getc, :eof?].all? { input.respond_to? _1 })
          # io like
          input

        elsif input.respond_to?(:to_str)
          # stringy
          input = StringIO.new(input.to_str.dup)
          input.set_encoding('UTF-8')

        else
          # no idea
          raise ArgumentError, "expected an IO or string as input, but got #{input.inspect}"
        end
    end

    # @return true when the input is at the end of the stream
    def eof? = @input.eof?

    # get a character from the input buffer
    # yields to a block if given, but always returns the read char
    def getc(&body)
      char = @buffer.empty? ? @input.getc : @buffer.pop
      char.tap do |c|
        body.call(c) unless c.nil? or body.nil?
      end
    end

    # push the given character back onto the input buffer
    # @return nil
    def ungetc(c)
      @buffer.push(c)
      return nil
    end

    # push the given string back on the input buffer
    # @input str [Array<Char>, String] the string to add back to the buffer
    # @return nil
    def ungets(str)
      case str
      when Array
        @buffer.concat(str.reverse)
      when String
        @buffer.concat(str.each_char.to_a.reverse)
      else
        raise ArgumentError, "ungets expects string or char array, got #{str.inspect}"
      end

      return nil
    end

    # consume a single character from the input
    # if a block is given, it's a predicate which must pass, or nil will be returned
    # @yieldparam char a single character from the input
    # @yieldreturn true if the character should be returned
    # @return the next char in the stream, or nil if {eof?} or the block isn't truthy
    def consume(&pred)
      getc do |c|
        if pred
          return c if pred.call(c)

          # explicit return for no match nil
          # otherwise, getc falls through and returns the char
          return ungetc(c)
        end
      end
    end

    # consume from input, assuming that all characters match
    # if not, they are placed back on the input buffer for future matching
    def consume_string(string)
      buffer  = []
      matched = string.each_char.all? do |char|
        if (current = consume { _1 == char })
          buffer << current
        end
      end

      if matched
        buffer.join
      else
        buffer.reverse.each { ungets _1 }
        nil
      end
    end

    # consume from input, while the given predicate holds
    # @input prefix [String] a prefix to add to the returned string
    # @return the string that was read, or nil if no matches were made
    def consume_while(prefix: nil, &pred)
      buffer = prefix&.dup || ""

      # fill up while we pass
      while (char = getc) and pred.call(char)
        buffer += char
      end

      # the last char we read _didn't_ pass the check
      ungetc(char) unless char.nil?
      buffer.length == 0 ? nil : buffer
    end

    # consume from input, while the given predicate returns false
    # @input prefix [String] a prefix to add to the returned string
    # @return the string that was conumed
    def consume_until(prefix: nil, &pred)
      consume_while(prefix:) { |c| not pred.call(c) }
    end
  end

end
