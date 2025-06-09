#!/usr/bin/env python3
import re
import os
import sys

def fix_async_method_without_await(file_path):
    """Fix async methods that don't have await by converting to Task.Run or removing async"""
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Pattern 1: async Task<T> method that returns Task.FromResult
    # Convert to non-async method returning Task.Run
    pattern1 = r'public\s+(virtual\s+|override\s+)?async\s+Task<([^>]+)>\s+(\w+)\s*\([^)]*\)\s*\{([^}]+)return\s+Task\.FromResult\s*\('
    def replace1(match):
        modifiers = match.group(1) or ''
        return_type = match.group(2)
        method_name = match.group(3)
        body_start = match.group(4)
        return f'public {modifiers}Task<{return_type}> {method_name}({{params}})\\n{{\\n    return Task.Run(() =>\\n    {{{body_start}return '
    
    # Pattern 2: Simple async methods with no await - add Task.Run
    pattern2 = r'public\s+(virtual\s+|override\s+)?async\s+Task\s+(\w+)\s*\(([^)]*)\)\s*\n\s*\{'
    
    # Count occurrences for reporting
    async_count = len(re.findall(r'async\s+Task', content))
    await_count = len(re.findall(r'await\s+', content))
    
    if async_count > await_count:
        print(f"Found {async_count - await_count} async methods without await in {file_path}")
    
    return content != original_content, content

def process_file(file_path):
    """Process a single file to fix async/await issues"""
    
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return False
        
    changed, content = fix_async_method_without_await(file_path)
    
    if changed:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed: {file_path}")
        return True
    
    return False

def main():
    # List of files with CS1998 errors
    files_to_fix = [
        '/mnt/c/projects/AiDotNet/src/ProductionMonitoring/AlertManager.cs',
        '/mnt/c/projects/AiDotNet/src/ProductionMonitoring/ConceptDriftDetector.cs',
        '/mnt/c/projects/AiDotNet/src/ProductionMonitoring/ModelHealthScorer.cs',
        '/mnt/c/projects/AiDotNet/src/ProductionMonitoring/PerformanceMonitor.cs',
        '/mnt/c/projects/AiDotNet/src/ProductionMonitoring/RetrainingRecommender.cs',
        '/mnt/c/projects/AiDotNet/src/Pipeline/DataLoadingStep.cs',
        '/mnt/c/projects/AiDotNet/src/Pipeline/MLPipelineExample.cs',
        '/mnt/c/projects/AiDotNet/src/Pipeline/PipelineOrchestrator.cs',
        '/mnt/c/projects/AiDotNet/src/FoundationModels/Providers/ONNXModelProvider.cs'
    ]
    
    fixed_count = 0
    for file_path in files_to_fix:
        if process_file(file_path):
            fixed_count += 1
    
    print(f"\nFixed {fixed_count} files")

if __name__ == "__main__":
    main()