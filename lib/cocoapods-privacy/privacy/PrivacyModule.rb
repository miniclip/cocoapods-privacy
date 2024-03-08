require 'cocoapods-privacy/command'
require 'cocoapods-core/specification/dsl/attribute_support'
require 'cocoapods-core/specification/dsl/attribute'
require 'xcodeproj'

KSource_Files_Key = 'source_files' # Singular form does not exist for source_file
KExclude_Files_Key = 'exclude_files' # Singular form does not exist for exclude_file
KResource_Bundle_Key = 'resource_bundle' # Both resource_bundle and resource_bundles essentially refer to the same parameters, and resource_bundle can also point to multiple parameters

class BBRow
  attr_accessor  :content, :is_comment, :is_spec_start, :is_spec_end, :key, :value

  def initialize(content, is_comment=false, is_spec_start=false, is_spec_end=false)
    @content = content
    @is_comment = is_comment
    @is_spec_start = is_spec_start
    @is_spec_end = is_spec_end

    parse_key_value
  end

  def parse_key_value
    # Add logic here to extract key and value
    if @content.include?('=')
      key_value_split = @content.split('=')
      @key = key_value_split[0]
      @value = key_value_split[1..-1].join('=')
    else
      @key = nil
      @value = nil
    end
  end
end

class BBSpec
  attr_accessor :name, :alias_name, :full_name, :parent, :rows, :privacy_sources_files, :privacy_exclude_files, :privacy_file

  def initialize(name, alias_name, full_name)
    @rows = []
    @name = name
    @alias_name = alias_name
    @full_name = full_name
    @privacy_file = "Pod/Privacy/#{full_name}/PrivacyInfo.xcprivacy"
  end


  def uniq_full_name_in_parent(name)
    names = []
    @rows.each_with_index do |line, index|
      if line && line.is_a?(BBSpec)  
        names << line.name
      end
    end

    # Check if names contain name, if so, add a ".diff" suffix to name until name is not included in names
    while names.include?(name)
      name = "#{name}.diff"
    end

    "#{@full_name}.#{name}"
  end

  # Convert singular properties to spec strings for easy parsing
  def assemble_single_property_to_complex(property_name)
    property_name += "s" if property_name == KResource_Bundle_Key # If a singular resource_bundle is detected, convert it directly to a plural one with the same functionality
    property_name
  end

  def privacy_handle(podspec_file_path)
    @rows.each_with_index do |line, index|
      if !line || line.is_a?(BBSpec) || !line.key || line.key.empty? 
        next
      end
       
      if !line.is_comment && line.key.include?("." + KResource_Bundle_Key)
        @has_resource_bundle = true
      elsif !line.is_comment && line.key.include?("." + KSource_Files_Key)
        @source_files_index = index
      end
    end
    create_privacy_file_if_need(podspec_file_path)
    modify_privacy_resource_bundle_if_need(podspec_file_path)
  end

  # Create privacy file corresponding to Spec if needed
  def create_privacy_file_if_need(podspec_file_path)
    if @source_files_index
      PrivacyUtils.create_privacy_if_empty(File.join(File.dirname(podspec_file_path), @privacy_file))
    end
  end

  # Parse all multiline parameters, currently handling source_files, exclude_files, and resource_bundle
  # Input format ['.source_files':false,'.exclude_files':true......] => true indicates that excess multiline content needs to be deleted based on the acquired reset properties
  # Return format {'.source_files':BBRow,......}
  def fetch_mul_line_property(propertys_mul_line_hash)
    property_hash = {}
    line_processing = nil
    property_config_processing = nil
    @rows.each_with_index do |line, index|
      if !line || line.is_a?(BBSpec) || line.is_comment
        next
      end

      property_find = propertys_mul_line_hash.find { |key, _| line.key && line.key.include?(key) } # Returns nil if not found, returns an array if found, where key and value are in the first and second parameters respectively
      if property_find
        property_config_processing = property_find 
      end

      if property_config_processing
        begin
          property_name = property_config_processing.first
          is_replace_line = property_config_processing.second
          if line_processing
            code = "#{line_processing.value}#{line.content}"
          else
            code = "#{line.value}"
          end

          # Clear content and value, all content will be assembled later, excess content needs to be cleared to avoid duplication
          if is_replace_line
            line.content = ''
            line.value = nil
          end

          property_name_complex = assemble_single_property_to_complex(property_name)
          spec_str = "Pod::Spec.new do |s|; s.#{property_name_complex} = #{code}; end;"
          RubyVM::InstructionSequence.compile(spec_str)
          spec = eval(spec_str)
          property_value = spec.attributes_hash[property_name_complex]
        rescue SyntaxError, StandardError => e
          unless line_processing
            line_processing = line
          end
          line_processing.value = code if line_processing # Store the current incomplete value and concatenate it with the complete one later
          next
        end

        final_line = (line_processing ? line_processing : line)
        final_line.value = property_value
        property_hash[property_name] = final_line
        line_processing = nil
        property_config_processing = nil
      end
    end

    property_hash
  end

  # Handle strings or arrays, convert them all to arrays, and convert them to actual folder addresses
  def handle_string_or_array_files(podspec_file_path, line)
    value = line.value
    if value.is_a?(String) && !value.empty?
      array = [value]
    elsif value.is_a?(Array)
      array = value
    else
      array = []
    end
  
    files = array.map do |file_path|
      File.join(File.dirname(podspec_file_path), file_path.strip)
    end
    files
  end

  # Map newly added privacy files to podspec and parse privacy_sources_files and privacy_exclude_files
  def modify_privacy_resource_bundle_if_need(podspec_file_path)
    if @source_files_index
      privacy_resource_bundle = { "#{full_name}.privacy" => @privacy_file }

      # Parse all multiline parameters here, currently handling source_files, exclude_files, resource_bundle
      propertys_mul_line_hash = {}
      propertys_mul_line_hash[KSource_Files_Key] = false
      propertys_mul_line_hash[KExclude_Files_Key] = false
      if @has_resource_bundle
        propertys_mul_line_hash[KResource_Bundle_Key] = true # Requires generation of reset properties
      else # If there was no original resource_bundle, a separate resource_bundle line needs to be added
        space = PrivacyUtils.count_spaces_before_first_character(rows[@source_files_index].content)
        line = "#{alias_name}.resource_bundle = #{privacy_resource_bundle}"
        line = PrivacyUtils.add_spaces_to_string(line, space)
        row = BBRow.new(line)
        @rows.insert(@source_files_index+1, row)
      end
      property_value_hash = fetch_mul_line_property(propertys_mul_line_hash)
      property_value_hash.each do |property, line|
        if property == KSource_Files_Key                 # Handle source_files
          @privacy_sources_files = handle_string_or_array_files(podspec_file_path, line)
        elsif property == KExclude_Files_Key             # Handle exclude_files
          @privacy_exclude_files = handle_string_or_array_files(podspec_file_path, line)
        elsif property == KResource_Bundle_Key           # Handle original resource_bundle and merge privacy manifest file mapping
          merged_resource_bundle = line.value.merge(privacy_resource_bundle)
          @resource_bundle = merged_resource_bundle
          line.value = merged_resource_bundle
          line.content = "#{line.key}= #{line.value}"
        end
      end
    end
  end
