class Autowatch
  attr_writer :ruby, :include, :lib_dir, :test_dir

  def initialize(options = {})
    options.each_pair do |key, value|
      method = "#{key}="
      if self.respond_to?(method)
        self.send(method, value)
      end
    end
    yield self  if block_given?
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

  def run(file)
    if file =~ %r{^#{@lib_dir}#{File::SEPARATOR}?(.+)$}
      # lib file
      parts = $1.split(File::SEPARATOR)
      parts[-1] = "test_#{parts[-1]}"
      file = "#{@test_dir}/" + File.join(parts)
    end
    run_test_file(file)
  end

  private
    def run_test_file(file)
      cmd = "%s -I%s %s" % [ @ruby, @include, file ]
      open("| #{cmd}", "r") do |f|
      end
    end
end
