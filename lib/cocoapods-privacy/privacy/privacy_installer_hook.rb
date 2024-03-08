require 'active_support/core_ext/string/inflections'
require 'fileutils'
require 'cocoapods/podfile'
require 'cocoapods-privacy/command'

module Pod
  class Installer
    # Directly execute `pod privacy` command
    def privacy_analysis(custom_folds)
      prepare
      resolve_dependencies
      clean_sandbox

      privacy_handle(custom_folds)
    end

    # Hook for `pod install` command
    alias_method :privacy_origin_install!, :install!
    def install!
      privacy_origin_install!()

      unless Pod::Config.instance.is_privacy || (Pod::Config.instance.privacy_folds && !Pod::Config.instance.privacy_folds.empty?)
        return
      end

      privacy_handle(Pod::Config.instance.privacy_folds)
    end

    def privacy_handle(custom_folds)
      puts "👇👇👇👇👇👇 Start analysis project privacy 👇👇👇👇👇👇"
      # Filter out the components that are needed and do not have a privacy protocol file
      modules = @analysis_result.specifications.select { 
        |obj| obj.is_need_search_module && !obj.has_privacy
      }
      
      # Store local debugging components
      development_folds = []
      exclude_folds = []

      # Get the component's project pods directory
      pod_folds = modules.map { |spec|
        name = spec.name.split('/').first
        fold = File.join(@sandbox.root, name)
        podspec_file_path_develop = validate_development_pods(name)

        # First verify if the component points to a local directory
        if podspec_file_path_develop
          podspec_fold_path = File.dirname(podspec_file_path_develop)
          source_files = spec.attributes_hash['source_files']
          exclude_files = spec.attributes_hash['exclude_files']
          if source_files && !source_files.empty?
            Array(source_files).each do |file|
              development_folds << File.join(podspec_fold_path, file)
            end

            # Handle exclude_files to exclude folders
            Array(exclude_files).each do |file|
              exclude_folds << File.join(podspec_fold_path, file)
            end
          end
          nil
        elsif Dir.exist?(fold)
          formatter_search_fold(fold) 
        end
      }.compact
    
      
      pod_folds += development_folds # Concatenate local debugging and remote pod directories
      pod_folds += [formatter_search_fold(PrivacyUtils.project_code_fold)].compact # Concatenate the project's main directory
      pod_folds += custom_folds || [] # Concatenate custom directories passed externally
      pod_folds = pod_folds.uniq # Remove duplicates

      if pod_folds.empty?
        puts "No component or project directory found, please check your project"
      else
        # Handle project privacy protocol
        PrivacyModule.load_project(pod_folds, exclude_folds.uniq)
      end
      puts "👆👆👆👆👆👆 End analysis project privacy 👆👆👆👆👆👆"
    end

    private
    def formatter_search_fold(fold)
      File.join(fold, "**", "*.{m,c,swift,mm,hap,hpp,cpp,c#}") 
    end

    def validate_development_pods(name)
      development_pods = @sandbox.development_pods
      podspec_file_path = development_pods[name] if name && development_pods[name]
      podspec_file_path
    end
  end
end