# Created by GitVers - Fill the commented stuff out yourself

require 'rubygems'
require 'rubygems/package_task'

spec = Gem::Specification.new do |gem|
    gem.name         = File.basename(`git rev-parse --show-toplevel`).chop
    gem.version      = `gitver version`
    
    gem.author       = `git config --get user.name`
    gem.email        = `git config --get user.email`
    gem.homepage     = "https://github.com/zerocool/fish.rb"
    gem.summary      = "A fish interpreter"
    gem.description  = "Ruby fish interpreter for the newer multi-stack version of fish"
    
    gem.files        = `git ls-files`.split($\)
    
    gem.bindir       = "./"
    gem.executables  = ["fish.rb"]
end

Gem::PackageTask.new(spec) do |pkg|
    pkg.gem_spec = spec
end
