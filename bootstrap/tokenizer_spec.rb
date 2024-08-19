# frozen_string_literal: true

require_relative 'lexer'
require_relative 'tokenizer'

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
      token = begin
        actual.next
      rescue StandardError
        raise "expected: #{tag}, but hit end of stream"
      end

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
  describe '#initialize' do
    subject(:tokenizer) { described_class.new(input) }

    context 'with a lexer' do
      let(:input) { DenverBS::Lexer.new('hi') }

      it 'justs use the input lexer' do
        expect(subject.input).to be(input)
      end
    end

    context 'with a string' do
      let(:input) { 'hi' }

      it 'creates a lexer' do
        expect(subject.input).to be_a(DenverBS::Lexer)
      end
    end
  end

  describe 'tokenization' do
    subject(:tokens) { described_class.new(input).each }

    describe 'simple string parsing' do
      let(:input) { '"hello"' }

      it 'returns a single string' do
        expect(tokens).to tokenize_as({ tag: :string, value: 'hello' })
      end
    end

    describe 'complicated string parsing' do
      let(:input) { "\"hello\n\t\\\"and more\"" }

      it 'returns a single string' do
        expect(tokens).to tokenize_as({ tag: :string, value: "hello\n\t\"and more" })
      end
    end

    describe 'binary numbers' do
      let(:input) { '#b0000 #b1111 #b11110000 #b2' }

      it 'returns some numbers' do
        expect(tokens).to(
          tokenize_as(
            { tag: :number, value: 0 },
            { tag: :ws },
            { tag: :number, value: 15 },
            { tag: :ws },
            { tag: :number, value: 240 },
            { tag: :ws },
            { tag: :invalid } # invalid not a symbol
          )
        )
      end
    end

    describe 'hex numbers' do
      let(:input) { '#x15 #xDD #x0 #xq' }

      it 'returns some numbers' do
        expect(tokens).to(
          tokenize_as(
            { tag: :number, value: 0x15 },
            { tag: :ws },
            { tag: :number, value: 0xDD },
            { tag: :ws },
            { tag: :number, value: 0x00 },
            { tag: :ws },
            { tag: :invalid } # invalid not a symbol
          )
        )
      end
    end

    describe 'decimal numbers' do
      let(:input) { '#u0 #u15 #u240 #ua' }

      it 'returns some numbers' do
        expect(tokens).to(
          tokenize_as(
            { tag: :number, value: 0 },
            { tag: :ws },
            { tag: :number, value: 15 },
            { tag: :ws },
            { tag: :number, value: 240 },
            { tag: :ws },
            { tag: :invalid } # invalid not a symbol
          )
        )
      end
    end

    describe 'float numbers' do
      let(:input) { '0.0 15 2.40e2 2. 3.0e-6' }

      it 'returns some numbers' do
        expect(tokens).to(
          tokenize_as(
            { tag: :number, value: 0 },
            { tag: :ws },
            { tag: :number, value: 15 },
            { tag: :ws },
            { tag: :number, value: 240 },
            { tag: :ws },
            { tag: :invalid }, # digit after decimal
            { tag: :ws },
            { tag: :number, value: 3e-6 }
          )
        )
      end
    end

    context 'example one' do
      let(:input) { <<~CODE }
        (one #b0 two #u1 three #x2)
      CODE

      it 'extracts known tokens' do
        expect(tokens).to(
          tokenize_as(
            { tag: :paren_o },
            { tag: :ident, value: 'one' },
            { tag: :ws },
            { tag: :number, value: 0 },
            { tag: :ws },
            { tag: :ident, value: 'two' },
            { tag: :ws },
            { tag: :number, value: 1 },
            { tag: :ws },
            { tag: :ident, value: 'three' },
            { tag: :ws },
            { tag: :number, value: 2 },
            { tag: :paren_c },
            { tag: :eol }
          )
        )
      end
    end
  end
end
