require 'cocoapods-privacy/command'

module Pod
  class Command
    class Privacy < Command
      class Config < Privacy
          self.summary = 'Initialize privacy manifest configuration'
  
          self.description = <<-DESC
              Initialize privacy manifest configuration, including the necessary privacy API template, source whitelist and blacklist, etc. See the configuration file format in detail at #{"https://github.com/ymoyao/cocoapods-privacy"}
          DESC
      
          def initialize(argv)
              @config = argv.shift_argument
              super
          end
      
          def validate!
              super
              help! 'A config url is required.' unless @config
              raise Informative, "The configuration file format is not JSON, please check your configuration #{@config}" unless @config.end_with?(".json")                
          end

          def run
            load_config_file()
          end

          def load_config_file
            # Check if @config is a remote URL or a local file path
            if @config.start_with?('http')
              download_remote_config
            else
              copy_local_config
            end
          end
          
          def download_remote_config
            # Configuration file directory
            cache_config_file = PrivacyUtils.cache_config_file

            # Start download
            system("curl -o #{cache_config_file} #{@config}")

            if File.exist?(cache_config_file)
              puts "Configuration file downloaded to: #{cache_config_file}"
            else
              raise Informative, "Error downloading the configuration file, please check the download URL #{@config}"
            end
          end
          
          def copy_local_config
            # Configuration file directory
            cache_config_file = PrivacyUtils.cache_config_file
          
            # Copy local file
            FileUtils.cp(@config, cache_config_file)
          
            puts "Configuration file copied to: #{cache_config_file}"
          end
      end
    end
  end
end