require 'erb'

class Autowatchr
  class Config
    attr_writer :command, :ruby, :include, :require, :lib_dir, :test_dir,
      :lib_re, :test_re, :test_file, :failed_results_re, :completed_re, 
      :failing_only, :run_suite

    def initialize(options = {})
      @failing_only = @run_suite = true

      options.each_pair do |key, value|
        method = "#{key}="
        if self.respond_to?(method)
          self.send(method, value)
        end
      end
    end

    def command
      @command ||= "<%= ruby %> -I<%= include %> <% list_of_requires.each { |lib| %>-r<%= lib %> <% } %><%= predicate %>"
    end

    def ruby
      @ruby ||= "ruby"
    end

    def include
      @include ||= ".:#{self.lib_dir}:#{self.test_dir}"
    end

    def require
      @require
    end

    def list_of_requires
      if @require.nil? || @require.empty?
        []
      elsif @require.is_a?(Array)
        @require
      else
        [@require]
      end
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
    
    def test_file
      @test_file ||= 'test_%s.rb'
    end

    def failed_results_re
      @failed_results_re ||= /^\s+\d+\) (?:Failure|Error):\n(.*?)\((.*?)\)/
    end

    def completed_re
      @completed_re ||= /\d+ tests, \d+ assertions, \d+ failures, \d+ errors/
    end

    def failing_only
      @failing_only
    end

    def run_suite
      @run_suite
    end

    def eval_command(predicate)
      ERB.new(self.command).result(binding)
    end
  end

  class Tee < StringIO
    attr_reader :io
    def initialize(io)
      super("")
      @io = io
    end

    def write(string)
      super
      @io.write(string)
    end
  end

  attr_reader :config

  def initialize(script=nil, options = {})
    @config = Config.new(options)
    yield @config  if block_given?
    @script = script || self
    @test_files = []
    @failed_tests = {}

    discover_files
    run_all_tests
    start_watching_files
  end

  def run_lib_file(file)
    md = file.match(%r{^#{@config.lib_dir}#{File::SEPARATOR}?(.+)$})
    parts = md[1].split(File::SEPARATOR)
    parts[-1] = config.test_file % File.basename(parts[-1],'.rb')
    file = "#{@config.test_dir}/" + File.join(parts)
    run_test_file(file)
  end

  def run_test_file(files)
    files = [files]   unless files.is_a?(Array)

    passing  = []
    commands = []
    files.each do |file|
      tests = @failed_tests[file]
      if tests && !tests.empty?
        predicate = %!#{file} -n "/^(#{tests.join("|")})$/"!
        commands << @config.eval_command(predicate)
      else
        passing << file
      end
    end

    if !passing.empty?
      predicate = if passing.length > 1
                    "-e \"%w[#{passing.join(" ")}].each do |f| require f end\""
                  else
                    passing[0]
                  end
      commands.unshift(@config.eval_command(predicate))
    end

    cmd = commands.join("; ")
    puts cmd

    results = execute_cmd(cmd)
    handle_results(results, files)
  end

  def classname_to_path(s)
    File.join(@config.test_dir, underscore(s)+".rb")
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

    def execute_cmd(cmd)
      tee = Tee.new($stdout)
      $stdout = tee

      system(cmd)

      $stdout = tee.io
      tee.rewind
      results = tee.read
      tee.close

      results
    end

    def handle_results(results, files_ran)
      return  if !@config.failing_only
      num_previously_failed = @failed_tests.length

      failed = results.scan(@config.failed_results_re)
      completed = results =~ @config.completed_re

      previously_failed = @failed_tests.keys & files_ran
      failed.each do |(test_name, class_name)|
        key = classname_to_path(class_name)
        if files_ran.include?(key)
          @failed_tests[key] ||= []
          @failed_tests[key] |= [test_name]
          previously_failed.delete(key)
        else
          puts "Couldn't map class to file: #{class_name}"
        end
      end

      previously_failed.each do |file|
        @failed_tests.delete(file)
      end

      if @config.run_suite && @failed_tests.empty? && num_previously_failed > 0
        run_all_tests
      end
    end

    # File vendor/rails/activesupport/lib/active_support/inflector.rb, line 206
    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end
    
end
