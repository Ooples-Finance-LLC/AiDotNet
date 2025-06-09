#!/usr/bin/env python3
import re

file_path = "/mnt/c/projects/AiDotNet/src/AutoML/SimpleAutoMLModel.cs"

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fix indentation in the IInterpretableModel region
in_region = False
fixed_lines = []

for line in lines:
    if "#region IInterpretableModel Implementation" in line:
        in_region = True
        fixed_lines.append(line)
    elif "#endregion" in line and in_region:
        in_region = False
        fixed_lines.append(line)
    elif in_region:
        # Add 4 spaces (one level of indentation) if the line starts with 4 spaces
        if line.startswith("    ") and not line.startswith("        "):
            fixed_lines.append("    " + line)
        else:
            fixed_lines.append(line)
    else:
        fixed_lines.append(line)

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(fixed_lines)

print("Fixed indentation in SimpleAutoMLModel.cs")