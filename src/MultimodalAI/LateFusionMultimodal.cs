using AiDotNet.Interfaces;
using AiDotNet.LinearAlgebra;
using AiDotNet.NeuralNetworks;
using AiDotNet.NeuralNetworks.Layers;
using AiDotNet.ActivationFunctions;
using AiDotNet.Enums;
using AiDotNet.Extensions;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using System.Threading.Tasks;

namespace AiDotNet.MultimodalAI
{
    /// <summary>
    /// Late fusion multimodal model that processes each modality separately before combining
    /// </summary>
    /// <remarks>
    /// This model implements late fusion strategy where each modality is processed
    /// independently through separate neural networks before combining their outputs.
    /// This approach preserves modality-specific characteristics and allows for
    /// specialized processing of each input type.
    /// </remarks>
    [Serializable]
    public class LateFusionMultimodal : MultimodalModelBase, IDisposable
    {
        private readonly Dictionary<string, NeuralNetwork<double>> _modalityNetworks;
        private NeuralNetwork<double>? _fusionNetwork;
        private readonly int _modalityHiddenSize;
        private readonly int _fusionHiddenSize;
        private readonly double _learningRate;
        private readonly string _aggregationMethod;
        private readonly Random _random;
        private readonly Dictionary<string, double> _modalityWeights;
        private bool _disposed;
        private readonly object _lockObject = new object();

        /// <summary>
        /// Initializes a new instance of LateFusionMultimodal
        /// </summary>
        /// <param name="fusedDimension">Dimension of the fused representation</param>
        /// <param name="modalityHiddenSize">Hidden size for modality-specific networks</param>
        /// <param name="fusionHiddenSize">Hidden size for fusion network</param>
        /// <param name="learningRate">Learning rate for training</param>
        /// <param name="aggregationMethod">Method for aggregating modality outputs (mean, max, weighted)</param>
        public LateFusionMultimodal(int fusedDimension, int modalityHiddenSize = 128,
                                  int fusionHiddenSize = 256, double learningRate = 0.001,
                                  string aggregationMethod = "weighted", int? randomSeed = null)
            : base("late_fusion", fusedDimension)
        {
            if (fusedDimension <= 0)
                throw new ArgumentException("Fused dimension must be positive", nameof(fusedDimension));
            if (modalityHiddenSize <= 0)
                throw new ArgumentException("Modality hidden size must be positive", nameof(modalityHiddenSize));
            if (fusionHiddenSize <= 0)
                throw new ArgumentException("Fusion hidden size must be positive", nameof(fusionHiddenSize));
            if (learningRate <= 0 || learningRate > 1)
                throw new ArgumentException("Learning rate must be in (0, 1]", nameof(learningRate));
            if (!new[] { "mean", "max", "weighted", "concat" }.Contains(aggregationMethod.ToLowerInvariant()))
                throw new ArgumentException("Invalid aggregation method. Use 'mean', 'max', 'weighted', or 'concat'", nameof(aggregationMethod));

            _modalityNetworks = new Dictionary<string, NeuralNetwork<double>>();
            _modalityHiddenSize = modalityHiddenSize;
            _fusionHiddenSize = fusionHiddenSize;
            _learningRate = learningRate;
            _aggregationMethod = aggregationMethod.ToLowerInvariant();
            _random = randomSeed.HasValue ? new Random(randomSeed.Value) : new Random();
            _modalityWeights = new Dictionary<string, double>();
        }

