namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a layer that splits the input tensor along a specific dimension into multiple equal parts.
/// </summary>
/// <remarks>
/// <para>
/// A split layer divides the input tensor into multiple equal parts along a specified dimension. This is useful
/// for parallel processing of data or for implementing multi-headed attention mechanisms. The layer ensures that 
/// the input size is divisible by the number of splits to maintain consistency.
/// </para>
/// <para><b>For Beginners:</b> This layer breaks up your input data into smaller, equal-sized chunks.
/// 
/// Think of it like cutting a pizza into equal slices:
/// - Your input data is the whole pizza
/// - The number of splits determines how many slices you want
/// - Each slice has the same size and shape
/// 
/// Benefits include:
/// - Processing different parts of the input in parallel
/// - Allowing different operations on different parts of the input
/// - Creating multi-stream architectures where each stream handles a portion of the data
/// 
/// For example, in natural language processing, you might split word embeddings to create
/// multiple "attention heads" that each focus on different aspects of the text.
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class SplitLayer<T> : LayerBase<T>
{
    /// <summary>
    /// The number of parts to split the input tensor into.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field specifies how many equal parts the input tensor will be divided into. The input size must be
    /// divisible by this number to ensure all splits have the same size.
    /// </para>
    /// <para><b>For Beginners:</b> This is how many equal pieces the input will be cut into.
    /// 
    /// For example:
    /// - If numSplits is 2, the input is cut in half
    /// - If numSplits is 4, the input is cut into quarters
    /// 
    /// The layer will check that the input can be divided equally by this number
    /// without any remainder to ensure all pieces are exactly the same size.
    /// </para>
    /// </remarks>
    private readonly int _numSplits;

    /// <summary>
    /// Stores the input tensor from the most recent forward pass.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field caches the input to the layer during the forward pass, which is needed during the backward pass
    /// to compute gradients. It is cleared when ResetState() is called.
    /// </para>
    /// <para><b>For Beginners:</b> This is like the layer's short-term memory of what input it received.
    /// 
    /// During training, the layer needs to remember what input it processed so that it can
    /// properly calculate how to improve. This temporary storage is cleared between batches
    /// or when you explicitly reset the layer.
    /// </para>
    /// </remarks>
    private Tensor<T>? _lastInput;

    /// <summary>
    /// Gets a value indicating whether this layer supports training through backpropagation.
    /// </summary>
    /// <value>
    /// Always returns <c>true</c> as split layers can propagate gradients.
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates that the split layer can participate in the training process by propagating gradients.
    /// Although the layer has no trainable parameters itself, it can pass gradients back to previous layers.
    /// </para>
    /// <para><b>For Beginners:</b> This property tells you that the layer can be used during training.
    /// 
    /// Even though this layer doesn't have any parameters that need to be adjusted:
    /// - It can still pass error information backward to previous layers during training
    /// - It participates in the backpropagation process
    /// 
    /// This allows the layer to be included in networks that learn from data.
    /// </para>
    /// </remarks>
    public override bool SupportsTraining => true;

    /// <summary>
    /// Initializes a new instance of the <see cref="SplitLayer{T}"/> class.
    /// </summary>
    /// <param name="inputShape">The shape of the input tensor.</param>
    /// <param name="numSplits">The number of parts to split the input tensor into.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a split layer with the specified input shape and number of splits. It verifies
    /// that the input size is divisible by the number of splits to ensure all splits have the same size.
    /// </para>
    /// <para><b>For Beginners:</b> This sets up a new layer that will divide the input into equal parts.
    /// 
    /// When creating a split layer, you need to specify:
    /// - inputShape: The dimensions of the data going into the layer
    /// - numSplits: How many equal pieces to divide the input into
    /// 
    /// The constructor checks that the input can be divided equally by the number of splits.
    /// For example, if your input has 100 features and you want 4 splits, that works (100 � 4 = 25).
    /// But if your input has 100 features and you want 3 splits, that won't work
    /// because you'd get splits of size 33.33... which isn't a whole number.
    /// </para>
    /// </remarks>
    public SplitLayer(int[] inputShape, int numSplits)
        : base(inputShape, CalculateOutputShape(inputShape, numSplits))
    {
        _numSplits = numSplits;
    }

    /// <summary>
    /// Calculates the output shape of the split layer based on input shape and number of splits.
    /// </summary>
    /// <param name="inputShape">The shape of the input tensor.</param>
    /// <param name="numSplits">The number of parts to split the input tensor into.</param>
    /// <returns>The calculated output shape for the split layer.</returns>
    /// <exception cref="ArgumentException">Thrown when the input size is not divisible by the number of splits.</exception>
    /// <remarks>
    /// <para>
    /// This method calculates the output shape of the split layer based on the input shape and the number of splits.
    /// It verifies that the input size is divisible by the number of splits and throws an exception if it's not.
    /// </para>
    /// <para><b>For Beginners:</b> This method figures out the shape of the data that will come out of this layer.
    /// 
    /// It also performs an important check:
    /// - It verifies that the input can be divided equally by the number of splits
    /// - If not, it throws an error to prevent problems later
    /// 
    /// The output shape will have one more dimension than the input, with the new dimension
    /// representing the different splits, and another dimension representing the size of each split.
    /// </para>
    /// </remarks>
    private static int[] CalculateOutputShape(int[] inputShape, int numSplits)
    {
        if (inputShape[0] % numSplits != 0)
        {
            throw new ArgumentException("Input size must be divisible by the number of splits");
        }

        return [inputShape[0] / numSplits];
    }

    /// <summary>
    /// Performs the forward pass of the split layer.
    /// </summary>
    /// <param name="input">The input tensor to process.</param>
    /// <returns>The output tensor after splitting.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the forward pass of the split layer. It divides the input tensor into multiple
    /// equal-sized parts along the specified dimension and returns a new tensor containing all the splits.
    /// </para>
    /// <para><b>For Beginners:</b> This method does the actual work of splitting the input data.
    /// 
    /// During the forward pass:
    /// 1. The input is saved for later use in training
    /// 2. The method calculates how big each split should be
    /// 3. It creates a new tensor with an additional dimension to hold all the splits
    /// 4. It copies the data from the input into the appropriate positions in the output
    /// 
    /// After splitting, the data will have a new dimension that indicates which split each piece belongs to.
    /// For example, if you split a batch of 10 samples with 100 features into 5 splits, you'll get
    /// an output with shape [10, 5, 20], where 20 is the size of each split.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        _lastInput = input;
        int batchSize = input.Shape[0];
        int inputSize = input.Shape[1];
        int splitSize = inputSize / _numSplits;
        var output = new Tensor<T>([batchSize, _numSplits, splitSize]);
        for (int i = 0; i < batchSize; i++)
        {
            for (int j = 0; j < _numSplits; j++)
            {
                for (int k = 0; k < splitSize; k++)
                {
                    output[i, j, k] = input[i, j * splitSize + k];
                }
            }
        }
        return output;
    }

    /// <summary>
    /// Performs the backward pass of the split layer.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's input.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the backward pass of the split layer, which is used during training to propagate
    /// error gradients back through the network. It recombines the gradients from all splits into a single
    /// gradient tensor matching the original input shape.
    /// </para>
    /// <para><b>For Beginners:</b> This method reverses the splitting process for training.
    /// 
    /// During the backward pass:
    /// 1. The method throws an error if the forward pass hasn't been called first
    /// 2. It calculates how big each split is
    /// 3. It creates a gradient tensor matching the original input shape
    /// 4. It copies the gradient values from each split back to their original positions
    /// 
    /// This process ensures that error information flows backward through the network properly,
    /// allowing layers before the split to learn from the training process.
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        if (_lastInput == null)
            throw new InvalidOperationException("Forward pass must be called before backward pass.");
        int batchSize = _lastInput.Shape[0];
        int inputSize = _lastInput.Shape[1];
        int splitSize = inputSize / _numSplits;
        var inputGradient = new Tensor<T>(_lastInput.Shape);
        for (int i = 0; i < batchSize; i++)
        {
            for (int j = 0; j < _numSplits; j++)
            {
                for (int k = 0; k < splitSize; k++)
                {
                    inputGradient[i, j * splitSize + k] = outputGradient[i, j, k];
                }
            }
        }
        return inputGradient;
    }

    /// <summary>
    /// Updates the parameters of the layer using the calculated gradients.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the parameter updates.</param>
    /// <remarks>
    /// <para>
    /// This method is a no-op for the split layer since it has no trainable parameters to update.
    /// It is implemented to satisfy the interface requirements of LayerBase.
    /// </para>
    /// <para><b>For Beginners:</b> This method doesn't do anything in the split layer.
    /// 
    /// Since the split layer doesn't have any trainable parameters:
    /// - There's nothing to update during training
    /// - This method exists just to fulfill the requirements of being a layer
    /// 
    /// Other layers would use this method to update their weights and biases,
    /// but the split layer simply passes data through without modification.
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        // No parameters to update in this layer
    }

    /// <summary>
    /// Gets all trainable parameters of the layer as a single vector.
    /// </summary>
    /// <returns>An empty vector since this layer has no trainable parameters.</returns>
    /// <remarks>
    /// <para>
    /// This method returns an empty vector since the split layer has no trainable parameters.
    /// It is implemented to satisfy the interface requirements of LayerBase.
    /// </para>
    /// <para><b>For Beginners:</b> This method returns an empty list because the layer has no parameters.
    /// 
    /// Since the split layer doesn't modify the data in any way that requires learning:
    /// - There are no weights or biases to adjust
    /// - This method returns an empty vector (a list with no elements)
    /// 
    /// Other layers would return their weights and biases here, which would be
    /// used for saving the model or applying optimization techniques.
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // SplitLayer has no trainable parameters, so return an empty vector
        return Vector<T>.Empty();
    }

    /// <summary>
    /// Resets the internal state of the split layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method resets the internal state of the split layer, clearing the cached input.
    /// This is useful when starting to process a new batch or when implementing stateful networks.
    /// </para>
    /// <para><b>For Beginners:</b> This method clears the layer's memory to start fresh.
    /// 
    /// When resetting the state:
    /// - The stored input from the previous forward pass is cleared
    /// 
    /// This is important for:
    /// - Processing a new batch of unrelated data
    /// - Preventing information from one batch affecting another
    /// - Starting a new training episode
    /// 
    /// Think of it like clearing your workspace before starting a new project -
    /// it ensures that old information doesn't interfere with new processing.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // Clear cached values from forward pass
        _lastInput = null;
    }
}