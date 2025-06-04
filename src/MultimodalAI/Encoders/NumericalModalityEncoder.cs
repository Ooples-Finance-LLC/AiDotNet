using System;
using System.Collections.Generic;
using System.Linq;
using AiDotNet.LinearAlgebra;

namespace AiDotNet.MultimodalAI.Encoders
{
    /// <summary>
    /// Numerical data modality encoder for processing numerical/tabular data
    /// </summary>
    public class NumericalModalityEncoder : ModalityEncoderBase
    {
        private readonly bool _useFeatureEngineering;
        private readonly bool _useInteractionFeatures;
        private readonly int _polynomialDegree;
        private readonly double _missingValueIndicator;
        private readonly NormalizationMethod _normalizationMethod;
        
        // Feature statistics for normalization
        private double[] _featureMeans;
        private double[] _featureStdDevs;
        private double[] _featureMins;
        private double[] _featureMaxs;
        private bool _statisticsComputed;
        
        /// <summary>
        /// Normalization methods for numerical features
        /// </summary>
        public enum NormalizationMethod
        {
            None,
            StandardScore,
            MinMax,
            Robust
        }
        
        /// <summary>
        /// Initializes a new instance of NumericalModalityEncoder
        /// </summary>
        /// <param name="outputDimension">Output dimension of the encoder (default: 128)</param>
        /// <param name="useFeatureEngineering">Whether to create engineered features (default: true)</param>
        /// <param name="useInteractionFeatures">Whether to create interaction features (default: true)</param>
        /// <param name="polynomialDegree">Degree for polynomial features (default: 2)</param>
        /// <param name="normalizationMethod">Method for normalizing features (default: StandardScore)</param>
        /// <param name="missingValueIndicator">Value to use for missing data (default: -999)</param>
        public NumericalModalityEncoder(int outputDimension = 128, bool useFeatureEngineering = true,
            bool useInteractionFeatures = true, int polynomialDegree = 2,
            NormalizationMethod normalizationMethod = NormalizationMethod.StandardScore,
            double missingValueIndicator = -999) 
            : base("Numerical", outputDimension)
        {
            _useFeatureEngineering = useFeatureEngineering;
            _useInteractionFeatures = useInteractionFeatures;
            _polynomialDegree = Math.Max(1, Math.Min(polynomialDegree, 3)); // Limit to reasonable range
            _normalizationMethod = normalizationMethod;
            _missingValueIndicator = missingValueIndicator;
            _statisticsComputed = false;
        }

        /// <summary>
        /// Encodes numerical data into a vector representation
        /// </summary>
        /// <param name="input">Numerical data as array, Vector, or Tensor</param>
        /// <returns>Encoded vector representation</returns>
        public override Vector<double> Encode(object input)
        {
            if (!ValidateInput(input))
            {
                throw new ArgumentException($"Invalid input type for numerical encoding. Expected numerical array or Vector/Tensor, got {input?.GetType()?.Name ?? "null"}");
            }

            // Preprocess the input
            var preprocessed = Preprocess(input);
            var numericData = preprocessed as double[] ?? throw new InvalidOperationException("Preprocessing failed");

            // Extract features
            var features = ExtractNumericalFeatures(numericData);
            
            // Project to output dimension if needed
            if (features.Length != OutputDimension)
            {
                features = ProjectToOutputDimension(features);
            }

            // Final normalization
            return Normalize(features);
        }

