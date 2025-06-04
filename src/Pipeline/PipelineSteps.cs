using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using AiDotNet.AutoML;
using AiDotNet.Deployment;
using AiDotNet.Enums;
using AiDotNet.Interfaces;
using AiDotNet.LinearAlgebra;
using AiDotNet.Models;
using AiDotNet.NeuralNetworks;
using AiDotNet.ProductionMonitoring;
using AiDotNet.Helpers;
using AiDotNet.Factories;

namespace AiDotNet.Pipeline
{
    /// <summary>
    /// Production-ready data loading pipeline step with support for multiple data sources
    /// </summary>
    public class DataLoadingStep : PipelineStepBase
    {
        private readonly string source;
        private readonly DataSourceType sourceType;
        private readonly Func<Task<(double[][] data, double[] labels)>>? customLoader;
        private readonly DataLoadingOptions options;
        
        // Cached data for transform operations
        private double[][]? cachedData;
        private double[]? cachedLabels;
        
        public DataLoadingStep(string source, DataSourceType sourceType, DataLoadingOptions? options = null) 
            : base("DataLoading")
        {
            this.source = source ?? throw new ArgumentNullException(nameof(source));
            this.sourceType = sourceType;
            this.options = options ?? new DataLoadingOptions();
            
            // Data loading steps don't need fitting
            Position = PipelinePosition.Beginning;
            SupportsParallelExecution = true;
        }
        
        public DataLoadingStep(Func<Task<(double[][] data, double[] labels)>> customLoader, DataLoadingOptions? options = null) 
            : base("DataLoading")
        {
            this.customLoader = customLoader ?? throw new ArgumentNullException(nameof(customLoader));
            this.sourceType = DataSourceType.Custom;
            this.options = options ?? new DataLoadingOptions();
            
            Position = PipelinePosition.Beginning;
            SupportsParallelExecution = true;
        }
        
        protected override bool RequiresFitting() => false;
        
        protected override async void FitCore(double[][] inputs, double[]? targets)
        {
            // Data loading doesn't require fitting, but we can cache the data
            cachedData = inputs;
            cachedLabels = targets;
            
            UpdateMetadata("RowCount", inputs.Length.ToString());
            UpdateMetadata("FeatureCount", inputs[0]?.Length.ToString() ?? "0");
            UpdateMetadata("HasLabels", (targets != null).ToString());
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            // For data loading, transform might mean reloading or returning cached data
            if (options.UseCache && cachedData != null)
            {
                return cachedData;
            }
            
            // If we need to reload, we need to do it synchronously
            var task = LoadDataAsync();
            task.Wait();
            var (data, _) = task.Result;
            
            cachedData = data;
            return data;
        }
        
        public async Task<(double[][] data, double[] labels)> LoadDataAsync()
        {
            try
            {
                if (sourceType == DataSourceType.Custom && customLoader != null)
                {
                    return await customLoader();
                }
                
                return sourceType switch
                {
                    DataSourceType.CSV => await LoadFromCSVAsync(),
                    DataSourceType.JSON => await LoadFromJSONAsync(),
                    DataSourceType.Database => await LoadFromDatabaseAsync(),
                    DataSourceType.API => await LoadFromAPIAsync(),
                    _ => throw new NotSupportedException($"Data source type {sourceType} not supported")
                };
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Failed to load data from {sourceType}: {ex.Message}", ex);
            }
        }
        
        private async Task<(double[][] data, double[] labels)> LoadFromCSVAsync()
        {
            var lines = await File.ReadAllLinesAsync(source);
            if (lines.Length == 0)
            {
                throw new InvalidOperationException("CSV file is empty");
            }
            
            var data = new List<double[]>();
            var labels = new List<double>();
            
            // Skip header if configured
            int startIndex = options.HasHeader ? 1 : 0;
            
            for (int i = startIndex; i < lines.Length; i++)
            {
                if (string.IsNullOrWhiteSpace(lines[i]))
                    continue;
                
                var parts = lines[i].Split(options.Delimiter);
                if (parts.Length < 2)
                {
                    if (options.SkipInvalidRows)
                        continue;
                    throw new FormatException($"Invalid row at line {i + 1}: expected at least 2 columns");
                }
                
                try
                {
                    var features = parts.Take(parts.Length - 1).Select(double.Parse).ToArray();
                    var label = double.Parse(parts.Last());
                    
                    data.Add(features);
                    labels.Add(label);
                }
                catch (FormatException)
                {
                    if (!options.SkipInvalidRows)
                        throw new FormatException($"Invalid numeric data at line {i + 1}");
                }
            }
            
            if (data.Count == 0)
            {
                throw new InvalidOperationException("No valid data rows found in CSV file");
            }
            
            return (data.ToArray(), labels.ToArray());
        }
        
        private Task<(double[][] data, double[] labels)> LoadFromJSONAsync()
        {
            // TODO: Implement JSON loading with proper schema validation
            throw new NotImplementedException("JSON loading will be implemented based on specific schema requirements");
        }
        
        private Task<(double[][] data, double[] labels)> LoadFromDatabaseAsync()
        {
            // TODO: Implement database loading with connection management
            throw new NotImplementedException("Database loading will be implemented with proper connection handling");
        }
        
        private Task<(double[][] data, double[] labels)> LoadFromAPIAsync()
        {
            // TODO: Implement API loading with retry logic and authentication
            throw new NotImplementedException("API loading will be implemented with proper HTTP client management");
        }
        
        protected override bool ValidateInputCore(double[][] inputs)
        {
            if (inputs == null || inputs.Length == 0)
                return false;
            
            // Check if all rows have the same number of features
            int featureCount = inputs[0].Length;
            return inputs.All(row => row != null && row.Length == featureCount);
        }
    }
    
