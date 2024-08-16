module DenverBS
  module Data

    # any kind of value in the s-expression tree
    Atom = ::Data.define(:tag, :value, :token) do
      def to_s
        case tag
        when :null
          "()"
        when :cons
          value.to_s
        when :symbol, :number
          value.to_s
        else
          "#{tag.to_s}|#{value.inspect}"
        end
      end
    end

    # the value of an Atom.new(:cons)
    Cons = ::Data.define(:car, :cdr) do
      def to_s(cont: false)
        case cdr
        in { tag: :null }
          "#{cont ? "" : "("}#{car})"

        in { tag: :cons, value: cons }
          "#{cont ? "" : "("}#{car} #{cons.to_s(cont: true)}"

        else
          "#{cont ? "" : "("}#{car} . #{cdr})"
        end
      end
    end

    class << self
      def cons(car, cdr, token) = Atom.new(:cons, Cons.new(car, cdr), token)
      def true(token)  = Atom.new(:true, true, token)
      def false(token) = Atom.new(:false, false, token)
      def null(token)  = Atom.new(:null, nil, token)
    end

  end
end
