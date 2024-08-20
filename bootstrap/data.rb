# frozen_string_literal: true

module DenverBS
  module Data

    # any kind of value in the s-expression tree
    # "extra" is cdr for cons; this way we can share this one big #to_s

    Atom = ::Data.define(:tag, :value, :extra, :token) do

      # cons
      def pair? = tag == :cons
      def atom? = !pair?

      def car   = value
      def cdr   = extra
      def cdar  = cdr.car
      def cddr  = cdr.cdr

      def count = pair? ? (1 + cdr.count) : 0

      # formater
      def to_s(cont: false)
        case tag

          # atoms
        when :symbol, :number
          value.to_s
        when :true, :false
          "##{value ? 't' : 'f'}"
        when :string
          value.inspect

          # cons

        when :cons
          case cdr
          in { tag: :null }
            "#{cont ? '' : '('}#{car})"
          in { tag: :cons }
            "#{cont ? '' : '('}#{car} #{cdr.to_s(cont: true)}"
          else
            "#{cont ? '' : '('}#{car} . #{cdr})"
          end

        when :null
          '()'

          # fallback
        else
          "#{tag}|#{value.inspect}"
        end
      end
    end

    class << self
      def true(token)  = Atom.new(:true, true, nil, token)
      def false(token) = Atom.new(:false, false, nil, token)
      def cons(car, cdr, token) = Atom.new(:cons, car, cdr, token)
      def null(token)  = Atom.new(:null, nil, nil, token)
      def symbol(name, token) = Atom.new(:symbol, name, nil, token)

      def error(message, token) = Atom.new(:error, message, nil, token)
    end
  end
end
