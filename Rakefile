require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "harukaze"
    gem.summary = %Q{iPhone Ad Hoc / App Store builds made easy.}
    gem.description = %Q{A tool to simplify building of your iPhone app for ad hoc distribution or submitting to the App Store.}
    gem.email = "andrey@subbotin.me"
    gem.homepage = "http://github.com/eploko/harukaze"
    gem.authors = ["Andrey Subbotin"]
    gem.executables = ['harukaze']
    gem.default_executable = ['harukaze']    
    gem.add_dependency "term-ansicolor"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end
