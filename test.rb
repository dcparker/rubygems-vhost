require 'rubygems'
Gem.freeze 'merb-core', '>1.0.3'
gem 'merb-core', '<1.0.7.1'
require 'merb-core'
require 'days_and_times'
puts "Loaded Gems:\n#{Gem.loaded_specs.collect {|key,spec| spec.full_gem_path}.join("\n")}"
