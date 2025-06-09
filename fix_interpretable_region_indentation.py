#!/usr/bin/env python3
import re

files_to_fix = [
    "/mnt/c/projects/AiDotNet/src/MultimodalAI/MultimodalModelBase.cs",
    "/mnt/c/projects/AiDotNet/src/Models/ParameterPlaceholderModel.cs",
    "/mnt/c/projects/AiDotNet/src/Models/VectorModel.cs",
    "/mnt/c/projects/AiDotNet/src/Reasoning/ReasoningModelBase.cs",
    "/mnt/c/projects/AiDotNet/src/NeuralNetworks/TokenizerAdapter.cs",
    "/mnt/c/projects/AiDotNet/src/ReinforcementLearning/Models/ReinforcementLearningModelBase.cs"
]

for file_path in files_to_fix:
    try:
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
        
        print(f"Fixed indentation in {file_path}")
    except Exception as e:
        print(f"Error fixing {file_path}: {e}")