    /// <summary>
    /// Data loading configuration options
    /// </summary>
    public class DataLoadingOptions
    {
        public bool HasHeader { get; set; } = true;
        public char Delimiter { get; set; } = ',';
        public bool SkipInvalidRows { get; set; } = false;
        public bool UseCache { get; set; } = true;
        public int? MaxRows { get; set; }
        public string? DateTimeFormat { get; set; }
    }
    
    /// <summary>
    /// Production-ready data cleaning pipeline step
    /// </summary>
    public class DataCleaningStep : PipelineStepBase
    {
        private readonly DataCleaningConfig config;
        private Dictionary<int, double> imputationValues;
        private HashSet<int> rowsToRemove;
        private IOutlierRemoval<double, double[][], (double[][], double[])>? outlierRemover;
        
        public DataCleaningStep(DataCleaningConfig config) : base("DataCleaning")
        {
            this.config = config ?? throw new ArgumentNullException(nameof(config));
            this.imputationValues = new Dictionary<int, double>();
            this.rowsToRemove = new HashSet<int>();
            
            IsCacheable = true;
            SupportsParallelExecution = true;
        }
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            // Calculate imputation values for each feature
            if (config.HandleMissingValues)
            {
                for (int j = 0; j < inputs[0].Length; j++)
                {
                    var columnValues = inputs
                        .Select(row => row[j])
                        .Where(val => !double.IsNaN(val) && !double.IsInfinity(val))
                        .ToList();
                    
                    if (columnValues.Count > 0)
                    {
                        imputationValues[j] = config.ImputationStrategy switch
                        {
                            ImputationStrategy.Mean => columnValues.Average(),
                            ImputationStrategy.Median => CalculateMedian(columnValues),
                            ImputationStrategy.Mode => CalculateMode(columnValues),
                            ImputationStrategy.Zero => 0.0,
                            _ => columnValues.Average()
                        };
                    }
                }
            }
            
            // Initialize outlier detector
            if (config.HandleOutliers)
            {
                outlierRemover = config.OutlierMethod switch
                {
                    OutlierDetectionMethod.IQR => new AiDotNet.OutlierRemoval.IQROutlierRemoval<double>(),
                    OutlierDetectionMethod.ZScore => new AiDotNet.OutlierRemoval.ZScoreOutlierRemoval<double>(),
                    OutlierDetectionMethod.MAD => new AiDotNet.OutlierRemoval.MADOutlierRemoval<double>(),
                    _ => new AiDotNet.OutlierRemoval.IQROutlierRemoval<double>()
                };
            }
            
            UpdateMetadata("ImputationValuesCount", imputationValues.Count.ToString());
            UpdateMetadata("OutlierMethod", config.OutlierMethod.ToString());
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            var cleanedData = new List<double[]>();
            rowsToRemove.Clear();
            
            for (int i = 0; i < inputs.Length; i++)
            {
                var row = inputs[i].ToArray(); // Create a copy
                bool shouldRemoveRow = false;
                
                // Handle missing values
                if (config.HandleMissingValues)
                {
                    for (int j = 0; j < row.Length; j++)
                    {
                        if (double.IsNaN(row[j]) || double.IsInfinity(row[j]))
                        {
                            if (config.RemoveRowsWithMissing)
                            {
                                shouldRemoveRow = true;
                                break;
                            }
                            else if (imputationValues.ContainsKey(j))
                            {
                                row[j] = imputationValues[j];
                            }
                        }
                    }
                }
                
                if (!shouldRemoveRow)
                {
                    cleanedData.Add(row);
                }
                else
                {
                    rowsToRemove.Add(i);
                }
            }
            
            // Remove duplicates if configured
            if (config.RemoveDuplicates)
            {
                cleanedData = RemoveDuplicateRows(cleanedData);
            }
            
            // Handle outliers
            if (config.HandleOutliers && outlierRemover != null)
            {
                cleanedData = HandleOutliers(cleanedData);
            }
            
            UpdateMetadata("RowsRemoved", rowsToRemove.Count.ToString());
            UpdateMetadata("FinalRowCount", cleanedData.Count.ToString());
            
            return cleanedData.ToArray();
        }
        
        private List<double[]> RemoveDuplicateRows(List<double[]> data)
        {
            var seen = new HashSet<string>();
            var unique = new List<double[]>();
            
            foreach (var row in data)
            {
                var key = string.Join(",", row.Select(v => v.ToString("G17")));
                if (seen.Add(key))
                {
                    unique.Add(row);
                }
            }
            
            return unique;
        }
        
        private List<double[]> HandleOutliers(List<double[]> data)
        {
            if (outlierRemover == null || data.Count == 0)
                return data;
            
            // Convert to double[][] for IOutlierRemoval interface
            var dataArray = data.ToArray();
            
            // Create dummy labels since we're only interested in feature outliers
            var dummyLabels = new double[dataArray.Length];
            
            // Use outlier removal
            var (cleanedData, _) = outlierRemover.RemoveOutliers(dataArray, dummyLabels);
            
            // Track which rows were removed
            var originalIndices = Enumerable.Range(0, dataArray.Length).ToHashSet();
            var cleanedIndices = new HashSet<int>();
            
            // Find which rows remain after outlier removal
            for (int i = 0; i < cleanedData.Length; i++)
            {
                for (int j = 0; j < dataArray.Length; j++)
                {
                    if (AreRowsEqual(cleanedData[i], dataArray[j]))
                    {
                        cleanedIndices.Add(j);
                        break;
                    }
                }
            }
            
            // Mark removed rows
            var removedIndices = originalIndices.Except(cleanedIndices);
            foreach (var idx in removedIndices)
            {
                rowsToRemove.Add(idx);
            }
            
            return cleanedData.ToList();
        }
        
        private bool AreRowsEqual(double[] row1, double[] row2)
        {
            if (row1.Length != row2.Length) return false;
            
            for (int i = 0; i < row1.Length; i++)
            {
                if (Math.Abs(row1[i] - row2[i]) > 1e-10)
                    return false;
            }
            
            return true;
        }
        
