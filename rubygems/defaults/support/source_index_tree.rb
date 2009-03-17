class Gem::SourceIndex::Tree
  include Enumerable

  def initialize
    refresh!
  end

  attr_reader :spec_dir
  def spec_dir=(value)
    @spec_dir = value
    if @partial_hash
      @hash[@spec_dir] = @partial_hash
      @partial_hash = nil
    end
  end

  def inspect
    "{SourceIndexTree: #{@hash[@spec_dir].inspect[1..-2]}}"
  end

  def for(key)
    @hash[key]
  end

  def [](key)
    @hash[@spec_dir][key]
  end
  def []=(key,value)
    @hash[@spec_dir][key] = value
  end

  def delete(key)
    @hash[@spec_dir].delete(key)
  end

  def each(&block)
    @hash[@spec_dir].each(&block)
  end

  def keys
    @hash[@spec_dir].keys
  end

  def values
    @hash[@spec_dir].values
  end

  def size
    @hash[@spec_dir].size
  end

  def clear
    @hash.delete(@spec_dir)
  end

  def refresh!
    @hash = Hash.new do |h,spec_dir|
      h[spec_dir] = Dir.glob(File.join(spec_dir, '*.gemspec')).inject({}) do |gems,spec_file|
        if gemspec = Gem::SourceIndex.load_specification(spec_file.untaint)
          if Gem.freeze_list.has_key?(gemspec.name)
            version_requirement = Gem::Requirement.create Gem.freeze_list[gemspec.name]
            gems[gemspec.full_name] = gemspec if version_requirement.satisfied_by? gemspec.version
          else
            gems[gemspec.full_name] = gemspec
          end
        end
        gems
      end
    end
  end

  # This is rather unstable. We're not really sure what you want to do in most cases... It should work though.
  def replace(tree)
    if tree.instance_variable_get(:@partial_hash).is_a?(Hash)
      tree = tree.instance_variable_get(:@partial_hash)
    elsif tree.instance_variable_get(:@hash).is_a?(Hash)
      tree = tree.instance_variable_get(:@hash)
    end
    @hash[@spec_dir].replace(tree)
  end
end
