require_relative './lexer.rb'
require_relative './tokenizer.rb'

# custome matcher for token streams
# @example
#
# describe "tokenization" do
#   subject(:tokens) { Tokenizer.new(input).each }
#
#   describe "simple string parsing" do
#     let(:input) { '"hello" "friend"' }
#     it "should return some strings" do
#       expect(tokens).to tokenize_as(
#         { tag: :string, value: "hello" },
#         :ws,
#         { tag: :string, value: "friend" },
#       )
#     end
#   end
RSpec::Matchers.define :tokenize_as do |*expected|
  description { 'tokenize to the given tokens from the stream' }

  # match unless raises let's us use the exception as the failure message
  # otherwise we need to store off tag/token, etc.
  failure_message { @rescued_exception&.to_s }

  # symbol is tag
  # hash with :tag, :value keys
  match_unless_raises do |actual|
    expected.each do |tag|
      token = actual.next rescue (raise "expected: #{tag}, but hit end of stream")

      case tag
      when Symbol
        tag == token&.tag or raise "expected: #{tag}, got #{token&.tag}"

      when Hash
        tag.to_a.all? { |(k, v)| v == token.send(k) } or raise "expected #{tag}, got #{token&.to_h}"

      else
        raise ArgumentError, "expected to match tag or token hash, got #{tag}"
      end
    end
  end
end

RSpec.describe DenverBS::Tokenizer do
  describe "#initialize" do
    subject(:tokenizer) { described_class.new(input) }

    context "with a lexer" do
      let(:input) { DenverBS::Lexer.new('hi') }

      it "should just use the input lexer" do
        expect(subject.input).to be(input)
      end
    end

    context "with a string" do
      let(:input) { "hi" }

      it "should create a lexer" do
        expect(subject.input).to be_a(DenverBS::Lexer)
      end
    end
  end

  describe "tokenization" do
    subject(:tokens) { described_class.new(input).each }

    describe "simple string parsing" do
      let(:input) { '"hello"' }
      it "should return a single string" do
        expect(tokens).to tokenize_as({ tag: :string, value: "hello" })
      end
    end

    describe "complicated string parsing" do
      let(:input) { "\"hello\n\t\\\"and more\"" }
      it "should return a single string" do
        expect(tokens).to tokenize_as({ tag: :string, value: "hello\n\t\"and more" })
      end
    end

    describe "binary numbers" do
      let(:input) { "#b0000 #b1111 #b11110000" }
      it "should return some numbers" do
        expect(tokens).to(
          tokenize_as(
            { tag: :number, value: 0 },
            { tag: :ws },
            { tag: :number, value: 15 },
            { tag: :ws },
            { tag: :number, value: 240 },
          )
        )
      end
    end

    context "example one" do
      let(:input) { <<~CODE }
        (one #b0 two #u1 three #x2)
      CODE

      it "should extract known tokens" do
        expect(tokens).to(
          tokenize_as(
            { tag: :paren_o },
            { tag: :ident, value: "one" },
            { tag: :ws },
            { tag: :number, value: 0 },
            { tag: :ws },
            { tag: :ident, value: "two" },
            { tag: :ws },
            { tag: :number, value: 1 },
            { tag: :ws },
            { tag: :ident, value: "three" },
            { tag: :ws },
            { tag: :number, value: 2 },
            { tag: :paren_c },
            { tag: :eol },
          )
        )
      end
    end

  end
end
