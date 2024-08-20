# frozen_string_literal: true

require 'debug'
require 'linenoise'

require_relative 'bootstrap/data'
require_relative 'bootstrap/parser'
require_relative 'bootstrap/evaluator'

# build the default env

machine = DenverBS::Evaluator.new

# cons helpers

%i[
  car cdr
  caar cadr cdar cddr
  caaar caadr cadar caddr cdaar cdadr cddar cdddr
].each do |op|
  machine.define_global(op.to_s) do |cdr|
    next DenverBS::Data.error("wrong arity", nil) unless cdr.count == 1

    cdr.each.first.send(op)
  end
end

machine.define_global("list") { |cdr| cdr }

machine.define_global("cons") do |cdr|
  next DenverBS::Data.error("wrong arity", nil) unless cdr.count == 2

  DenverBS::Data.cons(cdr.caar, cdr.cdar, nil)
end

# print out the atom
machine.define_global("print") do |args|
  puts args.each.map(&:to_s).join(" ")
  DenverBS::Data.null(nil)
end

# define some simple math ops (identity)
[[:+, 0], [:-, 0], [:*, 1]].each do |(op, identity)|
  machine.define_global(op.to_s) do |args|
    if args.each.all? { _1.tag == :number }
      values = args.each.map(&:value)
      sum    = values.reduce(identity, &op)
      DenverBS::Data::Atom.new(:number, sum, nil, nil)
    else
      DenverBS::Data.error("cannot #{op} non-numbers", nil)
    end
  end
end

# define comparisons
machine.define_global("<") do |args|
  args = args.each.to_a

  if args.all? { _1.tag == :number }
    values = args.map(&:value)
    result = values.each_cons(2).all? { |a, b| a < b }
    DenverBS::Data.bool(result, nil)
  else
    DenverBS::Data.error("cannot compare non-numbers", nil)
  end
end

while (input = Linenoise.linenoise('>> '))
  parser = DenverBS::Parser.new(input)
  parser.each do
    machine.evaluate(_1, machine.global).tap do |value|
      machine.set_global("_", value)

      puts "#> #{value}"
    end
  end
end