        /// <summary>
        /// Preprocesses raw numerical input
        /// </summary>
        public override object Preprocess(object input)
        {
            double[] data;

            switch (input)
            {
                case double[] doubleArray:
                    data = (double[])doubleArray.Clone();
                    break;
                case float[] floatArray:
                    data = floatArray.Select(f => (double)f).ToArray();
                    break;
                case int[] intArray:
                    data = intArray.Select(i => (double)i).ToArray();
                    break;
                case Vector<double> vector:
                    data = vector.ToArray();
                    break;
                case Vector<float> floatVector:
                    data = floatVector.ToArray().Select(f => (double)f).ToArray();
                    break;
                case Tensor<double> tensor:
                    if (tensor.Rank != 1)
                        throw new ArgumentException($"Tensor must be 1D for numerical encoding, got rank {tensor.Rank}");
                    data = tensor.ToArray();
                    break;
                case Tensor<float> floatTensor:
                    if (floatTensor.Rank != 1)
                        throw new ArgumentException($"Tensor must be 1D for numerical encoding, got rank {floatTensor.Rank}");
                    data = floatTensor.ToArray().Select(f => (double)f).ToArray();
                    break;
                default:
                    throw new ArgumentException($"Unsupported input type: {input?.GetType()?.Name ?? "null"}");
            }

            // Handle missing values
            data = HandleMissingValues(data);

            // Compute statistics if needed
            if (!_statisticsComputed && _normalizationMethod != NormalizationMethod.None)
            {
                ComputeStatistics(data);
            }

            // Apply normalization
            data = ApplyNormalization(data);

            return data;
        }

        /// <summary>
        /// Validates the input for numerical encoding
        /// </summary>
        protected override bool ValidateInput(object input)
        {
            return input is double[] || input is float[] || input is int[] ||
                   input is Vector<double> || input is Vector<float> ||
                   input is Tensor<double> || input is Tensor<float>;
        }

        /// <summary>
        /// Extracts features from numerical data
        /// </summary>
        private Vector<double> ExtractNumericalFeatures(double[] data)
        {
            var features = new List<double>();

            // Original features
            features.AddRange(data);

            if (_useFeatureEngineering)
            {
                // Statistical aggregations
                features.AddRange(ExtractStatisticalFeatures(data));

                // Polynomial features
                if (_polynomialDegree > 1)
                {
                    features.AddRange(ExtractPolynomialFeatures(data));
                }

                // Interaction features
                if (_useInteractionFeatures && data.Length > 1)
                {
                    features.AddRange(ExtractInteractionFeatures(data));
                }

                // Binned features
                features.AddRange(ExtractBinnedFeatures(data));
            }

            return new Vector<double>(features.ToArray());
        }

        /// <summary>
        /// Extracts statistical features from the data
        /// </summary>
        private double[] ExtractStatisticalFeatures(double[] data)
        {
            var features = new List<double>();

            if (data.Length == 0)
                return features.ToArray();

            // Basic statistics
            double mean = data.Average();
            double variance = data.Select(x => Math.Pow(x - mean, 2)).Average();
            double stdDev = Math.Sqrt(variance);
            
            features.Add(mean);
            features.Add(stdDev);
            features.Add(data.Min());
            features.Add(data.Max());
            features.Add(data.Max() - data.Min()); // Range

            // Higher moments
            if (stdDev > 0)
            {
                double skewness = data.Select(x => Math.Pow((x - mean) / stdDev, 3)).Average();
                double kurtosis = data.Select(x => Math.Pow((x - mean) / stdDev, 4)).Average() - 3;
                features.Add(skewness);
                features.Add(kurtosis);
            }
            else
            {
                features.Add(0); // Skewness
                features.Add(0); // Kurtosis
            }

            // Percentiles
            var sorted = data.OrderBy(x => x).ToArray();
            features.Add(GetPercentile(sorted, 0.25)); // Q1
            features.Add(GetPercentile(sorted, 0.50)); // Median
            features.Add(GetPercentile(sorted, 0.75)); // Q3

            return features.ToArray();
        }

        /// <summary>
        /// Extracts polynomial features
        /// </summary>
        private double[] ExtractPolynomialFeatures(double[] data)
        {
            var features = new List<double>();

            // Square features
            foreach (var value in data)
            {
                features.Add(value * value);
            }

            // Cubic features if degree >= 3
            if (_polynomialDegree >= 3)
            {
                foreach (var value in data)
                {
                    features.Add(value * value * value);
                }
            }

            return features.ToArray();
        }

