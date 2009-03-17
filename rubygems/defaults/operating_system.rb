# This extension to RubyGems adds the following capabilities:
#   1) Gems are loaded from the Gem Path in order. The first location in the path that encounters a gem by the called name
#       will answer the request for the latest version. If a specific version is asked for, each location will be searched
#       in order for the first match.
#   2) Freeze versions of gems for your app by running Gem.freeze(name, version). Or, use the built-in freeze list files:
#       frozen_gems.txt in the runtime directory, or .frozen_gems in your user home directory. In those files simply list
#       the gem names and version requirements to freeze to, like "merb-core =1.0.7.1"
require 'rubygems/defaults/support/source_index_tree'

class Gem::SourceIndex
  class << self
    def from_gems_in(*spec_dirs)
      source_index = new
      source_index.spec_dirs = spec_dirs
      source_index
    end
  end

  attr_reader :parent
  def parent!
    @parent ||= self.class.new(@gems)
  end
  attr_reader :spec_dir
  def spec_dir=(path)
    @spec_dir = path
    @gems.spec_dir = path
    @spec_dirs = spec_dirs
  end
  # Creates a nested structure of SourceIndexes oldest ancestor being the last in the list, self being the youngest descendent.
  def spec_dirs=(paths)
    # Save the closest one for me,
    my_spec_dir = paths.shift
    # and assign the rest to my parent.
    parent!.spec_dirs = paths unless paths.empty?
    self.spec_dir = my_spec_dir
  end
  # Returns [spec_dir] + parent.spec_dirs.
  def spec_dirs
    @parent ? [@spec_dir] + parent.spec_dirs : [spec_dir]
  end

  def gems
    @gems.for(spec_dir)
  end

  ##
  # Constructs a source index instance from the provided
  # specifications
  #
  # specifications::
  #   [Hash] hash of [Gem name, Gem::Specification] pairs
  def initialize(gems_tree=nil)
    @gems = Tree.new(gems_tree)
    @spec_dirs = nil
  end

  def search(gem_pattern, platform_only = false)
    version_requirement = nil
    only_platform = false

    # TODO - Remove support and warning for legacy arguments after 2008/11
    unless Gem::Dependency === gem_pattern
      warn "#{Gem.location_of_caller.join ':'}:Warning: Gem::SourceIndex#search support for #{gem_pattern.class} patterns is deprecated"
    end

    case gem_pattern
    when Regexp then
      version_requirement = platform_only || Gem::Requirement.default
    when Gem::Dependency then
      only_platform = platform_only
      version_requirement = gem_pattern.version_requirements
      gem_pattern = if Regexp === gem_pattern.name then
                      gem_pattern.name
                    elsif gem_pattern.name.empty? then
                      //
                    else
                      /^#{Regexp.escape gem_pattern.name}$/
                    end
    else
      version_requirement = platform_only || Gem::Requirement.default
      gem_pattern = /#{gem_pattern}/i
    end

    unless Gem::Requirement === version_requirement then
      version_requirement = Gem::Requirement.create version_requirement
    end

    specs = find_specs_by_name_and_version(gem_pattern, version_requirement)

    if only_platform then
      specs = specs.select do |spec|
        Gem::Platform.match spec.platform
      end
    end

    specs.sort_by { |s| s.sort_obj }
  end

  def find_specs_by_name_and_version(gem_pattern, version_requirement)
    found = gems.values.select { |spec| spec.name =~ gem_pattern && version_requirement.satisfied_by?(spec.version) }
    found = (@parent ? @parent.find_specs_by_name_and_version(gem_pattern, version_requirement) : []) if found.empty?
    found
  end

  def each(&block) # :yields: gem.full_name, gem
    @gems.for(spec_dir).each(&block)
    @parent.each(&block) if @parent
  end

  def refresh!
    raise 'source index not created from disk' if @spec_dirs.nil?
    @gems.refresh!
  end
end

module Gem
  def self.freeze_list
    @@freeze_list ||= {}
  end
  def self.freeze_list=(hash)
    freeze_list.replace hash
  end

  def self.freeze(name, version)
    freeze_list[name] = version
  end

  ##
  # Array of paths to search for Gems.
  # Hack adds gems directory within current directory, if it is present.
  def self.path
    @gem_path ||= nil
  
    unless @gem_path then
      paths = [ENV['GEM_PATH'] || Gem.configuration.path || default_path]
  
      if defined?(APPLE_GEM_HOME) and not ENV['GEM_PATH'] then
        paths << APPLE_GEM_HOME
      end
      paths.unshift("#{Dir.pwd}/gems") if File.directory?("#{Dir.pwd}/gems") && File.directory?("#{Dir.pwd}/gems/specifications")
  
      set_paths paths.compact.join(File::PATH_SEPARATOR)
    end
  
    @gem_path
  end
end

# Now read the appropriate freeze files:

puts "Using rubygems-#{Gem::RubyGemsVersion}, extended for vhosts by BehindLogic."
["#{Gem.user_home}/.frozen_gems", "./frozen_gems.txt"].each do |frozen_file|
  if File.exists?(frozen_file)
    gem_dependencies = File.read(frozen_file)
    gem_dependencies.each_line do |line|
      name, version = line.split(/\s+/,2)
      if name && version
        puts "Freezing rubygems to #{name} #{version}"
        Gem.freeze name, version
      end
    end
  end
end
