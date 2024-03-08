require 'cocoapods-core/specification/root_attribute_accessors'

module Pod
  class Specification

    # Checks if the specification has a privacy protocol file
    def has_privacy
      resource_bundle = attributes_hash['resource_bundles']
      resource_bundle && resource_bundle.to_s.include?('PrivacyInfo.xcprivacy')
    end

    # Determines if the module should be searched
    def is_need_search_module
      unless File.exist?(PrivacyUtils.cache_config_file)
        raise Informative, "Configuration file missing, run `pod privacy config config_file` to configure."
      end

      # Find the source (might be a subspec)
      git_source = recursive_git_source(self)
      unless git_source
        return false
      end

      # Determine if the git source is whitelisted or blacklisted, ensuring the component is owned and not a third-party SDK
      config = Privacy::Config.instance          
      git_source_whitelisted = config.source_white_list.any? { |item| git_source.include?(item) }
      git_source_blacklisted = config.source_black_list.any? { |item| git_source.include?(item) }
      git_source_whitelisted && !git_source_blacklisted
    end

    # Returns the resource_bundles
    def bb_resource_bundles
      hash_value['resource_bundles']
    end

    private
    # Recursively finds the git source of the specification
    def recursive_git_source(spec)
      return nil unless spec
      if spec.source && spec.source.key?(:git)
        spec.source[:git]
      else
        recursive_git_source(spec.instance_variable_get(:@parent))
      end
    end
  end
end