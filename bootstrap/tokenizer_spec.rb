require_relative './lexer.rb'
require_relative './tokenizer.rb'

RSpec.describe DenverBS::Tokenizer do

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

  describe "tokenization" do
    subject(:enumerator) { tokenizer.each }

    describe "simple string parsing" do
      let(:input) { '"hello"' }

      it "should return a single string" do
        tokens = subject.to_a

        aggregate_failures do
          expect(tokens.length).to eq(1)
          expect(tokens[0].tag).to eq(:string)
          expect(tokens[0].value).to eq("hello")
        end
      end
    end

    describe "complicated string parsing" do
      let(:input) { "\"hello\n\t\\\"and more\"" }

      it "should return a single string" do
        tokens = subject.to_a

        aggregate_failures do
          expect(tokens.length).to eq(1)
          expect(tokens[0].tag).to eq(:string)
          expect(tokens[0].value).to eq("hello\n\t\"and more")
        end
      end
    end

    context "example one" do

      let(:input) { <<~CODE }
        (one #b0 two #u1 three #x2)
      CODE

      it "should extract known tokens" do
        aggregate_failures do
          expect(subject.next&.tag).to eq(:paren_o)
          expect(subject.next&.tag).to eq(:ident)
          expect(subject.next&.tag).to eq(:ws)
          expect(subject.next&.tag).to eq(:number)
          expect(subject.next&.tag).to eq(:ws)
          expect(subject.next&.tag).to eq(:ident)
          expect(subject.next&.tag).to eq(:ws)
          expect(subject.next&.tag).to eq(:number)
          expect(subject.next&.tag).to eq(:ws)
          expect(subject.next&.tag).to eq(:ident)
          expect(subject.next&.tag).to eq(:ws)
          expect(subject.next&.tag).to eq(:number)
          expect(subject.next&.tag).to eq(:paren_c)
          expect(subject.next&.tag).to eq(:eol)
          expect { subject.next }.to raise_error StopIteration
        end
      end
    end

  end
end
