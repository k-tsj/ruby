def assert_expr(str)
  puts "################################################################"
  puts str
  iseq = RubyVM::InstructionSequence.compile(str)
  r = iseq.eval
  raise "#{r.inspect}:\n#{str}" unless r == :ok
  puts
end

class TestHash
  def deconstruct_keys(keys)
    {a: 0}
  end
end

assert_expr %q{
  case 1
  in 1
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case []
  in ()
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1]
  in ()
    :ng
  else
    :ok
  end
}

assert_expr %q{
  case [1]
  in (1)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1]
  in (2)
    :ng
  else
    :ok
  end
}

assert_expr %q{
  case [1]
  in (Integer)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1]
  in (1, 2)
    :ng
  else
    :ok
  end
}

assert_expr %q{
  case [1, 2]
  in (1, 2)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1]
  in (a)
    a == 1 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1]
  in (*)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1]
  in (*a)
    a == [1] && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [[1]]
  in ((1))
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case "a"
  in "a"
    :ok
  else
    :ng
  end
}

assert_expr %q{
  x = 1
  case "012"
  in "0#{x}2"
    :ok
  else
    :ng
  end
}


assert_expr %q{
  case :ab
  in :"a#{}b"
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case "ab"
  in /b/
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case "ab"
  in /b/
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case ["a"]
  in %w(a)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [2]
  in (1..3)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [2]
  in (1...3)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [2]
  in (1..)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [2]
  in (1...)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case ["b"]
  in ("a".."c")
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1]
  in (*a, b)
    a == [] && b == 1 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1, 2]
  in (*a, b)
    a == [1] && b == 2 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1, 2, 3]
  in (*a, b, c)
    a == [1] && b == 2 && c == 3 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1, 2, 3]
  in (a, *b)
    a == 1 && b == [2, 3] && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1, 2, 3]
  in (a, *b, c)
    a == 1 && b == [2] && c == 3 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1, 2, 3]
  in (a, *, b)
    a == 1 && b == 3 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1, 2, 3]
  in (*, a)
    a == 3 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {k0: 0, k1: 1, k2: 2}
  in (k0: 0, k1: a, k2:)
    a == 1 && k2 == 2 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {k0: 0, k1: 1, k2: 2}
  in (k3:)
    :ng
  else
    :ok
  end
}

assert_expr %q{
  case {k0: 0, k1: 1, k2: 2}
  in (k0:, **rest)
    k0 == 0 && rest == {k1: 1, k2: 2} && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {k0: 0, k1: 1, k2: 2}
  in (**rest)
    rest == {k0: 0, k1: 1, k2: 2} && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {}
  in (**rest)
    rest == {} && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {}
  in (a: 0)
    :ng
  else
    :ok
  end
}

assert_expr %q{
  case {a: 0}
  in (a:)
    a == 0 && :ok
  else
    :ng
  end
}

assert_expr %q{
  h = {a: 0}
  case h
  in (a:, **b)
    a == 0 && b == {} && h == {a: 0} && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [0]
  in (a) if a == 0
    a == 0 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [0]
  in (a) if a == 1
    :ng
  else
    :ok
  end
}

assert_expr %q{
  ary = []
  case [0]
  in (1) if ary << 1
    :ng
  else
    ary == [] && :ok
  end
}

assert_expr %q{
  case [0]
  in (a) unless a == 1
    a == 0 && :ok
  else
    :ng
  end
}

assert_expr %q{
  begin 
    case 0
    in 1
      :ng
    end
  rescue NoMatchingPatternError
    :ok
  end
}

assert_expr %q{
  case [0, 1]
  in a, b
    a == 0 && b == 1 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [0, 1]
  in a
    a == [0, 1] && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [0, 1]
  in *a, b
    a == [0] && b == 1 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {a: 0}
  in a:
    a == 0 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {a: 0}
  in a:, **b
    a == 0 && b == {} && :ok
  else
    :ng
  end
}

assert_expr %q{
  a = 1
  case [0]
  in (^a)
    :ng
  else
    :ok
  end
}

assert_expr %q{
  _ = 1
  case [0]
  in (_)
    :ok
  else
    :ng
  end
}

begin
  assert_expr %q{
    case [0]
    in (^a)
      :ng
    else
      :ok
    end
  }
rescue SyntaxError
else
  puts "failed at #{__LINE__}"
  exit
end

