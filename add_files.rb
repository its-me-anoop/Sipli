require 'xcodeproj'
project_path = 'WaterQuest.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group_services = project.main_group.find_subpath(File.join('WaterQuest', 'Services'), true)
file_ref_motion = group_services.new_reference('MotionManager.swift')
target.add_file_references([file_ref_motion])

group_components = project.main_group.find_subpath(File.join('WaterQuest', 'Components'), true)
file_ref_liquid = group_components.new_reference('LiquidProgressView.swift')
target.add_file_references([file_ref_liquid])

project.save
