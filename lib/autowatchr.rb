class Autowatchr
  class Config
    attr_writer :ruby, :include, :lib_dir, :test_dir
    def initialize(options = {})
      options.each_pair do |key, value|
        method = "#{key}="
        if self.respond_to?(method)
          self.send(method, value)
        end
      end
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
  end

  attr_reader :config
  attr_accessor :interrupted, :wants_to_quit

  def initialize(script, options = {})
    @config = Config.new(options)
    yield @config  if block_given?
    @script = script
    start_watching_files
  end

  def run_lib_file(file)
    md = file.match(%r{^#{@config.lib_dir}#{File::SEPARATOR}?(.+)$})
    parts = md[1].split(File::SEPARATOR)
    parts[-1] = "test_#{parts[-1]}"
    file = "#{@config.test_dir}/" + File.join(parts)
    run_test_file(file)
  end

  def run_test_file(file)
    cmd = "%s -I%s %s" % [ @config.ruby, @config.include, file ]

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
      @script.watch("^#{@config.test_dir}.*/test_.*\.rb") { |md| run_test_file(md[0]) }
      @script.watch("^#{@config.lib_dir}.*/.*\.rb") { |md| run_lib_file(md[0]) }
    end
end