        /// <summary>
        /// Extracts interaction features between pairs of features
        /// </summary>
        private double[] ExtractInteractionFeatures(double[] data)
        {
            var features = new List<double>();
            int maxInteractions = Math.Min(data.Length * (data.Length - 1) / 2, 50); // Limit interactions
            int added = 0;

            for (int i = 0; i < data.Length && added < maxInteractions; i++)
            {
                for (int j = i + 1; j < data.Length && added < maxInteractions; j++)
                {
                    // Multiplication interaction
                    features.Add(data[i] * data[j]);
                    
                    // Difference interaction
                    features.Add(data[i] - data[j]);
                    
                    // Ratio interaction (with protection against division by zero)
                    if (Math.Abs(data[j]) > 1e-8)
                    {
                        features.Add(data[i] / data[j]);
                    }
                    else
                    {
                        features.Add(0);
                    }
                    
                    added++;
                }
            }

            return features.ToArray();
        }

        /// <summary>
        /// Creates binned/discretized features
        /// </summary>
        private double[] ExtractBinnedFeatures(double[] data)
        {
            var features = new List<double>();
            int numBins = 5;

            foreach (var value in data)
            {
                // Create one-hot encoded bins
                var bins = new double[numBins];
                double normalizedValue = (value - data.Min()) / (data.Max() - data.Min() + 1e-8);
                int binIndex = Math.Min((int)(normalizedValue * numBins), numBins - 1);
                bins[binIndex] = 1.0;
                features.AddRange(bins);
            }

            return features.ToArray();
        }

        /// <summary>
        /// Projects features to the desired output dimension
        /// </summary>
        private Vector<double> ProjectToOutputDimension(Vector<double> features)
        {
            if (features.Length == OutputDimension)
                return features;

            var result = new double[OutputDimension];

            if (features.Length > OutputDimension)
            {
                // Use feature selection based on variance
                var featureVariances = new List<(int Index, double Variance)>();
                
                for (int i = 0; i < features.Length; i++)
                {
                    // Simple variance estimate using feature value as proxy
                    featureVariances.Add((i, Math.Abs(features[i])));
                }

                // Select top features by variance
                var selectedIndices = featureVariances
                    .OrderByDescending(f => f.Variance)
                    .Take(OutputDimension)
                    .OrderBy(f => f.Index)
                    .Select(f => f.Index)
                    .ToList();

                for (int i = 0; i < OutputDimension; i++)
                {
                    result[i] = features[selectedIndices[i]];
                }
            }
            else
            {
                // Copy existing features
                for (int i = 0; i < features.Length; i++)
                {
                    result[i] = features[i];
                }
                
                // Pad with learned representations
                var random = new Random(42);
                for (int i = features.Length; i < OutputDimension; i++)
                {
                    // Create synthetic features based on existing ones
                    int idx1 = random.Next(features.Length);
                    int idx2 = random.Next(features.Length);
                    result[i] = (features[idx1] + features[idx2]) / 2.0;
                }
            }

            return new Vector<double>(result);
        }

        /// <summary>
        /// Handles missing values in the data
        /// </summary>
        private double[] HandleMissingValues(double[] data)
        {
            var result = new double[data.Length];
            
            for (int i = 0; i < data.Length; i++)
            {
                if (double.IsNaN(data[i]) || double.IsInfinity(data[i]))
                {
                    result[i] = _missingValueIndicator;
                }
                else
                {
                    result[i] = data[i];
                }
            }

            return result;
        }

        /// <summary>
        /// Computes statistics for normalization
        /// </summary>
        private void ComputeStatistics(double[] data)
        {
            int n = data.Length;
            _featureMeans = new double[n];
            _featureStdDevs = new double[n];
            _featureMins = new double[n];
            _featureMaxs = new double[n];

            // For this simple implementation, compute element-wise statistics
            for (int i = 0; i < n; i++)
            {
                _featureMeans[i] = data[i];
                _featureStdDevs[i] = 1.0; // Default to 1 for single sample
                _featureMins[i] = data[i];
                _featureMaxs[i] = data[i];
            }

            _statisticsComputed = true;
        }

