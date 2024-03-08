require 'digest'

module PrivacyUtils

    def self.privacy_name
      'PrivacyInfo.xcprivacy'
    end
    
    # Determine if it is the main project by whether it contains a podspec
    def self.isMainProject
      !(podspec_file_path && !podspec_file_path.empty?)
    end

    # Find the podspec file
    def self.podspec_file_path
      base_path = Pathname.pwd
      matching_files = Dir.glob(File.join(base_path, '*.podspec'))
      matching_files.first
    end

    # Xcode project path
    def self.project_path
      matching_files = Dir[File.join(Pathname.pwd, '*.xcodeproj')].uniq
      matching_files.first
    end

    # Xcode project main code directory
    def self.project_code_fold
      projectPath = project_path
      File.join(Pathname.pwd,File.basename(projectPath, File.extname(projectPath)))
    end

    # Use regular expression to match the number of spaces before the first character
    def self.count_spaces_before_first_character(str)
      match = str.match(/\A\s*/)
      match ? match[0].length : 0
    end

    # Add a specified number of spaces using string multiplication
    def self.add_spaces_to_string(str, num_spaces)
      spaces = ' ' * num_spaces
      "#{spaces}#{str}"
    end

    def self.to_md5(string)
      md5 = Digest::MD5.new
      md5.update(string)
      md5.hexdigest
    end

    def self.cache_privacy_fold
      # Local cache directory
      cache_directory = File.expand_path('~/.cache')
      
      # Target folder path
      target_directory = File.join(cache_directory, 'cocoapods-privacy', 'privacy')

      # Create folder if it does not exist
      FileUtils.mkdir_p(target_directory) unless Dir.exist?(target_directory)

      target_directory
    end

    # Etag folder
    def self.cache_privacy_etag_fold
      File.join(cache_privacy_fold,'etag')
    end
    
    # config.json file
    def self.cache_config_file
      config_file = File.join(cache_privacy_fold, 'config.json')
    end

    # privacy.log file
    def self.cache_log_file
      config_file = File.join(cache_privacy_fold, 'privacy.log')
    end

    # Create default privacy protocol file
    def self.create_privacy_if_empty(file_path) 
      # File content
     file_content = <<~EOS
     <?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
       <key>NSPrivacyTracking</key>
       <false/>
       <key>NSPrivacyTrackingDomains</key>
       <array/>
       <key>NSPrivacyCollectedDataTypes</key>
       <array/>
       <key>NSPrivacyAccessedAPITypes</key>
       <array/>
     </dict>
     </plist>     
     EOS
   
     isCreate = create_file_and_fold_if_no_exit(file_path,file_content)
     if isCreate
       puts "【Privacy List】(Initialized) Storage Location => #{file_path}"
     end
   end
   
   # Create file, write default values, automatically create file path if it does not exist
   def self.create_file_and_fold_if_no_exit(file_path,file_content = nil)
     folder_path = File.dirname(file_path)
     FileUtils.mkdir_p(folder_path) unless File.directory?(folder_path)
   
     # Create file (if it does not exist or is empty)
     if !File.exist?(file_path) || File.zero?(file_path)
       File.open(file_path, 'w') do |file|
         file.write(file_content)
       end
       return true
     end 
     return false
   end

   # Check if there is a child group in the group with the specified path
   def self.find_group_by_path(group,path)
     result = nil
     sub_group = group.children
     if sub_group && !sub_group.empty?
       sub_group.each do |item|
         if item.path == path
           result = item
           break
         end
       end
     end
     result
   end

end