assert_expr %q{
  case 0
  in Integer => a
    a == 0 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [0, [1, 2]]
  in (a, (_, b) => c)
    a == 0 && b == 2 && c == [1, 2] && :ok
  else
    :ng
  end
}

assert_expr %q{
  case 1
  in 0 | 1 | 2 => a
    a == 1 && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [:b, 0]
  in (:a | :b | :c => t, _)
    t == :b && :ok
  else
    :ng
  end
}

begin
  assert_expr %q{
    case 0
    in a | 0
      :ng
    else
      :ok
    end
  }
rescue SyntaxError
else
  puts "failed at #{__LINE__}"
  exit
end

assert_expr %q{
  case 0
  in _ | 0
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case 0
  in Array(1)
    :ng
  else
    :ok
  end
}

assert_expr %q{
  case [1]
  in Array(1)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case {a: 0}
  in Hash(a: 0)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case {a: 0}
  in Hash(a: 1)
    :ng
  else
    :ok
  end
}

assert_expr %q{
  case TestHash.new
  in Hash(a: 0)
    :ng
  in TestHash(a: 0)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [nil, self, true, false, __FILE__, __LINE__, __ENCODING__]
  in (nil, self, true, false, __FILE__, __LINE__ | _, __ENCODING__)
    :ok
  else
    :ng
  end
}

begin
  assert_expr %q{
    case 0
    in $a
    end
  }
rescue SyntaxError
else
  puts "failed at #{__LINE__}"
  exit
end

assert_expr %q{
  case [1, 2, 3]
  in a, *b, c
    [a, b, c] ==  [1, [2], 3] && :ok
  else
    :ng
  end
}

assert_expr %q{
  case [1, 2, 3]
  in *a, b
    [a, b] ==  [[1, 2], 3] && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {d: 4, e: 5, f: 6}
  in d:, e: Integer | Float => i, **f
    [d, i, f] ==  [4, 5, {f: 6}] && :ok
  else
    :ng
  end
}

assert_expr %q{
  case []
  in []
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case {a: 0}
  in {}
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case TestHash.new
  in {}
    :ng
  in {a: 0}
    :ng
  in (a: 0)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [0, 0]
  in (a,)
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [0, 0]
  in a, ^a
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case [0, 1]
  in a, ^a
    :ng
  else
    :ok
  end
}

assert_expr %q{
  case 0
  in a if a == 0
    :ok
  else
    :ng
  end
}

################################################################
## Refinements
################################################################

class C1
  def deconstruct
    [:C1]
  end
end

class C2
end

module RefinementsTest
  refine Array do
    def deconstruct
      [0]
    end
  end

  refine Hash do
    def deconstruct_keys(keys)
      $keys = keys
      {a: 0}
    end
  end

  refine C2.singleton_class do
    def ===(obj)
      obj.kind_of?(C1)
    end
  end
end

using RefinementsTest

def assert_expr(str)
  puts "################################################################"
  puts str
  r = eval(str)
  raise "#{r.inspect}:\n#{str}" unless r == :ok
  puts
end

assert_expr %q{
  case []
  in [0]
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case {}
  in {a: 0}
    :ok
  else
    :ng
  end
}

assert_expr %q{
  case C1.new
  in C2(:C1)
    :ok
  else
    :ng
  end
}

################################################################
## deconstruct_keys

module DeconstructKeysTest
  refine Hash do
    def deconstruct_keys(keys)
      $keys = keys
      self
    end
  end
end

using DeconstructKeysTest

def assert_expr(str)
  puts "################################################################"
  puts str
  r = eval(str)
  raise "#{r.inspect}:\n#{str}" unless r == :ok
  puts
end

assert_expr %q{
  case {a: 0, b: 0, c: 0}
  in {}
    $keys == [] && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {a: 0, b: 0, c: 0}
  in {a: 0, b:}
    $keys == [:a, :b] && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {a: 0, b: 0, c: 0}
  in {a: 0, b:, **}
    $keys == [:a, :b] && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {a: 0, b: 0, c: 0}
  in {a: 0, b:, **r}
    $keys == nil && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {a: 0, b: 0, c: 0}
  in {**}
    $keys == nil && :ok
  else
    :ng
  end
}

assert_expr %q{
  case {a: 0, b: 0, c: 0}
  in {**r}
    $keys == nil && :ok
  else
    :ng
  end
}
