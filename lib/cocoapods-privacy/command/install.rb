require 'cocoapods-privacy/command'

module Pod
    class Config
        attr_accessor :privacy_folds  # Stores the folders to search for privacy information
        attr_accessor :is_privacy  # Indicates whether the privacy option is enabled
    end
end

module Pod
    class Command
      class Install < Command
        class << self
          alias_method :origin_options, :options
          def options
            [
            ['--privacy', 'Use this option to automatically generate and update PrivacyInfo.xcprivacy'],
            ['--privacy-folds=folds', 'Specify folders for searching, separate multiple folders with a comma ","'],
            ].concat(origin_options)
          end
        end
  
        alias_method :privacy_origin_initialize, :initialize
        def initialize(argv)
          privacy_folds = argv.option('privacy-folds', '').split(',')  # Retrieves the specified privacy folders
          is_privacy = argv.flag?('privacy',false)  # Checks if the privacy option is enabled
          privacy_origin_initialize(argv)  # Calls the original initialize method
          instance = Pod::Config.instance  # Gets the singleton instance of the configuration
          instance.privacy_folds = privacy_folds  # Sets the privacy folders in the configuration
          instance.is_privacy = is_privacy  # Sets the privacy flag in the configuration
        end
      end
    end
end