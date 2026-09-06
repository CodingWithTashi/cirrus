#!/usr/bin/ruby
# frozen_string_literal: true

# Adds the CirrusWidget WidgetKit extension target to ios/Runner.xcodeproj.
#
# Run from the repo root with the SYSTEM Ruby, which is the one CocoaPods'
# `xcodeproj` gem is installed against:
#
#     /usr/bin/ruby tool/ios_widget_target.rb
#
# Idempotent: a project that already has the target is left untouched, so it
# is safe to re-run after `git checkout ios/Runner.xcodeproj/project.pbxproj`
# (the recovery `pubspec.yaml` prescribes after `dart run
# flutter_launcher_icons` rewrites that file).
#
# Why a script and not the Xcode wizard: the wizard is thirty seconds of GUI
# nobody can review, and a hand-edited pbxproj is thirty UUIDs nobody can
# verify. This is the third option — the same library CocoaPods uses to edit
# the project on every `pod install`, driven by a file that says exactly what
# it changes. `test/ios_widget_test.dart` pins the result.
#
# What the Xcode wizard does that this deliberately does NOT:
#   * add the target to the Runner scheme's build list, or create a scheme of
#     its own — Flutter parses `xcodebuild -showBuildSettings` last-wins and
#     must only ever see Runner's block; the target dependency below is what
#     builds the extension;
#   * link Foundation via a hard-coded `iPhoneOS18.0.sdk` developer-dir path
#     (the gem's default, red in the navigator under Xcode 26) — frameworks
#     are added SDKROOT-relative, the way Xcode itself records them.

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'ios', 'Runner.xcodeproj')
TARGET_NAME = 'CirrusWidget'
FOLDER = 'CirrusWidget'
BUNDLE_ID = 'com.quitvape.lastPuff.CirrusWidget'
TEAM = 'PZFFFQ5T9X'
# Accessory (lock-screen) families and Gauge are iOS 16 APIs; the interactive
# +/- is iOS 17 and #available-guarded. An iOS 15 host simply never loads an
# appex whose MinimumOSVersion it cannot meet.
DEPLOYMENT_TARGET = '16.0'

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == TARGET_NAME }
  puts "#{TARGET_NAME}: target already present, nothing to do"
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target not found'
generated = project.files.find { |f| f.path == 'Flutter/Generated.xcconfig' } \
  or abort 'Flutter/Generated.xcconfig reference not found'

ext = project.new_target(:app_extension, TARGET_NAME, :ios, DEPLOYMENT_TARGET)

# --- Build settings ---------------------------------------------------------
# The gem's common settings for an app extension are only SDKROOT and the
# deployment target; everything the wizard would have written is set here.
%w[Debug Release Profile].each do |name|
  config = ext.build_configurations.find { |c| c.name == name } \
    or abort "expected a #{name} configuration on #{TARGET_NAME}"

  # FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER, which the extension's Info.plist
  # reads, are defined nowhere but here. NOT Debug.xcconfig / Release.xcconfig:
  # those `#include?` the Pods-Runner xcconfigs, whose OTHER_LDFLAGS would drag
  # every Firebase pod into the extension's link line.
  config.base_configuration_reference = generated

  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => BUNDLE_ID,
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'DEVELOPMENT_TEAM' => TEAM,
    'CODE_SIGN_STYLE' => 'Automatic',
    'CODE_SIGN_ENTITLEMENTS' => "#{FOLDER}/CirrusWidget.entitlements",
    'INFOPLIST_FILE' => "#{FOLDER}/Info.plist",
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOYMENT_TARGET,
    'TARGETED_DEVICE_FAMILY' => '1,2',
    # Explicit, so Xcode 26's new-target defaults (Swift 6 language mode,
    # main-actor default isolation) never apply.
    'SWIFT_VERSION' => '5.0',
    # Without it archive validation fails with "Found an unexpected .appex at
    # the top level".
    'SKIP_INSTALL' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' =>
      '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
  )
  # Runner carries this on its own target config, so it is not inherited.
  config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if name == 'Debug'
end

# --- Sources ----------------------------------------------------------------
group = project.main_group.find_subpath(FOLDER, true)
group.set_source_tree('<group>')
group.set_path(FOLDER)

swift_files = Dir[File.join(ROOT, 'ios', FOLDER, '*.swift')].sort.map { |f| File.basename(f) }
abort "no Swift sources under ios/#{FOLDER}" if swift_files.empty?
swift_files.each do |name|
  ref = group.new_file(name)
  ext.source_build_phase.add_file_reference(ref, true)
end
# Plain references only — never through add_file_references, which routes
# every non-header file into the Sources phase.
group.new_file('Info.plist')
group.new_file('CirrusWidget.entitlements')

# --- Frameworks -------------------------------------------------------------
ext.frameworks_build_phase.files.dup.each(&:remove_from_project)
project.frameworks_group.children.select { |c| c.display_name == 'iOS' }.each(&:remove_from_project)
%w[WidgetKit SwiftUI].each do |name|
  ref = project.frameworks_group.new_file("System/Library/Frameworks/#{name}.framework", :sdk_root)
  ext.frameworks_build_phase.add_file_reference(ref, true)
end

# --- Embed in Runner --------------------------------------------------------
runner.add_dependency(ext)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.dst_path = ''
embed.add_file_reference(ext.product_reference, true).settings = {
  'ATTRIBUTES' => ['RemoveHeadersOnCopy'],
}
# Right after "Embed Frameworks", where Xcode's own wizard puts it.
frameworks_phase = runner.build_phases.find do |p|
  p.respond_to?(:name) && p.name == 'Embed Frameworks'
end
if frameworks_phase
  runner.build_phases.move(embed, runner.build_phases.index(frameworks_phase) + 1)
end

attributes = (project.root_object.attributes['TargetAttributes'] ||= {})
attributes[ext.uuid] = { 'CreatedOnToolsVersion' => '26.3' }

project.save
puts "#{TARGET_NAME}: target added (#{swift_files.join(', ')})"
