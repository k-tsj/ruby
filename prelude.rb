class Array
  def self.deconstruct(val)
    raise PatternNotMatch unless val.kind_of?(self)
    val
  end
end

class Regexp
  def deconstruct(val)
    m = Regexp.new("\\A#{source}\\z", options).match(val.to_s)
    raise PatternMatch::PatternNotMatch unless m
    m.captures.empty? ? [m[0]] : m.captures
  end
end

module Deconstructable
  def call(*subpatterns)
    if Object == self
      PatternKeywordArgStyleDeconstructor.new(Object, :respond_to?, :__send__, *subpatterns)
    else
      pattern_matcher(*subpatterns)
    end
  end
end

class ::Object
  def pattern_matcher(*subpatterns)
    PatternObjectDeconstructor.new(self, *subpatterns)
  end
end

module AttributeMatcher
  def self.included(klass)
    class << klass
      def pattern_matcher(*subpatterns)
        PatternKeywordArgStyleDeconstructor.new(self, :respond_to?, :__send__, *subpatterns)
      end
    end
  end
end

module KeyMatcher
  def self.included(klass)
    class << klass
      def pattern_matcher(*subpatterns)
        PatternKeywordArgStyleDeconstructor.new(self, :has_key?, :[], *subpatterns)
      end
    end
  end
end

class Pattern
  attr_accessor :parent, :next, :prev

  def initialize(*subpatterns)
    @parent = nil
    @next = nil
    @prev = nil
    @subpatterns = subpatterns.map {|i| i.kind_of?(Pattern) ? i : PatternValue.new(i) }
    set_subpatterns_relation
  end

  def vars
    @subpatterns.map(&:vars).flatten
  end

  def ancestors
    root? ? [self] : parent.ancestors.unshift(self)
  end

  def binding
    vars.each_with_object({}) {|v, h| h[v.name] = v.val }
  end

  def &(pattern)
    PatternAnd.new(self, pattern)
  end

  def |(pattern)
    PatternOr.new(self, pattern)
  end

  def !@
    PatternNot.new(self)
  end

  def to_a
    [self, PatternQuantifier.new(0)]
  end

  def quantifier?
    raise NotImplementedError
  end

  def quantified?
    (@next && @next.quantifier?) || (root? ? false : @parent.quantified?)
  end

  def root?
    @parent == nil
  end

  def validate
    if root?
      dup_vars = vars - vars.uniq(&:name)
      unless dup_vars.empty?
        raise MalformedPatternError, "duplicate variables: #{dup_vars.map(&:name).join(', ')}"
      end
    end
    raise MalformedPatternError if @subpatterns.count {|i| i.quantifier? } > 1
    @subpatterns.each(&:validate)
  end

  private

  def set_subpatterns_relation
    @subpatterns.each do |i|
      i.parent = self
    end
    @subpatterns.each_cons(2) do |a, b|
      a.next = b
      b.prev = a
    end
  end
end

class PatternQuantifier < Pattern
  attr_reader :min_k

  def initialize(min_k = 0)
    super()
    @min_k = min_k
  end

  def ===(val)
    raise PatternMatchError, 'must not happen'
  end

  def validate
    super
    raise MalformedPatternError unless @prev
    raise MalformedPatternError unless @parent.kind_of?(PatternDeconstructor)
  end

  def quantifier?
    true
  end
end

class PatternElement < Pattern
  def quantifier?
    false
  end
end

class PatternDeconstructor < PatternElement
end

class PatternObjectDeconstructor < PatternDeconstructor
  def initialize(deconstructor, *subpatterns)
    super(*subpatterns)
    @deconstructor = deconstructor
  end

  def ===(val)
    deconstructed_vals = @deconstructor.deconstruct(val)
    k = deconstructed_vals.length - (@subpatterns.length - 2)
    quantifier = @subpatterns.find(&:quantifier?)
    if quantifier
      return false unless quantifier.min_k <= k
    else
      return false unless @subpatterns.length == deconstructed_vals.length
    end
    @subpatterns.flat_map do |pat|
      case
      when pat.next && pat.next.quantifier?
        []
      when pat.quantifier?
        pat.prev.vars.each {|v| v.set_bind_to(pat) }
        Array.new(k, pat.prev)
      else
        [pat]
      end
    end.zip(deconstructed_vals).all? do |pat, v|
      pat === v
    end
  end
end

PatternHashRest = Object.new

