using AiDotNet.Interfaces;
using AiDotNet.LinearAlgebra;
using AiDotNet.NeuralNetworks;
using AiDotNet.NeuralNetworks.Layers;
using AiDotNet.ActivationFunctions;
using AiDotNet.Extensions;
using AiDotNet.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using System.Threading.Tasks;

namespace AiDotNet.MultimodalAI
{
    /// <summary>
    /// Cross-attention multimodal model that uses attention mechanisms to fuse modalities
    /// </summary>
    /// <remarks>
    /// This model implements cross-attention fusion where different modalities
    /// attend to each other through learned attention mechanisms. This allows
    /// for dynamic, context-aware fusion of multimodal information.
    /// </remarks>
    [Serializable]
    public class CrossAttentionMultimodal : MultimodalModelBase, IDisposable
    {
        private readonly int _numAttentionHeads;
        private readonly int _attentionDimension;
        private readonly double _learningRate;
        private readonly double _dropoutRate;
        private readonly Dictionary<string, Matrix<double>> _queryProjections;
        private readonly Dictionary<string, Matrix<double>> _keyProjections;
        private readonly Dictionary<string, Matrix<double>> _valueProjections;
        private Matrix<double>? _outputProjection;
        private NeuralNetwork<double>? _feedForwardNetwork;
        private readonly Random _random;
        private bool _disposed;
        private readonly object _lockObject = new object();

        /// <summary>
        /// Initializes a new instance of CrossAttentionMultimodal
        /// </summary>
        /// <param name="fusedDimension">Dimension of the fused representation</param>
        /// <param name="numAttentionHeads">Number of attention heads</param>
        /// <param name="attentionDimension">Dimension for attention computation</param>
        /// <param name="learningRate">Learning rate for training</param>
        /// <param name="dropoutRate">Dropout rate for regularization</param>
        public CrossAttentionMultimodal(int fusedDimension, int numAttentionHeads = 8,
                                      int attentionDimension = 64, double learningRate = 0.001,
                                      double dropoutRate = 0.1, int? randomSeed = null)
            : base("cross_attention", fusedDimension)
        {
            if (fusedDimension <= 0)
                throw new ArgumentException("Fused dimension must be positive", nameof(fusedDimension));
            if (numAttentionHeads <= 0)
                throw new ArgumentException("Number of attention heads must be positive", nameof(numAttentionHeads));
            if (attentionDimension <= 0)
                throw new ArgumentException("Attention dimension must be positive", nameof(attentionDimension));
            if (learningRate <= 0 || learningRate > 1)
                throw new ArgumentException("Learning rate must be in (0, 1]", nameof(learningRate));
            if (dropoutRate < 0 || dropoutRate >= 1)
                throw new ArgumentException("Dropout rate must be in [0, 1)", nameof(dropoutRate));

            _numAttentionHeads = numAttentionHeads;
            _attentionDimension = attentionDimension;
            _learningRate = learningRate;
            _dropoutRate = dropoutRate;
            _queryProjections = new Dictionary<string, Matrix<double>>();
            _keyProjections = new Dictionary<string, Matrix<double>>();
            _valueProjections = new Dictionary<string, Matrix<double>>();
            _random = randomSeed.HasValue ? new Random(randomSeed.Value) : new Random();
        }

        /// <summary>
        /// Adds a modality encoder and initializes attention projections
        /// </summary>
        public override void AddModalityEncoder(string modalityName, IModalityEncoder encoder)
        {
            base.AddModalityEncoder(modalityName, encoder);
            
            // Initialize attention projection matrices for this modality
            int encoderDim = encoder.OutputDimension;
            
            _queryProjections[modalityName] = InitializeProjectionMatrix(encoderDim, _attentionDimension * _numAttentionHeads);
            _keyProjections[modalityName] = InitializeProjectionMatrix(encoderDim, _attentionDimension * _numAttentionHeads);
            _valueProjections[modalityName] = InitializeProjectionMatrix(encoderDim, _attentionDimension * _numAttentionHeads);
        }