        /// <summary>
        /// Adds a modality encoder and creates a corresponding network
        /// </summary>
        public override void AddModalityEncoder(string modalityName, IModalityEncoder encoder)
        {
            if (_disposed)
                throw new ObjectDisposedException(nameof(LateFusionMultimodal));

            base.AddModalityEncoder(modalityName, encoder);
            
            lock (_lockObject)
            {
                // Create a modality-specific network with explicit layers
                var layers = new List<ILayer<double>>
                {
                    new FullyConnectedLayer<double>(encoder.OutputDimension, _modalityHiddenSize, null as IActivationFunction<double>),
                    new ActivationLayer<double>(new[] { _modalityHiddenSize }, new ReLUActivation<double>() as IActivationFunction<double>),
                    new FullyConnectedLayer<double>(_modalityHiddenSize, _modalityHiddenSize / 2, null as IActivationFunction<double>),
                    new ActivationLayer<double>(new[] { _modalityHiddenSize / 2 }, new ReLUActivation<double>() as IActivationFunction<double>)
                };
                
                var architecture = new NeuralNetworkArchitecture<double>(
                    complexity: NetworkComplexity.Medium,
                    taskType: NeuralNetworkTaskType.Regression,
                    shouldReturnFullSequence: false,
                    layers: layers,
                    isDynamicSampleCount: true,
                    isPlaceholder: false);
                
                var network = new NeuralNetwork<double>(architecture);
                _modalityNetworks[modalityName] = network;
                
                // Initialize weight for weighted aggregation
                _modalityWeights[modalityName] = 1.0 / (_modalityWeights.Count + 1);
                
                // Normalize weights
                var totalWeight = _modalityWeights.Values.Sum();
                foreach (var key in _modalityWeights.Keys.ToList())
                {
                    _modalityWeights[key] /= totalWeight;
                }
            }
        }

        /// <summary>
        /// Processes multimodal input data using late fusion
        /// </summary>
        /// <param name="modalityData">Dictionary mapping modality names to their data</param>
        /// <returns>Fused representation</returns>
        public override Vector<double> ProcessMultimodal(Dictionary<string, object> modalityData)
        {
            if (_disposed)
                throw new ObjectDisposedException(nameof(LateFusionMultimodal));

            ValidateModalityData(modalityData);

            lock (_lockObject)
            {
                try
                {
                    var modalityOutputs = new Dictionary<string, Vector<double>>();
                    var processingTasks = new List<Task<(string, Vector<double>)>>();

                    // Process each modality independently in parallel
                    foreach (var kvp in modalityData)
                    {
                        if (_modalityEncoders.ContainsKey(kvp.Key) && _modalityNetworks.ContainsKey(kvp.Key))
                        {
                            var modalityName = kvp.Key;
                            var data = kvp.Value;
                            
                            var task = Task.Run(() =>
                            {
                                // Encode modality
                                var encoded = EncodeModality(modalityName, data);
                                
                                // Process through modality-specific network
                                var inputTensor = new Tensor<double>(new[] { encoded.Length }, encoded);
                                var outputTensor = _modalityNetworks[modalityName].Predict(inputTensor);
                                
                                // Extract output vector
                                var outputArray = outputTensor.ToArray();
                                var output = new Vector<double>(outputArray.Length);
                                for (int i = 0; i < outputArray.Length; i++)
                                {
                                    output[i] = outputArray[i];
                                }
                                
                                return (modalityName, output);
                            });
                            
                            processingTasks.Add(task);
                        }
                    }

                    // Wait for all modality processing to complete
                    Task.WaitAll(processingTasks.ToArray());
                    
                    // Collect results
                    foreach (var task in processingTasks)
                    {
                        var (modalityName, output) = task.Result;
                        modalityOutputs[modalityName] = output;
                    }

                    if (modalityOutputs.Count == 0)
                        throw new InvalidOperationException("No modalities were successfully processed");

                    // Aggregate modality outputs
                    var aggregated = AggregateModalityOutputs(modalityOutputs);

                    // Initialize fusion network if needed
                    if (_fusionNetwork == null)
                    {
                        InitializeFusionNetwork(aggregated.Length);
                    }

                    // Final fusion processing
                    var fusionInputTensor = new Tensor<double>(new[] { aggregated.Length }, aggregated);
                    var fusedTensor = _fusionNetwork!.Predict(fusionInputTensor);
                    
                    // Extract fused vector
                    var fusedArray = fusedTensor.ToArray();
                    var fused = new Vector<double>(fusedArray.Length);
                    for (int i = 0; i < fusedArray.Length; i++)
                    {
                        fused[i] = fusedArray[i];
                    }

                    // Project to target dimension if needed
                    if (fused.Length != _fusedDimension)
                    {
                        fused = ProjectToTargetDimension(fused, _fusedDimension);
                    }

                    return NormalizeFused(fused);
                }
                catch (Exception ex)
                {
                    throw new InvalidOperationException($"Error processing multimodal data: {ex.Message}", ex);
                }
            }
        }

