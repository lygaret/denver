# frozen_string_literal: true

require_relative 'parser'

RSpec::Matchers.define :be_symbol do |expected|
  description { 'be an atom matching the given symbol' }
  failure_message { "expected #{expected}, #{@rescued_exception&.to_s}" }

  # symbol is tag
  # hash with :tag, :value keys
  match_unless_raises do |actual|
    raise "but got nil" if actual.nil?
    raise "but is not an atom" unless actual.atom?
    raise "but is not a symbol" unless actual.tag == :symbol
    raise "but is the symbol '#{expected}'" unless actual.value == expected
  end
end

RSpec.describe DenverBS::Parser do
  let(:parser) { described_class.new(input) }
  let(:enum)   { parser.each }

  subject(:result) { enum.first }

  describe "example" do
    let(:input) { <<~CODE }
      (alpha beta (1 2 3) #xff . 10)
    CODE

    its(:car) { is_expected.to be_symbol("alpha") }
    its(:cdar) { is_expected.to be_symbol("beta") }

    it "formats as expected" do
      expect(result.to_s).to eq("(alpha beta (1.0 2.0 3.0) 255 . 10.0)")
    end
  end
end
