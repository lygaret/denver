# frozen_string_literal: true

require 'debug'
require 'linenoise'

require_relative 'bootstrap/parser'

while (input = Linenoise.linenoise('> '))
  DenverBS::Parser.new(input).each do |atom|
    puts "> #{atom}"
  end
end
