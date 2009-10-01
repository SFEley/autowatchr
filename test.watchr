require 'lib/autowatchr'

Autowatchr.new(self) do |config|
  config.test_regexp = "^#{config.test_dir}/test_\\w+.rb"
end
