# One-shot setup: adds the WaterQuestTests unit-test bundle target to
# WaterQuest.xcodeproj, wires it to the existing shared scheme.
#
# Idempotency caveat: the script short-circuits at the target-level check
# below. If it crashes BETWEEN `project.save` (pbxproj persisted) and
# `scheme.save!` (scheme not yet updated), re-running will see the target
# already exists and skip the scheme update, leaving the scheme half-
# configured. Recovery: delete the WaterQuestTests target from the project
# (via Xcode UI or a short `xcodeproj` snippet) and re-run.

require 'xcodeproj'

PROJECT_PATH  = File.expand_path('../WaterQuest.xcodeproj', __dir__)
SCHEME_PATH   = File.join(PROJECT_PATH, 'xcshareddata', 'xcschemes', 'WaterQuest.xcscheme')
TEST_TARGET   = 'WaterQuestTests'
MAIN_TARGET   = 'WaterQuest'

project = Xcodeproj::Project.open(PROJECT_PATH)

# --- Idempotency check ---
if project.targets.any? { |t| t.name == TEST_TARGET }
  puts "#{TEST_TARGET} target already exists – nothing to do."
  exit 0
end

main_target = project.targets.find { |t| t.name == MAIN_TARGET }
raise "Could not find target '#{MAIN_TARGET}'" unless main_target

# --- Create unit test target ---
test_target = project.new_target(
  :unit_test_bundle,
  TEST_TARGET,
  :ios,
  '17.0',
  project.products_group,
  :swift
)

# Unit test bundles get Foundation linked implicitly via SDKROOT —
# drop the explicit reference the DSL added (its path is pinned to a
# specific iPhoneOS<version>.sdk and will rot on Xcode upgrades).
frameworks_phase = test_target.frameworks_build_phase
frameworks_phase.files.to_a.each do |build_file|
  if build_file.display_name == 'Foundation.framework'
    frameworks_phase.remove_build_file(build_file)
  end
end

# --- Build settings for Debug and Release ---
%w[Debug Release].each do |config_name|
  config = test_target.build_configuration_list[config_name]
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']   = 'com.waterquest.hydration.tests'
  config.build_settings['GENERATE_INFOPLIST_FILE']     = 'YES'
  config.build_settings['TEST_HOST']                   = '$(BUILT_PRODUCTS_DIR)/Sipli.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Sipli'
  config.build_settings['BUNDLE_LOADER']               = '$(TEST_HOST)'
  config.build_settings['SWIFT_VERSION']               = '5.9'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']  = '17.0'
  config.build_settings['TARGETED_DEVICE_FAMILY']      = '1'
end

# --- Add WaterQuest as a dependency of the test target ---
test_target.add_dependency(main_target)

# --- Create source group and add test file ---
tests_group = project.main_group.find_subpath(TEST_TARGET, true)
tests_group.path        = TEST_TARGET
tests_group.source_tree = '<group>'

test_file_ref = tests_group.new_reference('WaterQuestTests.swift')
test_target.source_build_phase.add_file_reference(test_file_ref)

# --- Save pbxproj ---
project.save

# --- Update shared scheme to include test target ---
scheme = Xcodeproj::XCScheme.new(SCHEME_PATH)

# Add to build action (build-for-testing only, not running/archiving)
build_entry = Xcodeproj::XCScheme::BuildAction::Entry.new(test_target)
build_entry.build_for_testing   = true
build_entry.build_for_running   = false
build_entry.build_for_profiling = false
build_entry.build_for_archiving = false
build_entry.build_for_analyzing = false
scheme.build_action.add_entry(build_entry)

# Add to test action
testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
scheme.test_action.add_testable(testable)

scheme.save!

puts "Added #{TEST_TARGET} target."