        /// <summary>
        /// Processes multimodal input data using cross-attention fusion
        /// </summary>
        /// <param name="modalityData">Dictionary mapping modality names to their data</param>
        /// <returns>Fused representation</returns>
        public override Vector<double> ProcessMultimodal(Dictionary<string, object> modalityData)
        {
            ValidateModalityData(modalityData);

            // Encode each modality
            var encodedModalities = new Dictionary<string, Vector<double>>();
            foreach (var kvp in modalityData)
            {
                if (_modalityEncoders.ContainsKey(kvp.Key))
                {
                    encodedModalities[kvp.Key] = EncodeModality(kvp.Key, kvp.Value);
                }
            }

            // Apply cross-modal attention
            var attendedFeatures = new Dictionary<string, Vector<double>>();
            
            foreach (var queryModality in encodedModalities.Keys)
            {
                var queryFeatures = encodedModalities[queryModality];
                var attended = ApplyCrossModalAttention(queryFeatures, encodedModalities, queryModality);
                attendedFeatures[queryModality] = attended;
            }

            // Combine attended features
            var combined = CombineAttendedFeatures(attendedFeatures);

            // Initialize output projection if needed
            if (_outputProjection == null)
            {
                _outputProjection = InitializeProjectionMatrix(combined.Length, _fusedDimension);
            }

            // Apply output projection
            var projected = _outputProjection * combined;

            // Apply feed-forward network
            if (_feedForwardNetwork == null)
            {
                InitializeFeedForwardNetwork(_fusedDimension);
            }
            
            // Process through neural network
            var inputTensor = new Tensor<double>(new[] { projected.Length }, projected);
            var outputTensor = _feedForwardNetwork!.Predict(inputTensor);
            
            // Extract output vector
            var outputArray = outputTensor.ToArray();
            var output = new Vector<double>(outputArray.Length);
            for (int i = 0; i < outputArray.Length; i++)
            {
                output[i] = outputArray[i];
            }

            return NormalizeFused(output);
        }

        /// <summary>
        /// Applies cross-modal attention mechanism
        /// </summary>
        private Vector<double> ApplyCrossModalAttention(Vector<double> queryFeatures, Dictionary<string, Vector<double>> allModalities, string queryModality)
        {
            // Project query features
            var queries = ProjectToMultiHead(_queryProjections[queryModality] * queryFeatures);

            // Collect keys and values from all modalities
            var allKeys = new List<Matrix<double>>();
            var allValues = new List<Matrix<double>>();

            foreach (var kvp in allModalities)
            {
                var features = kvp.Value;
                var keys = ProjectToMultiHead(_keyProjections[kvp.Key] * features);
                var values = ProjectToMultiHead(_valueProjections[kvp.Key] * features);
                
                allKeys.Add(keys);
                allValues.Add(values);
            }

            // Compute attention for each head
            var attendedHeads = new List<Vector<double>>();
            
            for (int head = 0; head < _numAttentionHeads; head++)
            {
                var headAttended = ComputeAttentionHead(
                    GetHeadSlice(queries, head),
                    allKeys.Select(k => GetHeadSlice(k, head)).ToList(),
                    allValues.Select(v => GetHeadSlice(v, head)).ToList()
                );
                attendedHeads.Add(headAttended);
            }

            // Concatenate heads
            return ConcatenateHeads(attendedHeads);
        }

        /// <summary>
        /// Computes attention for a single head
        /// </summary>
        private Vector<double> ComputeAttentionHead(Vector<double> query, List<Vector<double>> keys, List<Vector<double>> values)
        {
            var scores = new Vector<double>(keys.Count);
            
            // Compute attention scores
            for (int i = 0; i < keys.Count; i++)
            {
                scores[i] = ComputeAttentionScore(query, keys[i]);
            }

            // Apply softmax to get attention weights
            var weights = Softmax(scores);

            // Weighted sum of values
            var attended = new Vector<double>(values[0].Length);
            for (int i = 0; i < values.Count; i++)
            {
                for (int j = 0; j < attended.Length; j++)
                {
                    attended[j] += weights[i] * values[i][j];
                }
            }

            return attended;
        }

