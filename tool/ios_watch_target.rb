#!/usr/bin/ruby
# frozen_string_literal: true

# Adds the Apple Watch app and its watch-face complication to
# ios/Runner.xcodeproj.
#
# Run from the repo root with the SYSTEM Ruby, which is the one CocoaPods'
# `xcodeproj` gem is installed against:
#
#     /usr/bin/ruby tool/ios_watch_target.rb
#
# Idempotent, the same way `tool/ios_widget_target.rb` is: a project that
# already has the watch app is left untouched, so it is safe to re-run after
# `git checkout ios/Runner.xcodeproj/project.pbxproj` (the recovery
# `pubspec.yaml` prescribes after `dart run flutter_launcher_icons` rewrites
# that file). `test/ios_watch_test.dart` pins everything below.
#
# Two targets, because a complication is a WidgetKit extension and extensions
# ship inside an app:
#
#     Runner.app/Watch/CirrusWatch.app/PlugIns/CirrusWatchComplication.appex
#
# Three things the Xcode wizard does that this deliberately does NOT:
#
#   * add either target to the Runner scheme, or create schemes of their own.
#     Flutter parses `xcodebuild -showBuildSettings` last-wins and must only
#     ever see Runner's block — measured: with CirrusWidget embedded the
#     command emits exactly one "Build settings for action" block. A watch
#     target leaking into that parse would hand Flutter `SDKROOT = watchos`.
#     The target dependency plus the embed phase below is what builds them.
#   * link Foundation through a hard-coded `WatchOS11.0.sdk` developer-dir path.
#     That is the gem's default and the SDK does not exist under Xcode 26, so it
#     is cleared and the frameworks re-added SDKROOT-relative.
#   * make the watch app run independently of the phone. Every number it draws
#     comes from the mirror the iPhone pushes, so a standalone install could
#     only ever show the empty card — see the note in CirrusWatch/Info.plist.

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'ios', 'Runner.xcodeproj')

APP_NAME = 'CirrusWatch'
EXT_NAME = 'CirrusWatchComplication'
HOST_BUNDLE_ID = 'com.quitvape.lastPuff'
# Since watchOS 7 a single-target watch app only has to be PREFIXED by the
# host's id, so a plain `.watch` suffix is correct; `.watchkitapp` is the legacy
# two-target convention and buys nothing.
#
# **`.complication` is a RESERVED suffix and Apple will not register it.**
# `<watch app>.complication` answers "cannot be registered to your development
# team because it is not available" — from automatic signing AND from the
# developer portal by hand, which is what proves it is Apple's rule rather than
# a signing limitation. Measured on Sep 6 2026 against team PZFFFQ5T9X with
# `.watchkitapp`, with `.watch`, and again after the parent id already existed,
# so it is neither the parent's suffix nor an ordering race. It is the word;
# `.widget` registers instantly. (Presumably reserved for the legacy WatchKit
# complication bundle.)
#
# When it fails, signing falls back to a wildcard profile, which cannot carry
# App Groups — so the three App Group errors that follow are a cascade, not
# three separate problems.
#
# Do NOT "fix" it with a sibling like `com.quitvape.lastPuff.watchface`: that
# registers and the whole device build succeeds, but an embedded extension's id
# must be its container's plus a period and a suffix, and a sibling matches only
# as a raw string prefix. It builds today and is rejected on upload.
#
# Both App IDs also need the App Group attached by hand — automatic signing
# creates the watch app's id but the group is a separate step. Simulator builds
# never register an App ID at all, which is why every simulator pass in this
# feature's history was green while the device build was not.
APP_BUNDLE_ID = "#{HOST_BUNDLE_ID}.watch"
EXT_BUNDLE_ID = "#{APP_BUNDLE_ID}.widget"
TEAM = 'PZFFFQ5T9X'
# watchOS 10: `.containerBackground`, the modern single-target watch app, and
# WidgetKit accessory families (watchOS 9) all present. Series 4 and later.
DEPLOYMENT_TARGET = '10.0'

