require 'cocoapods-privacy/command'

module PrivacyLog

  # Displays a tip for the log file location
  def self.result_log_tip
    puts "For detailed log, please check the file at #{PrivacyUtils.cache_log_file}"
  end

  # Writes results to the log file
  def self.write_to_result_log(log)
    log_file_path = PrivacyUtils.cache_log_file
    # Attempt to create the file and folder if they do not exist, and write the initial log
    is_create = PrivacyUtils.create_file_and_fold_if_no_exit(log_file_path, log)
    # If the file already exists, append the new log
    unless is_create
      File.open(log_file_path, "a") do |file|
        file << log
      end
    end
  end

  # Clears the result log file
  def self.clean_result_log
    File.open(PrivacyUtils.cache_log_file, "w") do |file|
      # Write an empty string to clear the file content
      file.write("")
    end
  end
end