end


module PrivacyModule

  public

  # Process project
  def self.load_project(folds, exclude_folds)
    project_path = PrivacyUtils.project_path()
    resources_folder_path = File.join(File.basename(project_path, File.extname(project_path)),'Resources')
    privacy_file_path = File.join(resources_folder_path, PrivacyUtils.privacy_name)
    # If privacy file does not exist, create a privacy protocol template
    unless File.exist?(privacy_file_path) 
      PrivacyUtils.create_privacy_if_empty(privacy_file_path)
    end
    
    # If there is no privacy file, create one and add it to the project
    # Open the Xcode project, create it under Resources
    project = Xcodeproj::Project.open(File.basename(project_path))
    main_group = project.main_group
    resources_group = main_group.find_subpath('Resources', false)
    if resources_group.nil?
      resources_group = main_group.new_group('Resources', resources_folder_path)
    end

    # If there is no reference, create a new Xcode reference
    if resources_group.find_file_by_path(PrivacyUtils.privacy_name).nil?
      privacy_file_ref = resources_group.new_reference(PrivacyUtils.privacy_name, :group)
      privacy_file_ref.last_known_file_type = 'text.xml'
      target = project.targets.first
      resources_build_phase = target.resources_build_phase
      resources_build_phase.add_file_reference(privacy_file_ref) # Add file reference to resources build phase
    end
    
    project.save

    # Start searching for APIs and return JSON string data
    PrivacyLog.clean_result_log()
    json_data = PrivacyHunter.search_pricacy_apis(folds, exclude_folds)

    # Write data to privacy manifest file
    PrivacyHunter.write_to_privacy(json_data, privacy_file_path)
    PrivacyLog.result_log_tip()
  end

  # Process module
  def self.load_module(podspec_file_path)
    puts "👇👇👇👇👇👇 Start analysis component privacy 👇👇👇👇👇👇"
    PrivacyLog.clean_result_log()
    privacy_hash = PrivacyModule.check(podspec_file_path)
    privacy_hash.each do |privacy_file_path, hash|
      PrivacyLog.write_to_result_log("#{privacy_file_path}: \n")
      source_files = hash[KSource_Files_Key]
      exclude_files = hash[KExclude_Files_Key]
      data = PrivacyHunter.search_pricacy_apis(source_files, exclude_files)
      PrivacyHunter.write_to_privacy(data, privacy_file_path) unless data.empty?
    end
    PrivacyLog.result_log_tip()
    puts "👆👆👆👆👆👆 End analysis component privacy 👆👆👆👆👆👆"
  end

  def self.check(podspec_file_path)
      # Step 1: Read podspec
      lines = read_podspec(podspec_file_path)
      
      # Step 2: Parse line by line and convert to BBRow model
      rows = parse_row(lines)

      # Step 3.1: If Row belongs to Spec, gather them into BBSpec,
      # Step 3.2: Store rows inside BBSpec using arrays
      # Step 3.3: Create a privacy template for each valid spec and modify its podspec reference
      combin_sepcs_and_rows = combin_sepc_if_need(rows, podspec_file_path)

      # Step 4: Unfold modified Spec, reconvert to BBRow
      rows = unfold_sepc_if_need(combin_sepcs_and_rows)

      # Step 5: Open privacy template, modify its podspec file, and write line by line
      File.open(podspec_file_path, 'w') do |file|
        # Write rows line by line
        rows.each do |row|
          file.puts(row.content)
        end
      end

      # Step 6: Get privacy related information and pass it to subsequent processing
      privacy_hash = fetch_privacy_hash(combin_sepcs_and_rows, podspec_file_path).compact
      filtered_privacy_hash = privacy_hash.reject { |_, value| value.empty? }
      filtered_privacy_hash
  end

  private
  def self.read_podspec(file_path)
    File.readlines(file_path)
  end
  
  def self.parse_row(lines)
    rows = []  
    code_stack = [] # Stack, used to exclude interference from 'if', 'end', etc. on the spec

    lines.each do |line|
      content = line.strip
      is_comment = content.start_with?('#')
      is_spec_start = !is_comment && (content.include?('Pod::Spec.new') || content.include?('.subspec'))
      is_if = !is_comment && content.start_with?('if')  
      is_end = !is_comment && content.start_with?('end')

      # Exclude interference from 'if' and 'end' on spec_end
      code_stack.push('spec') if is_spec_start 
      code_stack.push('if') if is_if 
      stack_last = code_stack.last 
      is_spec_end = is_end && stack_last && stack_last == 'spec'
      is_if_end = is_end && stack_last && stack_last == 'if'
      code_stack.pop if is_spec_end || is_if_end

      row = BBRow.new(line, is_comment, is_spec_start, is_spec_end)
      rows << row
    end
    rows
  end

  # Data format:
  # [
  #   BBRow
  #   BBRow
  #   BBSpec
  #     rows
  #         [
  #            BBRow
  #            BBSpec 
  #            BBRow
  #            BBRow
  #         ] 
  #   BBRow
  #   ......  
  # ]
  # Combine Row -> Spec (some lines not in Spec: comments before Spec new)
  def self.combin_sepc_if_need(rows, podspec_file_path) 
    spec_stack = []
    result_rows = []
    default_name = File.basename(podspec_file_path, File.extname(podspec_file_path))

    rows.each do |row|
      if row.is_spec_start 
        # Get parent spec
        parent_spec = spec_stack.last 

        # Create spec
        name = row.content.split("'")[1]&.strip || default_name
        alias_name = row.content.split("|")[1]&.strip
        full_name = parent_spec ? parent_spec.uniq_full_name_in_parent(name) : name

        spec = BBSpec.new(name, alias_name, full_name)
        spec.rows << row
        spec.parent = parent_spec

        # When a spec exists, store it in spec.rows; otherwise, store it directly outside
        (parent_spec ? parent_spec.rows : result_rows ) << spec
  
        # Push spec into stack
        spec_stack.push(spec)
      elsif row.is_spec_end
        # Add current row to current spec's rows
        spec_stack.last&.rows << row

        # Perform privacy protocol modification
        spec_stack.last.privacy_handle(podspec_file_path)

        # Pop spec from stack
        spec_stack.pop
      else
        # When a spec exists, store it in spec.rows; otherwise, store it directly outside
        (spec_stack.empty? ? result_rows : spec_stack.last.rows) << row
      end
    end
  
    result_rows
  end

  # Flatten all rows in specs, concatenate into a one-level array [BBRow]
  def self.unfold_sepc_if_need(rows)
    result_rows = []
    rows.each do |row|
      if row.is_a?(BBSpec) 
        result_rows += unfold_sepc_if_need(row.rows)
      else
          result_rows << row
      end
    end
    result_rows
  end


  def self.fetch_privacy_hash(rows, podspec_file_path)
    privacy_hash = {}
    specs = rows.select { |row| row.is_a?(BBSpec) }
    specs.each do |spec|
      value = spec.privacy_sources_files ? {KSource_Files_Key => spec.privacy_sources_files, KExclude_Files_Key => spec.privacy_exclude_files || []} : {}
      privacy_hash[File.join(File.dirname(podspec_file_path), spec.privacy_file)] = value
      privacy_hash.merge!(fetch_privacy_hash(spec.rows, podspec_file_path))
    end
    privacy_hash
  end

end