        /// <summary>
        /// Computes attention score between query and key
        /// </summary>
        private double ComputeAttentionScore(Vector<double> query, Vector<double> key)
        {
            // Scaled dot-product attention
            double dotProduct = 0;
            for (int i = 0; i < query.Length; i++)
            {
                dotProduct += query[i] * key[i];
            }
            return dotProduct / Math.Sqrt(_attentionDimension);
        }

        /// <summary>
        /// Applies softmax to scores
        /// </summary>
        private Vector<double> Softmax(Vector<double> scores)
        {
            var exp = new Vector<double>(scores.Length);
            double maxScore = scores.Max();
            double sum = 0;

            // Compute exp(score - max) for numerical stability
            for (int i = 0; i < scores.Length; i++)
            {
                exp[i] = Math.Exp(scores[i] - maxScore);
                sum += exp[i];
            }

            // Normalize
            for (int i = 0; i < exp.Length; i++)
            {
                exp[i] /= sum;
            }

            return exp;
        }

        /// <summary>
        /// Projects features to multi-head format
        /// </summary>
        private Matrix<double> ProjectToMultiHead(Vector<double> features)
        {
            int headDim = _attentionDimension;
            var multiHead = new Matrix<double>(_numAttentionHeads, headDim);
            
            for (int head = 0; head < _numAttentionHeads; head++)
            {
                for (int i = 0; i < headDim; i++)
                {
                    int idx = head * headDim + i;
                    if (idx < features.Length)
                    {
                        multiHead[head, i] = features[idx];
                    }
                }
            }
            
            return multiHead;
        }

        /// <summary>
        /// Gets a slice for a specific attention head
        /// </summary>
        private Vector<double> GetHeadSlice(Matrix<double> multiHead, int head)
        {
            var slice = new Vector<double>(multiHead.Columns);
            for (int i = 0; i < multiHead.Columns; i++)
            {
                slice[i] = multiHead[head, i];
            }
            return slice;
        }

        /// <summary>
        /// Concatenates attention heads
        /// </summary>
        private Vector<double> ConcatenateHeads(List<Vector<double>> heads)
        {
            int totalDim = heads.Sum(h => h.Length);
            var concatenated = new Vector<double>(totalDim);
            
            int offset = 0;
            foreach (var head in heads)
            {
                for (int i = 0; i < head.Length; i++)
                {
                    concatenated[offset + i] = head[i];
                }
                offset += head.Length;
            }
            
            return concatenated;
        }

        /// <summary>
        /// Combines attended features from all modalities
        /// </summary>
        private Vector<double> CombineAttendedFeatures(Dictionary<string, Vector<double>> attendedFeatures)
        {
            // Use weighted combination based on cross-modality attention weights
            if (_crossModalityAttention != null)
            {
                return WeightedCombination(attendedFeatures, _crossModalityAttention);
            }

            // Default: concatenate all attended features
            var features = attendedFeatures.Values.ToList();
            int totalDim = features.Sum(f => f.Length);
            var combined = new Vector<double>(totalDim);
            
            int offset = 0;
            foreach (var feature in features)
            {
                for (int i = 0; i < feature.Length; i++)
                {
                    combined[offset + i] = feature[i];
                }
                offset += feature.Length;
            }
            
            return combined;
        }

        /// <summary>
        /// Performs weighted combination of features
        /// </summary>
        private Vector<double> WeightedCombination(Dictionary<string, Vector<double>> features, Matrix<double> weights)
        {
            var modalityList = features.Keys.ToList();
            var firstFeature = features.Values.First();
            var combined = new Vector<double>(firstFeature.Length);

            for (int i = 0; i < modalityList.Count; i++)
            {
                var modality = modalityList[i];
                var feature = features[modality];
                
                for (int j = 0; j < feature.Length; j++)
                {
                    // Use diagonal weights for simplicity
                    double weight = (i < weights.Rows && i < weights.Columns) ? weights[i, i] : 1.0 / modalityList.Count;
                    combined[j] += weight * feature[j];
                }
            }

            return combined;
        }

