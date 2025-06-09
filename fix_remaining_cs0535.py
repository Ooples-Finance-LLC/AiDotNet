#!/usr/bin/env python3
import os

# Files that still need fixing based on the error output
files_to_check = [
    ("src/AutoML/SimpleAutoMLModel.cs", "IAutoMLModel"),
    ("src/MultimodalAI/MultimodalModelBase.cs", "MultimodalInput<T>", "Dictionary<string, object>"),
    ("src/Reasoning/ReasoningModelBase.cs", "IReasoningModel", "Tensor<T>", "Tensor<T>"),
    ("src/Models/ParameterPlaceholderModel.cs", "T", "TInput", "TOutput"),
    ("src/ReinforcementLearning/Agents/DQNAgent.cs", "QNetwork"),
    ("src/Models/VectorModel.cs", "VectorModel", "Matrix<T>"),
    ("src/NeuralNetworks/TokenizerAdapter.cs", "TokenizerAdapter", "string", "string"),
    ("src/ReinforcementLearning/Models/ReinforcementLearningModelBase.cs", "ReinforcementLearningModelBase", "Tensor<T>", "Tensor<T>"),
]

def check_and_add_using(file_path):
    """Check if Interpretability using is present and add if missing."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if "using AiDotNet.Interpretability;" not in content:
        # Find the last using statement
        lines = content.split('\n')
        last_using_idx = -1
        for i, line in enumerate(lines):
            if line.strip().startswith("using ") and ";" in line:
                last_using_idx = i
        
        if last_using_idx >= 0:
            lines.insert(last_using_idx + 1, "using AiDotNet.Interpretability;")
            content = '\n'.join(lines)
            
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Added using statement to {file_path}")
            return True
    return False

def check_implementation(file_path):
    """Check if IInterpretableModel implementation exists."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    return "#region IInterpretableModel Implementation" in content

# Check all files
for file_info in files_to_check:
    file_path = os.path.join("/mnt/c/projects/AiDotNet", file_info[0])
    if os.path.exists(file_path):
        print(f"\nChecking {file_path}")
        
        # Check using statement
        using_added = check_and_add_using(file_path)
        
        # Check implementation
        has_impl = check_implementation(file_path)
        print(f"  Has IInterpretableModel implementation: {has_impl}")
        
        if not has_impl:
            print(f"  WARNING: Missing implementation!")
    else:
        print(f"File not found: {file_path}")

print("\nDone!")