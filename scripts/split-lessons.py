#!/usr/bin/env python3
"""
Split bugs-and-lessons-learned.md into domain-scoped files.
"""
import re

# Read source file
with open('Docs/bugs-and-lessons-learned.md', 'r') as f:
    content = f.read()

# Extract preamble
preamble_match = re.search(r'^(# Bugs Fixed & Lessons Learned.*?)(?=## Bug Fixes)', content, re.DOTALL)
preamble = preamble_match.group(1).strip() if preamble_match else ""

# Parse entries - match both "—" and ":"
entries = {}
lines = content.split('\n')
i = 0
while i < len(lines):
    line = lines[i]
    match = re.match(r'^##+ (BUG-\d+|LESSON-OPS-\d+)[\s:—]', line)
    if match:
        entry_id = match.group(1)
        entry_lines = [line]
        i += 1
        while i < len(lines):
            next_line = lines[i]
            if re.match(r'^##+ (BUG-\d+|LESSON-OPS-\d+)[\s:—]', next_line):
                break
            if re.match(r'^##+ (Bug Fixes|Operational Lessons|Known Open Issues)', next_line):
                break
            entry_lines.append(next_line)
            i += 1
        entries[entry_id] = '\n'.join(entry_lines)
        continue
    i += 1

print(f"Total entries extracted: {len(entries)}")

# Domain classification based on requirements
dashboard_required = {
    'LESSON-OPS-043', 'LESSON-OPS-050', 'LESSON-OPS-052', 'LESSON-OPS-055',
    'LESSON-OPS-065', 'LESSON-OPS-099', 'LESSON-OPS-111',
    'BUG-039', 'BUG-054', 'BUG-056', 'BUG-080', 'BUG-081',
}

firmware_required = {
    'LESSON-OPS-056', 'LESSON-OPS-068', 'LESSON-OPS-069', 'LESSON-OPS-070',
    'LESSON-OPS-072', 'LESSON-OPS-073', 'LESSON-OPS-074',
    'LESSON-OPS-100', 'LESSON-OPS-101', 'LESSON-OPS-102', 'LESSON-OPS-103',
    'LESSON-OPS-104', 'LESSON-OPS-105', 'LESSON-OPS-106', 'LESSON-OPS-107',
    'LESSON-OPS-108', 'LESSON-OPS-109',
    'BUG-057', 'BUG-061', 'BUG-062', 'BUG-064', 'BUG-075', 'BUG-076',
    'BUG-077', 'BUG-078', 'BUG-079',
}

build_required = {
    'LESSON-OPS-066', 'LESSON-OPS-067', 'LESSON-OPS-071', 'LESSON-OPS-077',
    'LESSON-OPS-090', 'LESSON-OPS-091', 'LESSON-OPS-097', 'LESSON-OPS-098',
    'BUG-055',
}

testing_required = {
    'LESSON-OPS-057', 'LESSON-OPS-063', 'LESSON-OPS-080', 'LESSON-OPS-081',
    'LESSON-OPS-082', 'LESSON-OPS-083', 'LESSON-OPS-112', 'LESSON-OPS-113',
    'LESSON-OPS-114',
    'BUG-051',
}

operations_required = {
    'LESSON-OPS-051', 'LESSON-OPS-058', 'LESSON-OPS-069', 'LESSON-OPS-073',
}

# Content-based keywords for assignment
dashboard_keywords = ['dashboard', 'chart', 'card', 'SSE', 'EventSource', 'polling',
                      'fetch()', 'import', 'export', 'innerHTML', 'DOM', 'browser']
firmware_keywords = ['NVS', 'ESP-IDF', 'httpd', 'C++', 'RTOS', 'FreeRTOS', 'lwip',
                     'socket', 'PSRAM', 'partition', 'firmware', 'manifest', 'aggregator',
                     'satellite']
build_keywords = ['generator', 'render_sensor_config', 'bump-version', 'minify',
                  'generate-header', 'preflight', 'YAML']
