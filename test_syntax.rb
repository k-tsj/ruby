def assert_syntax(str)
  r = eval(str)
  raise "#{r.inspect}:\n#{str}" unless r == :ok
  print '.'
end

assert_syntax open('syntax.rb').read

assert_syntax %q{
  =(x:) = {x: 1, y: 2}
  x == 1 ? :ok : :ng
}

assert_syntax %q{
  class C
    def deconstruct
      [0, 1, [2, 1], x: 3, y: 4, z: 5]
    end
  end

  case C.new
  => =(0, *, =(b, _), x: 3, y:, **z) if b == 2
    p b #=> 2
    p y #=> 4
    p z #=> {z: 5}
    :ok
  else
    :ng
  end
}

assert_syntax %q{
  case [0, {x: 3, y: 4, z: 5}]
  => =(a, x:3,y:,**z)
    p y #=> 4
    p z #=> {z: 5}
    :ok
  else
    :ng
  end
}

assert_syntax %q{
  case [0,1,2]
  => =(*, a)
    a == 2 && :ok
  else
    :ng
  end
}


assert_syntax %q{
  case [0,1,2]
  => =(*)
    :ok
  else
    :ng
  end
}

assert_syntax %q{
  case [0,1,2]
  => =(a, *b, c)
    a == 0 && b == [1] && c == 2 && :ok
  else
    :ng
  end
}

assert_syntax %q{
  case [0,1,2]
  => =(a, *)
    a == 0 && :ok
  else
    :ng
  end
}

assert_syntax %q{
  case [0,1,2]
  => =(a, *b)
    a == 0 && b == [1, 2] && :ok
  else
    :ng
  end
}

assert_syntax %q{
  case {a: 0, c: 1, d: 100}
  => =(a: b, c:, **d)
    b == 0 && c == 1 && d == {d: 100} && :ok
  else
    :ng
  end
}

assert_syntax %q{
  case {a: 0, c: 1}
  => =(a: b, c:)
    b == 0 && c == 1 && :ok
  else
    :ng
  end
}

assert_syntax %q{
  case [{a: 0}]
  => =(a: b)
    b == 0 && :ok
  else
    :ng
  end
}

assert_syntax %q{
  case {a: 0}
  => =(**x)
    x == {a: 0} && :ok
  else
    :ng
  end
}

assert_syntax %q{
  case 100;
  => =(a)
    a == 100 && :ok
  else
    :ng
  end
}

assert_syntax %q{
  case [100, 200]
  => =(a, b)
    a == 100 && b == 200 && :ok
  else
    :ng
  end
}
