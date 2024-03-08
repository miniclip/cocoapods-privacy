module Pod
  class Command
    class Privacy < Command

      def initialize(argv)
        super
      end

      def run
        if PrivacyUtils.isMainProject
          puts "Detected project file at #{PrivacyUtils.project_path || ""}. Please use 'pod privacy install' to create and automatically retrieve privacy manifests for the project."
        elsif PrivacyUtils.podspec_file_path
          puts "Detected component at #{PrivacyUtils.podspec_file_path || ""}. Please use 'pod privacy spec' to create and automatically retrieve privacy manifests for the component."
        else
          puts "No project or podspec file detected. Please switch to a directory containing a project or a podspec file and retry the command."
        end
      end      
    end
  end
end