testing_keywords = ['Playwright', 'fixture', 'mock', 'CI', 'browser test', 'Firefox',
                    'Chromium', 'test.spec']
operations_keywords = ['flash', 'USB', 'serial', 'OTA', 'device test', 'esphome compile',
                       'LXC', 'Proxmox']

def assign_by_content(entry_id, entry_text):
    """Assign entry to domain based on content keywords."""
    text_lower = entry_text.lower()

    scores = {
        'dashboard.md': sum(1 for kw in dashboard_keywords if kw.lower() in text_lower),
        'firmware.md': sum(1 for kw in firmware_keywords if kw.lower() in text_lower),
        'build-pipeline.md': sum(1 for kw in build_keywords if kw.lower() in text_lower),
        'testing.md': sum(1 for kw in testing_keywords if kw.lower() in text_lower),
        'operations.md': sum(1 for kw in operations_keywords if kw.lower() in text_lower),
    }

    # Return domain with highest score, or firmware as default
    max_score = max(scores.values())
    if max_score == 0:
        return 'firmware.md'  # Default fallback
    return max(scores, key=scores.get)

# Build final domain assignments
domains = {
    'dashboard.md': set(dashboard_required),
    'firmware.md': set(firmware_required),
    'build-pipeline.md': set(build_required),
    'testing.md': set(testing_required),
    'operations.md': set(operations_required),
}

# Assign remaining entries
all_assigned = set()
for domain_set in domains.values():
    all_assigned.update(domain_set)

for entry_id in entries.keys():
    if entry_id not in all_assigned:
        domain = assign_by_content(entry_id, entries[entry_id])
        domains[domain].add(entry_id)

# Print statistics
print("\nDomain distribution:")
for domain_file in sorted(domains.keys()):
    domain_set = domains[domain_file]
    bugs = sorted([e for e in domain_set if e.startswith('BUG-')])
    lessons = sorted([e for e in domain_set if e.startswith('LESSON-OPS-')])
    print(f"  {domain_file}: {len(bugs)} bugs, {len(lessons)} lessons")

# Create index
index_rows = []
for entry_id in sorted(entries.keys()):
    domain_file = None
    for df, de in domains.items():
        if entry_id in de:
            domain_file = df
            break
    if domain_file:
        index_rows.append(f"| {entry_id} | {domain_file} |")

index_content = f"""{preamble}

_Split from Docs/bugs-and-lessons-learned.md at v7.6.4.0._

## Entry Index

This index lists every BUG and LESSON-OPS entry and its domain file location.

| Entry | Domain File |
|-------|-------------|
{chr(10).join(index_rows)}
"""

with open('Docs/lessons/index.md', 'w') as f:
    f.write(index_content)

print(f"\n✓ Created index.md with {len(index_rows)} entries")

# Create domain files
for domain_file, domain_entry_set in sorted(domains.items()):
    domain_name = domain_file.replace('.md', '').replace('-', ' ').title()

    bugs = sorted([e for e in domain_entry_set if e.startswith('BUG-')])
    lessons = sorted([e for e in domain_entry_set if e.startswith('LESSON-OPS-')])

    domain_content = f"""# Lessons — {domain_name}

_Split from Docs/bugs-and-lessons-learned.md at v7.6.4.0._

"""

    if bugs:
        domain_content += "## Bug Fixes\n\n"
        for bug_id in bugs:
            if bug_id in entries:
                domain_content += entries[bug_id] + "\n\n---\n\n"

    if lessons:
        domain_content += "## Lessons Learned\n\n"
        for lesson_id in lessons:
            if lesson_id in entries:
                domain_content += entries[lesson_id] + "\n\n---\n"

    # Remove trailing separator from last entry
    domain_content = domain_content.rstrip() + '\n'

    filepath = f'Docs/lessons/{domain_file}'
    with open(filepath, 'w') as f:
        f.write(domain_content)

    print(f"✓ Created {domain_file}: {len(bugs)} bugs, {len(lessons)} lessons")

print("\n✓ All files created successfully!")
