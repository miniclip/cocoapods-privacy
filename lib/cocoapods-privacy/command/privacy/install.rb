module Pod
  class Command
    class Privacy < Command
      class Install < Privacy
          self.summary = 'Create corresponding privacy manifest files in the project'

          self.description = <<-DESC
              1. Create privacy manifest files in the Resources folder of the project.
              2. Search for corresponding components and complete the privacy API sections.
              3. Only handles the privacy API sections, privacy permissions must be managed separately!!!
          DESC

          def self.options
              [
                ["--folds=folds", 'Enter custom search folders, use “,” to separate multiple directories'],
              ].concat(super)
          end

          def initialize(argv)
              @folds = argv.option('folds', '').split(',')
              super
          end
  
          def run
              verify_podfile_exists!

              installer = installer_for_config
              installer.repo_update = false
              installer.update = false
              installer.deployment = false
              installer.clean_install = false
              installer.privacy_analysis(@folds)
          end
      end
    end
  end
end