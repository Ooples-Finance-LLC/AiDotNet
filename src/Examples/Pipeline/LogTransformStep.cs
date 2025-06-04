using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using AiDotNet.Interfaces;

namespace AiDotNet.Examples.Pipeline
{
    /// <summary>
    /// Pipeline step that applies logarithmic transformation to features.
    /// Useful for normalizing skewed distributions and handling outliers.
    /// </summary>
    /// <typeparam name="T">The numeric type used for calculations.</typeparam>
    public class LogTransformStep<T> : IPipelineStep
        where T : struct, IComparable<T>, IConvertible, IEquatable<T>
    {
        private double _offset = 1.0; // To handle zero and negative values
        private double _base = Math.E; // Natural logarithm by default
        private HashSet<int>? _featureIndices; // Which features to transform (null = all)
        
        public string Name => "LogTransform";
        public bool IsFitted { get; private set; }

        /// <summary>
        /// Creates a new log transform step.
        /// </summary>
        /// <param name="offset">Value to add before log transformation to handle zeros/negatives.</param>
        /// <param name="logBase">Base of the logarithm (e.g., Math.E, 10, 2).</param>
        /// <param name="featureIndices">Specific feature indices to transform (null = all features).</param>
        public LogTransformStep(double offset = 1.0, double logBase = 0, int[]? featureIndices = null)
        {
            _offset = offset;
            _base = logBase > 0 ? logBase : Math.E;
            _featureIndices = featureIndices?.ToHashSet();
        }

        public async Task FitAsync(double[][] inputs, double[]? targets = null)
        {
            // Validate inputs
            if (inputs == null || inputs.Length == 0)
                throw new ArgumentException("Input data cannot be null or empty.");

            // Check for negative values that would cause issues
            var minValue = double.MaxValue;
            foreach (var row in inputs)
            {
                foreach (var value in row)
                {
                    minValue = Math.Min(minValue, value);
                }
            }

            // Adjust offset if needed to ensure all values are positive after adding offset
            if (minValue + _offset <= 0)
            {
                _offset = Math.Abs(minValue) + 1.0;
                Console.WriteLine($"Adjusted offset to {_offset} to handle negative values.");
            }

            await Task.Delay(10); // Simulate processing
            IsFitted = true;
        }

        public async Task<double[][]> TransformAsync(double[][] inputs)
        {
            if (!IsFitted)
                throw new InvalidOperationException("LogTransformStep must be fitted before transforming data.");

            var transformed = new double[inputs.Length][];
            
            for (int i = 0; i < inputs.Length; i++)
            {
                transformed[i] = new double[inputs[i].Length];
                
                for (int j = 0; j < inputs[i].Length; j++)
                {
                    // Apply transform only to specified features (or all if not specified)
                    if (_featureIndices == null || _featureIndices.Contains(j))
                    {
                        // Apply log transformation with offset
                        var value = inputs[i][j] + _offset;
                        transformed[i][j] = _base == Math.E 
                            ? Math.Log(value) 
                            : Math.Log(value) / Math.Log(_base);
                    }
                    else
                    {
                        // Keep original value for features not being transformed
                        transformed[i][j] = inputs[i][j];
                    }
                }
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
            var parameters = new Dictionary<string, object>
            {
                ["Offset"] = _offset,
                ["Base"] = _base,
                ["TransformAll"] = _featureIndices == null
            };
            
            if (_featureIndices != null)
            {
                parameters["FeatureIndices"] = _featureIndices.ToArray();
            }
            
            return parameters;
        }

        public void SetParameters(Dictionary<string, object> parameters)
        {
            if (parameters.ContainsKey("Offset"))
                _offset = Convert.ToDouble(parameters["Offset"]);
            
            if (parameters.ContainsKey("Base"))
                _base = Convert.ToDouble(parameters["Base"]);
            
            if (parameters.ContainsKey("FeatureIndices") && parameters["FeatureIndices"] is int[] indices)
                _featureIndices = indices.ToHashSet();
        }

        public bool ValidateInput(double[][] inputs)
        {
            if (inputs == null || inputs.Length == 0)
                return false;

            // Check that all rows have the same number of features
            var expectedFeatures = inputs[0].Length;
            return inputs.All(row => row != null && row.Length == expectedFeatures);
        }

        public Dictionary<string, string> GetMetadata()
        {
            return new Dictionary<string, string>
            {
                ["Type"] = "LogTransform",
                ["Version"] = "1.0",
                ["Description"] = "Applies logarithmic transformation to features",
                ["Formula"] = _base == Math.E ? $"ln(x + {_offset})" : $"log_{_base}(x + {_offset})"
            };
        }

        /// <summary>
        /// Inverse transform to convert log-transformed values back to original scale.
        /// </summary>
        public double[][] InverseTransform(double[][] transformedInputs)
        {
            var original = new double[transformedInputs.Length][];
            
            for (int i = 0; i < transformedInputs.Length; i++)
            {
                original[i] = new double[transformedInputs[i].Length];
                
                for (int j = 0; j < transformedInputs[i].Length; j++)
                {
                    if (_featureIndices == null || _featureIndices.Contains(j))
                    {
                        // Apply inverse transformation
                        var value = _base == Math.E 
                            ? Math.Exp(transformedInputs[i][j])
                            : Math.Pow(_base, transformedInputs[i][j]);
                        original[i][j] = value - _offset;
                    }
                    else
                    {
                        original[i][j] = transformedInputs[i][j];
                    }
                }
            }
            
            return original;
        }
    }
}