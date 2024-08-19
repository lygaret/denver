# frozen_string_literal: true

require_relative 'lexer'

RSpec.describe DenverBS::Lexer do
  subject { described_class.new(input) }

  context 'with a string' do
    let(:input) { 'hi' }

    it 'does not raise an error' do
      expect { subject }.not_to raise_error
    end
  end

  context 'with empty input' do
    let(:input) { '' }

    it { is_expected.to be_eof }
  end

  context 'with a stream' do
    it 'is expected not to error out' do
      File.open(__FILE__, 'r') do |f|
        lex = described_class.new(f)

        expect(lex).not_to be_eof
      end
    end
  end

  context 'with non io' do
    let(:input) { 4 }

    it 'raises an error' do
      expect { subject }.to raise_error(ArgumentError)
    end
  end

  describe '#getc and #ungetc' do
    let(:input) { 'hi' }

    it 'returns the next char' do
      expect(subject.getc).to eq('h')
    end

    it 'returns ungot chars' do
      subject.ungetc('q')
      expect(subject.getc).to eq('q')
    end

    it 'ungets a whole string in the right order' do
      subject.ungets('quite')

      expect(subject.getc).to eq('q')
      expect(subject.getc).to eq('u')
      expect(subject.getc).to eq('i')
      expect(subject.getc).to eq('t')
      expect(subject.getc).to eq('e')
      expect(subject.getc).to eq('h')
      expect(subject.getc).to eq('i')
      expect(subject.getc).to be_nil
    end

    it "calls it's block, but return the char" do
      called = false
      retval = subject.getc do |c|
        called = c
        :some_value_return
      end

      aggregate_failures do
        expect(called).to eq('h')
        expect(retval).to eq('h')
      end
    end
  end

  describe '#consume' do
    let(:input) { 'hi' }

    it 'consumes a single char with no args' do
      expect(subject.consume).to eq('h')
    end

    it 'consumes a single char with a passing predicate' do
      expect(subject.consume { _1 == 'h' }).to eq('h')
    end

    it 'does not a single char with a failing predicate' do
      # also check that it's still on the input buffer
      aggregate_failures do
        expect(subject.consume { _1 == 'i' }).to be_nil
        expect(subject.consume).to eq('h')
      end
    end
  end

  describe '#consume_while' do
    let(:input) { 'abcdefg' }

    it 'consumes while a pred returns true' do
      count  = 3
      retval = subject.consume_while do |_|
        (count -= 1) >= 0
      end

      aggregate_failures do
        expect(retval).to eq('abc')
        expect(subject.consume).to eq('d')
      end
    end
  end

  describe '#consume_until' do
    let(:input) { 'abcdefg' }

    it 'consumes while a pred returns false' do
      count  = 3
      retval = subject.consume_until do |_|
        (count -= 1).negative?
      end

      aggregate_failures do
        expect(retval).to eq('abc')
        expect(subject.consume).to eq('d')
      end
    end
  end

  describe '#consume_string' do
    let(:input) { 'abcdefg' }

    it 'consumes the matching string' do
      retval = subject.consume_string('abc')

      aggregate_failures do
        expect(retval).to eq('abc')
        expect(subject.consume).to eq('d')
      end
    end

    it 'does not consume on partial match string' do
      retval = subject.consume_string('abcf')

      aggregate_failures do
        expect(retval).to be_nil
        expect(subject.consume).to eq('a')
      end
    end
  end
end
