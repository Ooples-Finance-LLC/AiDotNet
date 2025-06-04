using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using AiDotNet.Interfaces;

namespace AiDotNet.Examples.Pipeline
{
    /// <summary>
    /// Pipeline step that generates polynomial and interaction features.
    /// Transforms features into a higher-dimensional space to capture non-linear relationships.
    /// </summary>
    /// <typeparam name="T">The numeric type used for calculations.</typeparam>
    public class PolynomialFeaturesStep<T> : IPipelineStep
        where T : struct, IComparable<T>, IConvertible, IEquatable<T>
    {
        private readonly int _degree;
        private readonly bool _includeInteractions;
        private readonly bool _includeBias;
        private List<int[]>? _featurePowers;
        
        public string Name => "PolynomialFeatures";
        public bool IsFitted { get; private set; }

        /// <summary>
        /// Creates a new polynomial features step.
        /// </summary>
        /// <param name="degree">The degree of polynomial features to generate.</param>
        /// <param name="includeInteractions">Whether to include interaction terms.</param>
        /// <param name="includeBias">Whether to include a bias term (all ones).</param>
        public PolynomialFeaturesStep(int degree = 2, bool includeInteractions = true, bool includeBias = true)
        {
            if (degree < 1)
                throw new ArgumentException("Degree must be at least 1.", nameof(degree));
            
            _degree = degree;
            _includeInteractions = includeInteractions;
            _includeBias = includeBias;
        }

        public async Task FitAsync(double[][] inputs, double[]? targets = null)
        {
            if (inputs == null || inputs.Length == 0)
                throw new ArgumentException("Input data cannot be null or empty.");

            var numFeatures = inputs[0].Length;
            
            // Generate all combinations of feature powers up to the specified degree
            _featurePowers = GenerateFeaturePowers(numFeatures, _degree, _includeInteractions);
            
            await Task.Delay(10); // Simulate processing
            IsFitted = true;
        }

        public async Task<double[][]> TransformAsync(double[][] inputs)
        {
            if (!IsFitted || _featurePowers == null)
                throw new InvalidOperationException("PolynomialFeaturesStep must be fitted before transforming data.");

            var transformed = new double[inputs.Length][];
            
            for (int i = 0; i < inputs.Length; i++)
            {
                var features = new List<double>();
                
                // Apply each power combination
                foreach (var powers in _featurePowers)
                {
                    double value = 1.0;
                    for (int j = 0; j < powers.Length; j++)
                    {
                        if (powers[j] > 0)
                        {
                            value *= Math.Pow(inputs[i][j], powers[j]);
                        }
                    }
                    features.Add(value);
                }
                
                transformed[i] = features.ToArray();
            }

            await Task.Delay(5); // Simulate processing
            return transformed;
        }

        public async Task<double[][]> FitTransformAsync(double[][] inputs, double[]? targets = null)
        {
            await FitAsync(inputs, targets);
            return await TransformAsync(inputs);
        }

        public Dictionary<string, object> GetParameters()
        {
            return new Dictionary<string, object>
            {
                ["Degree"] = _degree,
                ["IncludeInteractions"] = _includeInteractions,
                ["IncludeBias"] = _includeBias,
                ["NumGeneratedFeatures"] = _featurePowers?.Count ?? 0
            };
        }

        public void SetParameters(Dictionary<string, object> parameters)
        {
            // Degree is set in constructor and cannot be changed after creation
            // This is because changing the degree would require re-fitting
        }

        public bool ValidateInput(double[][] inputs)
        {
            if (inputs == null || inputs.Length == 0)
                return false;

            var expectedFeatures = inputs[0].Length;
            return inputs.All(row => row != null && row.Length == expectedFeatures);
        }

        public Dictionary<string, string> GetMetadata()
        {
            return new Dictionary<string, string>
            {
                ["Type"] = "PolynomialFeatures",
                ["Version"] = "1.0",
                ["Description"] = $"Generates polynomial features up to degree {_degree}",
                ["Features"] = _includeInteractions ? "Includes interactions" : "No interactions"
            };
        }

        /// <summary>
        /// Gets the feature names for the transformed features.
        /// </summary>
        /// <param name="inputFeatureNames">Names of the input features.</param>
        /// <returns>Names of all polynomial features.</returns>
        public string[] GetFeatureNames(string[] inputFeatureNames)
        {
            if (_featurePowers == null)
                throw new InvalidOperationException("PolynomialFeaturesStep must be fitted first.");

            var featureNames = new List<string>();
            
            foreach (var powers in _featurePowers)
            {
                var terms = new List<string>();
                
                for (int i = 0; i < powers.Length; i++)
                {
                    if (powers[i] > 0)
                    {
                        var term = inputFeatureNames[i];
                        if (powers[i] > 1)
                        {
                            term += $"^{powers[i]}";
                        }
                        terms.Add(term);
                    }
                }
                
                if (terms.Count == 0)
                {
                    featureNames.Add("1"); // Bias term
                }
                else
                {
                    featureNames.Add(string.Join("*", terms));
                }
            }
            
            return featureNames.ToArray();
        }

        private List<int[]> GenerateFeaturePowers(int numFeatures, int degree, bool includeInteractions)
        {
            var powers = new List<int[]>();
            
            // Add bias term if requested
            if (_includeBias)
            {
                powers.Add(new int[numFeatures]); // All zeros = bias term
            }
            
            // Generate all combinations
            GeneratePowersRecursive(powers, new int[numFeatures], 0, 0, degree, includeInteractions);
            
            return powers;
        }

        private void GeneratePowersRecursive(
            List<int[]> powers,
            int[] current,
            int featureIndex,
            int currentDegree,
            int maxDegree,
            bool includeInteractions)
        {
            if (currentDegree > maxDegree)
                return;
            
            if (featureIndex == current.Length)
            {
                // Check if this is a valid combination
                var totalDegree = current.Sum();
                if (totalDegree > 0 && totalDegree <= maxDegree)
                {
                    // Check interaction constraint
                    if (includeInteractions || current.Count(p => p > 0) <= 1)
                    {
                        powers.Add((int[])current.Clone());
                    }
                }
                return;
            }
            
            // Try all possible powers for this feature
            for (int power = 0; power <= maxDegree - currentDegree; power++)
            {
                current[featureIndex] = power;
                GeneratePowersRecursive(powers, current, featureIndex + 1, currentDegree + power, maxDegree, includeInteractions);
            }
            
            current[featureIndex] = 0; // Reset for backtracking
        }
    }
}