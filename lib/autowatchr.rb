class Autowatchr
  class Config
    attr_writer :ruby, :include, :lib_dir, :test_dir, :lib_regexp, :test_regexp
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

    def lib_regexp
      @lib_regexp ||= "^#{self.lib_dir}.*/.*\.rb$"
    end

    def test_regexp
      @test_regexp ||= "^#{self.test_dir}.*/test_.*\.rb$"
    end
  end

  attr_reader :config

  def initialize(script, options = {})
    @config = Config.new(options)
    yield @config  if block_given?
    @script = script
    @test_files = []

    discover_files
    run_all_tests
    start_watching_files
  end

  def run_lib_file(file)
    md = file.match(%r{^#{@config.lib_dir}#{File::SEPARATOR}?(.+)$})
    parts = md[1].split(File::SEPARATOR)
    parts[-1] = "test_#{parts[-1]}"
    file = "#{@config.test_dir}/" + File.join(parts)
    run_test_file(file)
  end

  def run_test_file(files)
    files = [files]   unless files.is_a?(Array)
    file_str = if files.length > 1
                 "-e \"%w[#{files.join(" ")}].each { |f| require f }\""
               else
                 files[0]
               end

    cmd = "%s -I%s %s" % [ @config.ruby, @config.include, file_str ]
    puts cmd

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
    def discover_files
      @test_files = Dir.glob("#{@config.test_dir}/**/*").grep(/#{@config.test_regexp}/)
    end

    def run_all_tests
      run_test_file(@test_files)
    end

    def start_watching_files
      @script.watch(@config.test_regexp) { |md| run_test_file(md[0]) }
      @script.watch(@config.lib_regexp)  { |md| run_lib_file(md[0]) }
    end
end