class PatternKeywordArgStyleDeconstructor < PatternDeconstructor
  def initialize(klass, checker, getter, *keyarg_subpatterns)
    spec = normalize_keyword_arg(keyarg_subpatterns)
    super(*spec.values)
    @klass = klass
    @checker = checker
    @getter = getter
    @spec = spec
  end

  def ===(val)
    if @spec.has_key?(PatternHashRest)
      val = val.merge({PatternHashRest => @spec.keys.each_with_object(val.dup) {|k, h| h.delete(k) }})
    end
    raise PatternNotMatch unless val.kind_of?(@klass)
    raise PatternNotMatch unless @spec.keys.all? {|k| val.__send__(@checker, k) }
    @spec.all? {|k, pat| pat === val.__send__(@getter, k) rescue raise PatternNotMatch }
  end

  private

  def normalize_keyword_arg(subpatterns)
    syms = subpatterns.take_while {|i| i.kind_of?(Symbol) }
    rest = subpatterns.drop(syms.length)
    hash = case rest.length
           when 0
             {}
           when 1
             rest[0]
           else
             raise MalformedPatternError
           end
    variables = Hash[syms.map {|i, h| [i, PatternVariable.new(i)] }]
    Hash[variables.merge(hash).map {|k, v| [k, v.kind_of?(Pattern) ? v : PatternValue.new(v)] }]
  end
end

class PatternVariable < PatternElement
  attr_reader :name, :val

  def initialize(name, binding)
    super()
    @name = name
    @val = nil
    @bind_to = nil
    @binding = binding
  end

  def ===(val)
    bind(val)
    true
  end

  def vars
    [self]
  end

  def set_bind_to(quantifier)
    if @val
      outer = @val
      (nest_level(quantifier) - 1).times do
        outer = outer[-1]
      end
      @bind_to = []
      outer << @bind_to
    else
      @val = @bind_to = []
      @binding.local_variable_set(@name, @val) unless @name == :_
    end
  end

  private

  def bind(val)
    if quantified?
      @bind_to << val
    else
      @val = val
      @binding.local_variable_set(@name, val) unless @name == :_
    end
  end

  def nest_level(quantifier)
    qs = ancestors.map {|i| (i.next and i.next.quantifier?) ? i.next : nil }.find_all {|i| i }.reverse
    qs.index(quantifier) || (raise PatternMatchError)
  end
end

class PatternValue < PatternElement
  def initialize(val, compare_by = :===)
    super()
    @val = val
    @compare_by = compare_by
  end

  def ===(val)
    @val.__send__(@compare_by, val)
  end
end

class PatternAnd < PatternElement
  def ===(val)
    @subpatterns.all? {|i| i === val }
  end
end

class PatternOr < PatternElement
  def ===(val)
    @subpatterns.find do |i|
      begin
        i === val
      rescue PatternNotMatch
        false
      end
    end
  end

  def validate
    super
    raise MalformedPatternError unless vars.length == 0
  end
end

class PatternNot < PatternElement
  def ===(val)
    ! (@subpatterns[0] === val)
  rescue PatternNotMatch
    true
  end

  def validate
    super
    raise MalformedPatternError unless vars.length == 0
  end
end

class PatternCondition < PatternElement
  def initialize(condition)
    super()
    @condition = condition
  end

  def ===(val)
    @condition.call
  end

  def validate
    super
    raise MalformedPatternError if ancestors.find {|i| i.next and ! i.next.kind_of?(PatternCondition) }
  end

  def inspect
    "#<#{self.class.name}: condition=#{@condition.inspect}>"
  end
end

class PatternNotMatch < Exception; end
class PatternMatchError < StandardError; end
class NoMatchingPatternError < PatternMatchError; end
class MalformedPatternError < PatternMatchError; end

class Thread
  MUTEX_FOR_THREAD_EXCLUSIVE = Thread::Mutex.new # :nodoc:
  private_constant :MUTEX_FOR_THREAD_EXCLUSIVE

  # call-seq:
  #    Thread.exclusive { block }   => obj
  #
  # Wraps the block in a single, VM-global Mutex.synchronize, returning the
  # value of the block. A thread executing inside the exclusive section will
  # only block other threads which also use the Thread.exclusive mechanism.
  def self.exclusive
    warn "Thread.exclusive is deprecated, use Thread::Mutex", caller
    MUTEX_FOR_THREAD_EXCLUSIVE.synchronize{
      yield
    }
  end
end