# The mirror contract and the queue, shared with the home-screen widget rather
# than forked. Both are Foundation-only — which is why `swiftc` can compile them
# on a Mac for `test/ios_widget_contract_test.dart` — so they build for watchOS
# unchanged. Two implementations of the same maths in this repo have already
# drifted once (`streakEngine.ts` vs `streak_engine.dart`); this is the same
# rule applied across a device boundary.
SHARED = ['CirrusWidget/CirrusShared.swift', 'CirrusWidget/CirrusOutbox.swift'].freeze
# Spoken by BOTH devices, so it is a member of the watch app and of Runner.
WIRE = 'CirrusWatch/WatchWire.swift'

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == APP_NAME }
  puts "#{APP_NAME}: target already present, nothing to do"
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target not found'
generated = project.files.find { |f| f.path == 'Flutter/Generated.xcconfig' } \
  or abort 'Flutter/Generated.xcconfig reference not found'

app = project.new_target(:application, APP_NAME, :watchos, DEPLOYMENT_TARGET)
ext = project.new_target(:app_extension, EXT_NAME, :watchos, DEPLOYMENT_TARGET)

# --- Build settings ---------------------------------------------------------
# The gem already writes SDKROOT=watchos, WATCHOS_DEPLOYMENT_TARGET,
# TARGETED_DEVICE_FAMILY=4, SKIP_INSTALL=YES and the asset-catalog names.
# Everything the wizard would add on top is set here.
[[app, APP_BUNDLE_ID, 'CirrusWatch'], [ext, EXT_BUNDLE_ID, 'CirrusWatchComplication']]
  .each do |target, bundle_id, folder|
  %w[Debug Release Profile].each do |name|
    config = target.build_configurations.find { |c| c.name == name } \
      or abort "expected a #{name} configuration on #{target.name}"

    # FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER, which both Info.plists read,
    # are defined nowhere but here — and a watch app whose version does not
    # match the host's is rejected on upload (ITMS-90473), exactly as the
    # widget's would be. NOT Debug.xcconfig / Release.xcconfig: those
    # `#include?` the Pods-Runner xcconfigs, whose OTHER_LDFLAGS would drag
    # every iOS Firebase pod into a watchOS link line.
    #
    # Its two EXCLUDED_ARCHS entries are conditioned on `sdk=iphone*`, so they
    # are inert here — checked before this was written.
    config.base_configuration_reference = generated

    config.build_settings.merge!(
      'PRODUCT_BUNDLE_IDENTIFIER' => bundle_id,
      'PRODUCT_NAME' => '$(TARGET_NAME)',
      'DEVELOPMENT_TEAM' => TEAM,
      'CODE_SIGN_STYLE' => 'Automatic',
      'CODE_SIGN_ENTITLEMENTS' => "#{folder}/#{folder}.entitlements",
      'INFOPLIST_FILE' => "#{folder}/Info.plist",
      'GENERATE_INFOPLIST_FILE' => 'NO',
      'WATCHOS_DEPLOYMENT_TARGET' => DEPLOYMENT_TARGET,
      'TARGETED_DEVICE_FAMILY' => '4',
      'SDKROOT' => 'watchos',
      'SUPPORTED_PLATFORMS' => 'watchsimulator watchos',
      # Explicit, so Xcode 26's new-target defaults (Swift 6 language mode,
      # main-actor default isolation) never apply — the same pin the widget
      # target carries, and for the same reason.
      'SWIFT_VERSION' => '5.0',
      # Both are embedded, so neither may install at the top level.
      'SKIP_INSTALL' => 'YES',
      'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks',
    )
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if name == 'Debug'
  end
end
# Only the app has an icon; an extension inheriting the name would look for one
# in a catalog it does not have.
ext.build_configurations.each do |config|
  config.build_settings.delete('ASSETCATALOG_COMPILER_APPICON_NAME')
  config.build_settings.delete('ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME')
end

# --- Sources ----------------------------------------------------------------
def group_for(project, folder)
  group = project.main_group.find_subpath(folder, true)
  group.set_source_tree('<group>')
  group.set_path(folder)
  group
end

# A file reference is created once and added to as many targets as need it —
# which is the whole point: one copy of the contract, three readers of it.
def reference(project, path)
  existing = project.files.find { |f| f.real_path.to_s == File.join(project.project_dir.to_s, path) }
  return existing if existing

  dir, base = File.split(path)
  group_for(project, dir).new_file(base)
end

app_group = group_for(project, APP_NAME)
ext_group = group_for(project, EXT_NAME)