        /// <summary>
        /// Initializes projection matrix with Xavier initialization
        /// </summary>
        private Matrix<double> InitializeProjectionMatrix(int inputDim, int outputDim)
        {
            var random = new Random();
            var matrix = new Matrix<double>(outputDim, inputDim);
            double scale = Math.Sqrt(2.0 / (inputDim + outputDim));
            
            for (int i = 0; i < outputDim; i++)
            {
                for (int j = 0; j < inputDim; j++)
                {
                    matrix[i, j] = (random.NextDouble() * 2 - 1) * scale;
                }
            }
            
            return matrix;
        }

        /// <summary>
        /// Initializes feed-forward network
        /// </summary>
        private void InitializeFeedForwardNetwork(int dimension)
        {
            // Create layers explicitly
            var layers = new List<ILayer<double>>
            {
                new FullyConnectedLayer<double>(dimension, dimension * 2, null as IActivationFunction<double>),
                new ActivationLayer<double>(new[] { dimension * 2 }, new ReLUActivation<double>() as IActivationFunction<double>),
                new DropoutLayer<double>(_dropoutRate),
                new FullyConnectedLayer<double>(dimension * 2, dimension, null as IActivationFunction<double>),
                new ActivationLayer<double>(new[] { dimension }, new ReLUActivation<double>() as IActivationFunction<double>)
            };

            var architecture = new NeuralNetworkArchitecture<double>(
                complexity: NetworkComplexity.Medium,
                taskType: NeuralNetworkTaskType.Regression,
                shouldReturnFullSequence: false,
                layers: layers,
                isDynamicSampleCount: true,
                isPlaceholder: false);
            _feedForwardNetwork = new NeuralNetwork<double>(architecture);
        }

        /// <summary>
        /// Creates a copy of the model
        /// </summary>
        public override IFullModel<double, Dictionary<string, object>, Vector<double>> Clone()
        {
            var clone = new CrossAttentionMultimodal(_fusedDimension, _numAttentionHeads,
                                                   _attentionDimension, _learningRate, _dropoutRate);

            // Copy encoders
            foreach (var kvp in _modalityEncoders)
            {
                clone.AddModalityEncoder(kvp.Key, kvp.Value);
            }

            if (_crossModalityAttention != null)
            {
                clone.SetCrossModalityAttention(_crossModalityAttention.Clone() as Matrix<double>);
            }

            clone._isTrained = _isTrained;
            clone.Name = Name;

            return clone;
        }

        /// <summary>
        /// Trains the cross-attention model
        /// </summary>
        public override void Train(Matrix<double> inputs, Vector<double> targets)
        {
            // Simplified training - would need proper attention weight updates
            Console.WriteLine("Cross-attention training not fully implemented in this example");
            _isTrained = true;
        }

        /// <summary>
        /// Gets parameters of the model
        /// </summary>
        public override Dictionary<string, object> GetParametersDictionary()
        {
            var parameters = base.GetParametersDictionary();
            parameters["NumAttentionHeads"] = _numAttentionHeads;
            parameters["AttentionDimension"] = _attentionDimension;
            parameters["LearningRate"] = _learningRate;
            parameters["DropoutRate"] = _dropoutRate;
            return parameters;
        }

        /// <summary>
        /// Performs application-defined tasks associated with freeing, releasing, or resetting unmanaged resources.
        /// </summary>
        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        /// <summary>
        /// Releases unmanaged and - optionally - managed resources.
        /// </summary>
        /// <param name="disposing">true to release both managed and unmanaged resources; false to release only unmanaged resources.</param>
        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (disposing)
                {
                    lock (_lockObject)
                    {
                        // Dispose feed-forward network
                        if (_feedForwardNetwork is IDisposable disposableNetwork)
                        {
                            disposableNetwork.Dispose();
                        }
                        
                        // Clear projection matrices
                        _queryProjections.Clear();
                        _keyProjections.Clear();
                        _valueProjections.Clear();
                        
                        // Dispose encoders if they implement IDisposable
                        foreach (var encoder in _modalityEncoders.Values)
                        {
                            if (encoder is IDisposable disposableEncoder)
                            {
                                disposableEncoder.Dispose();
                            }
                        }
                        _modalityEncoders.Clear();
                    }
                }

                _disposed = true;
            }
        }

        /// <summary>
        /// Finalizer
        /// </summary>
        ~CrossAttentionMultimodal()
        {
            Dispose(false);
        }
    }
}