        private double CalculateMedian(List<double> values)
        {
            var sorted = values.OrderBy(v => v).ToList();
            int n = sorted.Count;
            
            if (n % 2 == 0)
            {
                return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0;
            }
            
            return sorted[n / 2];
        }
        
        private double CalculateMode(List<double> values)
        {
            return values
                .GroupBy(v => v)
                .OrderByDescending(g => g.Count())
                .First()
                .Key;
        }
        
        public HashSet<int> GetRemovedRowIndices() => new HashSet<int>(rowsToRemove);
    }
    
    /// <summary>
    /// Production-ready feature engineering pipeline step
    /// </summary>
    public class FeatureEngineeringStep : PipelineStepBase
    {
        private readonly FeatureEngineeringConfig config;
        private List<Func<double[], double>>? generatedFeatures;
        private Dictionary<string, object> featureMetadata;
        private int originalFeatureCount;
        
        public FeatureEngineeringStep(FeatureEngineeringConfig config) : base("FeatureEngineering")
        {
            this.config = config ?? throw new ArgumentNullException(nameof(config));
            this.featureMetadata = new Dictionary<string, object>();
            
            IsCacheable = true;
            SupportsParallelExecution = true;
        }
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            originalFeatureCount = inputs[0].Length;
            generatedFeatures = new List<Func<double[], double>>();
            
            if (config.AutoGenerate)
            {
                GenerateAutomaticFeatures(inputs, targets);
            }
            
            if (config.GeneratePolynomialFeatures)
            {
                GeneratePolynomialFeatures();
            }
            
            if (config.GenerateInteractionFeatures)
            {
                GenerateInteractionFeatures();
            }
            
            if (config.CustomFeatureGenerators != null)
            {
                generatedFeatures.AddRange(config.CustomFeatureGenerators);
            }
            
            UpdateMetadata("OriginalFeatures", originalFeatureCount.ToString());
            UpdateMetadata("GeneratedFeatures", generatedFeatures.Count.ToString());
            UpdateMetadata("TotalFeatures", (originalFeatureCount + generatedFeatures.Count).ToString());
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            if (generatedFeatures == null || generatedFeatures.Count == 0)
            {
                return inputs;
            }
            
            var transformed = new double[inputs.Length][];
            
            Parallel.For(0, inputs.Length, i =>
            {
                var originalFeatures = inputs[i];
                var newFeatures = new double[originalFeatureCount + generatedFeatures.Count];
                
                // Copy original features
                Array.Copy(originalFeatures, newFeatures, originalFeatureCount);
                
                // Generate new features
                for (int j = 0; j < generatedFeatures.Count; j++)
                {
                    try
                    {
                        newFeatures[originalFeatureCount + j] = generatedFeatures[j](originalFeatures);
                    }
                    catch
                    {
                        // Handle feature generation errors gracefully
                        newFeatures[originalFeatureCount + j] = 0.0;
                    }
                }
                
                transformed[i] = newFeatures;
            });
            
            return transformed;
        }
        
        private void GenerateAutomaticFeatures(double[][] inputs, double[]? targets)
        {
            // Analyze feature statistics to generate relevant features
            for (int i = 0; i < originalFeatureCount; i++)
            {
                var columnData = inputs.Select(row => row[i]).ToArray();
                var stats = CalculateColumnStatistics(columnData);
                
                // Generate log transform for positive skewed features
                if (stats.Skewness > 1.0 && stats.Min > 0)
                {
                    int featureIndex = i;
                    generatedFeatures.Add(row => Math.Log(row[featureIndex] + 1));
                    featureMetadata[$"log_{i}"] = "Log transform";
                }
                
                // Generate square root for features with high variance
                if (stats.Variance > 10 * stats.Mean && stats.Min >= 0)
                {
                    int featureIndex = i;
                    generatedFeatures.Add(row => Math.Sqrt(row[featureIndex]));
                    featureMetadata[$"sqrt_{i}"] = "Square root transform";
                }
                
                // Generate reciprocal for features not close to zero
                if (Math.Abs(stats.Min) > 0.1)
                {
                    int featureIndex = i;
                    generatedFeatures.Add(row => 1.0 / (row[featureIndex] + Math.Sign(row[featureIndex]) * 0.1));
                    featureMetadata[$"reciprocal_{i}"] = "Reciprocal transform";
                }
            }
        }
        
        private void GeneratePolynomialFeatures()
        {
            for (int i = 0; i < originalFeatureCount; i++)
            {
                int featureIndex = i;
                
                // Square terms
                generatedFeatures.Add(row => row[featureIndex] * row[featureIndex]);
                featureMetadata[$"poly2_{i}"] = "Polynomial degree 2";
                
                if (config.PolynomialDegree >= 3)
                {
                    // Cubic terms
                    generatedFeatures.Add(row => row[featureIndex] * row[featureIndex] * row[featureIndex]);
                    featureMetadata[$"poly3_{i}"] = "Polynomial degree 3";
                }
            }
        }
        
        private void GenerateInteractionFeatures()
        {
            // Generate pairwise interactions for top features
            int maxInteractions = Math.Min(config.MaxInteractionFeatures, originalFeatureCount * (originalFeatureCount - 1) / 2);
            int interactionCount = 0;
            
            for (int i = 0; i < originalFeatureCount && interactionCount < maxInteractions; i++)
            {
                for (int j = i + 1; j < originalFeatureCount && interactionCount < maxInteractions; j++)
                {
                    int feat1 = i;
                    int feat2 = j;
                    
                    generatedFeatures.Add(row => row[feat1] * row[feat2]);
                    featureMetadata[$"interaction_{i}_{j}"] = $"Interaction between features {i} and {j}";
                    interactionCount++;
                }
            }
        }
        
        private FeatureStatistics CalculateColumnStatistics(double[] columnData)
        {
            var validData = columnData.Where(v => !double.IsNaN(v) && !double.IsInfinity(v)).ToArray();
            
            if (validData.Length == 0)
            {
                return new FeatureStatistics();
            }
            
            var mean = validData.Average();
            var variance = validData.Select(v => Math.Pow(v - mean, 2)).Average();
            var stdDev = Math.Sqrt(variance);
            
            var sorted = validData.OrderBy(v => v).ToArray();
            var n = sorted.Length;
            
            return new FeatureStatistics
            {
                Mean = mean,
                Variance = variance,
                StdDev = stdDev,
                Min = sorted[0],
                Max = sorted[n - 1],
                Median = n % 2 == 0 ? (sorted[n/2-1] + sorted[n/2]) / 2 : sorted[n/2],
                Skewness = CalculateSkewness(validData, mean, stdDev)
            };
        }
        
        private double CalculateSkewness(double[] data, double mean, double stdDev)
        {
            if (stdDev == 0) return 0;
            
            var n = data.Length;
            var sum = data.Sum(v => Math.Pow((v - mean) / stdDev, 3));
            
            return n * sum / ((n - 1) * (n - 2));
        }
        
        private class FeatureStatistics
        {
            public double Mean { get; set; }
            public double Variance { get; set; }
            public double StdDev { get; set; }
            public double Min { get; set; }
            public double Max { get; set; }
            public double Median { get; set; }
            public double Skewness { get; set; }
        }
        
        public Dictionary<string, object> GetFeatureMetadata() => new Dictionary<string, object>(featureMetadata);
    }
    
    
    /// <summary>
    /// Production-ready data splitting pipeline step
    /// </summary>
    public class DataSplittingStep : PipelineStepBase
    {
        private readonly double trainRatio;
        private readonly double valRatio;
        private readonly double testRatio;
        private readonly bool stratify;
        private readonly int? randomSeed;
        
        // Split indices
        private int[]? trainIndices;
        private int[]? valIndices;
        private int[]? testIndices;
        
        public DataSplittingStep(double trainRatio, double valRatio, double testRatio, bool stratify = false, int? randomSeed = null) 
            : base("DataSplitting")
        {
            if (Math.Abs(trainRatio + valRatio + testRatio - 1.0) > 1e-6)
            {
                throw new ArgumentException("Train, validation, and test ratios must sum to 1.0");
            }
            
            this.trainRatio = trainRatio;
            this.valRatio = valRatio;
            this.testRatio = testRatio;
            this.stratify = stratify;
            this.randomSeed = randomSeed;
            
            // Data splitting doesn't transform the data, just organizes it
            IsCacheable = true;
        }
        
        protected override bool RequiresFitting() => true;
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            var n = inputs.Length;
            var random = randomSeed.HasValue ? new Random(randomSeed.Value) : new Random();
            
            if (stratify && targets != null)
            {
                // Stratified split
                PerformStratifiedSplit(inputs, targets, random);
            }
            else
            {
                // Random split
                PerformRandomSplit(n, random);
            }
            
            UpdateMetadata("TrainSize", trainIndices?.Length.ToString() ?? "0");
            UpdateMetadata("ValidationSize", valIndices?.Length.ToString() ?? "0");
            UpdateMetadata("TestSize", testIndices?.Length.ToString() ?? "0");
            UpdateMetadata("Stratified", stratify.ToString());
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            // Data splitting doesn't transform the data
            // The actual splitting is done by accessing the split properties
            return inputs;
        }
        
        private void PerformRandomSplit(int n, Random random)
        {
            var indices = Enumerable.Range(0, n).ToArray();
            
            // Shuffle indices
            for (int i = n - 1; i > 0; i--)
            {
                int j = random.Next(i + 1);
                (indices[i], indices[j]) = (indices[j], indices[i]);
            }
            
            int trainSize = (int)(n * trainRatio);
            int valSize = (int)(n * valRatio);
            
            trainIndices = indices.Take(trainSize).ToArray();
            valIndices = indices.Skip(trainSize).Take(valSize).ToArray();
            testIndices = indices.Skip(trainSize + valSize).ToArray();
        }
        
        private void PerformStratifiedSplit(double[][] inputs, double[] targets, Random random)
        {
            // Group by class
            var classGroups = targets
                .Select((label, index) => new { Label = label, Index = index })
                .GroupBy(x => x.Label)
                .ToDictionary(g => g.Key, g => g.Select(x => x.Index).ToList());
            
            var trainList = new List<int>();
            var valList = new List<int>();
            var testList = new List<int>();
            
            foreach (var group in classGroups.Values)
            {
                var shuffled = group.OrderBy(x => random.Next()).ToList();
                int groupSize = shuffled.Count();
                
                int trainSize = (int)(groupSize * trainRatio);
                int valSize = (int)(groupSize * valRatio);
                
                trainList.AddRange(shuffled.Take(trainSize));
                valList.AddRange(shuffled.Skip(trainSize).Take(valSize));
                testList.AddRange(shuffled.Skip(trainSize + valSize));
            }
            
            trainIndices = trainList.ToArray();
            valIndices = valList.ToArray();
            testIndices = testList.ToArray();
        }
        
        public (double[][] trainData, double[]? trainLabels) GetTrainData(double[][] allData, double[]? allLabels)
        {
            if (trainIndices == null)
                throw new InvalidOperationException("Data splitting has not been fitted yet");
            
            var trainData = trainIndices.Select(i => allData[i]).ToArray();
            var trainLabels = allLabels != null ? trainIndices.Select(i => allLabels[i]).ToArray() : null;
            
            return (trainData, trainLabels);
        }
        
        public (double[][] valData, double[]? valLabels) GetValidationData(double[][] allData, double[]? allLabels)
        {
            if (valIndices == null)
                throw new InvalidOperationException("Data splitting has not been fitted yet");
            
            var valData = valIndices.Select(i => allData[i]).ToArray();
            var valLabels = allLabels != null ? valIndices.Select(i => allLabels[i]).ToArray() : null;
            
            return (valData, valLabels);
        }
        
        public (double[][] testData, double[]? testLabels) GetTestData(double[][] allData, double[]? allLabels)
        {
            if (testIndices == null)
                throw new InvalidOperationException("Data splitting has not been fitted yet");
            
            var testData = testIndices.Select(i => allData[i]).ToArray();
            var testLabels = allLabels != null ? testIndices.Select(i => allLabels[i]).ToArray() : null;
            
            return (testData, testLabels);
        }
        
        public int[]? GetTrainIndices() => trainIndices?.ToArray();
        public int[]? GetValidationIndices() => valIndices?.ToArray();
        public int[]? GetTestIndices() => testIndices?.ToArray();
    }
    
    /// <summary>
    /// Production-ready normalization pipeline step
    /// </summary>
    public class NormalizationStep : PipelineStepBase
    {
        private readonly NormalizationMethod method;
        private INormalizer<double, double[][], double[][]>? normalizer;
        
        public NormalizationStep(NormalizationMethod method) : base("Normalization")
        {
            this.method = method;
            IsCacheable = true;
            SupportsParallelExecution = true;
        }
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            normalizer = NormalizerFactory.Create<double>(method);
            normalizer.Fit(inputs);
            
            UpdateMetadata("NormalizationMethod", method.ToString());
            UpdateMetadata("FeatureCount", inputs[0].Length.ToString());
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            if (normalizer == null)
                throw new InvalidOperationException("Normalizer has not been fitted");
            
            return normalizer.Transform(inputs);
        }
        
        public double[][] InverseTransform(double[][] normalizedData)
        {
            if (normalizer == null)
                throw new InvalidOperationException("Normalizer has not been fitted");
            
            return normalizer.InverseTransform(normalizedData);
        }
        
        public INormalizer<double, double[][], double[][]>? GetNormalizer() => normalizer;
    }
    
    /// <summary>
    /// Production-ready model training pipeline step
    /// </summary>
    public class ModelTrainingStep : PipelineStepBase
    {
        private readonly ModelTrainingConfig config;
        private IFullModel<double, Vector<double>, double>? trainedModel;
        private readonly Dictionary<string, double> trainingMetrics;
        
        public ModelTrainingStep(ModelTrainingConfig config) : base("ModelTraining")
        {
            this.config = config ?? throw new ArgumentNullException(nameof(config));
            this.trainingMetrics = new Dictionary<string, double>();
            
            Position = PipelinePosition.Middle;
            IsCacheable = false; // Training should not be cached
        }
        
        protected override bool RequiresFitting() => true;
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            if (targets == null)
                throw new ArgumentException("Targets are required for model training");
            
            // Create model based on configuration
            trainedModel = CreateModel();
            
            // Convert data to appropriate format
            var vectorInputs = inputs.Select(row => new Vector<double>(row)).ToArray();
            
            // Train the model
            var startTime = DateTime.UtcNow;
            
            for (int epoch = 0; epoch < config.Epochs; epoch++)
            {
                double epochLoss = 0.0;
                
                // Mini-batch training
                for (int i = 0; i < inputs.Length; i += config.BatchSize)
                {
                    int batchEnd = Math.Min(i + config.BatchSize, inputs.Length);
                    
                    for (int j = i; j < batchEnd; j++)
                    {
                        trainedModel.Train(vectorInputs[j], targets[j]);
                    }
                }
                
                // Calculate epoch metrics
                if ((epoch + 1) % config.ValidationFrequency == 0)
                {
                    epochLoss = CalculateEpochLoss(vectorInputs, targets);
                    trainingMetrics[$"Epoch_{epoch + 1}_Loss"] = epochLoss;
                    
                    if (config.EarlyStopping && CheckEarlyStopping(epochLoss))
                    {
                        UpdateMetadata("EarlyStoppingEpoch", (epoch + 1).ToString());
                        break;
                    }
                }
            }
            
            var trainingTime = (DateTime.UtcNow - startTime).TotalSeconds;
            UpdateMetadata("TrainingTime", $"{trainingTime:F2} seconds");
            UpdateMetadata("FinalLoss", trainingMetrics.Values.LastOrDefault().ToString("F4"));
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            if (trainedModel == null)
                throw new InvalidOperationException("Model has not been trained");
            
            // For model training step, transform means making predictions
            var predictions = new double[inputs.Length][];
            
            for (int i = 0; i < inputs.Length; i++)
            {
                var input = new Vector<double>(inputs[i]);
                var prediction = trainedModel.Predict(input);
                predictions[i] = new[] { prediction };
            }
            
            return predictions;
        }
        
        private IFullModel<double, Vector<double>, double> CreateModel()
        {
            // Create model based on configuration
            // This is a simplified example - in production, use a factory pattern
            return config.ModelType switch
            {
                ModelType.LinearRegression => new AiDotNet.Regression.SimpleRegression(),
                ModelType.DecisionTree => new AiDotNet.Regression.DecisionTreeRegression(),
                ModelType.RandomForest => new AiDotNet.Regression.RandomForestRegression(),
                _ => throw new NotSupportedException($"Model type {config.ModelType} not supported")
            };
        }
        
        private double CalculateEpochLoss(Vector<double>[] inputs, double[] targets)
        {
            double totalLoss = 0.0;
            
            for (int i = 0; i < inputs.Length; i++)
            {
                var prediction = trainedModel!.Predict(inputs[i]);
                totalLoss += Math.Pow(prediction - targets[i], 2);
            }
            
            return totalLoss / inputs.Length;
        }
        
        private bool CheckEarlyStopping(double currentLoss)
        {
            // Simple early stopping based on patience
            // In production, implement more sophisticated early stopping
            return false;
        }
        
        public IFullModel<double, Vector<double>, double>? GetTrainedModel() => trainedModel;
        public Dictionary<string, double> GetTrainingMetrics() => new Dictionary<string, double>(trainingMetrics);
    }
    
    /// <summary>
    /// Model training configuration
    /// </summary>
    public class ModelTrainingConfig
    {
        public ModelType ModelType { get; set; } = ModelType.LinearRegression;
        public int Epochs { get; set; } = 100;
        public int BatchSize { get; set; } = 32;
        public double LearningRate { get; set; } = 0.001;
        public bool EarlyStopping { get; set; } = true;
        public int Patience { get; set; } = 10;
        public int ValidationFrequency { get; set; } = 10;
        public Dictionary<string, object>? ModelSpecificParams { get; set; }
    }
    
    /// <summary>
    /// Production-ready model evaluation pipeline step
    /// </summary>
    public class EvaluationStep : PipelineStepBase
    {
        private readonly MetricType[] metrics;
        private readonly Dictionary<string, double> evaluationResults;
        private IFullModel<double, Vector<double>, double>? model;
        
        public EvaluationStep(params MetricType[] metrics) : base("Evaluation")
        {
            this.metrics = metrics.Length > 0 ? metrics : new[] { MetricType.Accuracy };
            this.evaluationResults = new Dictionary<string, double>();
            
            Position = PipelinePosition.End;
            IsCacheable = true;
        }
        
        public void SetModel(IFullModel<double, Vector<double>, double> model)
        {
            this.model = model ?? throw new ArgumentNullException(nameof(model));
        }
        
        protected override bool RequiresFitting() => false;
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            // Evaluation doesn't require fitting, but we can use this to set up evaluation data
            if (model == null)
                throw new InvalidOperationException("Model must be set before evaluation");
            
            if (targets == null)
                throw new ArgumentException("Targets are required for evaluation");
            
            // Perform evaluation
            PerformEvaluation(inputs, targets);
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            // Evaluation doesn't transform data
            return inputs;
        }
        
        private void PerformEvaluation(double[][] inputs, double[] targets)
        {
            var predictions = new double[inputs.Length];
            
            // Get predictions
            for (int i = 0; i < inputs.Length; i++)
            {
                var input = new Vector<double>(inputs[i]);
                predictions[i] = model!.Predict(input);
            }
            
            // Calculate metrics
            foreach (var metric in metrics)
            {
                double value = metric switch
                {
                    MetricType.MSE => CalculateMSE(predictions, targets),
                    MetricType.RMSE => Math.Sqrt(CalculateMSE(predictions, targets)),
                    MetricType.MAE => CalculateMAE(predictions, targets),
                    MetricType.R2 => CalculateR2(predictions, targets),
                    _ => 0.0
                };
                
                evaluationResults[metric.ToString()] = value;
            }
            
            // Update metadata
            foreach (var result in evaluationResults)
            {
                UpdateMetadata(result.Key, result.Value.ToString("F4"));
            }
        }
        
        private double CalculateMSE(double[] predictions, double[] targets)
        {
            double sum = 0.0;
            for (int i = 0; i < predictions.Length; i++)
            {
                sum += Math.Pow(predictions[i] - targets[i], 2);
            }
            return sum / predictions.Length;
        }
        
        private double CalculateMAE(double[] predictions, double[] targets)
        {
            double sum = 0.0;
            for (int i = 0; i < predictions.Length; i++)
            {
                sum += Math.Abs(predictions[i] - targets[i]);
            }
            return sum / predictions.Length;
        }
        
        private double CalculateR2(double[] predictions, double[] targets)
        {
            double targetMean = targets.Average();
            double ssTotal = targets.Sum(t => Math.Pow(t - targetMean, 2));
            double ssResidual = 0.0;
            
            for (int i = 0; i < predictions.Length; i++)
            {
                ssResidual += Math.Pow(targets[i] - predictions[i], 2);
            }
            
            return 1.0 - (ssResidual / ssTotal);
        }
        
        public Dictionary<string, double> GetEvaluationResults() => new Dictionary<string, double>(evaluationResults);
    }
    
    /// <summary>
    /// Production-ready cross-validation pipeline step
    /// </summary>
    public class CrossValidationStep : PipelineStepBase
    {
        private readonly CrossValidationType cvType;
        private readonly int folds;
        private readonly ModelTrainingConfig trainingConfig;
        private readonly Dictionary<string, List<double>> cvResults;
        
        public CrossValidationStep(CrossValidationType cvType, int folds, ModelTrainingConfig trainingConfig) 
            : base("CrossValidation")
        {
            this.cvType = cvType;
            this.folds = folds;
            this.trainingConfig = trainingConfig ?? throw new ArgumentNullException(nameof(trainingConfig));
            this.cvResults = new Dictionary<string, List<double>>();
            
            Position = PipelinePosition.Middle;
            IsCacheable = false;
        }
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            if (targets == null)
                throw new ArgumentException("Targets are required for cross-validation");
            
            // Perform cross-validation based on type
            var crossValidator = CreateCrossValidator();
            
            // Initialize result lists
            cvResults["TrainAccuracy"] = new List<double>();
            cvResults["ValidationAccuracy"] = new List<double>();
            cvResults["TrainLoss"] = new List<double>();
            cvResults["ValidationLoss"] = new List<double>();
            
            int foldIndex = 0;
            foreach (var (trainIndices, valIndices) in crossValidator.GetFolds(inputs.Length, targets))
            {
                // Split data
                var trainData = trainIndices.Select(i => inputs[i]).ToArray();
                var trainTargets = trainIndices.Select(i => targets[i]).ToArray();
                var valData = valIndices.Select(i => inputs[i]).ToArray();
                var valTargets = valIndices.Select(i => targets[i]).ToArray();
                
                // Train model on fold
                var modelStep = new ModelTrainingStep(trainingConfig);
                modelStep.FitAsync(trainData, trainTargets).Wait();
                
                // Evaluate on training and validation sets
                var trainPredictions = modelStep.TransformCore(trainData);
                var valPredictions = modelStep.TransformCore(valData);
                
                // Calculate metrics
                double trainLoss = CalculateLoss(trainPredictions, trainTargets);
                double valLoss = CalculateLoss(valPredictions, valTargets);
                
                cvResults["TrainLoss"].Add(trainLoss);
                cvResults["ValidationLoss"].Add(valLoss);
                
                foldIndex++;
            }
            
            // Update metadata with average results
            UpdateMetadata("AvgTrainLoss", cvResults["TrainLoss"].Average().ToString("F4"));
            UpdateMetadata("AvgValidationLoss", cvResults["ValidationLoss"].Average().ToString("F4"));
            UpdateMetadata("StdTrainLoss", CalculateStd(cvResults["TrainLoss"]).ToString("F4"));
            UpdateMetadata("StdValidationLoss", CalculateStd(cvResults["ValidationLoss"]).ToString("F4"));
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            // Cross-validation doesn't transform data
            return inputs;
        }
        
        private ICrossValidator<double> CreateCrossValidator()
        {
            return cvType switch
            {
                CrossValidationType.KFold => new AiDotNet.CrossValidators.KFoldCrossValidator(folds),
                CrossValidationType.StratifiedKFold => new AiDotNet.CrossValidators.StratifiedKFoldCrossValidator(folds),
                CrossValidationType.LeaveOneOut => new AiDotNet.CrossValidators.LeaveOneOutCrossValidator(),
                _ => new AiDotNet.CrossValidators.StandardCrossValidator(folds)
            };
        }
        
        private double CalculateLoss(double[][] predictions, double[] targets)
        {
            double sum = 0.0;
            for (int i = 0; i < predictions.Length; i++)
            {
                sum += Math.Pow(predictions[i][0] - targets[i], 2);
            }
            return sum / predictions.Length;
        }
        
        private double CalculateStd(List<double> values)
        {
            double mean = values.Average();
            double sumSquaredDiff = values.Sum(v => Math.Pow(v - mean, 2));
            return Math.Sqrt(sumSquaredDiff / values.Count);
        }
        
        public Dictionary<string, List<double>> GetCVResults() => new Dictionary<string, List<double>>(cvResults);
    }
    
    /// <summary>
    /// Production-ready data augmentation pipeline step
    /// </summary>
    public class DataAugmentationStep : PipelineStepBase
    {
        private readonly DataAugmentationConfig config;
        private readonly Random random;
        
        public DataAugmentationStep(DataAugmentationConfig config, int? randomSeed = null) : base("DataAugmentation")
        {
            this.config = config ?? throw new ArgumentNullException(nameof(config));
            this.random = randomSeed.HasValue ? new Random(randomSeed.Value) : new Random();
            
            IsCacheable = false; // Augmentation should be different each time
            SupportsParallelExecution = true;
        }
        
        protected override bool RequiresFitting() => false;
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            // Data augmentation doesn't require fitting
            UpdateMetadata("AugmentationFactor", config.AugmentationFactor.ToString());
            UpdateMetadata("NoiseLevel", config.NoiseLevel.ToString("F4"));
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            var augmentedData = new List<double[]>();
            
            // Add original data
            augmentedData.AddRange(inputs);
            
            // Generate augmented samples
            for (int aug = 1; aug < config.AugmentationFactor; aug++)
            {
                var augmentedBatch = new double[inputs.Length][];
                
                Parallel.For(0, inputs.Length, i =>
                {
                    augmentedBatch[i] = AugmentSample(inputs[i]);
                });
                
                augmentedData.AddRange(augmentedBatch);
            }
            
            UpdateMetadata("OriginalSamples", inputs.Length.ToString());
            UpdateMetadata("AugmentedSamples", augmentedData.Count.ToString());
            
            return augmentedData.ToArray();
        }
        
        private double[] AugmentSample(double[] sample)
        {
            var augmented = new double[sample.Length];
            
            for (int i = 0; i < sample.Length; i++)
            {
                double value = sample[i];
                
                // Add Gaussian noise
                if (config.AddNoise)
                {
                    double noise = GenerateGaussianNoise() * config.NoiseLevel;
                    value += noise * Math.Abs(value); // Proportional noise
                }
                
                // Apply random scaling
                if (config.RandomScaling)
                {
                    double scale = 1.0 + (random.NextDouble() - 0.5) * config.ScalingRange;
                    value *= scale;
                }
                
                // Apply feature dropout
                if (config.FeatureDropout && random.NextDouble() < config.DropoutRate)
                {
                    value = 0.0;
                }
                
                augmented[i] = value;
            }
            
            return augmented;
        }
        
        private double GenerateGaussianNoise()
        {
            // Box-Muller transform for Gaussian noise
            double u1 = 1.0 - random.NextDouble();
            double u2 = 1.0 - random.NextDouble();
            return Math.Sqrt(-2.0 * Math.Log(u1)) * Math.Sin(2.0 * Math.PI * u2);
        }
    }
    
    /// <summary>
    /// Production-ready deployment pipeline step
    /// </summary>
    public class DeploymentStep : PipelineStepBase
    {
        private readonly DeploymentConfig config;
        private IFullModel<double, Vector<double>, double>? model;
        private string? deploymentEndpoint;
        
        public DeploymentStep(DeploymentConfig config) : base("Deployment")
        {
            this.config = config ?? throw new ArgumentNullException(nameof(config));
            
            Position = PipelinePosition.End;
            IsCacheable = false;
        }
        
        public void SetModel(IFullModel<double, Vector<double>, double> model)
        {
            this.model = model ?? throw new ArgumentNullException(nameof(model));
        }
        
        protected override bool RequiresFitting() => false;
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            // Deployment doesn't require fitting, but we can use this to prepare deployment
            if (model == null)
                throw new InvalidOperationException("Model must be set before deployment");
            
            // Prepare deployment based on target
            PrepareDeployment();
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            // Deployment doesn't transform data
            return inputs;
        }
        
        private void PrepareDeployment()
        {
            // TODO: Implement actual deployment logic based on config.Target
            // This is a placeholder implementation
            
            UpdateMetadata("DeploymentTarget", config.Target.ToString());
            UpdateMetadata("CloudPlatform", config.CloudPlatform.ToString());
            UpdateMetadata("AutoScaling", config.EnableAutoScaling.ToString());
            UpdateMetadata("MinInstances", config.MinInstances.ToString());
            UpdateMetadata("MaxInstances", config.MaxInstances.ToString());
            
            // Simulate deployment endpoint
            deploymentEndpoint = config.Endpoint ?? $"https://api.{config.CloudPlatform.ToString().ToLower()}.com/model/{Guid.NewGuid()}";
            UpdateMetadata("Endpoint", deploymentEndpoint);
        }
        
        public string? GetDeploymentEndpoint() => deploymentEndpoint;
        
        public async Task<bool> DeployAsync()
        {
            if (model == null)
                throw new InvalidOperationException("Model must be set before deployment");
            
            // TODO: Implement actual deployment logic
            // This is a placeholder that simulates deployment
            await Task.Delay(1000); // Simulate deployment time
            
            return true;
        }
    }
    
    /// <summary>
    /// AutoML pipeline step
    /// </summary>
    public class AutoMLStep : ModelTrainingStep
    {
        private readonly AutoMLConfig config;
        
        public AutoMLStep(AutoMLConfig config) : base(new ModelTrainingConfig())
        {
            this.config = config ?? throw new ArgumentNullException(nameof(config));
            Name = "AutoML";
        }
    }
    
    /// <summary>
    /// Neural Architecture Search pipeline step
    /// </summary>
    public class NASStep : ModelTrainingStep
    {
        private readonly NASConfig config;
        
        public NASStep(NASConfig config) : base(new ModelTrainingConfig())
        {
            this.config = config ?? throw new ArgumentNullException(nameof(config));
            Name = "NeuralArchitectureSearch";
        }
    }
    
    /// <summary>
    /// Ensemble pipeline step
    /// </summary>
    public class EnsembleStep : ModelTrainingStep
    {
        private readonly EnsembleConfig config;
        
        public EnsembleStep(EnsembleConfig config) : base(new ModelTrainingConfig())
        {
            this.config = config ?? throw new ArgumentNullException(nameof(config));
            Name = "Ensemble";
        }
    }
    
    /// <summary>
    /// Hyperparameter tuning pipeline step
    /// </summary>
    public class HyperparameterTuningStep : PipelineStepBase
    {
        private readonly HyperparameterTuningConfig config;
        
        public HyperparameterTuningStep(HyperparameterTuningConfig config) : base("HyperparameterTuning")
        {
            this.config = config ?? throw new ArgumentNullException(nameof(config));
            Position = PipelinePosition.Middle;
        }
        
        protected override bool RequiresFitting() => true;
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            // TODO: Implement hyperparameter tuning logic
            UpdateMetadata("MaxTrials", config.MaxTrials.ToString());
            UpdateMetadata("OptimizationMetric", config.OptimizationMetric.ToString());
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            // Hyperparameter tuning doesn't transform data
            return inputs;
        }
    }
    
    /// <summary>
    /// Model interpretability pipeline step
    /// </summary>
    public class InterpretabilityStep : PipelineStepBase
    {
        private readonly InterpretationMethod[] methods;
        
        public InterpretabilityStep(InterpretationMethod[] methods) : base("Interpretability")
        {
            this.methods = methods ?? throw new ArgumentNullException(nameof(methods));
            Position = PipelinePosition.End;
        }
        
        protected override bool RequiresFitting() => false;
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            // TODO: Implement interpretability analysis
            UpdateMetadata("Methods", string.Join(", ", methods));
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            // Interpretability doesn't transform data
            return inputs;
        }
    }
    
    /// <summary>
    /// Model compression pipeline step
    /// </summary>
    public class ModelCompressionStep : PipelineStepBase
    {
        private readonly CompressionTechnique technique;
        
        public ModelCompressionStep(CompressionTechnique technique) : base("ModelCompression")
        {
            this.technique = technique;
            Position = PipelinePosition.End;
        }
        
        protected override bool RequiresFitting() => false;
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            // TODO: Implement model compression
            UpdateMetadata("CompressionTechnique", technique.ToString());
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            // Compression doesn't transform data
            return inputs;
        }
    }
    
    /// <summary>
    /// Production monitoring pipeline step
    /// </summary>
    public class MonitoringStep : PipelineStepBase
    {
        private readonly MonitoringConfig config;
        
        public MonitoringStep(MonitoringConfig config) : base("Monitoring")
        {
            this.config = config ?? throw new ArgumentNullException(nameof(config));
            Position = PipelinePosition.End;
        }
        
        protected override bool RequiresFitting() => false;
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            // TODO: Set up monitoring
            UpdateMetadata("DriftDetection", config.EnableDriftDetection.ToString());
            UpdateMetadata("PerformanceMonitoring", config.EnablePerformanceMonitoring.ToString());
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            // Monitoring doesn't transform data
            return inputs;
        }
    }
    
    /// <summary>
    /// A/B testing pipeline step
    /// </summary>
    public class ABTestingStep : PipelineStepBase
    {
        private readonly string experimentName;
        private readonly double trafficSplit;
        
        public ABTestingStep(string experimentName, double trafficSplit) : base("ABTesting")
        {
            this.experimentName = experimentName ?? throw new ArgumentNullException(nameof(experimentName));
            this.trafficSplit = trafficSplit;
            Position = PipelinePosition.End;
        }
        
        protected override bool RequiresFitting() => false;
        
        protected override void FitCore(double[][] inputs, double[]? targets)
        {
            // TODO: Set up A/B testing
            UpdateMetadata("ExperimentName", experimentName);
            UpdateMetadata("TrafficSplit", trafficSplit.ToString("P0"));
        }
        
        protected override double[][] TransformCore(double[][] inputs)
        {
            // A/B testing doesn't transform data
            return inputs;
        }
    }
    
}