# frozen_string_literal: true

require 'debug'
require 'linenoise'

require_relative 'bootstrap/data'
require_relative 'bootstrap/parser'
require_relative 'bootstrap/evaluator'

machine = DenverBS::Evaluator.new

while (input = Linenoise.linenoise('>> '))
  parser = DenverBS::Parser.new(input)
  parser.each do
    value = machine.evaluate(_1, machine.global)

    puts "#> #{value}"
  end
end
