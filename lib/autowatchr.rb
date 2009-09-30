class Autowatchr
  attr_writer :ruby, :include, :lib_dir, :test_dir

  def initialize(script, options = {})
    options.each_pair do |key, value|
      method = "#{key}="
      if self.respond_to?(method)
        self.send(method, value)
      end
    end
    yield self  if block_given?

    @script = script
    start_watching_files
  end

  def ruby
    @ruby ||= "ruby"
  end

  def include
    @include ||= ".:#{self.lib_dir}:#{self.test_dir}"
  end

  def lib_dir
    @lib_dir ||= "lib"
  end

  def test_dir
    @test_dir ||= "test"
  end

  def run_lib_file(file)
    md = file.match(%r{^#{@lib_dir}#{File::SEPARATOR}?(.+)$})
    parts = md[1].split(File::SEPARATOR)
    parts[-1] = "test_#{parts[-1]}"
    file = "#{@test_dir}/" + File.join(parts)
    run_test_file(file)
  end

  def run_test_file(file)
    cmd = "%s -I%s %s" % [ self.ruby, self.include, file ]

    # straight outta autotest
    results = []
    line = []
    open("| #{cmd}", "r") do |f|
      until f.eof? do
        c = f.getc
        putc c
        line << c
        if c == ?\n then
          results << if RUBY_VERSION >= "1.9" then
                       line.join
                      else
                        line.pack "c*"
                      end
          line.clear
        end
      end
    end
  end

  private
    def start_watching_files
      @script.watch("^#{self.test_dir}.*/test_.*\.rb") { |md| run_test_file(md[0]) }
      @script.watch("^#{self.lib_dir}.*/.*\.rb") { |md| run_lib_file(md[0]) }
    end
end
