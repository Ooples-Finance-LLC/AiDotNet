namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a layer that performs pooling operations on input tensors.
/// </summary>
/// <remarks>
/// <para>
/// The PoolingLayer reduces the spatial dimensions (height and width) of input tensors by applying
/// either max pooling or average pooling within local regions. This operation is commonly used in 
/// convolutional neural networks to reduce the spatial dimensions of feature maps, which helps to
/// reduce computation, provide translation invariance, and control overfitting.
/// </para>
/// <para><b>For Beginners:</b> This layer helps reduce the size of your data while keeping the important information.
/// 
/// Think of it like creating a thumbnail of an image:
/// - The pooling layer divides your input into small regions (e.g., 2�2 squares)
/// - For each region, it either:
///   - Takes the maximum value (max pooling): good for detecting features like edges
///   - Takes the average value (average pooling): good for preserving background information
/// - This creates a smaller output with fewer pixels but retains the important features
/// 
/// For example, using 2�2 max pooling on a 4�4 image would give you a 2�2 output,
/// where each value is the maximum from its corresponding 2�2 region in the input.
/// 
/// Pooling helps make your neural network:
/// - More efficient (by reducing the amount of data)
/// - More robust (by being less sensitive to exact positions of features)
/// - Less prone to overfitting (by reducing the number of parameters)
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class PoolingLayer<T> : LayerBase<T>
{
    /// <summary>
    /// Gets the size of the pooling window.
    /// </summary>
    /// <value>
    /// The size of the pooling window (both height and width).
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates the size of the square window used for pooling operations.
    /// For example, a pool size of 2 means that pooling is performed on 2�2 regions of the input.
    /// </para>
    /// <para><b>For Beginners:</b> This property defines how large each pooling region is.
    /// 
    /// For example:
    /// - PoolSize = 2 means each pooling region is 2�2 pixels
    /// - PoolSize = 3 means each pooling region is 3�3 pixels
    /// 
    /// Larger pool sizes reduce the output dimensions more dramatically but might lose more detail.
    /// Common values are 2 and 3.
    /// </para>
    /// </remarks>
    public int PoolSize { get; }

    /// <summary>
    /// Gets the stride of the pooling operation.
    /// </summary>
    /// <value>
    /// The number of pixels to move the pooling window for each step.
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates how many pixels the pooling window moves for each step.
    /// For example, a stride of 2 means the pooling window moves 2 pixels horizontally and vertically
    /// for each new pooling operation.
    /// </para>
    /// <para><b>For Beginners:</b> This property defines how far the pooling window moves each step.
    /// 
    /// For example:
    /// - Stride = 1 means the window slides just 1 pixel at a time (creates overlapping regions)
    /// - Stride = 2 means the window jumps 2 pixels each time (typical value, creates non-overlapping regions)
    /// 
    /// Usually, the stride is set equal to the pool size for non-overlapping pooling regions,
    /// but you can use a smaller stride if you want the regions to overlap.
    /// </para>
    /// </remarks>
    public int Stride { get; }

    /// <summary>
    /// Gets the type of pooling operation to perform.
    /// </summary>
    /// <value>
    /// The pooling type (Max or Average).
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates whether to use max pooling (which takes the maximum value within each pooling window)
    /// or average pooling (which computes the average of all values within each pooling window).
    /// </para>
    /// <para><b>For Beginners:</b> This property determines which mathematical operation is used for pooling.
    /// 
    /// There are two main types:
    /// - Max pooling: Takes the largest value in each region
    ///   * Good for detecting if a feature is present somewhere in the region
    ///   * Commonly used in most CNNs
    /// - Average pooling: Takes the average of all values in each region
    ///   * Good for preserving background information
    ///   * Sometimes used for the final layer of a network
    /// 
    /// Max pooling tends to be more common because it's better at preserving important features
    /// like edges and patterns.
    /// </para>
    /// </remarks>
    public PoolingType Type { get; }

    /// <summary>
    /// Gets a value indicating whether this layer supports training.
    /// </summary>
    /// <value>
    /// Always <c>true</c> because the PoolingLayer supports backpropagation, even though it has no parameters.
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates whether the layer supports backpropagation during training. Although
    /// the PoolingLayer has no trainable parameters, it still supports the backward pass to propagate
    /// gradients to previous layers.
    /// </para>
    /// <para><b>For Beginners:</b> This property tells you if the layer can participate in the training process.
    /// 
    /// A value of true means:
    /// - The layer can pass gradient information backward during training
    /// - It's part of the learning process, even though it doesn't have learnable parameters
    /// 
    /// While this layer doesn't have weights or biases that get updated during training,
    /// it still needs to properly handle gradients to ensure that layers before it
    /// can learn correctly.
    /// </para>
    /// </remarks>
    public override bool SupportsTraining => true;

    /// <summary>
    /// The input tensor from the most recent forward pass.
    /// </summary>
    /// <remarks>
    /// This field stores the input tensor from the most recent forward pass, which is needed
    /// during the backward pass for gradient calculation.
    /// </remarks>
    private Tensor<T>? _lastInput;

    /// <summary>
    /// The indices of the maximum values for max pooling operations.
    /// </summary>
    /// <remarks>
    /// This field stores the indices of the maximum values within each pooling window when
    /// performing max pooling. These indices are needed during the backward pass to properly
    /// route gradients back to the corresponding input positions.
    /// </remarks>
    private Tensor<int>? _maxIndices;

    /// <summary>
    /// Initializes a new instance of the <see cref="PoolingLayer{T}"/> class with the specified dimensions and pooling parameters.
    /// </summary>
    /// <param name="inputDepth">The depth (number of channels) of the input tensor.</param>
    /// <param name="inputHeight">The height of the input tensor.</param>
    /// <param name="inputWidth">The width of the input tensor.</param>
    /// <param name="poolSize">The size of the pooling window.</param>
    /// <param name="stride">The stride of the pooling operation.</param>
    /// <param name="type">The type of pooling to perform. Defaults to Max.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a PoolingLayer with the specified input dimensions and pooling parameters.
    /// The output dimensions are calculated based on the input dimensions, pool size, and stride.
    /// </para>
    /// <para><b>For Beginners:</b> This constructor sets up the layer with the necessary dimensions and pooling options.
    /// 
    /// When creating a PoolingLayer, you need to specify:
    /// - inputDepth: The number of channels in your input (e.g., 3 for RGB images)
    /// - inputHeight: The height of your input
    /// - inputWidth: The width of your input
    /// - poolSize: The size of the pooling regions (e.g., 2 for 2�2 regions)
    /// - stride: How far to move the pooling window each step
    /// - type: Whether to use max pooling or average pooling (defaults to max)
    /// 
    /// The constructor automatically calculates what the output dimensions will be
    /// based on these parameters. For example, a 28�28 input with pool size 2 and
    /// stride 2 would produce a 14�14 output.
    /// </para>
    /// </remarks>
    public PoolingLayer(int inputDepth, int inputHeight, int inputWidth, int poolSize, int stride, PoolingType type = PoolingType.Max)
        : base(CalculateInputShape(inputDepth, inputHeight, inputWidth),
               CalculateOutputShape(inputDepth, CalculateOutputDimension(inputHeight, poolSize, stride), CalculateOutputDimension(inputWidth, poolSize, stride)))
    {
        PoolSize = poolSize;
        Stride = stride;
        Type = type;
    }

    /// <summary>
    /// Calculates the output dimension size based on the input dimension, pool size, and stride.
    /// </summary>
    /// <param name="inputDim">The size of the input dimension (height or width).</param>
    /// <param name="poolSize">The size of the pooling window.</param>
    /// <param name="stride">The stride of the pooling operation.</param>
    /// <returns>The calculated output dimension size.</returns>
    /// <remarks>
    /// <para>
    /// This method calculates the size of an output dimension (height or width) based on the
    /// corresponding input dimension, pool size, and stride. The formula used is:
    /// output_dim = (input_dim - pool_size) / stride + 1
    /// </para>
    /// <para><b>For Beginners:</b> This method figures out how large the output will be after pooling.
    /// 
    /// The formula is fairly simple:
    /// (input size - pool size) / stride + 1
    /// 
    /// For example:
    /// - Input size = 28, pool size = 2, stride = 2
    /// - Output size = (28 - 2) / 2 + 1 = 14
    /// 
    /// The formula works because:
    /// - We need enough space for at least one pooling window (subtracting pool size)
    /// - We move the window by 'stride' pixels each time
    /// - We add 1 because we count the starting position
    /// 
    /// This calculation helps determine the dimensions of the output tensor.
    /// </para>
    /// </remarks>
    private static int CalculateOutputDimension(int inputDim, int poolSize, int stride)
    {
        return (inputDim - poolSize) / stride + 1;
    }

    /// <summary>
    /// Performs the forward pass of the pooling layer.
    /// </summary>
    /// <param name="input">The input tensor to process.</param>
    /// <returns>The output tensor after pooling.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the forward pass of the pooling layer. It divides the input tensor into
    /// regions according to the pool size and stride, and then applies either max pooling or average pooling
    /// to each region. The result is a tensor with reduced spatial dimensions.
    /// </para>
    /// <para><b>For Beginners:</b> This method performs the actual pooling operation.
    /// 
    /// During the forward pass:
    /// - The method divides the input into regions based on pool size and stride
    /// - For each region, it either:
    ///   - Finds the maximum value (for max pooling)
    ///   - Calculates the average value (for average pooling)
    /// - It saves these values in the output tensor
    /// 
    /// For max pooling, it also keeps track of which position in each region had the maximum value.
    /// This information is needed later during backpropagation.
    /// 
    /// The method also saves the input for later use in backpropagation.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        _lastInput = input;
        int batchSize = input.Shape[0];
        int channels = input.Shape[1];
        int inputHeight = input.Shape[2];
        int inputWidth = input.Shape[3];

        int outputHeight = (inputHeight - PoolSize) / Stride + 1;
        int outputWidth = (inputWidth - PoolSize) / Stride + 1;

        var output = new Tensor<T>([batchSize, channels, outputHeight, outputWidth]);
        _maxIndices = new Tensor<int>(output.Shape);

        for (int b = 0; b < batchSize; b++)
        {
            for (int c = 0; c < channels; c++)
            {
                for (int h = 0; h < outputHeight; h++)
                {
                    for (int w = 0; w < outputWidth; w++)
                    {
                        int hStart = h * Stride;
                        int wStart = w * Stride;
                        var poolRegion = input.GetSubTensor(b, c, hStart, wStart, PoolSize, PoolSize);

                        if (Type == PoolingType.Max)
                        {
                            (T maxVal, int maxIndex) = poolRegion.Max();
                            output[b, c, h, w] = maxVal;
                            _maxIndices[b, c, h, w] = maxIndex;
                        }
                        else if (Type == PoolingType.Average)
                        {
                            output[b, c, h, w] = poolRegion.Mean();
                        }
                    }
                }
            }
        }

        return output;
    }

    /// <summary>
    /// Performs the backward pass of the pooling layer.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's input.</returns>
    /// <exception cref="InvalidOperationException">Thrown when backward is called before forward or when _maxIndices is null during max pooling.</exception>
    /// <remarks>
    /// <para>
    /// This method implements the backward pass of the pooling layer, which is used during training to propagate
    /// error gradients back through the network. For max pooling, gradients are passed only to the positions
    /// that had the maximum values in each pooling region. For average pooling, gradients are distributed
    /// equally across all positions in each pooling region.
    /// </para>
    /// <para><b>For Beginners:</b> This method calculates how changes in the input would affect the final output.
    /// 
    /// During the backward pass:
    /// - The layer receives gradients for each position in the output tensor
    /// - It needs to pass these gradients back to the appropriate positions in the input tensor
    /// 
    /// For max pooling:
    /// - Only the position that had the maximum value gets the gradient
    /// - All other positions in the pooling region get zero gradient
    /// - This is because changing non-maximum values wouldn't affect the output
    /// 
    /// For average pooling:
    /// - The gradient is divided equally among all positions in the pooling region
    /// - Each position gets (output gradient) � (pool size � pool size)
    /// - This is because each input position contributes equally to the average
    /// 
    /// This approach follows the chain rule of calculus for the respective pooling operations.
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        if (_lastInput == null)
            throw new InvalidOperationException("Forward pass must be called before backward pass.");

        int batchSize = _lastInput.Shape[0];
        int channels = _lastInput.Shape[1];
        int inputHeight = _lastInput.Shape[2];
        int inputWidth = _lastInput.Shape[3];

        var inputGradient = new Tensor<T>(_lastInput.Shape);

        for (int b = 0; b < batchSize; b++)
        {
            for (int c = 0; c < channels; c++)
            {
                for (int h = 0; h < outputGradient.Shape[2]; h++)
                {
                    for (int w = 0; w < outputGradient.Shape[3]; w++)
                    {
                        int hStart = h * Stride;
                        int wStart = w * Stride;

                        if (Type == PoolingType.Max)
                        {
                            if (_maxIndices != null)
                            {
                                int maxIndex = _maxIndices[b, c, h, w];
                                int maxH = hStart + maxIndex / PoolSize;
                                int maxW = wStart + maxIndex % PoolSize;
                                inputGradient[b, c, maxH, maxW] = NumOps.Add(inputGradient[b, c, maxH, maxW], outputGradient[b, c, h, w]);
                            }
                            else
                            {
                                throw new InvalidOperationException("_maxIndices is null. This should not happen.");
                            }
                        }
                        else if (Type == PoolingType.Average)
                        {
                            T gradValue = outputGradient[b, c, h, w];
                            gradValue = NumOps.Divide(gradValue, NumOps.FromDouble(PoolSize * PoolSize));
                            for (int ph = 0; ph < PoolSize; ph++)
                            {
                                for (int pw = 0; pw < PoolSize; pw++)
                                {
                                    inputGradient[b, c, hStart + ph, wStart + pw] = NumOps.Add(inputGradient[b, c, hStart + ph, wStart + pw], gradValue);
                                }
                            }
                        }
                    }
                }
            }
        }

        return inputGradient;
    }

    /// <summary>
    /// Updates the parameters of the pooling layer using the calculated gradients.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the parameter updates.</param>
    /// <remarks>
    /// <para>
    /// This method is part of the training process, but since PoolingLayer has no trainable parameters,
    /// this method does nothing.
    /// </para>
    /// <para><b>For Beginners:</b> This method would normally update a layer's internal values during training.
    /// 
    /// However, since PoolingLayer just performs a fixed mathematical operation (pooling) and doesn't
    /// have any internal values that can be learned or adjusted, this method is empty.
    /// 
    /// This is unlike layers such as Dense or Convolutional layers, which have weights and biases
    /// that get updated during training.
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        // Pooling layers don't have trainable parameters, so this method does nothing.
    }

    /// <summary>
    /// Gets all trainable parameters from the pooling layer as a single vector.
    /// </summary>
    /// <returns>An empty vector since PoolingLayer has no trainable parameters.</returns>
    /// <remarks>
    /// <para>
    /// This method retrieves all trainable parameters from the layer as a single vector. Since PoolingLayer
    /// has no trainable parameters, it returns an empty vector.
    /// </para>
    /// <para><b>For Beginners:</b> This method returns all the learnable values in the layer.
    /// 
    /// Since PoolingLayer:
    /// - Only performs fixed mathematical operations (max or average calculation)
    /// - Has no weights, biases, or other learnable parameters
    /// - The method returns an empty list
    /// 
    /// This is different from layers like Dense layers, which would return their weights and biases.
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // PoolingLayer has no trainable parameters
        return Vector<T>.Empty();
    }

    /// <summary>
    /// Resets the internal state of the pooling layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method resets the internal state of the pooling layer, including the cached input tensor
    /// and maximum indices. This is useful when starting to process a new sequence or batch of data.
    /// </para>
    /// <para><b>For Beginners:</b> This method clears the layer's memory to start fresh.
    /// 
    /// When resetting the state:
    /// - Stored input from previous processing is cleared
    /// - For max pooling, the stored positions of maximum values are cleared
    /// - The layer forgets any information from previous data batches
    /// 
    /// This is important for:
    /// - Processing a new, unrelated batch of data
    /// - Ensuring clean state before a new training epoch
    /// - Preventing information from one batch affecting another
    /// 
    /// While the PoolingLayer doesn't maintain long-term state across samples,
    /// clearing these cached values helps with memory management and ensuring a clean processing pipeline.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // Clear cached values from forward pass
        _lastInput = null;
        _maxIndices = null;
    }
}