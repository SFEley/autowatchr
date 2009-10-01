require 'lib/autowatchr'

Autowatchr.new(self) do |config|
  config.test_re = "^#{config.test_dir}/test_\\w+.rb"
end
