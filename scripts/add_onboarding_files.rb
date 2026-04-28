# Syncs the onboarding folder against the Xcode project:
#   - Removes pbxproj references for files under WaterQuest/Views/Onboarding/
#     that no longer exist on disk (e.g. files deleted during a refactor).
#   - Adds pbxproj references for files on disk that aren't yet in the project.
#
# Idempotent. Safe to re-run. Adds files to the WaterQuest target's Sources
# build phase (or the WaterQuestTests target for files under WaterQuestTests/).

require 'xcodeproj'
require 'pathname'

PROJECT_PATH = File.expand_path('../WaterQuest.xcodeproj', __dir__)
PROJECT_ROOT = File.expand_path('..', __dir__)
MAIN_TARGET  = 'WaterQuest'
TEST_TARGET  = 'WaterQuestTests'

# Folders to sync — each entry is (relative folder, target name).
SYNC_FOLDERS = [
  ['WaterQuest/Views/Onboarding', MAIN_TARGET],
  ['WaterQuestTests',             TEST_TARGET]
]

# Standalone files that must always be present in the project. These are
# explicit re-adds so the path-prefix sync above never strips them.
ENSURED_FILES = [
  ['WaterQuest/Views/OnboardingView.swift', MAIN_TARGET]
]

project = Xcodeproj::Project.open(PROJECT_PATH)

main_target = project.targets.find { |t| t.name == MAIN_TARGET } or raise "No #{MAIN_TARGET} target"
test_target = project.targets.find { |t| t.name == TEST_TARGET } or raise "No #{TEST_TARGET} target"
target_by_name = { MAIN_TARGET => main_target, TEST_TARGET => test_target }

def disk_swift_files(absolute_dir)
  Dir.glob(File.join(absolute_dir, '**', '*.swift')).map { |f| Pathname.new(f).relative_path_from(Pathname.new(absolute_dir)).to_s }
end

def project_relative_for(folder, file_relative)
  File.join(folder, file_relative)
end

def find_or_make_group(project, components)
  group = project.main_group
  components.each do |part|
    next if part.empty?
    sub = group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.path == part }
    sub = group.new_group(part, part) unless sub
    group = sub
  end
  group
end

# --- Phase 1: remove dangling references --------------------------------
removed = []
SYNC_FOLDERS.each do |folder, target_name|
  abs = File.join(PROJECT_ROOT, folder)
  on_disk = Dir.exist?(abs) ? disk_swift_files(abs).map { |f| project_relative_for(folder, f) } : []
  on_disk_set = on_disk.to_set rescue Set.new(on_disk)

  folder_prefix = File.join(PROJECT_ROOT, folder) + File::SEPARATOR
  project.files.each do |file|
    next unless file.path
    rel = nil
    begin
      rp = file.real_path.to_s
      next unless rp.start_with?(folder_prefix)
      rel = Pathname.new(rp).relative_path_from(Pathname.new(PROJECT_ROOT)).to_s
    rescue
      next
    end
    next if on_disk_set.include?(rel)
    removed << rel
    file.remove_from_project
  end
end

# --- Phase 2: add missing references ------------------------------------
added = []
SYNC_FOLDERS.each do |folder, target_name|
  abs = File.join(PROJECT_ROOT, folder)
  next unless Dir.exist?(abs)
  on_disk = disk_swift_files(abs)
  target = target_by_name[target_name]

  on_disk.each do |relative_in_folder|
    rel = project_relative_for(folder, relative_in_folder)

    already = project.files.any? do |file|
      next false unless file.path
      begin
        Pathname.new(file.real_path.to_s).cleanpath.to_s == File.join(PROJECT_ROOT, rel)
      rescue
        false
      end
    end
    next if already

    parts = File.dirname(rel).split('/')
    group = find_or_make_group(project, parts)
    basename = File.basename(rel)
    ref = group.new_reference(basename)
    ref.last_known_file_type = 'sourcecode.swift'
    target.source_build_phase.add_file_reference(ref)
    added << rel
  end
end

# --- Phase 3: ensure standalone files are present -----------------------
ENSURED_FILES.each do |rel, target_name|
  abs = File.join(PROJECT_ROOT, rel)
  next unless File.exist?(abs)
  already = project.files.any? do |file|
    next false unless file.path
    begin
      Pathname.new(file.real_path.to_s).cleanpath.to_s == abs
    rescue
      false
    end
  end
  next if already

  parts = File.dirname(rel).split('/')
  group = find_or_make_group(project, parts)
  basename = File.basename(rel)
  ref = group.new_reference(basename)
  ref.last_known_file_type = 'sourcecode.swift'
  target_by_name[target_name].source_build_phase.add_file_reference(ref)
  added << rel
end

project.save

puts "Removed #{removed.size} dangling reference(s):" unless removed.empty?
removed.each { |r| puts "  - #{r}" }
puts "Added #{added.size} new reference(s):" unless added.empty?
added.each { |a| puts "  + #{a}" }
puts "Up to date." if removed.empty? && added.empty?
