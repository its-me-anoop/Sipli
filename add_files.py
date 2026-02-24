import sys
import re
import uuid

def generate_id():
    # pbxproj uses 24-char hex strings
    return uuid.uuid4().hex[:24].upper()

pbx_path = "WaterQuest.xcodeproj/project.pbxproj"

with open(pbx_path, "r") as f:
    pbx = f.read()

# Files we need to add:
# WaterQuest/Components/LiquidProgressView.swift
# WaterQuest/Services/MotionManager.swift

# We need:
# 1. PBXBuildFile section entries
# 2. PBXFileReference section entries
# 3. PBXGroup children entries
# 4. PBXSourcesBuildPhase files entries

liq_ref = generate_id()
liq_build = generate_id()
mot_ref = generate_id()
mot_build = generate_id()

# 1. PBXBuildFile
build_files = f"""
		{liq_build} /* LiquidProgressView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {liq_ref} /* LiquidProgressView.swift */; }};
		{mot_build} /* MotionManager.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {mot_ref} /* MotionManager.swift */; }};
"""
pbx = pbx.replace("/* End PBXBuildFile section */", build_files + "/* End PBXBuildFile section */")

# 2. PBXFileReference
file_refs = f"""
		{liq_ref} /* LiquidProgressView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LiquidProgressView.swift; sourceTree = "<group>"; }};
		{mot_ref} /* MotionManager.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MotionManager.swift; sourceTree = "<group>"; }};
"""
pbx = pbx.replace("/* End PBXFileReference section */", file_refs + "/* End PBXFileReference section */")

# 3. Groups (we need to inject into Components and Services group, but for simplicity, we can inject into the main WaterQuest group or just look for the Components group ID string if possible.
# A simpler brute-force is finding the /* Components */ and /* Services */ groups and appending to their children.

# Find Components group children array:
comp_match = re.search(r'(/\* Components \*/ = \{\n\s+isa = PBXGroup;\n\s+children = \(\n)', pbx)
if comp_match:
    pbx = pbx[:comp_match.end()] + f"\t\t\t\t{liq_ref} /* LiquidProgressView.swift */,\n" + pbx[comp_match.end():]

serv_match = re.search(r'(/\* Services \*/ = \{\n\s+isa = PBXGroup;\n\s+children = \(\n)', pbx)
if serv_match:
    pbx = pbx[:serv_match.end()] + f"\t\t\t\t{mot_ref} /* MotionManager.swift */,\n" + pbx[serv_match.end():]

# 4. PBXSourcesBuildPhase
# Find PBXSourcesBuildPhase
src_phase_match = re.search(r'(isa = PBXSourcesBuildPhase;\n\s+buildActionMask = [\d]+;\n\s+files = \(\n)', pbx)
if src_phase_match:
    pbx = pbx[:src_phase_match.end()] + f"\t\t\t\t{liq_build} /* LiquidProgressView.swift in Sources */,\n\t\t\t\t{mot_build} /* MotionManager.swift in Sources */,\n" + pbx[src_phase_match.end():]

with open(pbx_path, "w") as f:
    f.write(pbx)

print("Modified pbxproj successfully.")