        /// <summary>
        /// Trains the late fusion model
        /// </summary>
        public override void Train(Matrix<double> inputs, Vector<double> targets)
        {
            if (_disposed)
                throw new ObjectDisposedException(nameof(LateFusionMultimodal));

            if (inputs == null)
                throw new ArgumentNullException(nameof(inputs));
            if (targets == null)
                throw new ArgumentNullException(nameof(targets));
            if (inputs.Rows != targets.Length)
                throw new ArgumentException("Number of input samples must match number of targets");
            if (inputs.Rows == 0)
                throw new ArgumentException("Training data cannot be empty");

            lock (_lockObject)
            {
                try
                {
                    // For late fusion, we need to train each modality network separately
                    // This is a simplified approach - in practice, you'd want separate training data for each modality
                    
                    // Split input by modality
                    var modalityInputs = SplitInputsByModality(inputs);
                    
                    // Train each modality network
                    foreach (var kvp in modalityInputs)
                    {
                        if (_modalityNetworks.ContainsKey(kvp.Key))
                        {
                            Console.WriteLine($"Training {kvp.Key} modality network...");
                            
                            // Create target matrix for this modality
                            var modalityTargets = new Matrix<double>(targets.Length, _modalityHiddenSize / 2);
                            
                            // For simplicity, we'll use the same targets transformed
                            // In practice, you'd have modality-specific intermediate targets
                            for (int i = 0; i < targets.Length; i++)
                            {
                                for (int j = 0; j < modalityTargets.Columns; j++)
                                {
                                    modalityTargets[i, j] = targets[i] * (j + 1) / modalityTargets.Columns;
                                }
                            }
                            
                            var inputTensor = new Tensor<double>(new[] { kvp.Value.Rows, kvp.Value.Columns }, kvp.Value.ToColumnVector());
                            var targetTensor = new Tensor<double>(new[] { modalityTargets.Rows, modalityTargets.Columns }, modalityTargets.ToColumnVector());
                            _modalityNetworks[kvp.Key].Train(inputTensor, targetTensor);
                        }
                    }
                    
                    // Now train the fusion network
                    Console.WriteLine("Training fusion network...");
                    
                    // Process all inputs through modality networks to get fusion inputs
                    var fusionInputs = new Matrix<double>(inputs.Rows, 0);
                    
                    for (int i = 0; i < inputs.Rows; i++)
                    {
                        var modalityOutputs = new Dictionary<string, Vector<double>>();
                        
                        foreach (var kvp in modalityInputs)
                        {
                            if (_modalityNetworks.ContainsKey(kvp.Key))
                            {
                                var modalityInput = new Vector<double>(kvp.Value.Columns);
                                for (int j = 0; j < kvp.Value.Columns; j++)
                                {
                                    modalityInput[j] = kvp.Value[i, j];
                                }
                                
                                var inputTensor = new Tensor<double>(new[] { modalityInput.Length }, modalityInput);
                                var modalityOutput = _modalityNetworks[kvp.Key].Predict(inputTensor);
                                var outputArray = modalityOutput.ToArray();
                                var outputVector = new Vector<double>(outputArray.Length);
                                for (int j = 0; j < outputArray.Length; j++)
                                {
                                    outputVector[j] = outputArray[j];
                                }
                                
                                modalityOutputs[kvp.Key] = outputVector;
                            }
                        }
                        
                        var aggregated = AggregateModalityOutputs(modalityOutputs);
                        
                        if (i == 0)
                        {
                            fusionInputs = new Matrix<double>(inputs.Rows, aggregated.Length);
                            if (_fusionNetwork == null)
                            {
                                InitializeFusionNetwork(aggregated.Length);
                            }
                        }
                        
                        for (int j = 0; j < aggregated.Length; j++)
                        {
                            fusionInputs[i, j] = aggregated[j];
                        }
                    }
                    
                    // Convert targets to matrix format
                    var targetMatrix = new Matrix<double>(targets.Length, 1);
                    for (int i = 0; i < targets.Length; i++)
                    {
                        targetMatrix[i, 0] = targets[i];
                    }
                    
                    var fusionInputTensor = new Tensor<double>(new[] { fusionInputs.Rows, fusionInputs.Columns }, fusionInputs.ToColumnVector());
                    var fusionTargetTensor = new Tensor<double>(new[] { targetMatrix.Rows, targetMatrix.Columns }, targetMatrix.ToColumnVector());
                    _fusionNetwork!.Train(fusionInputTensor, fusionTargetTensor);
                    
                    _isTrained = true;
                    Console.WriteLine("Late fusion model training completed");
                }
                catch (Exception ex)
                {
                    throw new InvalidOperationException($"Training failed: {ex.Message}", ex);
                }
            }
        }

