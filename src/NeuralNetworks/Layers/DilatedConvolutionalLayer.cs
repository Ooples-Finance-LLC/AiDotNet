namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a dilated convolutional layer for neural networks that applies filters with gaps between filter elements.
/// </summary>
/// <remarks>
/// <para>
/// A dilated convolutional layer extends traditional convolutional layers by introducing gaps (dilation) between 
/// the elements of the convolution kernel. This increases the receptive field without increasing the number of 
/// parameters or computational cost. Dilated convolutions are particularly useful in tasks requiring a wide 
/// context without sacrificing resolution, such as semantic segmentation or audio generation.
/// </para>
/// <para><b>For Beginners:</b> A dilated convolutional layer is like looking at an image with a special magnifying glass.
/// 
/// Regular convolutions look at pixels that are right next to each other, like this:
/// - Looking at a 3�3 area of an image (9 adjacent pixels)
/// 
/// Dilated convolutions skip some pixels, creating gaps, like this:
/// - With dilation=2, it looks at pixels with a gap of 1 pixel between them
/// - The 3�3 filter now covers a 5�5 area (still using only 9 values)
/// 
/// Benefits:
/// - Sees a larger area without needing more computing power
/// - Captures wider patterns in the data
/// - Helps detect features at different scales
/// 
/// For example, in image processing, dilated convolutions can help the network understand 
/// both fine details and broader context at the same time.
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class DilatedConvolutionalLayer<T> : LayerBase<T>
{
    /// <summary>
    /// The number of channels in the input data.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field represents the depth or number of channels in the input data. For RGB images, this would typically be 3
    /// (one channel each for red, green, and blue). For grayscale images, this would be 1.
    /// </para>
    /// <para><b>For Beginners:</b> This is how many different "types" of information each input position has.
    /// 
    /// Examples:
    /// - For color images: 3 channels (red, green, blue)
    /// - For grayscale images: 1 channel (just brightness)
    /// - For audio: might be frequency bands
    /// - For text data converted to numbers: might be embedding dimensions
    /// 
    /// Think of it like layers of information stacked on top of each other at each position.
    /// </para>
    /// </remarks>
    private readonly int _inputDepth;

    /// <summary>
    /// The number of filters (output channels) in the convolutional layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field represents the number of different filters applied in the convolutional layer, which determines
    /// the number of output channels. Each filter learns to detect different features in the input.
    /// </para>
    /// <para><b>For Beginners:</b> This is how many different patterns the layer will look for.
    /// 
    /// Each filter is like a detector for a specific pattern:
    /// - Some might detect edges
    /// - Others might detect corners
    /// - Others might detect textures, colors, or shapes
    /// 
    /// More filters mean the network can recognize more different patterns,
    /// but also mean more calculations and memory usage.
    /// </para>
    /// </remarks>
    private readonly int _outputDepth;

    /// <summary>
    /// The size of the convolution kernel (filter) in both height and width dimensions.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field represents the size of the square filter used in the convolution operation.
    /// Common kernel sizes are 3�3, 5�5, and 7�7.
    /// </para>
    /// <para><b>For Beginners:</b> This is the size of the "window" that looks at the input data.
    /// 
    /// The kernel size determines how much local context is considered:
    /// - Small kernels (3�3): Look at very local patterns
    /// - Larger kernels (7�7): Look at wider patterns
    /// 
    /// For example, with a 3�3 kernel, each output value is calculated by looking at 
    /// a 3�3 grid of input values (accounting for dilation).
    /// </para>
    /// </remarks>
    private readonly int _kernelSize;

    /// <summary>
    /// The stride (step size) of the convolution operation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field determines how many steps the convolution filter moves between applications. A stride of 1 means
    /// the filter moves one pixel at a time, while a stride of 2 means it moves two pixels, effectively
    /// downsampling the output to half the resolution.
    /// </para>
    /// <para><b>For Beginners:</b> This is how many positions the window "jumps" each time it moves.
    /// 
    /// Think of it like walking:
    /// - Stride=1: Taking small steps, looking at every position
    /// - Stride=2: Taking bigger steps, skipping some positions
    /// 
    /// Larger strides:
    /// - Make the output smaller than the input
    /// - Reduce computation time
    /// - Can lose some information
    /// 
    /// For example, with stride=2, a 100�100 image would become roughly 50�50 after the convolution.
    /// </para>
    /// </remarks>
    private readonly int _stride;

    /// <summary>
    /// The amount of zero-padding added to the input before convolution.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field determines how many pixels of padding are added around the input data. Padding helps
    /// to maintain the spatial dimensions and ensures that border pixels receive equal attention
    /// in the convolution operation.
    /// </para>
    /// <para><b>For Beginners:</b> This is like adding an extra border around the input data.
    /// 
    /// Why use padding:
    /// - Without padding, the output gets smaller after each convolution
    /// - With padding, the output can stay the same size as the input
    /// - It helps the network pay attention to features at the edges
    /// 
    /// For example, with padding=1 and a 3�3 kernel, a single row of zeros is added 
    /// around the entire input before applying the convolution.
    /// </para>
    /// </remarks>
    private readonly int _padding;

    /// <summary>
    /// The dilation factor that determines the spacing between kernel elements.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field represents the dilation rate, which determines the spacing between the elements of the convolution kernel.
    /// A dilation of 1 is a standard convolution, while a dilation of 2 means there is one pixel gap between each
    /// filter element, effectively expanding the receptive field without increasing parameters.
    /// </para>
    /// <para><b>For Beginners:</b> This is how spread out the points in the filter window are.
    /// 
    /// Think of it like this:
    /// - Dilation=1: Looking at adjacent pixels (standard convolution)
    /// - Dilation=2: Looking at every other pixel (one gap between)
    /// - Dilation=3: Looking at every third pixel (two gaps between)
    /// 
    /// Benefits:
    /// - Sees a wider area with the same number of filter points
    /// - Captures long-range dependencies
    /// - Efficient way to increase the "field of view"
    /// 
    /// For example, a 3�3 filter with dilation=2 would cover a 5�5 area,
    /// but still only use 9 values from that area.
    /// </para>
    /// </remarks>
    private readonly int _dilation;

    /// <summary>
    /// The weight tensors (filters) for the convolutional layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This tensor stores the learnable weights for each convolution filter. The shape is
    /// [outputDepth, inputDepth, kernelSize, kernelSize], representing the weights for each
    /// output channel, input channel, and spatial location in the kernel.
    /// </para>
    /// <para><b>For Beginners:</b> These are the actual pattern detectors that the network learns.
    /// 
    /// Each filter is like a template that tries to match patterns in the input:
    /// - The values in the filter determine what pattern it detects
    /// - During training, these values adjust to better detect useful patterns
    /// - Each output channel has its own set of filters
    /// 
    /// For instance, a filter might learn to detect vertical edges by having positive
    /// weights on one side and negative weights on the other.
    /// </para>
    /// </remarks>
    private Tensor<T> _kernels = default!;

    /// <summary>
    /// The bias values for each output channel.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This vector stores the learnable bias term for each output channel. The bias is added
    /// to the output of the convolution operation before applying the activation function.
    /// </para>
    /// <para><b>For Beginners:</b> These are adjustment values that help fine-tune the output.
    /// 
    /// Biases work like this:
    /// - After applying the filters, a constant value is added to each output channel
    /// - This helps the network adjust the "threshold" for activating features
    /// - Each output channel has its own bias value
    /// 
    /// Think of biases like adjusting the baseline sensitivity of each pattern detector.
    /// </para>
    /// </remarks>
    private Vector<T> _biases = default!;

    /// <summary>
    /// The input tensor from the last forward pass, saved for backpropagation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This tensor stores the input received during the last forward pass. It is necessary for computing
    /// gradients during the backward pass (backpropagation).
    /// </para>
    /// <para><b>For Beginners:</b> This remembers what input data was processed most recently.
    /// 
    /// During training:
    /// - The layer needs to remember what input it processed
    /// - This helps it calculate how to update its filters
    /// - It's like keeping your work when solving a math problem
    /// 
    /// This is automatically cleared after each training batch to save memory.
    /// </para>
    /// </remarks>
    private Tensor<T>? _lastInput;

    /// <summary>
    /// The output tensor from the last forward pass, saved for backpropagation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This tensor stores the output produced during the last forward pass. It is used during
    /// backpropagation to compute certain gradients, particularly for activation functions.
    /// </para>
    /// <para><b>For Beginners:</b> This stores what the layer output after its most recent calculation.
    /// 
    /// During training:
    /// - The network needs to remember what predictions it made
    /// - This helps calculate how to improve for next time
    /// - It's used along with the true answer to adjust the weights
    /// 
    /// This is also cleared after each training batch to save memory.
    /// </para>
    /// </remarks>
    private Tensor<T>? _lastOutput;

    /// <summary>
    /// The gradients for the kernels, computed during backpropagation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This tensor stores the gradients of the loss with respect to each kernel weight.
    /// These gradients are used to update the weights during training.
    /// </para>
    /// <para><b>For Beginners:</b> This stores information about how to adjust each filter value.
    /// 
    /// During training:
    /// - The network calculates how each filter value contributed to errors
    /// - Gradients indicate both direction and amount to change each value
    /// - Larger gradients mean bigger adjustments are needed
    /// 
    /// Think of gradients as instructions for improving each filter based on
    /// what the network learned from its mistakes.
    /// </para>
    /// </remarks>
    private Tensor<T>? _kernelGradients;

    /// <summary>
    /// The gradients for the biases, computed during backpropagation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This vector stores the gradients of the loss with respect to each bias value.
    /// These gradients are used to update the biases during training.
    /// </para>
    /// <para><b>For Beginners:</b> This stores information about how to adjust each bias value.
    /// 
    /// During training:
    /// - The network calculates how each bias contributed to errors
    /// - These gradients show how to adjust the "sensitivity" of each detector
    /// - They help fine-tune when each feature detector should activate
    /// 
    /// Bias gradients tend to be simpler than weight gradients because
    /// each output channel only has one bias value.
    /// </para>
    /// </remarks>
    private Vector<T>? _biasGradients;

    /// <summary>
    /// Gets a value indicating whether this layer supports training.
    /// </summary>
    /// <value>
    /// Always <c>true</c> because this layer has trainable parameters (kernels and biases).
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates that the dilated convolutional layer supports training through backpropagation.
    /// The layer has trainable parameters (kernels and biases) that are updated during the training process.
    /// </para>
    /// <para><b>For Beginners:</b> This property tells you that this layer can learn from data.
    /// 
    /// A value of true means:
    /// - The layer adjusts its filters and biases during training
    /// - It improves over time as it sees more examples
    /// - It participates in the learning process of the neural network
    /// 
    /// This is different from some layers (like pooling layers) that don't have
    /// trainable parameters and therefore don't "learn" in the same way.
    /// </para>
    /// </remarks>
    public override bool SupportsTraining => true;

    /// <summary>
    /// Initializes a new instance of the <see cref="DilatedConvolutionalLayer{T}"/> class with scalar activation.
    /// </summary>
    /// <param name="inputDepth">The number of channels in the input data.</param>
    /// <param name="outputDepth">The number of filters (output channels).</param>
    /// <param name="kernelSize">The size of the convolution kernel.</param>
    /// <param name="inputHeight">The height of the input data.</param>
    /// <param name="inputWidth">The width of the input data.</param>
    /// <param name="dilation">The dilation factor that determines spacing between kernel elements.</param>
    /// <param name="stride">The stride of the convolution operation. Defaults to 1.</param>
    /// <param name="padding">The amount of zero-padding added to the input. Defaults to 0.</param>
    /// <param name="activation">The activation function to apply. Defaults to ReLU.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a new dilated convolutional layer with the specified parameters.
    /// The activation function operates on individual scalar values in the output tensor.
    /// The layer is initialized with weights using Xavier initialization to help with training convergence.
    /// </para>
    /// <para><b>For Beginners:</b> This sets up the convolutional layer with all its needed settings.
    /// 
    /// When creating this layer, you need to specify:
    /// - Input information: how many channels, height, and width
    /// - Filter information: how many filters and what size
    /// - Dilation: how spread out the filter points should be
    /// - Optional settings: stride, padding, and activation function
    /// 
    /// The layer automatically initializes the filters with small random values
    /// that are carefully scaled to work well with training.
    /// 
    /// Example: For processing 32�32 color images with 16 filters of size 3�3 and dilation of 2:
    /// ```csharp
    /// var convLayer = new DilatedConvolutionalLayer<float>(
    ///     inputDepth: 3,           // RGB input
    ///     outputDepth: 16,         // 16 different feature detectors
    ///     kernelSize: 3,           // 3�3 filters
    ///     inputHeight: 32,         // Image height
    ///     inputWidth: 32,          // Image width
    ///     dilation: 2,             // Look at every other pixel
    ///     stride: 1,               // Move one pixel at a time
    ///     padding: 2               // Add padding to maintain size
    /// );
    /// ```
    /// </para>
    /// </remarks>
    public DilatedConvolutionalLayer(int inputDepth, int outputDepth, int kernelSize, int inputHeight, int inputWidth, 
                                     int dilation, int stride = 1, int padding = 0, 
                                     IActivationFunction<T>? activation = null)
        : base(CalculateInputShape(inputDepth, inputHeight, inputWidth), 
               CalculateOutputShape(outputDepth, CalculateOutputDimension(inputHeight, kernelSize, stride, padding, dilation), 
                   CalculateOutputDimension(inputWidth, kernelSize, stride, padding, dilation)), 
               activation ?? new ReLUActivation<T>())
    {
        _inputDepth = inputDepth;
        _outputDepth = outputDepth;
        _kernelSize = kernelSize;
        _stride = stride;
        _padding = padding;
        _dilation = dilation;

        _kernels = new Tensor<T>([_outputDepth, _inputDepth, _kernelSize, _kernelSize]);
        _biases = new Vector<T>(_outputDepth);

        InitializeWeights();
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="DilatedConvolutionalLayer{T}"/> class with vector activation.
    /// </summary>
    /// <param name="inputDepth">The number of channels in the input data.</param>
    /// <param name="outputDepth">The number of filters (output channels).</param>
    /// <param name="kernelSize">The size of the convolution kernel.</param>
    /// <param name="inputHeight">The height of the input data.</param>
    /// <param name="inputWidth">The width of the input data.</param>
    /// <param name="dilation">The dilation factor that determines spacing between kernel elements.</param>
    /// <param name="stride">The stride of the convolution operation. Defaults to 1.</param>
    /// <param name="padding">The amount of zero-padding added to the input. Defaults to 0.</param>
    /// <param name="vectorActivation">The vector activation function to apply. Defaults to ReLU.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a new dilated convolutional layer with the specified parameters.
    /// Unlike the other constructor, this one accepts a vector activation function that operates on
    /// entire vectors rather than individual scalar values.
    /// </para>
    /// <para><b>For Beginners:</b> This is an alternative setup that uses a different kind of activation function.
    /// 
    /// This constructor is almost identical to the first one, but with one key difference:
    /// - Regular activation: processes each output value separately
    /// - Vector<double> activation: processes groups of values together
    /// 
    /// Vector<double> activation functions can capture relationships between different output values,
    /// which might be useful for some advanced applications.
    /// 
    /// For most basic uses, the regular constructor is sufficient.
    /// </para>
    /// </remarks>
    public DilatedConvolutionalLayer(int inputDepth, int outputDepth, int kernelSize, int inputHeight, int inputWidth, 
                                     int dilation, int stride = 1, int padding = 0, 
                                     IVectorActivationFunction<T>? vectorActivation = null)
        : base(CalculateInputShape(inputDepth, inputHeight, inputWidth), 
               CalculateOutputShape(outputDepth, CalculateOutputDimension(inputHeight, kernelSize, stride, padding, dilation), 
                   CalculateOutputDimension(inputWidth, kernelSize, stride, padding, dilation)), 
               vectorActivation ?? new ReLUActivation<T>())
    {
        _inputDepth = inputDepth;
        _outputDepth = outputDepth;
        _kernelSize = kernelSize;
        _stride = stride;
        _padding = padding;
        _dilation = dilation;

        _kernels = new Tensor<T>([_outputDepth, _inputDepth, _kernelSize, _kernelSize]);
        _biases = new Vector<T>(_outputDepth);

        InitializeWeights();
    }

    /// <summary>
    /// Initializes the kernel weights and biases with appropriate values.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method initializes the kernel weights using Xavier initialization, which helps with training
    /// convergence by setting initial values to a scale appropriate for the layer's dimensions.
    /// The biases are initialized to zero.
    /// </para>
    /// <para><b>For Beginners:</b> This sets up the initial values for the filters and biases.
    /// 
    /// For good training:
    /// - Weights need to start with small random values
    /// - These values are carefully scaled based on layer size
    /// - Too large or too small values can make training difficult
    /// 
    /// The method uses "Xavier initialization," which is a popular way to set
    /// initial weights that helps the network learn effectively.
    /// 
    /// Biases are simply initialized to zero, as they'll adjust during training.
    /// </para>
    /// </remarks>
    private void InitializeWeights()
    {
        // Xavier initialization
        T scale = NumOps.Sqrt(NumOps.FromDouble(2.0 / (_inputDepth * _kernelSize * _kernelSize + _outputDepth)));

        for (int i = 0; i < _kernels.Shape[0]; i++)
        {
            for (int j = 0; j < _kernels.Shape[1]; j++)
            {
                for (int k = 0; k < _kernels.Shape[2]; k++)
                {
                    for (int l = 0; l < _kernels.Shape[3]; l++)
                    {
                        _kernels[i, j, k, l] = NumOps.Multiply(NumOps.FromDouble(Random.NextDouble() - 0.5), scale);
                    }
                }
            }
        }

        for (int i = 0; i < _biases.Length; i++)
        {
            _biases[i] = NumOps.Zero;
        }
    }

    /// <summary>
    /// Performs the forward pass of the convolutional layer.
    /// </summary>
    /// <param name="input">The input tensor to process.</param>
    /// <returns>The output tensor after convolution and activation.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the forward pass of the dilated convolutional layer. It applies the convolution
    /// operation with the specified dilation, stride, and padding to the input tensor. The result is passed
    /// through the activation function to produce the final output.
    /// </para>
    /// <para><b>For Beginners:</b> This is where the layer processes input data to detect patterns.
    /// 
    /// During the forward pass:
    /// 1. For each position in the output:
    ///    - Look at the corresponding area in the input (accounting for dilation)
    ///    - Multiply each input value by the corresponding filter value
    ///    - Sum up all these multiplications
    ///    - Add the bias value
    /// 2. Apply the activation function to the result
    /// 3. Save the input and output for later use in training
    /// 
    /// The dilation controls how spread out the filter points are when looking
    /// at the input, allowing the network to capture wider patterns.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        _lastInput = input;
        int batchSize = input.Shape[0];
        int inputHeight = input.Shape[1];
        int inputWidth = input.Shape[2];
        int outputHeight = CalculateOutputDimension(inputHeight, _kernelSize, _stride, _padding, _dilation);
        int outputWidth = CalculateOutputDimension(inputWidth, _kernelSize, _stride, _padding, _dilation);

        var output = new Tensor<T>([batchSize, outputHeight, outputWidth, _outputDepth]);

        for (int b = 0; b < batchSize; b++)
        {
            for (int oh = 0; oh < outputHeight; oh++)
            {
                for (int ow = 0; ow < outputWidth; ow++)
                {
                    for (int od = 0; od < _outputDepth; od++)
                    {
                        T sum = _biases[od];

                        for (int kh = 0; kh < _kernelSize; kh++)
                        {
                            for (int kw = 0; kw < _kernelSize; kw++)
                            {
                                int ih = oh * _stride + kh * _dilation - _padding;
                                int iw = ow * _stride + kw * _dilation - _padding;

                                if (ih >= 0 && ih < inputHeight && iw >= 0 && iw < inputWidth)
                                {
                                    for (int id = 0; id < _inputDepth; id++)
                                    {
                                        sum = NumOps.Add(sum, NumOps.Multiply(input[b, ih, iw, id], _kernels[od, id, kh, kw]));
                                    }
                                }
                            }
                        }

                        output[b, oh, ow, od] = sum;
                    }
                }
            }
        }

        _lastOutput = ApplyActivation(output);
        return _lastOutput;
    }

    /// <summary>
    /// Performs the backward pass of the convolutional layer to compute gradients.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's input.</returns>
    /// <exception cref="InvalidOperationException">Thrown when backward is called before forward.</exception>
    /// <remarks>
    /// <para>
    /// This method implements the backward pass (backpropagation) of the dilated convolutional layer. 
    /// It computes the gradients of the loss with respect to the layer's weights, biases, and inputs.
    /// These gradients are used to update the parameters during training.
    /// </para>
    /// <para><b>For Beginners:</b> This is where the layer learns from its mistakes during training.
    /// 
    /// During the backward pass:
    /// 1. The layer receives information about how its output contributed to errors
    /// 2. It calculates three things:
    ///    - How to adjust each filter value (kernel gradients)
    ///    - How to adjust each bias value (bias gradients)
    ///    - How the error flows back to the previous layer (input gradients)
    /// 3. These gradients are used to update the filters and biases
    /// 
    /// The dilation is also taken into account when calculating these gradients,
    /// ensuring that the learning process understands the dilated nature of the convolution.
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        if (_lastInput == null || _lastOutput == null)
        {
            throw new InvalidOperationException("Forward pass must be called before backward pass.");
        }

        int batchSize = _lastInput.Shape[0];
        int inputHeight = _lastInput.Shape[1];
        int inputWidth = _lastInput.Shape[2];
        int outputHeight = outputGradient.Shape[1];
        int outputWidth = outputGradient.Shape[2];

        // Initialize gradients
        var kernelGradients = new Tensor<T>(_kernels.Shape);
        var biasGradients = new Vector<T>(_biases.Length);
        var inputGradients = new Tensor<T>(_lastInput.Shape);

        // Compute gradients
        for (int b = 0; b < batchSize; b++)
        {
            for (int oh = 0; oh < outputHeight; oh++)
            {
                for (int ow = 0; ow < outputWidth; ow++)
                {
                    for (int od = 0; od < _outputDepth; od++)
                    {
                        T outputGrad = outputGradient[b, oh, ow, od];
                        biasGradients[od] = NumOps.Add(biasGradients[od], outputGrad);

                        for (int kh = 0; kh < _kernelSize; kh++)
                        {
                            for (int kw = 0; kw < _kernelSize; kw++)
                            {
                                int ih = oh * _stride + kh * _dilation - _padding;
                                int iw = ow * _stride + kw * _dilation - _padding;

                                if (ih >= 0 && ih < inputHeight && iw >= 0 && iw < inputWidth)
                                {
                                    for (int id = 0; id < _inputDepth; id++)
                                    {
                                        T inputVal = _lastInput[b, ih, iw, id];
                                        kernelGradients[od, id, kh, kw] = NumOps.Add(kernelGradients[od, id, kh, kw], NumOps.Multiply(outputGrad, inputVal));
                                        inputGradients[b, ih, iw, id] = NumOps.Add(inputGradients[b, ih, iw, id], NumOps.Multiply(outputGrad, _kernels[od, id, kh, kw]));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Store gradients for parameter update
        _kernelGradients = kernelGradients;
        _biasGradients = biasGradients;

        return inputGradients;
    }

    /// <summary>
    /// Calculates the shape of the input tensor expected by this layer.
    /// </summary>
    /// <param name="inputDepth">The number of channels in the input data.</param>
    /// <param name="inputHeight">The height of the input data.</param>
    /// <param name="inputWidth">The width of the input data.</param>
    /// <returns>The calculated input shape for this layer.</returns>
    /// <remarks>
    /// <para>
    /// This method calculates the expected input shape for the layer based on the specified dimensions.
    /// It is used internally during layer initialization to configure the layer's input shape.
    /// </para>
    /// <para><b>For Beginners:</b> This helps the layer know what shape of data to expect.
    /// 
    /// This method:
    /// - Takes the basic dimensions of the input (height, width, depth)
    /// - Formats them into the proper shape expected by the layer
    /// - Helps with automatic shape checking when building networks
    /// 
    /// It's an internal helper method that makes sure all the layer's
    /// calculations will work correctly with the input data.
    /// </para>
    /// </remarks>
    private new static int[][] CalculateInputShape(int inputDepth, int inputHeight, int inputWidth)
    {
        return [[inputHeight, inputWidth, inputDepth]];
    }

    /// <summary>
    /// Calculates the shape of the output tensor produced by this layer.
    /// </summary>
    /// <param name="outputDepth">The number of filters (output channels).</param>
    /// <param name="outputHeight">The height of the output data.</param>
    /// <param name="outputWidth">The width of the output data.</param>
    /// <returns>The calculated output shape for this layer.</returns>
    /// <remarks>
    /// <para>
    /// This method calculates the output shape that will be produced by the layer based on the
    /// specified dimensions. It is used internally during layer initialization.
    /// </para>
    /// <para><b>For Beginners:</b> This determines what shape of data the layer will output.
    /// 
    /// This method:
    /// - Takes the dimensions of the output (height, width, depth)
    /// - Formats them into the proper shape for the output
    /// - Helps with automatic shape matching when connecting layers
    /// 
    /// It's an internal helper method that ensures the network knows what
    /// shape of data to expect from this layer.
    /// </para>
    /// </remarks>
    private new static int[] CalculateOutputShape(int outputDepth, int outputHeight, int outputWidth)
    {
        return [outputHeight, outputWidth, outputDepth];
    }

    /// <summary>
    /// Calculates the output dimension (height or width) based on input dimension and convolution parameters.
    /// </summary>
    /// <param name="inputDim">The input dimension (height or width).</param>
    /// <param name="kernelSize">The size of the convolution kernel.</param>
    /// <param name="stride">The stride of the convolution operation.</param>
    /// <param name="padding">The amount of zero-padding added to the input.</param>
    /// <param name="dilation">The dilation factor that determines spacing between kernel elements.</param>
    /// <returns>The calculated output dimension.</returns>
    /// <remarks>
    /// <para>
    /// This method calculates the output dimension (height or width) of the convolution operation based on
    /// the input dimension and convolution parameters using the formula:
    /// (inputDim + 2 * padding - dilation * (kernelSize - 1) - 1) / stride + 1.
    /// </para>
    /// <para><b>For Beginners:</b> This calculates how big the output will be after applying the convolution.
    /// 
    /// This formula accounts for:
    /// - How big the input is
    /// - How big the filter is
    /// - How much padding is added
    /// - How much dilation is used
    /// - How big the stride is
    /// 
    /// For example:
    /// - With a 32�32 input, 3�3 kernel, stride of 1, padding of 1, and dilation of 1:
    ///   Output size = (32 + 2*1 - 1*(3-1) - 1)/1 + 1 = 32
    ///   (The output stays the same size as the input)
    /// 
    /// - With the same setup but dilation of 2:
    ///   Output size = (32 + 2*1 - 2*(3-1) - 1)/1 + 1 = 30
    ///   (The output shrinks slightly)
    /// </para>
    /// </remarks>
    private static int CalculateOutputDimension(int inputDim, int kernelSize, int stride, int padding, int dilation)
    {
        return (inputDim + 2 * padding - dilation * (kernelSize - 1) - 1) / stride + 1;
    }

    /// <summary>
    /// Updates the layer's weights and biases using the calculated gradients and the specified learning rate.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the parameter updates.</param>
    /// <exception cref="InvalidOperationException">Thrown when update is called before backward.</exception>
    /// <remarks>
    /// <para>
    /// This method updates the layer's weights and biases based on the gradients calculated during the backward pass.
    /// The learning rate determines the size of the parameter updates. Smaller learning rates lead to more
    /// stable but slower training, while larger learning rates can lead to faster but potentially unstable training.
    /// </para>
    /// <para><b>For Beginners:</b> This method actually changes the filters and biases to improve future predictions.
    /// 
    /// After figuring out how each value should change (in the backward pass):
    /// - Each filter value is adjusted in the direction that reduces errors
    /// - Each bias value is also adjusted to optimize performance
    /// - The learning rate controls how big these adjustments are
    /// 
    /// Think of it like adjusting a recipe after tasting:
    /// - Too salty? Reduce salt next time
    /// - Too bland? Add more seasoning
    /// - But make small adjustments, not drastic ones
    /// 
    /// After updating, the gradients are cleared to prepare for the next training batch.
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        if (_kernelGradients == null || _biasGradients == null)
        {
            throw new InvalidOperationException("UpdateParameters called before Backward.");
        }

        for (int i = 0; i < _kernels.Shape[0]; i++)
        {
            for (int j = 0; j < _kernels.Shape[1]; j++)
            {
                for (int k = 0; k < _kernels.Shape[2]; k++)
                {
                    for (int l = 0; l < _kernels.Shape[3]; l++)
                    {
                        _kernels[i, j, k, l] = NumOps.Subtract(_kernels[i, j, k, l], NumOps.Multiply(learningRate, _kernelGradients[i, j, k, l]));
                    }
                }
            }
        }

        for (int i = 0; i < _biases.Length; i++)
        {
            _biases[i] = NumOps.Subtract(_biases[i], NumOps.Multiply(learningRate, _biasGradients[i]));
        }

        // Reset gradients
        _kernelGradients = null;
        _biasGradients = null;
    }

    /// <summary>
    /// Gets all trainable parameters of the layer as a single vector.
    /// </summary>
    /// <returns>A vector containing all trainable parameters.</returns>
    /// <remarks>
    /// <para>
    /// This method retrieves all trainable parameters (weights and biases) of the layer as a single vector.
    /// This is useful for optimization algorithms that operate on all parameters at once, or for saving
    /// and loading model weights.
    /// </para>
    /// <para><b>For Beginners:</b> This method collects all the layer's learnable values into a single list.
    /// 
    /// The parameters include:
    /// - All the filter weights (the majority of the parameters)
    /// - All the bias values (one per output channel)
    /// 
    /// This combined list is useful for:
    /// - Saving the model to disk
    /// - Loading parameters from a previously trained model
    /// - Advanced optimization techniques that need all parameters together
    /// 
    /// Think of it like packing all the knowledge the layer has learned into a single container.
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // Calculate total number of parameters
        int totalParams = _kernels.Length + _biases.Length;
        var parameters = new Vector<T>(totalParams);

        int index = 0;

        // Copy kernel parameters
        for (int od = 0; od < _outputDepth; od++)
        {
            for (int id = 0; id < _inputDepth; id++)
            {
                for (int kh = 0; kh < _kernelSize; kh++)
                {
                    for (int kw = 0; kw < _kernelSize; kw++)
                    {
                        parameters[index++] = _kernels[od, id, kh, kw];
                    }
                }
            }
        }

        // Copy bias parameters
        for (int od = 0; od < _outputDepth; od++)
        {
            parameters[index++] = _biases[od];
        }

        return parameters;
    }

    /// <summary>
    /// Sets the trainable parameters of the layer from a single vector.
    /// </summary>
    /// <param name="parameters">A vector containing all parameters to set.</param>
    /// <exception cref="ArgumentException">Thrown when the parameters vector has incorrect length.</exception>
    /// <remarks>
    /// <para>
    /// This method sets all trainable parameters (weights and biases) of the layer from a single vector.
    /// This is useful for loading saved model weights or for implementing optimization algorithms
    /// that operate on all parameters at once.
    /// </para>
    /// <para><b>For Beginners:</b> This method updates all the layer's learnable values from a provided list.
    /// 
    /// When setting parameters:
    /// - The input must be a vector with the exact right length
    /// - The values are distributed back to the filter weights and biases
    /// - This allows loading previously trained weights
    /// 
    /// Use cases include:
    /// - Restoring a saved model
    /// - Using pre-trained weights
    /// - Testing specific weight configurations
    /// 
    /// The method throws an error if the provided vector doesn't contain exactly the right number of values.
    /// </para>
    /// </remarks>
    public override void SetParameters(Vector<T> parameters)
    {
        if (parameters.Length != _kernels.Length + _biases.Length)
        {
            throw new ArgumentException($"Expected {_kernels.Length + _biases.Length} parameters, but got {parameters.Length}");
        }

        int index = 0;

        // Set kernel parameters
        for (int od = 0; od < _outputDepth; od++)
        {
            for (int id = 0; id < _inputDepth; id++)
            {
                for (int kh = 0; kh < _kernelSize; kh++)
                {
                    for (int kw = 0; kw < _kernelSize; kw++)
                    {
                        _kernels[od, id, kh, kw] = parameters[index++];
                    }
                }
            }
        }

        // Set bias parameters
        for (int od = 0; od < _outputDepth; od++)
        {
            _biases[od] = parameters[index++];
        }
    }

    /// <summary>
    /// Resets the internal state of the layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method resets the internal state of the layer by clearing all cached values from forward
    /// and backward passes. This is useful when starting to process a new batch of data.
    /// </para>
    /// <para><b>For Beginners:</b> This method clears the layer's memory to start fresh.
    /// 
    /// When resetting the state:
    /// - The saved input and output are cleared
    /// - The calculated gradients are cleared
    /// - The layer forgets previous calculations it performed
    /// 
    /// This is useful:
    /// - Between training batches to free up memory
    /// - When switching from training to evaluation mode
    /// - When starting to process completely new data
    /// 
    /// It's like wiping a whiteboard clean before starting a new calculation.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // Clear cached values from forward and backward passes
        _lastInput = null;
        _lastOutput = null;
        _kernelGradients = null;
        _biasGradients = null;
    }
}