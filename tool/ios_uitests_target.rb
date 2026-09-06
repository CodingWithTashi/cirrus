#!/usr/bin/ruby
# frozen_string_literal: true

# Adds the RunnerUITests XCUITest target (and its shared scheme) to
# ios/Runner.xcodeproj. Companion to tool/ios_widget_target.rb — same gem,
# same reasons, same idempotence:
#
#     /usr/bin/ruby tool/ios_uitests_target.rb
#
# The bundle is a test-only artefact: it drives the SIMULATOR'S HOME SCREEN
# (Springboard) to add the Cirrus widget, tap its +/−, and kill and relaunch
# the app — the things no Flutter test can reach, because they happen outside
# the app's process. See ios/RunnerUITests/CirrusWidgetUITests.swift for the
# loop and how to run it. Nothing here ships: test bundles are never embedded
# in the archive.

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'ios', 'Runner.xcodeproj')
TARGET_NAME = 'RunnerUITests'
FOLDER = 'RunnerUITests'
BUNDLE_ID = 'com.quitvape.lastPuff.RunnerUITests'
TEAM = 'PZFFFQ5T9X'

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target not found'

target = project.targets.find { |t| t.name == TARGET_NAME }
if target
  puts "#{TARGET_NAME}: target already present"
else
  target = project.new_target(:ui_test_bundle, TARGET_NAME, :ios, '16.0')

  %w[Debug Release Profile].each do |name|
    config = target.build_configurations.find { |c| c.name == name } \
      or abort "expected a #{name} configuration on #{TARGET_NAME}"
    config.build_settings.merge!(
      'PRODUCT_BUNDLE_IDENTIFIER' => BUNDLE_ID,
      'PRODUCT_NAME' => '$(TARGET_NAME)',
      'DEVELOPMENT_TEAM' => TEAM,
      'CODE_SIGN_STYLE' => 'Automatic',
      'GENERATE_INFOPLIST_FILE' => 'YES',
      'IPHONEOS_DEPLOYMENT_TARGET' => '16.0',
      'TARGETED_DEVICE_FAMILY' => '1,2',
      'SWIFT_VERSION' => '5.0',
      'TEST_TARGET_NAME' => 'Runner',
      'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @loader_path/Frameworks',
    )
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if name == 'Debug'
  end

  group = project.main_group.find_subpath(FOLDER, true)
  group.set_source_tree('<group>')
  group.set_path(FOLDER)
  Dir[File.join(ROOT, 'ios', FOLDER, '*.swift')].sort.each do |path|
    ref = group.new_file(File.basename(path))
    target.source_build_phase.add_file_reference(ref, true)
  end

  # Same red-in-the-navigator Foundation link the widget script clears.
  target.frameworks_build_phase.files.dup.each(&:remove_from_project)
  project.frameworks_group.children.select { |c| c.display_name == 'iOS' }.each(&:remove_from_project)

  target.add_dependency(runner)
  attributes = (project.root_object.attributes['TargetAttributes'] ||= {})
  attributes[target.uuid] = { 'CreatedOnToolsVersion' => '26.3', 'TestTargetID' => runner.uuid }
  project.save
  puts "#{TARGET_NAME}: target added"
end

# A scheme of its own, so the Runner scheme — the one Flutter drives — never
# gains a build entry (Flutter parses `-showBuildSettings` last-wins).
scheme_path = Xcodeproj::XCScheme.shared_data_dir(PROJECT_PATH) + "#{TARGET_NAME}.xcscheme"
if File.exist?(scheme_path)
  puts "#{TARGET_NAME}: scheme already present"
else
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(runner)
  scheme.add_build_target(target, false)
  scheme.add_test_target(target)
  scheme.set_launch_target(runner)
  scheme.save_as(PROJECT_PATH, TARGET_NAME, true)
  puts "#{TARGET_NAME}: shared scheme written"
end
