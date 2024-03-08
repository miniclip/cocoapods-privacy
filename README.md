# CocoaPods Privacy Plugin

In spring 2024, Apple will review apps' privacy practices, requiring all apps to submit a privacy manifest. Apps failing to provide this information may face removal. To simplify the management of privacy compliance, particularly for components within an app, the `cocoapods-privacy` plugin has been developed. For detailed information on Apple's privacy requirements, visit [Apple's official documentation](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files).

## Installation

To install `cocoapods-privacy`, run the following command:

```shell
$ gem install cocoapods-privacy
```

## Usage

### Initialization

Initially, you must provide a JSON configuration to `cocoapods-privacy`. Below is how to set a default configuration:

```shell
$ pod privacy config https://raw.githubusercontent.com/ymoyao/cocoapods-privacy/main/resources/config.json
```

The default configuration includes three keys that you may customize:

- `source.white.list`: A whitelist of sources. By default, this is empty. You should add your own component sources. This list is used by the `pod privacy install` or `pod install --privacy` commands to search for `NSPrivacyAccessedAPITypes`.
- `source.black.list`: A blacklist of sources, also empty by default. It functions similarly to the whitelist.
- `api.template.url`: A required field specifying a template URL for searching `NSPrivacyAccessedAPITypes`.

Example configuration:

```json
"source.white.list": ["yourserver.com"],
"source.black.list": ["github.com"],
"api.template.url": "https://raw.githubusercontent.com/miniclip/cocoapods-privacy/main/resources/NSPrivacyAccessedAPITypes.plist"
```

After customizing, you can set a local configuration like this:

```shell
$ pod privacy config /yourfilepath/config.json
```

### Applying to a Component

Use the following command to generate a privacy file for a component:

```shell
$ pod privacy spec [podspec_file_path]
```

This command automatically creates a privacy file, searches for `source_files` paths related to `NSPrivacyAccessedAPITypes` in the podspec, and writes the result to `PrivacyInfo.xcprivacy`. If a component has multiple subspecs, each defined `source_files` will result in its own `PrivacyInfo.xcprivacy`, and the `.podspec` file will be updated to link the `.xcprivacy` file under the `resource_bundle` key.

Example before and after the command:

**Before:**

```ruby
Pod::Spec.new do |s|
  s.name         = 'Demo'
  ...
  s.source_files = 'xxxx'
  s.subspec 'idfa' do |sp|
      sp.source_files = 'xxxxx'
  end
  s.subspec 'noidfa' do |sp|
  end
end
```

**After:**

```ruby
Pod::Spec.new do |s|
  s.name             = 'Demo'
  ...
  s.source_files     = 'xxxx'
  s.resource_bundle  = {"Demo.privacy" => "Pod/Privacy/Demo/PrivacyInfo.xcprivacy"}
  s.subspec 'idfa' do |sp|
      sp.source_files     = 'xxxxx'
      sp.resource_bundle  = {"Demo.idfa.privacy" => "Pod/Privacy/Demo.idfa/PrivacyInfo.xcprivacy"}
  end
  s.subspec 'noidfa' do |sp|
  end
end
```

### Applying to a Project

To integrate privacy information into your project, use one of the following commands:

```shell
$ pod install --privacy
```

or

```shell
$ pod privacy install
```

This process will generate a `PrivacyInfo.xcprivacy` file in your project resources if none exists and will search for components that comply with the configuration files but do not have their own privacy manifest file.

## Notice

The `cocoapods-privacy` plugin is focused on managing `NSPrivacyAccessedAPITypes`. It automates the search and creation process for these types. However, you must manage `NSPrivacyCollectedDataTypes` independently.
