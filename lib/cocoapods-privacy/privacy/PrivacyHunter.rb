require 'json'
require 'cocoapods-privacy/command'

##
# Features:
# 1. Check if the local privacy protocol template is up to date. If not, download the remote privacy protocol template.
# 2. Use the template to search the specified folders.
# 3. Convert the found content into the privacy protocol format and write it to the PrivacyInfo.xcprivacy file.
##
module PrivacyHunter

  KTypes = "NSPrivacyAccessedAPITypes"
  KType = "NSPrivacyAccessedAPIType"
  KReasons = "NSPrivacyAccessedAPITypeReasons"
  KAPI = "NSPrivacyAccessedAPI"

  # Formats the privacy template from the plist file
  def self.formatter_privacy_template
    # Template data source plist file
    template_plist_file = fetch_template_plist_file

    # Read and parse the data source plist file
    json_str = `plutil -convert json -o - "#{template_plist_file}"`.chomp
    map = JSON.parse(json_str)
    type_datas = map[KTypes]

    apis = {}
    keyword_type_map = {} # {systemUptime: NSPrivacyAccessedAPICategorySystemBootTime, mach_absolute_time: NSPrivacyAccessedAPICategorySystemBootTime, ...}
    type_datas.each do |value|
      type = value[KType]
      apis_inner = value[KAPI]
      apis_inner.each do |keyword, reason|
        keyword_type_map[keyword] = type
      end
      apis = apis.merge(apis_inner)
    end
    [apis, keyword_type_map]
  end

  # Searches for privacy APIs in the source folders
  def self.search_pricacy_apis(source_folders, exclude_folders=[])
    apis, keyword_type_map = formatter_privacy_template

    # Optimize the search to complete in one loop
    datas = []
    apis_found = search_files(source_folders, exclude_folders, apis)
    unless apis_found.empty?
      apis_found.each do |keyword, reason|
        reasons = reason.split(',')
        type = keyword_type_map[keyword]
        
        # If data exists, add reasons to data
        datas.map! do |data|
          if data[KType] == type
            data[KReasons] += reasons
            data[KReasons] = data[KReasons].uniq
          end
          data
        end

        # If no data exists, create new data
        unless datas.any? { |data| data[KType] == type }
          data = {}
          data[KType] = type
          data[KReasons] ||= []
          data[KReasons] += reasons
          data[KReasons] = data[KReasons].uniq
          datas.push(data)
        end
      end
    end

    # Print the search results
    puts datas

    # Convert to JSON string
    json_data = datas.to_json
  end

  # Writes JSON data to the privacy file
  def self.write_to_privacy(json_data, privacy_path)
    # Convert JSON to plist format
    plist_data = `echo '#{json_data}' | plutil -convert xml1 - -o -`

    # Create a temporary file
    temp_plist = File.join(PrivacyUtils.cache_privacy_fold, "#{PrivacyUtils.to_md5(privacy_path)}.plist")
    File.write(temp_plist, plist_data)

    # Get the existing NSPrivacyAccessedAPITypes data from the original file
    origin_privacy_data = `/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes' '#{privacy_path}' 2>/dev/null`
    new_privacy_data = `/usr/libexec/PlistBuddy -c 'Print' '#{temp_plist}'`

    # Check if the new data matches the original data
    if origin_privacy_data.strip == new_privacy_data.strip
      puts "#{privacy_path} data is consistent, no insertion needed."
    else
      unless origin_privacy_data.strip.empty?
        # Delete the :NSPrivacyAccessedAPITypes key
        system("/usr/libexec/PlistBuddy -c 'Delete :NSPrivacyAccessedAPITypes' '#{privacy_path}'")
      end

      # Add the :NSPrivacyAccessedAPITypes key and set it as an array
      system("/usr/libexec/PlistBuddy -c 'Add :NSPrivacyAccessedAPITypes array' '#{privacy_path}'")

      # Merge JSON data into the privacy file
      system("/usr/libexec/PlistBuddy -c 'Merge #{temp_plist} :NSPrivacyAccessedAPITypes' '#{privacy_path}'")

      puts "NSPrivacyAccessedAPITypes data has been inserted."
    end

    # Delete the temporary file
    File.delete(temp_plist)
  end

  private

  # Fetches the template plist file
  def self.fetch_template_plist_file
    unless File.exist?(PrivacyUtils.cache_config_file)
      raise Pod::Informative, "Configuration file missing, run `pod privacy config config_file` to configure."
    end

    template_url = Privacy::Config.instance.api_template_url
    unless template_url && !template_url.empty?
      raise Pod::Informative, "The configuration file lacks an `api.template.url` entry, please complete it before updating the configuration with `pod privacy config config_file`."
    end

    # Target file path
    local_file_path = File.join(PrivacyUtils.cache_privacy_fold, 'NSPrivacyAccessedAPITypes.plist')
    
    # Get the update time of the remote file
    remote_file_time, etag = remoteFile?(template_url)

    # Check if the local file's last modification time matches the remote file's time; if so, no download is needed
    if File.exist?(local_file_path) && file_identical?(local_file_path, remote_file_time, etag)
    else
      # Use curl to download the file
      system("curl -o #{local_file_path} #{template_url}")
      puts "Privacy protocol template file has been updated to: #{local_file_path}"

      # Sync the remote file identifier (time or etag)
      syncFile?(local_file_path, remote_file_time, etag)
    end
    
    local_file_path
  end

  # Gets the update time of the remote file
  def self.remoteFile?(remote_url)
    uri = URI.parse(remote_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    response = http.request_head(uri.path)

    last_modified = response['Last-Modified']
    etag = response['ETag']

    [last_modified, etag]
  end

  # Checks if the local file's last modification time matches the remote file's
  def self.file_identical?(local_file_path, remote_file_time, etag) 
    if remote_file_time
      remote_file_time && Time.parse(remote_file_time) == File.mtime(local_file_path)
    elsif etag
      File.exist?(File.join(PrivacyUtils.cache_privacy_etag_fold, etag))
    else
      false
    end
  end

  # Syncs the file identifier
  def self.syncFile?(local_file_path, remote_file_time, etag)
    if remote_file_time
      syncFileTime?(local_file_path, remote_file_time)
    elsif etag
      PrivacyUtils.create_file_and_fold_if_no_exit(File.join(PrivacyUtils.cache_privacy_etag_fold, etag))
    end
  end

  # Syncs the remote file time to the local file
  def self.syncFileTime?(local_file_path, remote_file_time)
    File.utime(File.atime(local_file_path), Time.parse(remote_file_time), local_file_path)
  end

  # Checks if a file contains specified APIs
  def self.contains_apis?(file_path, apis)
    file_content = File.read(file_path)
    apis_found = {}
    apis.each do |keyword, value|
      if file_content.include?(keyword)
        apis_found[keyword] = value
      end
    end

    apis_found
  end

  # Searches all subfolders for files
  def self.search_files(folder_paths, exclude_folders, apis)
    # Retrieve all files (including subfolders) in the specified folders
    all_files = []
    folder_paths.each do |folder|
      files_in_folder = Dir.glob(folder, File::FNM_DOTMATCH)
      # Filter out directories, keeping only file paths, and add them to all_files
      all_files += files_in_folder.reject { |file| File.directory?(file) }
    end

    # Retrieve files to exclude
    exclude_files = []
    exclude_folders.each do |folder|
      files_in_folder = Dir.glob(folder, File::FNM_DOTMATCH)
      exclude_files += files_in_folder.reject { |file| File.directory?(file) }
    end

    # Exclude the files that need to be excluded
    all_files = all_files.uniq - exclude_files.uniq

    # Iterate over files to search
    apis_found = {}
    all_files.each do |file_path|
      api_contains = contains_apis?(file_path, apis)
      apis_found = apis_found.merge(api_contains)
      
      unless api_contains.empty?
        log = "File #{file_path} contains the keyword '#{api_contains.keys}'.\n" 
        PrivacyLog.write_to_result_log(log)
      end
    end
    PrivacyLog.write_to_result_log("\n") unless apis_found.empty?
    apis_found
  end
end