class IO

  # call-seq:
  #    ios.read_nonblock(maxlen [, options])              -> string
  #    ios.read_nonblock(maxlen, outbuf [, options])      -> outbuf
  #
  # Reads at most <i>maxlen</i> bytes from <em>ios</em> using
  # the read(2) system call after O_NONBLOCK is set for
  # the underlying file descriptor.
  #
  # If the optional <i>outbuf</i> argument is present,
  # it must reference a String, which will receive the data.
  # The <i>outbuf</i> will contain only the received data after the method call
  # even if it is not empty at the beginning.
  #
  # read_nonblock just calls the read(2) system call.
  # It causes all errors the read(2) system call causes: Errno::EWOULDBLOCK, Errno::EINTR, etc.
  # The caller should care such errors.
  #
  # If the exception is Errno::EWOULDBLOCK or Errno::EAGAIN,
  # it is extended by IO::WaitReadable.
  # So IO::WaitReadable can be used to rescue the exceptions for retrying
  # read_nonblock.
  #
  # read_nonblock causes EOFError on EOF.
  #
  # If the read byte buffer is not empty,
  # read_nonblock reads from the buffer like readpartial.
  # In this case, the read(2) system call is not called.
  #
  # When read_nonblock raises an exception kind of IO::WaitReadable,
  # read_nonblock should not be called
  # until io is readable for avoiding busy loop.
  # This can be done as follows.
  #
  #   # emulates blocking read (readpartial).
  #   begin
  #     result = io.read_nonblock(maxlen)
  #   rescue IO::WaitReadable
  #     IO.select([io])
  #     retry
  #   end
  #
  # Although IO#read_nonblock doesn't raise IO::WaitWritable.
  # OpenSSL::Buffering#read_nonblock can raise IO::WaitWritable.
  # If IO and SSL should be used polymorphically,
  # IO::WaitWritable should be rescued too.
  # See the document of OpenSSL::Buffering#read_nonblock for sample code.
  #
  # Note that this method is identical to readpartial
  # except the non-blocking flag is set.
  #
  # By specifying `exception: false`, the options hash allows you to indicate
  # that read_nonblock should not raise an IO::WaitReadable exception, but
  # return the symbol :wait_readable instead.
  def read_nonblock(len, buf = nil, exception: true)
    __read_nonblock(len, buf, exception)
  end

  # call-seq:
  #    ios.write_nonblock(string)   -> integer
  #    ios.write_nonblock(string [, options])   -> integer
  #
  # Writes the given string to <em>ios</em> using
  # the write(2) system call after O_NONBLOCK is set for
  # the underlying file descriptor.
  #
  # It returns the number of bytes written.
  #
  # write_nonblock just calls the write(2) system call.
  # It causes all errors the write(2) system call causes: Errno::EWOULDBLOCK, Errno::EINTR, etc.
  # The result may also be smaller than string.length (partial write).
  # The caller should care such errors and partial write.
  #
  # If the exception is Errno::EWOULDBLOCK or Errno::EAGAIN,
  # it is extended by IO::WaitWritable.
  # So IO::WaitWritable can be used to rescue the exceptions for retrying write_nonblock.
  #
  #   # Creates a pipe.
  #   r, w = IO.pipe
  #
  #   # write_nonblock writes only 65536 bytes and return 65536.
  #   # (The pipe size is 65536 bytes on this environment.)
  #   s = "a"  #100000
  #   p w.write_nonblock(s)     #=> 65536
  #
  #   # write_nonblock cannot write a byte and raise EWOULDBLOCK (EAGAIN).
  #   p w.write_nonblock("b")   # Resource temporarily unavailable (Errno::EAGAIN)
  #
  # If the write buffer is not empty, it is flushed at first.
  #
  # When write_nonblock raises an exception kind of IO::WaitWritable,
  # write_nonblock should not be called
  # until io is writable for avoiding busy loop.
  # This can be done as follows.
  #
  #   begin
  #     result = io.write_nonblock(string)
  #   rescue IO::WaitWritable, Errno::EINTR
  #     IO.select(nil, [io])
  #     retry
  #   end
  #
  # Note that this doesn't guarantee to write all data in string.
  # The length written is reported as result and it should be checked later.
  #
  # On some platforms such as Windows, write_nonblock is not supported
  # according to the kind of the IO object.
  # In such cases, write_nonblock raises <code>Errno::EBADF</code>.
  #
  # By specifying `exception: false`, the options hash allows you to indicate
  # that write_nonblock should not raise an IO::WaitWritable exception, but
  # return the symbol :wait_writable instead.
  def write_nonblock(buf, exception: true)
    __write_nonblock(buf, exception)
  end
end