        /// <summary>
        /// Creates a copy of the model
        /// </summary>
        public override IFullModel<double, Dictionary<string, object>, Vector<double>> Clone()
        {
            var clone = new LateFusionMultimodal(_fusedDimension, _modalityHiddenSize,
                                               _fusionHiddenSize, _learningRate, _aggregationMethod);

            // Copy encoders and networks
            foreach (var kvp in _modalityEncoders)
            {
                clone.AddModalityEncoder(kvp.Key, kvp.Value);
            }

            clone._isTrained = _isTrained;
            clone.Name = Name;

            return clone;
        }

        /// <summary>
        /// Aggregates modality outputs based on the specified method
        /// </summary>
        private Vector<double> AggregateModalityOutputs(Dictionary<string, Vector<double>> outputs, Dictionary<string, double>? weights = null)
        {
            if (outputs.Count == 0)
                throw new ArgumentException("No modality outputs to aggregate");

            int dimension = outputs.First().Value.Length;
            var aggregated = new Vector<double>(dimension);

            switch (_aggregationMethod.ToLower())
            {
                case "mean":
                    // Simple mean aggregation
                    foreach (var output in outputs.Values)
                    {
                        for (int i = 0; i < dimension; i++)
                        {
                            aggregated[i] += output[i];
                        }
                    }
                    aggregated = aggregated / outputs.Count;
                    break;

                case "max":
                    // Max pooling aggregation
                    for (int i = 0; i < dimension; i++)
                    {
                        aggregated[i] = outputs.Values.Max(v => v[i]);
                    }
                    break;

                case "weighted":
                    // Weighted aggregation
                    if (weights == null || weights.Count == 0)
                    {
                        // Use stored modality weights or equal weights
                        weights = _modalityWeights.Count > 0 ? _modalityWeights : 
                                  System.Linq.Enumerable.ToDictionary(outputs.Keys, k => k, k => 1.0 / outputs.Count);
                    }

                    // Normalize weights
                    double totalWeight = weights.Values.Sum();
                    
                    foreach (var kvp in outputs)
                    {
                        double weight = weights.ContainsKey(kvp.Key) ? weights[kvp.Key] / totalWeight : 0;
                        for (int i = 0; i < dimension; i++)
                        {
                            aggregated[i] += weight * kvp.Value[i];
                        }
                    }
                    break;

                case "concat":
                    // Concatenation (results in larger dimension)
                    var allValues = new List<double>();
                    foreach (var output in outputs.Values)
                    {
                        for (int i = 0; i < output.Length; i++)
                        {
                            allValues.Add(output[i]);
                        }
                    }
                    aggregated = new Vector<double>(allValues.ToArray());
                    break;

                default:
                    throw new ArgumentException($"Unknown aggregation method: {_aggregationMethod}");
            }

            return aggregated;
        }

        /// <summary>
        /// Calculates weight/confidence for a modality output
        /// </summary>
        private double CalculateModalityWeight(Vector<double> output)
        {
            // Simple confidence based on output magnitude
            // In practice, could use learned attention weights
            return output.Magnitude();
        }

        /// <summary>
        /// Initializes the fusion network
        /// </summary>
        private void InitializeFusionNetwork(int inputDimension)
        {
            if (inputDimension <= 0)
                throw new ArgumentException("Input dimension must be positive", nameof(inputDimension));

            // Create layers explicitly
            var layers = new List<ILayer<double>>
            {
                new FullyConnectedLayer<double>(inputDimension, _fusionHiddenSize, null as IActivationFunction<double>),
                new ActivationLayer<double>(new[] { _fusionHiddenSize }, new ReLUActivation<double>() as IActivationFunction<double>),
                new FullyConnectedLayer<double>(_fusionHiddenSize, _fusionHiddenSize / 2, null as IActivationFunction<double>),
                new ActivationLayer<double>(new[] { _fusionHiddenSize / 2 }, new ReLUActivation<double>() as IActivationFunction<double>),
                new FullyConnectedLayer<double>(_fusionHiddenSize / 2, _fusedDimension, null as IActivationFunction<double>)
            };

            var architecture = new NeuralNetworkArchitecture<double>(
                complexity: NetworkComplexity.Medium,
                taskType: NeuralNetworkTaskType.Regression,
                shouldReturnFullSequence: false,
                layers: layers,
                isDynamicSampleCount: true,
                isPlaceholder: false);
            
            _fusionNetwork = new NeuralNetwork<double>(architecture);
        }

