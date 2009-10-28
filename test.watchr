require 'lib/autowatchr'

Autowatchr.new(self) do |config|
  config.test_re = "^#{config.test_dir}/test_\\w+.rb"
  config.require = "rubygems"   if Object.const_defined?(:Gem)
end