        /// <summary>
        /// Applies normalization to the data
        /// </summary>
        private double[] ApplyNormalization(double[] data)
        {
            if (_normalizationMethod == NormalizationMethod.None)
                return data;

            var normalized = new double[data.Length];

            for (int i = 0; i < data.Length; i++)
            {
                switch (_normalizationMethod)
                {
                    case NormalizationMethod.StandardScore:
                        if (_statisticsComputed && i < _featureStdDevs.Length && _featureStdDevs[i] > 0)
                        {
                            normalized[i] = (data[i] - _featureMeans[i]) / _featureStdDevs[i];
                        }
                        else
                        {
                            normalized[i] = data[i];
                        }
                        break;

                    case NormalizationMethod.MinMax:
                        if (_statisticsComputed && i < _featureMaxs.Length)
                        {
                            double range = _featureMaxs[i] - _featureMins[i];
                            if (range > 0)
                            {
                                normalized[i] = (data[i] - _featureMins[i]) / range;
                            }
                            else
                            {
                                normalized[i] = 0.5; // Center if no range
                            }
                        }
                        else
                        {
                            normalized[i] = data[i];
                        }
                        break;

                    case NormalizationMethod.Robust:
                        // Simplified robust scaling using median and IQR approximation
                        normalized[i] = data[i] / (1 + Math.Abs(data[i]));
                        break;

                    default:
                        normalized[i] = data[i];
                        break;
                }
            }

            return normalized;
        }

        /// <summary>
        /// Gets the percentile value from sorted data
        /// </summary>
        private double GetPercentile(double[] sortedData, double percentile)
        {
            if (sortedData.Length == 0)
                return 0;

            double index = percentile * (sortedData.Length - 1);
            int lower = (int)Math.Floor(index);
            int upper = (int)Math.Ceiling(index);

            if (lower == upper)
                return sortedData[lower];

            double weight = index - lower;
            return sortedData[lower] * (1 - weight) + sortedData[upper] * weight;
        }

        /// <summary>
        /// Fits the encoder to training data (for learning statistics)
        /// </summary>
        public void Fit(double[][] trainingData)
        {
            if (trainingData == null || trainingData.Length == 0)
                return;

            int numFeatures = trainingData[0].Length;
            _featureMeans = new double[numFeatures];
            _featureStdDevs = new double[numFeatures];
            _featureMins = new double[numFeatures];
            _featureMaxs = new double[numFeatures];

            // Initialize min/max
            for (int i = 0; i < numFeatures; i++)
            {
                _featureMins[i] = double.MaxValue;
                _featureMaxs[i] = double.MinValue;
            }

            // Compute means and min/max
            foreach (var sample in trainingData)
            {
                for (int i = 0; i < numFeatures && i < sample.Length; i++)
                {
                    _featureMeans[i] += sample[i];
                    _featureMins[i] = Math.Min(_featureMins[i], sample[i]);
                    _featureMaxs[i] = Math.Max(_featureMaxs[i], sample[i]);
                }
            }

            for (int i = 0; i < numFeatures; i++)
            {
                _featureMeans[i] /= trainingData.Length;
            }

            // Compute standard deviations
            foreach (var sample in trainingData)
            {
                for (int i = 0; i < numFeatures && i < sample.Length; i++)
                {
                    _featureStdDevs[i] += Math.Pow(sample[i] - _featureMeans[i], 2);
                }
            }

            for (int i = 0; i < numFeatures; i++)
            {
                _featureStdDevs[i] = Math.Sqrt(_featureStdDevs[i] / trainingData.Length);
            }

            _statisticsComputed = true;
        }
    }
}