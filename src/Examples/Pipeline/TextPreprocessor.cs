using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using AiDotNet.Interfaces;

namespace AiDotNet.Examples.Pipeline
{
    /// <summary>
    /// Example text preprocessing pipeline step.
    /// In production, this would include tokenization, normalization, vectorization, etc.
    /// </summary>
    /// <typeparam name="T">The numeric type used for calculations.</typeparam>
    public class TextPreprocessor<T> : IPipelineStep
        where T : struct, IComparable<T>, IConvertible, IEquatable<T>
    {
        private Dictionary<string, int> _vocabulary = new();
        private int _maxVocabSize = 10000;
        private int _maxSequenceLength = 512;
        
        public string Name => "TextPreprocessor";
        public bool IsFitted { get; private set; }

        public async Task FitAsync(double[][] inputs, double[]? targets = null)
        {
            // Build vocabulary from input data
            // In a real implementation, this would analyze text data
            _vocabulary.Clear();
            _vocabulary["<PAD>"] = 0;
            _vocabulary["<UNK>"] = 1;
            _vocabulary["<START>"] = 2;
            _vocabulary["<END>"] = 3;
            
            // Simulate vocabulary building
            await Task.Delay(10);
            
            IsFitted = true;
        }

        public async Task<double[][]> TransformAsync(double[][] inputs)
        {
            if (!IsFitted)
                throw new InvalidOperationException("TextPreprocessor must be fitted before transforming data.");

            // In a real implementation, this would:
            // 1. Tokenize text
            // 2. Convert tokens to IDs
            // 3. Pad/truncate sequences
            // 4. Create attention masks
            
            var transformed = new List<double[]>();
            foreach (var input in inputs)
            {
                // Simulate text preprocessing
                var processed = new double[_maxSequenceLength];
                for (int i = 0; i < Math.Min(input.Length, _maxSequenceLength); i++)
                {
                    processed[i] = input[i];
                }
                transformed.Add(processed);
            }
            
            await Task.Delay(5);
            return transformed.ToArray();
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
                ["MaxVocabSize"] = _maxVocabSize,
                ["MaxSequenceLength"] = _maxSequenceLength,
                ["VocabularySize"] = _vocabulary.Count
            };
        }

        public void SetParameters(Dictionary<string, object> parameters)
        {
            if (parameters.ContainsKey("MaxVocabSize"))
                _maxVocabSize = Convert.ToInt32(parameters["MaxVocabSize"]);
            if (parameters.ContainsKey("MaxSequenceLength"))
                _maxSequenceLength = Convert.ToInt32(parameters["MaxSequenceLength"]);
        }

        public bool ValidateInput(double[][] inputs)
        {
            return inputs != null && inputs.Length > 0;
        }

        public Dictionary<string, string> GetMetadata()
        {
            return new Dictionary<string, string>
            {
                ["Type"] = "TextPreprocessor",
                ["Version"] = "1.0",
                ["Description"] = "Preprocesses text data for NLP models"
            };
        }
    }
}