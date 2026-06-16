# Adds the App Intents hardening source/test files to their targets.
# Idempotent: skips files already referenced. Each new file is placed in the
# same group as an existing sibling so its on-disk path resolves correctly.
require 'xcodeproj'

PROJECT_PATH = File.expand_path('../WaterQuest.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

app   = project.targets.find { |t| t.name == 'WaterQuest' }      or raise 'no WaterQuest target'
tests = project.targets.find { |t| t.name == 'WaterQuestTests' } or raise 'no WaterQuestTests target'

# new file basename => [sibling basename, target]
additions = {
  'HydrationIntentCore.swift' => ['SipliAppIntents.swift', app],
  'HydrationMerge.swift'      => ['HydrationStore.swift',  app],
  'SipliAppIntentsTests.swift'=> ['FluidTypeRankingTests.swift', tests],
}

additions.each do |basename, (sibling_name, target)|
  if project.files.any? { |f| f.path&.split('/')&.last == basename }
    puts "skip (already referenced): #{basename}"
    next
  end

  sibling = project.files.find { |f| f.path&.split('/')&.last == sibling_name }
  raise "could not find sibling #{sibling_name}" unless sibling

  ref = sibling.parent.new_reference(basename)
  target.source_build_phase.add_file_reference(ref)
  puts "added #{basename} -> #{target.name} (group: #{sibling.parent.display_name})"
end

project.save
puts 'saved.'
