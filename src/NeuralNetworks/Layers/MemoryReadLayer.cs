namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a layer that reads from a memory tensor using an attention mechanism.
/// </summary>
/// <remarks>
/// <para>
/// The MemoryReadLayer implements a form of attention-based memory access. It computes attention scores
/// between the input and memory tensors, using these scores to create a weighted sum of memory values.
/// This approach allows the layer to selectively retrieve information from memory based on the current input.
/// The layer consists of key weights (for attention computation), value weights (for transforming memory values),
/// and output weights (for final processing).
/// </para>
/// <para><b>For Beginners:</b> This layer helps a neural network retrieve information from memory.
/// 
/// Think of it like searching for relevant information in a book:
/// - You have a query (your current input)
/// - You have a memory (like pages of a book)
/// - The layer finds which parts of the memory are most relevant to your query
/// - It then combines those relevant parts to produce an output
/// 
/// For example, if your input represents a question like "What's the capital of France?",
/// the layer would look through memory to find information about France, give more attention
/// to content about its capital, and then combine this information to produce the answer "Paris".
/// 
/// This is similar to how modern language models can retrieve and use stored information
/// when answering questions.
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class MemoryReadLayer<T> : LayerBase<T>
{
    /// <summary>
    /// The weight matrix used to transform the input into query keys.
    /// </summary>
    /// <remarks>
    /// This matrix transforms the input vector into a key vector that is used to query the memory.
    /// </remarks>
    private Matrix<T> _keyWeights;
    
    /// <summary>
    /// The weight matrix used to transform the memory values after attention.
    /// </summary>
    /// <remarks>
    /// This matrix transforms the retrieved memory values into the output space.
    /// </remarks>
    private Matrix<T> _valueWeights;
    
    /// <summary>
    /// The weight matrix applied to the output after value transformation.
    /// </summary>
    /// <remarks>
    /// This matrix applies a final transformation to the output before adding the bias.
    /// </remarks>
    private Matrix<T> _outputWeights;
    
    /// <summary>
    /// The bias vector added to the output.
    /// </summary>
    /// <remarks>
    /// This vector is added to the output after all weight transformations.
    /// </remarks>
    private Vector<T> _outputBias;

    /// <summary>
    /// The input tensor from the most recent forward pass.
    /// </summary>
    /// <remarks>
    /// This field stores the input tensor from the most recent forward pass, which is needed
    /// during the backward pass for gradient calculation.
    /// </remarks>
    private Tensor<T>? _lastInput;
    
    /// <summary>
    /// The memory tensor from the most recent forward pass.
    /// </summary>
    /// <remarks>
    /// This field stores the memory tensor from the most recent forward pass, which is needed
    /// during the backward pass for gradient calculation.
    /// </remarks>
    private Tensor<T>? _lastMemory;
    
    /// <summary>
    /// The output tensor from the most recent forward pass.
    /// </summary>
    /// <remarks>
    /// This field stores the output tensor from the most recent forward pass, which is needed
    /// during the backward pass for gradient calculation.
    /// </remarks>
    private Tensor<T>? _lastOutput;
    
    /// <summary>
    /// The attention scores tensor from the most recent forward pass.
    /// </summary>
    /// <remarks>
    /// This field stores the attention scores from the most recent forward pass, which is needed
    /// during the backward pass for gradient calculation.
    /// </remarks>
    private Tensor<T>? _lastAttentionScores;

    /// <summary>
    /// The gradient of the loss with respect to the key weights.
    /// </summary>
    /// <remarks>
    /// This field stores the gradient of the key weights, which is used to update the weights
    /// during the parameter update step.
    /// </remarks>
    private Matrix<T>? _keyWeightsGradient;
    
    /// <summary>
    /// The gradient of the loss with respect to the value weights.
    /// </summary>
    /// <remarks>
    /// This field stores the gradient of the value weights, which is used to update the weights
    /// during the parameter update step.
    /// </remarks>
    private Matrix<T>? _valueWeightsGradient;
    
    /// <summary>
    /// The gradient of the loss with respect to the output weights.
    /// </summary>
    /// <remarks>
    /// This field stores the gradient of the output weights, which is used to update the weights
    /// during the parameter update step.
    /// </remarks>
    private Matrix<T>? _outputWeightsGradient;
    
    /// <summary>
    /// The gradient of the loss with respect to the output bias.
    /// </summary>
    /// <remarks>
    /// This field stores the gradient of the output bias, which is used to update the bias
    /// during the parameter update step.
    /// </remarks>
    private Vector<T>? _outputBiasGradient;

    /// <summary>
    /// Gets a value indicating whether this layer supports training.
    /// </summary>
    /// <value>
    /// Always <c>true</c> because the MemoryReadLayer has trainable parameters.
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates that MemoryReadLayer can be trained through backpropagation. The layer
    /// has trainable parameters (weights and biases) that are updated during training to optimize
    /// the memory reading process.
    /// </para>
    /// <para><b>For Beginners:</b> This property tells you that this layer can learn from data.
    /// 
    /// A value of true means:
    /// - The layer has internal values (weights and biases) that change during training
    /// - It will improve its performance as it sees more data
    /// - It learns to better focus attention on relevant parts of memory
    /// 
    /// During training, the layer learns:
    /// - Which features in the input are important for querying memory
    /// - How to transform retrieved memory information
    /// - How to combine everything into a useful output
    /// </para>
    /// </remarks>
    public override bool SupportsTraining => true;

    /// <summary>
    /// Initializes a new instance of the <see cref="MemoryReadLayer{T}"/> class with the specified dimensions
    /// and a scalar activation function.
    /// </summary>
    /// <param name="inputDimension">The size of the input vector.</param>
    /// <param name="memoryDimension">The size of each memory entry.</param>
    /// <param name="outputDimension">The size of the output vector.</param>
    /// <param name="activationFunction">The activation function to apply after processing. Defaults to Identity if not specified.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a MemoryReadLayer with the specified dimensions and activation function.
    /// The layer is initialized with random weights scaled according to the layer dimensions to facilitate
    /// stable training. The bias is initialized to zero.
    /// </para>
    /// <para><b>For Beginners:</b> This constructor sets up the layer with the necessary dimensions and activation function.
    /// 
    /// When creating a MemoryReadLayer, you need to specify:
    /// - inputDimension: The size of your query vector (e.g., 128 for a 128-feature query)
    /// - memoryDimension: The size of each memory entry (e.g., 256 for memory entries with 256 features)
    /// - outputDimension: The size of the output you want (e.g., 64 for a 64-feature result)
    /// - activationFunction: The function that processes the final output (optional)
    /// 
    /// The constructor creates weight matrices of the appropriate sizes and initializes them
    /// with small random values to start the learning process. The initialization scale
    /// is carefully chosen to prevent vanishing or exploding gradients during training.
    /// </para>
    /// </remarks>
    public MemoryReadLayer(int inputDimension, int memoryDimension, int outputDimension, IActivationFunction<T>? activationFunction = null)
        : base([inputDimension], [outputDimension], activationFunction ?? new IdentityActivation<T>())
    {
        _keyWeights = new Matrix<T>(inputDimension, memoryDimension);
        _valueWeights = new Matrix<T>(memoryDimension, outputDimension);
        _outputWeights = new Matrix<T>(outputDimension, outputDimension);
        _outputBias = new Vector<T>(outputDimension);

        InitializeParameters();
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="MemoryReadLayer{T}"/> class with the specified dimensions
    /// and a vector activation function.
    /// </summary>
    /// <param name="inputDimension">The size of the input vector.</param>
    /// <param name="memoryDimension">The size of each memory entry.</param>
    /// <param name="outputDimension">The size of the output vector.</param>
    /// <param name="activationFunction">The vector activation function to apply after processing. Defaults to Identity if not specified.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a MemoryReadLayer with the specified dimensions and vector activation function.
    /// A vector activation function operates on entire vectors rather than individual elements.
    /// The layer is initialized with random weights scaled according to the layer dimensions to facilitate
    /// stable training. The bias is initialized to zero.
    /// </para>
    /// <para><b>For Beginners:</b> This constructor sets up the layer with the necessary dimensions and a vector-based activation function.
    /// 
    /// A vector activation function:
    /// - Operates on entire groups of numbers at once, rather than one at a time
    /// - Can capture relationships between different elements in the output
    /// - Defaults to the Identity function, which doesn't change the values
    /// 
    /// This constructor is useful when you need more complex activation patterns
    /// that consider the relationships between different outputs in your memory reading operation.
    /// </para>
    /// </remarks>
    public MemoryReadLayer(int inputDimension, int memoryDimension, int outputDimension, IVectorActivationFunction<T>? activationFunction = null)
        : base([inputDimension], [outputDimension], activationFunction ?? new IdentityActivation<T>())
    {
        _keyWeights = new Matrix<T>(inputDimension, memoryDimension);
        _valueWeights = new Matrix<T>(memoryDimension, outputDimension);
        _outputWeights = new Matrix<T>(outputDimension, outputDimension);
        _outputBias = new Vector<T>(outputDimension);

        InitializeParameters();
    }

    /// <summary>
    /// Initializes the layer's weights and biases.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method initializes the weights using a scaling factor derived from the dimensions
    /// of the weight matrices. The scaling helps prevent vanishing or exploding gradients
    /// during training. The bias is initialized to zero.
    /// </para>
    /// <para><b>For Beginners:</b> This method sets up the initial values for the layer's weights and biases.
    /// 
    /// Proper initialization is important for neural networks because:
    /// - Starting with good values helps the network learn faster
    /// - It helps prevent problems during training like vanishing or exploding gradients
    ///   (when values become too small or too large)
    /// 
    /// This method:
    /// - Calculates a scaling factor based on the size of the matrices
    /// - Initializes weights to small random values multiplied by this scale
    /// - Sets all bias values to zero
    /// 
    /// This approach (known as "He initialization") works well for many types of neural networks.
    /// </para>
    /// </remarks>
    private void InitializeParameters()
    {
        T scale = NumOps.Sqrt(NumOps.FromDouble(2.0 / (_keyWeights.Rows + _keyWeights.Columns)));
        InitializeMatrix(_keyWeights, scale);
        InitializeMatrix(_valueWeights, scale);
        InitializeMatrix(_outputWeights, scale);

        for (int i = 0; i < _outputBias.Length; i++)
        {
            _outputBias[i] = NumOps.Zero;
        }
    }

    /// <summary>
    /// Initializes a matrix with random values scaled by the given factor.
    /// </summary>
    /// <param name="matrix">The matrix to initialize.</param>
    /// <param name="scale">The scaling factor for the random values.</param>
    /// <remarks>
    /// <para>
    /// This method fills the matrix with random values between -0.5 and 0.5, scaled by the provided factor.
    /// This approach helps to establish good initial conditions for training, especially for deeper networks
    /// where proper weight initialization is crucial for convergence.
    /// </para>
    /// <para><b>For Beginners:</b> This method fills a matrix with small random numbers.
    /// 
    /// When initializing a neural network:
    /// - We need to start with random values to break symmetry
    /// - Values that are too large or too small can cause problems
    /// - The scale parameter helps control how large the initial values are
    /// 
    /// This method goes through each position in the matrix and assigns it a random
    /// value between -0.5 and 0.5, multiplied by the scale factor. This gives a
    /// controlled amount of randomness that helps the network start learning effectively.
    /// </para>
    /// </remarks>
    private void InitializeMatrix(Matrix<T> matrix, T scale)
    {
        for (int i = 0; i < matrix.Rows; i++)
        {
            for (int j = 0; j < matrix.Columns; j++)
            {
                matrix[i, j] = NumOps.Multiply(NumOps.FromDouble(Random.NextDouble() - 0.5), scale);
            }
        }
    }

    /// <summary>
    /// Performs the forward pass of the memory read layer with input and memory tensors.
    /// </summary>
    /// <param name="input">The input tensor to process.</param>
    /// <param name="memory">The memory tensor to read from.</param>
    /// <returns>The output tensor after memory reading and processing.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the forward pass of the memory read layer. It computes attention scores
    /// between the input and memory, applies softmax to get attention weights, retrieves a weighted sum
    /// of memory values, applies transformations through the value and output weights, and finally adds
    /// the bias and applies the activation function.
    /// </para>
    /// <para><b>For Beginners:</b> This method performs the actual memory reading operation based on the input.
    /// 
    /// The forward pass works in these steps:
    /// 1. Use the input to create query keys by applying the key weights
    /// 2. Compare these keys with each memory entry to get attention scores
    /// 3. Convert the scores to weights using softmax (making them sum to 1.0)
    /// 4. Use these weights to create a weighted sum of memory values
    /// 5. Transform this retrieved information through value and output weights
    /// 6. Add bias and apply activation function for the final output
    /// 
    /// This is similar to how attention works in many modern AI systems:
    /// the input "attends" to relevant parts of memory, focusing more on what's important
    /// for the current task and less on irrelevant information.
    /// </para>
    /// </remarks>
    public Tensor<T> Forward(Tensor<T> input, Tensor<T> memory)
    {
        _lastInput = input;
        _lastMemory = memory;

        var keys = input.Multiply(_keyWeights);
        var attentionScores = keys.Multiply(memory.Transpose([1, 0]));
        
        var softmaxActivation = new SoftmaxActivation<T>();
        var attentionWeights = softmaxActivation.Activate(attentionScores);
        _lastAttentionScores = attentionWeights;

        var readValues = attentionWeights.Multiply(memory);
        var output = readValues.Multiply(_valueWeights).Multiply(_outputWeights).Add(_outputBias);
        _lastOutput = ApplyActivation(output);

        return _lastOutput;
    }

    /// <summary>
    /// Performs the backward pass of the memory read layer.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's inputs (both input and memory).</returns>
    /// <exception cref="InvalidOperationException">Thrown when backward is called before forward.</exception>
    /// <remarks>
    /// <para>
    /// This method implements the backward pass of the memory read layer, which is used during training to propagate
    /// error gradients back through the network. It computes the gradients of all weights and biases, as well as
    /// the gradients with respect to both the input and memory tensors. The computed weight and bias gradients
    /// are stored for later use in the parameter update step.
    /// </para>
    /// <para><b>For Beginners:</b> This method calculates how all parameters should change to reduce errors.
    /// 
    /// During the backward pass:
    /// - The layer receives gradients indicating how the output should change
    /// - It calculates how each weight, bias, and input value should change
    /// - These gradients are used later to update the parameters during training
    /// 
    /// The backward pass is complex because it needs to:
    /// - Calculate gradients for all weights (key, value, and output)
    /// - Calculate gradients for the bias
    /// - Calculate gradients for both the input and memory tensors
    /// - Handle the chain rule through the softmax attention mechanism
    /// 
    /// This is an implementation of backpropagation through an attention mechanism,
    /// which is a key component of many modern neural network architectures.
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        if (_lastInput == null || _lastMemory == null || _lastOutput == null || _lastAttentionScores == null)
            throw new InvalidOperationException("Forward pass must be called before backward pass.");

        var activationGradient = ApplyActivationDerivative(_lastOutput, outputGradient);

        _outputWeightsGradient = activationGradient.Transpose([1, 0]).Multiply(_lastOutput).ToMatrix();
        _outputBiasGradient = activationGradient.Sum([0]).ToVector();

        var valueGradient = activationGradient.Multiply(_outputWeights.Transpose()).Multiply(_valueWeights.Transpose());

        var softmaxActivation = new SoftmaxActivation<T>();
        var softmaxDerivative = softmaxActivation.Derivative(_lastAttentionScores);
        var attentionWeightsGradient = softmaxDerivative.ElementwiseMultiply(valueGradient.Multiply(_lastMemory.Transpose([1, 0])));

        _keyWeightsGradient = _lastInput.Transpose([1, 0]).Multiply(attentionWeightsGradient.Multiply(_lastMemory)).ToMatrix();
        _valueWeightsGradient = _lastMemory.Transpose([1, 0]).Multiply(_lastAttentionScores.Transpose([1, 0]).Multiply(activationGradient)).ToMatrix();

        var inputGradient = attentionWeightsGradient.Multiply(_keyWeights.Transpose());
        var memoryGradient = attentionWeightsGradient.Transpose([1, 0]).Multiply(_lastInput.Multiply(_keyWeights));

        // Combine inputGradient and memoryGradient into a single Tensor
        return CombineGradients(inputGradient, memoryGradient);
    }

    /// <summary>
    /// Combines gradients for input and memory into a single tensor.
    /// </summary>
    /// <param name="inputGradient">The gradient with respect to the input tensor.</param>
    /// <param name="memoryGradient">The gradient with respect to the memory tensor.</param>
    /// <returns>A combined tensor containing both gradients.</returns>
    /// <remarks>
    /// <para>
    /// This method combines the gradients for the input and memory tensors into a single tensor
    /// by concatenating them along the first dimension. This allows the backward pass to return
    /// a single gradient tensor that contains information about how both inputs should change.
    /// </para>
    /// <para><b>For Beginners:</b> This method packages two sets of gradients into one tensor.
    /// 
    /// Since the MemoryReadLayer has two inputs (the input tensor and the memory tensor),
    /// the backward pass needs to calculate gradients for both. This method:
    /// 
    /// - Takes the separate gradients for input and memory
    /// - Combines them into a single tensor by stacking them together
    /// - Returns this combined tensor to the previous layer
    /// 
    /// Later, these combined gradients can be split apart again if needed to
    /// update both the input and memory pathways in the neural network.
    /// </para>
    /// </remarks>
    private static Tensor<T> CombineGradients(Tensor<T> inputGradient, Tensor<T> memoryGradient)
    {
        // Assuming we want to concatenate the gradients along the first dimension
        return Tensor<T>.Concatenate([inputGradient, memoryGradient], 0);
    }

    /// <summary>
    /// Updates the parameters of the memory read layer using the calculated gradients.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the parameter updates.</param>
    /// <exception cref="InvalidOperationException">Thrown when UpdateParameters is called before Backward.</exception>
    /// <remarks>
    /// <para>
    /// This method updates all trainable parameters of the layer (key weights, value weights, output weights,
    /// and output bias) based on the gradients calculated during the backward pass. The learning rate controls
    /// the size of the parameter updates. Each parameter is updated by subtracting the corresponding gradient
    /// multiplied by the learning rate.
    /// </para>
    /// <para><b>For Beginners:</b> This method updates all the layer's weights and biases during training.
    /// 
    /// After the backward pass calculates how parameters should change, this method:
    /// - Takes each weight matrix and bias vector
    /// - Subtracts the corresponding gradient scaled by the learning rate
    /// - This moves the parameters in the direction that reduces errors
    /// 
    /// The learning rate controls how big each update step is:
    /// - Smaller learning rates mean slower but more stable learning
    /// - Larger learning rates mean faster but potentially unstable learning
    /// 
    /// This is how the layer gradually improves its performance over many training iterations.
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        if (_keyWeightsGradient == null || _valueWeightsGradient == null || _outputWeightsGradient == null || _outputBiasGradient == null)
            throw new InvalidOperationException("Backward pass must be called before updating parameters.");

        _keyWeights = _keyWeights.Subtract(_keyWeightsGradient.Multiply(learningRate));
        _valueWeights = _valueWeights.Subtract(_valueWeightsGradient.Multiply(learningRate));
        _outputWeights = _outputWeights.Subtract(_outputWeightsGradient.Multiply(learningRate));
        _outputBias = _outputBias.Subtract(_outputBiasGradient.Multiply(learningRate));
    }

    /// <summary>
    /// This method is not supported for MemoryReadLayer as it requires both input and memory tensors.
    /// </summary>
    /// <param name="input">The input tensor.</param>
    /// <returns>Not applicable as this method throws an exception.</returns>
    /// <exception cref="InvalidOperationException">Always thrown when this method is called.</exception>
    /// <remarks>
    /// <para>
    /// This method overrides the base Forward method but is not supported for MemoryReadLayer because
    /// memory reading requires both an input tensor and a memory tensor. Calling this method will always
    /// result in an InvalidOperationException.
    /// </para>
    /// <para><b>For Beginners:</b> This method exists to satisfy the base class requirements but should not be used.
    /// 
    /// Since the MemoryReadLayer needs both an input tensor and a memory tensor to work properly,
    /// this simplified version that only takes an input tensor cannot function correctly.
    /// 
    /// If you call this method, you'll get an error message directing you to use the
    /// correct Forward method that accepts both input and memory tensors.
    /// 
    /// Always use Forward(input, memory) instead of Forward(input) with this layer.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        throw new InvalidOperationException("MemoryReadLayer requires both input and memory tensors. Use the Forward(Tensor<T> input, Tensor<T> memory) method instead.");
    }

    /// <summary>
    /// Gets all trainable parameters from the memory read layer as a single vector.
    /// </summary>
    /// <returns>A vector containing all trainable parameters.</returns>
    /// <remarks>
    /// <para>
    /// This method retrieves all trainable parameters from the layer as a single vector. It concatenates
    /// the key weights, value weights, output weights, and output bias into a single vector. This is useful
    /// for optimization algorithms that operate on all parameters at once, or for saving and loading model weights.
    /// </para>
    /// <para><b>For Beginners:</b> This method collects all the learnable values in the layer.
    /// 
    /// The parameters:
    /// - Are the numbers that the neural network learns during training
    /// - Include all the weights and biases from this layer
    /// - Are combined into a single long list (vector)
    /// 
    /// This is useful for:
    /// - Saving the model to disk
    /// - Loading parameters from a previously trained model
    /// - Advanced optimization techniques that need access to all parameters
    /// 
    /// The method carefully arranges all parameters in a specific order
    /// so they can be correctly restored later.
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // Calculate total number of parameters
        int totalParams = _keyWeights.Rows * _keyWeights.Columns +
                          _valueWeights.Rows * _valueWeights.Columns +
                          _outputWeights.Rows * _outputWeights.Columns +
                          _outputBias.Length;
    
        var parameters = new Vector<T>(totalParams);
        int index = 0;
    
        // Copy key weights
        for (int i = 0; i < _keyWeights.Rows; i++)
        {
            for (int j = 0; j < _keyWeights.Columns; j++)
            {
                parameters[index++] = _keyWeights[i, j];
            }
        }
    
        // Copy value weights
        for (int i = 0; i < _valueWeights.Rows; i++)
        {
            for (int j = 0; j < _valueWeights.Columns; j++)
            {
                parameters[index++] = _valueWeights[i, j];
            }
        }
    
        // Copy output weights
        for (int i = 0; i < _outputWeights.Rows; i++)
        {
            for (int j = 0; j < _outputWeights.Columns; j++)
            {
                parameters[index++] = _outputWeights[i, j];
            }
        }
    
        // Copy output bias
        for (int i = 0; i < _outputBias.Length; i++)
        {
            parameters[index++] = _outputBias[i];
        }
    
        return parameters;
    }

    /// <summary>
    /// Sets the trainable parameters for the memory read layer.
    /// </summary>
    /// <param name="parameters">A vector containing all parameters to set.</param>
    /// <exception cref="ArgumentException">Thrown when the parameters vector has incorrect length.</exception>
    /// <remarks>
    /// <para>
    /// This method sets all trainable parameters of the layer from a single vector. It extracts the appropriate
    /// portions of the input vector for each parameter (key weights, value weights, output weights, and output bias).
    /// This is useful for loading saved model weights or for implementing optimization algorithms that operate
    /// on all parameters at once.
    /// </para>
    /// <para><b>For Beginners:</b> This method updates all the learnable values in the layer.
    /// 
    /// When setting parameters:
    /// - The input must be a vector with the correct length
    /// - The method extracts portions for each weight matrix and bias vector
    /// - It places each value in its correct position
    /// 
    /// This is useful for:
    /// - Loading a previously saved model
    /// - Transferring parameters from another model
    /// - Testing different parameter values
    /// 
    /// An error is thrown if the input vector doesn't have the expected number of parameters,
    /// ensuring that all matrices and vectors maintain their correct dimensions.
    /// </para>
    /// </remarks>
    public override void SetParameters(Vector<T> parameters)
    {
        int totalParams = _keyWeights.Rows * _keyWeights.Columns +
                          _valueWeights.Rows * _valueWeights.Columns +
                          _outputWeights.Rows * _outputWeights.Columns +
                          _outputBias.Length;
    
        if (parameters.Length != totalParams)
        {
            throw new ArgumentException($"Expected {totalParams} parameters, but got {parameters.Length}");
        }
    
        int index = 0;
    
        // Set key weights
        for (int i = 0; i < _keyWeights.Rows; i++)
        {
            for (int j = 0; j < _keyWeights.Columns; j++)
            {
                _keyWeights[i, j] = parameters[index++];
            }
        }
    
        // Set value weights
        for (int i = 0; i < _valueWeights.Rows; i++)
        {
            for (int j = 0; j < _valueWeights.Columns; j++)
            {
                _valueWeights[i, j] = parameters[index++];
            }
        }
    
        // Set output weights
        for (int i = 0; i < _outputWeights.Rows; i++)
        {
            for (int j = 0; j < _outputWeights.Columns; j++)
            {
                _outputWeights[i, j] = parameters[index++];
            }
        }
    
        // Set output bias
        for (int i = 0; i < _outputBias.Length; i++)
        {
            _outputBias[i] = parameters[index++];
        }
    }

    /// <summary>
    /// Resets the internal state of the memory read layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method resets the internal state of the memory read layer, including the cached inputs, memory,
    /// outputs, attention scores, and all gradients. This is useful when starting to process a new sequence
    /// or batch of data, or when implementing stateful networks.
    /// </para>
    /// <para><b>For Beginners:</b> This method clears the layer's memory to start fresh.
    /// 
    /// When resetting the state:
    /// - Stored inputs, memory, outputs, and attention scores from previous processing are cleared
    /// - All calculated gradients are cleared
    /// - The layer forgets any information from previous data batches
    /// 
    /// This is important for:
    /// - Processing a new, unrelated batch of data
    /// - Ensuring clean state before a new training epoch
    /// - Preventing information from one batch affecting another
    /// 
    /// Resetting state helps ensure that each forward and backward pass is independent,
    /// which is important for correct behavior in many neural network architectures.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // Clear cached values from forward and backward passes
        _lastInput = null;
        _lastMemory = null;
        _lastOutput = null;
        _lastAttentionScores = null;

        _keyWeightsGradient = null;
        _valueWeightsGradient = null;
        _outputWeightsGradient = null;
        _outputBiasGradient = null;
    }
}