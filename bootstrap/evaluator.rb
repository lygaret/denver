require_relative 'data'

module DenverBS
  class Evaluator
    class EnvHash < Hash
      def spawn(vars, vals)
        parent = self
        child  = EnvHash.new { |_, k| parent[k] }

        while (var = vars.car) && (val = vals.car)
          child[var.value] = val

          vars = vars.cdr
          vals = vals.cdr
        end

        child
      end
    end

    attr_reader :global, :memory

    def initialize
      @global = EnvHash.new
      @memory = []
    end

    def lookup(expr, env)
      env[expr.value] or DenverBS::Data.error("no such binding: #{key}", nil)
    end

    def update(expr, env, value)
      if env.key?(expr.value)
        env[expr.value] = value
      else
        DenverBS::Data.error("no such binding: #{key}", nil)
      end
    end

    def eprogn(expr, env)
      if expr.pair?
        if expr.cdr.pair?
          evaluate(expr.car, env)
          eprogn(expr.cdr, env)
        else
          evaluate(expr.car, env)
        end
      else
        DenverBS::Data.null(nil)
      end
    end

    def elist(expr, env)
      if expr.pair?
        car  = evaluate(expr.car, env)
        rest = elist(expr.cdr, env)
        DenverBS::Data.cons(car, rest, nil)
      else
        DenverBS::Data.null(nil)
      end
    end

    def make_function(vars, body, env)
      DenverBS::Data.function(nil) do |values|
        childenv = env.spawn(vars, values)
        eprogn(body, childenv)
      end
    end

    def invoke_function(expr, args, _env)
      if expr.tag == :function
        expr.value.call(args)
      else
        Data.error("not a function: #{expr}", nil)
      end
    end

    def evaluate(expr, env)
      return nil if expr.nil?

      if expr.atom?
        if expr.tag == :symbol
          lookup(expr, env)
        elsif %i[number string char true false vector null].include? expr.tag
          expr
        else
          Data.error("cannot evaluate: #{expr}", nil)
        end
      else
        case expr.car
        in { tag: :symbol, value: 'quote' }
          expr.cdr

        in { tag: :symbol, value: 'if' }
          if evaluate(expr.cdar, env).truthy?
            evaluate(expr.cddar, env)
          else
            evaluate(expr.cdddar, env)
          end

        in { tag: :symbol, value: 'list' }
          elist(expr.cdr, env)

        in { tag: :symbol, value: 'begin' }
          eprogn(expr.cdr, env)

        in { tag: :symbol, value: 'set!' }
          update(expr.cdar, env, evaluate(expr.cddar, env))

        in { tag: :symbol, value: 'lambda' }
          make_function(expr.cdar, expr.cddr, env)

        else
          func = evaluate(expr.car, env)
          args = elist(expr.cdr, env)
          invoke_function(func, args, env)

        end
      end
    end
  end
end
