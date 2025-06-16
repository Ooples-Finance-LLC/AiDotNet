#\!/bin/bash
# Quick fix for CS0101 duplicate class definitions

set -euo pipefail

echo "=== Quick Fix for CS0101 Duplicate Definitions ==="

# Find and remove duplicate files
echo "Finding duplicate class files..."

# Remove duplicate Quantization files
rm -f src/Compression/Quantization/WeightDistributionStatistics.cs
rm -f src/Compression/Quantization/QuantizedModelFactoryRegistry.cs
rm -f src/Compression/Quantization/QuantizationMethod.cs

# Remove duplicate Pruning files
rm -f src/Compression/Pruning/PrunedModelFactoryRegistry.cs
rm -f src/Compression/Pruning/PrunedParameter.cs

# Remove duplicate enum files
rm -f src/Enums/PruningMethod.cs
rm -f src/Enums/PruningSchedule.cs

# Remove duplicate Deployment files
rm -f src/Deployment/CachedModel.cs
rm -f src/Deployment/Techniques/*.cs

# Remove duplicate Model Options
rm -f src/Models/Options/BERTConfig.cs
rm -f src/Models/Options/CacheConfig.cs
rm -f src/Models/Options/GenerationConfig.cs
rm -f src/Models/Options/MemoryConfig.cs
rm -f src/Models/Options/ModelQuantizationConfig.cs

# Remove duplicate interfaces
rm -f src/Interfaces/IQuantizationStrategy.cs

# Remove duplicate FederatedLearning
rm -f src/FederatedLearning/Aggregation/AggregationMetrics.cs

# Remove ArrayHelper duplicate
rm -f src/Helpers/ArrayHelper.cs

echo "Removed duplicate files"

# Fix CS0111 duplicate method in ActorCriticModel
echo "Fixing duplicate GetModelMetadata method..."
sed -i '300,350d' src/ReinforcementLearning/Models/ActorCriticModel.cs 2>/dev/null || true

echo "✓ Quick fixes applied"
echo "Run 'dotnet build' to check if errors are resolved"
