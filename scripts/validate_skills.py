#!/usr/bin/env python3
"""Checks WaterQuest/Skills.skillsbundle against Apple's app skill rules
(Orchestrating complex actions with app skills, iOS 27.3 Siri AI preview):

- each folder in Skills/ holds exactly one SKILL.md and nothing else
- frontmatter has only `name` and `description`
- name: 1-64 chars of a-z, 0-9 and hyphens, no leading/trailing or double
  hyphen, matching the folder name, unique
- description: one non-empty line, at most 1024 characters
- body: at most 10,000 characters

Xcode 27.3 validates the bundle at build time too; this runs anywhere,
including CI without Xcode. Usage: scripts/validate_skills.py [bundle]
"""
import pathlib
import re
import sys

NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def check(bundle: pathlib.Path) -> list[str]:
    errors = []
    root = bundle / "Skills"
    if not root.is_dir():
        return [f"{root}: missing Skills folder"]
    for extra in bundle.iterdir():
        if extra.name != "Skills":
            errors.append(f"{extra}: only a Skills folder belongs in the bundle")
    seen = set()
    for skill in sorted(root.iterdir()):
        if not skill.is_dir():
            errors.append(f"{skill}: only skill folders belong in Skills/")
            continue
        files = [f.name for f in skill.iterdir()]
        if files != ["SKILL.md"]:
            errors.append(f"{skill}: must contain only SKILL.md, found {files}")
        md = skill / "SKILL.md"
        if not md.is_file():
            continue
        text = md.read_text(encoding="utf-8")
        m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
        if not m:
            errors.append(f"{md}: missing --- frontmatter")
            continue
        fields = {}
        for line in m.group(1).splitlines():
            key, sep, value = line.partition(":")
            if not sep:
                errors.append(f"{md}: bad frontmatter line {line!r}")
                continue
            fields[key.strip()] = value.strip()
        if set(fields) != {"name", "description"}:
            errors.append(f"{md}: frontmatter must have only name and description, has {sorted(fields)}")
        name = fields.get("name", "")
        if not (1 <= len(name) <= 64 and NAME.match(name)):
            errors.append(f"{md}: invalid name {name!r}")
        if name != skill.name:
            errors.append(f"{md}: name {name!r} must match folder {skill.name!r}")
        if name in seen:
            errors.append(f"{md}: duplicate name {name!r}")
        seen.add(name)
        desc = fields.get("description", "")
        if not desc or len(desc) > 1024:
            errors.append(f"{md}: description must be 1-1024 characters, is {len(desc)}")
        body = m.group(2)
        if len(body) > 10_000:
            errors.append(f"{md}: body is {len(body)} characters, limit is 10,000")
        if not body.strip():
            errors.append(f"{md}: empty body")
    if not seen:
        errors.append(f"{root}: no skills")
    return errors


if __name__ == "__main__":
    default = pathlib.Path(__file__).resolve().parent.parent / "WaterQuest" / "Skills.skillsbundle"
    bundle = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else default
    problems = check(bundle)
    for p in problems:
        print(p, file=sys.stderr)
    if problems:
        sys.exit(1)
    print(f"{bundle.name}: {len(list((bundle / 'Skills').iterdir()))} skills OK")
