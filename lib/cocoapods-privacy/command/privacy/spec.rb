module Pod
  class Command
    class Privacy < Command
      class Spec < Privacy
          self.summary = 'Create corresponding privacy manifest files based on the podspec'

          self.description = <<-DESC
              Create corresponding privacy manifest files based on the podspec and automatically modify the podspec file to map to the corresponding privacy manifest files.
          DESC

          self.arguments = [
              CLAide::Argument.new('podspec_file', false, true),
          ]

          def initialize(argv)
              @podspec_file = argv.arguments!.first
              super
          end

          def validate!
              @podspec_file = @podspec_file ? @podspec_file : PrivacyUtils.podspec_file_path
              unless @podspec_file && !@podspec_file.empty?
                raise Informative, 'No podspec file was found, please run pod privacy podspec_file_path'   
              end
          end

          def run
              PrivacyModule.load_module(@podspec_file)
          end
      end
    end
  end
end