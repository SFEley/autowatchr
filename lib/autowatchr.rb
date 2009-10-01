class Autowatchr
  class Config
    attr_writer :ruby, :include, :lib_dir, :test_dir, :lib_re, :test_re,
      :failed_results_re, :completed_re

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

    def lib_re
      @lib_re ||= '^%s.*/.*\.rb$' % self.lib_dir
    end

    def test_re
      @test_re ||= '^%s.*/test_.*\.rb$' % self.test_dir
    end

    def failed_results_re
      @failed_results_re ||= /^\s+\d+\) (?:Failure|Error):\n(.*?)\((.*?)\)/
    end

    def completed_re
      @completed_re ||= /\d+ tests, \d+ assertions, \d+ failures, \d+ errors/
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
    handle_results(results.join)
  end

  private
    def discover_files
      @test_files = Dir.glob("#{@config.test_dir}/**/*").grep(/#{@config.test_re}/)
    end

    def run_all_tests
      run_test_file(@test_files)
    end

    def start_watching_files
      @script.watch(@config.test_re) { |md| run_test_file(md[0]) }
      @script.watch(@config.lib_re)  { |md| run_lib_file(md[0]) }
    end

    def handle_results(results)
      failed = results.scan(@config.failed_results_re)
      debug_p failed.inspect, "failed"
      completed = results =~ @config.completed_re
      debug_p completed.inspect

      #self.files_to_test = consolidate_failures failed if completed

      #color = completed && self.files_to_test.empty? ? :green : :red
      #hook color unless $TESTING

      #self.tainted = true unless self.files_to_test.empty?
    end
end