app_swift = Dir[File.join(ROOT, 'ios', APP_NAME, '*.swift')].sort.map { |f| File.basename(f) }
ext_swift = Dir[File.join(ROOT, 'ios', EXT_NAME, '*.swift')].sort.map { |f| File.basename(f) }
abort "no Swift sources under ios/#{APP_NAME}" if app_swift.empty?
abort "no Swift sources under ios/#{EXT_NAME}" if ext_swift.empty?

app_swift.each do |name|
  app.source_build_phase.add_file_reference(app_group.new_file(name), true)
end
ext_swift.each do |name|
  ext.source_build_phase.add_file_reference(ext_group.new_file(name), true)
end

# The shared contract, into every target that reads it.
SHARED.each do |path|
  ref = reference(project, path)
  app.source_build_phase.add_file_reference(ref, true)
  ext.source_build_phase.add_file_reference(ref, true)
  runner.source_build_phase.add_file_reference(ref, true)
end
# The wire is spoken by the phone too. Its file reference already exists from
# the app_swift loop above, so this adds the same one to Runner.
runner.source_build_phase.add_file_reference(reference(project, WIRE), true)
# And the phone's own half of the link.
runner.source_build_phase.add_file_reference(
  reference(project, 'Runner/CirrusWatchLink.swift'), true
)

# Plain references only — never through add_file_references, which routes every
# non-header file into the Sources phase.
app_group.new_file('Info.plist')
app_group.new_file("#{APP_NAME}.entitlements")
ext_group.new_file('Info.plist')
ext_group.new_file("#{EXT_NAME}.entitlements")

assets = app_group.new_file('Assets.xcassets')
app.resources_build_phase.add_file_reference(assets, true)

# --- Frameworks -------------------------------------------------------------
# Clear the gem's hard-coded WatchOS11.0.sdk Foundation link, and the platform
# group it hangs off, then add what each target actually imports.
[app, ext].each { |t| t.frameworks_build_phase.files.dup.each(&:remove_from_project) }
project.frameworks_group.children
       .select { |c| c.display_name == 'watchOS' }
       .each(&:remove_from_project)

def link(project, target, names)
  names.each do |name|
    path = "System/Library/Frameworks/#{name}.framework"
    # Reuse the reference the widget target already created where there is one.
    # A second copy builds and signs identically and leaves the navigator with
    # three SwiftUI.frameworks in it, which is the kind of mess that makes the
    # next person distrust a generated project.
    ref = project.frameworks_group.children.find do |c|
      c.respond_to?(:path) && c.path == path && c.source_tree == 'SDKROOT'
    end
    ref ||= project.frameworks_group.new_file(path, :sdk_root)
    target.frameworks_build_phase.add_file_reference(ref, true)
  end
end

link(project, app, %w[SwiftUI WatchConnectivity WatchKit WidgetKit])
link(project, ext, %w[SwiftUI WidgetKit])

# --- Embed ------------------------------------------------------------------
# The complication into the watch app's PlugIns/ …
ext_embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
ext_embed.symbol_dst_subfolder_spec = :plug_ins
ext_embed.dst_path = ''
app.add_dependency(ext)
ext_embed.add_file_reference(ext.product_reference, true).settings = {
  'ATTRIBUTES' => ['RemoveHeadersOnCopy'],
}

# … and the watch app into Runner.app/Watch/. Spec 16 is the products
# directory; the path is what makes it "Embed Watch Content" rather than a
# stray bundle Apple's validator will not recognise.
runner.add_dependency(app)
app_embed = runner.new_copy_files_build_phase('Embed Watch Content')
app_embed.symbol_dst_subfolder_spec = :products_directory
app_embed.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
app_embed.add_file_reference(app.product_reference, true).settings = {
  'ATTRIBUTES' => ['RemoveHeadersOnCopy'],
}
# Right after the widget's embed phase, where Xcode's own wizard puts it.
anchor = runner.build_phases.find do |p|
  p.respond_to?(:name) && p.name == 'Embed Foundation Extensions'
end
runner.build_phases.move(app_embed, runner.build_phases.index(anchor) + 1) if anchor

attributes = (project.root_object.attributes['TargetAttributes'] ||= {})
attributes[app.uuid] = { 'CreatedOnToolsVersion' => '26.3' }
attributes[ext.uuid] = { 'CreatedOnToolsVersion' => '26.3' }

project.save
puts "#{APP_NAME}: target added (#{app_swift.join(', ')})"
puts "#{EXT_NAME}: target added (#{ext_swift.join(', ')})"