        /// <summary>
        /// Splits input matrix by modality
        /// </summary>
        private Dictionary<string, Matrix<double>> SplitInputsByModality(Matrix<double> inputs)
        {
            var result = new Dictionary<string, Matrix<double>>();
            var modalities = _modalityEncoders.Keys.OrderBy(k => k).ToList();
            
            if (modalities.Count == 0 || inputs.Columns == 0)
                return result;

            int colsPerModality = inputs.Columns / modalities.Count;
            int remainder = inputs.Columns % modalities.Count;
            
            int currentCol = 0;
            for (int i = 0; i < modalities.Count; i++)
            {
                int modalityCols = colsPerModality + (i < remainder ? 1 : 0);
                var modalityData = new Matrix<double>(inputs.Rows, modalityCols);
                
                for (int row = 0; row < inputs.Rows; row++)
                {
                    for (int col = 0; col < modalityCols; col++)
                    {
                        modalityData[row, col] = inputs[row, currentCol + col];
                    }
                }
                
                result[modalities[i]] = modalityData;
                currentCol += modalityCols;
            }
            
            return result;
        }

        /// <summary>
        /// Splits input vector by modality (simplified)
        /// </summary>
        private Dictionary<string, Vector<double>> SplitInputByModality(Vector<double> input)
        {
            var result = new Dictionary<string, Vector<double>>();
            var modalities = _modalityEncoders.Keys.ToList();
            
            if (modalities.Count == 0)
                return result;

            int dimensionPerModality = input.Length / modalities.Count;
            
            for (int i = 0; i < modalities.Count; i++)
            {
                int start = i * dimensionPerModality;
                int end = (i == modalities.Count - 1) ? input.Length : (i + 1) * dimensionPerModality;
                
                var modalityInput = new Vector<double>(end - start);
                for (int j = 0; j < modalityInput.Length; j++)
                {
                    modalityInput[j] = input[start + j];
                }
                
                result[modalities[i]] = modalityInput;
            }

            return result;
        }


        /// <summary>
        /// Gets parameters of the model
        /// </summary>
        public override Dictionary<string, object> GetParametersDictionary()
        {
            var parameters = base.GetParametersDictionary();
            parameters["ModalityHiddenSize"] = _modalityHiddenSize;
            parameters["FusionHiddenSize"] = _fusionHiddenSize;
            parameters["LearningRate"] = _learningRate;
            parameters["AggregationMethod"] = _aggregationMethod;
            parameters["NumModalityNetworks"] = _modalityNetworks.Count;
            parameters["IsTrained"] = _isTrained;
            
            if (_modalityWeights.Count > 0)
            {
                parameters["ModalityWeights"] = new Dictionary<string, double>(_modalityWeights);
            }
            
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
                        // Dispose modality networks
                        foreach (var network in _modalityNetworks.Values)
                        {
                            if (network is IDisposable disposableNetwork)
                            {
                                disposableNetwork.Dispose();
                            }
                        }
                        _modalityNetworks.Clear();
                        
                        // Dispose fusion network
                        if (_fusionNetwork is IDisposable disposableFusion)
                        {
                            disposableFusion.Dispose();
                        }
                        
                        // Dispose encoders if they implement IDisposable
                        foreach (var encoder in _modalityEncoders.Values)
                        {
                            if (encoder is IDisposable disposableEncoder)
                            {
                                disposableEncoder.Dispose();
                            }
                        }
                        _modalityEncoders.Clear();
                        
                        // Clear weights
                        _modalityWeights.Clear();
                    }
                }

                _disposed = true;
            }
        }

        /// <summary>
        /// Finalizer
        /// </summary>
        ~LateFusionMultimodal()
        {
            Dispose(false);
        }
    }
}