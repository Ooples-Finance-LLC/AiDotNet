namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a convolutional layer in a neural network that applies filters to input data.
/// </summary>
/// <remarks>
/// <para>
/// A convolutional layer applies a set of learnable filters to input data to extract features. 
/// Each filter slides across the input data, performing element-wise multiplication and summing
/// the results. This operation is called convolution and is particularly effective for processing
/// grid-like data such as images.
/// </para>
/// <para><b>For Beginners:</b> A convolutional layer is like a spotlight that scans over data
/// looking for specific patterns.
/// 
/// Think of it like examining a photo with a small magnifying glass:
/// - You move the magnifying glass across the image, one step at a time
/// - At each position, you note what you see in that small area
/// - After scanning the whole image, you have a collection of observations
/// 
/// For example, in image recognition:
/// - One filter might detect vertical edges
/// - Another might detect horizontal edges
/// - Together, they help the network recognize complex shapes
/// 
/// Convolutional layers are fundamental for recognizing patterns in images, audio, and other
/// grid-structured data.
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class ConvolutionalLayer<T> : LayerBase<T>
{
    /// <summary>
    /// Gets the depth (number of channels) of the input data.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The input depth represents the number of channels in the input data. For example, RGB images have
    /// a depth of 3 (red, green, and blue channels), while grayscale images have a depth of 1.
    /// </para>
    /// <para><b>For Beginners:</b> Input depth is the number of "layers" in your input data.
    /// 
    /// Think of it like:
    /// - A color photo has 3 layers (red, green, blue)
    /// - A black and white photo has 1 layer
    /// 
    /// Each layer contains different information about the same data.
    /// </para>
    /// </remarks>
    public int InputDepth { get; private set; }

    /// <summary>
    /// Gets the depth (number of filters) of the output data.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The output depth represents the number of filters applied to the input data. Each filter looks for
    /// a different pattern in the input, resulting in a different output channel.
    /// </para>
    /// <para><b>For Beginners:</b> Output depth is how many different patterns this layer will look for.
    /// 
    /// For example:
    /// - If output depth is 16, the layer will look for 16 different patterns
    /// - Each pattern creates its own output "layer" or channel
    /// - More output channels means the network can recognize more complex features
    /// 
    /// A higher number usually means the network can learn more details, but also requires more processing power.
    /// </para>
    /// </remarks>
    public int OutputDepth { get; private set; }

    /// <summary>
    /// Gets the size of each filter (kernel) used in the convolution operation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The kernel size determines the area of the input that is examined at each position. A larger kernel
    /// size means a larger area is considered for each output value, potentially capturing more complex patterns.
    /// </para>
    /// <para><b>For Beginners:</b> Kernel size is how big the "spotlight" or "magnifying glass" is.
    /// 
    /// For example:
    /// - A kernel size of 3 means a 3�3 area (9 pixels in an image)
    /// - A kernel size of 5 means a 5�5 area (25 pixels)
    /// 
    /// Smaller kernels (like 3�3) are good for detecting fine details.
    /// Larger kernels (like 7�7) can see broader patterns but may miss small details.
    /// </para>
    /// </remarks>
    public int KernelSize { get; private set; }

    /// <summary>
    /// Gets the step size for moving the kernel across the input data.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The stride determines how many positions to move the kernel for each step during the convolution
    /// operation. A stride of 1 means the kernel moves one position at a time, examining every possible
    /// position. A larger stride means fewer positions are examined, resulting in a smaller output.
    /// </para>
    /// <para><b>For Beginners:</b> Stride is how far you move the spotlight each time.
    /// 
    /// Think of it like:
    /// - Stride of 1: Move one step at a time (examine every position)
    /// - Stride of 2: Skip one position between each examination (move two steps each time)
    /// 
    /// Using a larger stride:
    /// - Makes the output smaller (reduces dimensions)
    /// - Speeds up processing
    /// - But might miss some information
    /// </para>
    /// </remarks>
    public int Stride { get; private set; }

    /// <summary>
    /// Gets the amount of zero-padding added to the input data before convolution.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Padding involves adding extra values (typically zeros) around the input data before performing
    /// the convolution. This allows the kernel to slide beyond the edges of the original input,
    /// preserving the spatial dimensions in the output.
    /// </para>
    /// <para><b>For Beginners:</b> Padding is like adding an extra border around your data.
    /// 
    /// Imagine adding a frame around a photo:
    /// - The frame is filled with zeros (blank data)
    /// - This allows the spotlight to analyze edges without going "off the picture"
    /// 
    /// Benefits of padding:
    /// - Maintains the size of your data through the layer
    /// - Ensures border information isn't lost
    /// - Without padding, each layer would make your data smaller
    /// </para>
    /// </remarks>
    public int Padding { get; private set; }
    
    /// <summary>
    /// Gets a value indicating whether this layer supports training through backpropagation.
    /// </summary>
    /// <value>
    /// Always returns <c>true</c> for convolutional layers, as they contain trainable parameters.
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates whether the layer can be trained through backpropagation. Convolutional
    /// layers have trainable parameters (kernel weights and biases), so they support training.
    /// </para>
    /// <para><b>For Beginners:</b> This property tells you if the layer can learn from data.
    /// 
    /// For convolutional layers:
    /// - The value is always true
    /// - This means the layer can adjust its pattern detectors (filters) during training
    /// - It will improve its pattern recognition as it processes more data
    /// </para>
    /// </remarks>
    public override bool SupportsTraining => true;

    /// <summary>
    /// The collection of filter kernels used for the convolution operation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This tensor stores the weight values for all kernels used in the layer. It has dimensions
    /// [OutputDepth, InputDepth, KernelSize, KernelSize], where each kernel is a set of weights
    /// that define a specific pattern to detect.
    /// </para>
    /// <para><b>For Beginners:</b> _kernels are the "pattern detectors" that the layer uses.
    /// 
    /// Each kernel:
    /// - Is a grid of numbers (weights)
    /// - Looks for a specific pattern in the input
    /// - Is learned during training
    /// 
    /// The layer has multiple kernels to detect different patterns, and these kernels
    /// are what actually get updated when the network learns.
    /// </para>
    /// </remarks>
    private Tensor<T> _kernels = default!;

    /// <summary>
    /// The bias values added to the convolution results for each output channel.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This vector stores the bias values for each output channel. _biases are constants that are
    /// added to the convolution results before applying the activation function.
    /// </para>
    /// <para><b>For Beginners:</b> _biases are like "adjustment factors" for each pattern detector.
    /// 
    /// Think of biases as:
    /// - A starting point or baseline value
    /// - Added to the result after applying the pattern detector
    /// - Helping the network be more flexible in what it can learn
    /// 
    /// For example, biases help the network detect patterns even when the input doesn't
    /// perfectly match what the kernel is looking for.
    /// </para>
    /// </remarks>
    private Vector<T> _biases = default!;

    /// <summary>
    /// Stored input data from the most recent forward pass, used for backpropagation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// During the backward pass (training), the layer needs access to the input data from the forward
    /// pass to calculate the gradients for the kernels and the input. This tensor stores that input data.
    /// </para>
    /// <para><b>For Beginners:</b> This is like the network's "short-term memory" of what it just saw.
    /// 
    /// The layer remembers:
    /// - The last data it processed
    /// - So it can figure out how to improve when learning
    /// 
    /// This is similar to looking at a problem you got wrong and the answer you gave,
    /// so you can understand where you made a mistake.
    /// </para>
    /// </remarks>
    private Tensor<T> _lastInput = default!;

    /// <summary>
    /// Stored output data from the most recent forward pass, used for backpropagation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// During the backward pass (training), the layer needs access to the output data from the forward
    /// pass to calculate the gradients for the activation function. This tensor stores that output data.
    /// </para>
    /// <para><b>For Beginners:</b> This is the network's memory of what answer it produced.
    /// 
    /// The layer remembers:
    /// - What output it produced for the last input
    /// - So it can calculate how to improve
    /// 
    /// This allows the network to compare what it predicted with the correct answer
    /// and adjust its internal values to make better predictions next time.
    /// </para>
    /// </remarks>
    private Tensor<T> _lastOutput = default!;

    /// <summary>
    /// Random number generator used for weight initialization.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This random number generator is used to initialize the kernel weights with random values.
    /// Random initialization helps the network break symmetry and learn different patterns in
    /// different kernels.
    /// </para>
    /// <para><b>For Beginners:</b> This creates random starting points for the pattern detectors.
    /// 
    /// The random generator:
    /// - Creates different starting weights each time
    /// - Ensures different kernels learn different patterns
    /// - Gives the network a better chance of learning successfully
    /// 
    /// Without randomness, all pattern detectors might end up looking for the same thing.
    /// </para>
    /// </remarks>
    private readonly Random _random = default!;

    /// <summary>
    /// Initializes a new instance of the <see cref="ConvolutionalLayer{T}"/> class with the specified parameters
    /// and a scalar activation function.
    /// </summary>
    /// <param name="inputDepth">The number of channels in the input data.</param>
    /// <param name="outputDepth">The number of filters (output channels) to create.</param>
    /// <param name="kernelSize">The size of each filter kernel (width and height).</param>
    /// <param name="inputHeight">The height of the input data.</param>
    /// <param name="inputWidth">The width of the input data.</param>
    /// <param name="stride">The step size for moving the kernel. Defaults to 1.</param>
    /// <param name="padding">The amount of zero-padding to add around the input. Defaults to 0.</param>
    /// <param name="activation">The activation function to apply. Defaults to ReLU if not specified.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a convolutional layer with the specified configuration. The input shape is determined
    /// by the inputDepth, inputHeight, and inputWidth parameters, while the output shape is calculated based on
    /// these values along with the kernel size, stride, and padding. The kernels and biases are initialized with
    /// random values.
    /// </para>
    /// <para><b>For Beginners:</b> This setup method creates a new convolutional layer with specific settings.
    /// 
    /// When creating the layer, you specify:
    /// - Input details: How many channels and the dimensions of your data
    /// - How many patterns to look for (outputDepth)
    /// - How big each pattern detector is (kernelSize)
    /// - How to move the detector across the data (stride)
    /// - Whether to add an extra border (padding)
    /// - What mathematical function to apply to the results (activation)
    /// 
    /// The layer then creates all the necessary pattern detectors with random starting values
    /// that will be improved during training.
    /// </para>
    /// </remarks>
    public ConvolutionalLayer(int inputDepth, int outputDepth, int kernelSize, int inputHeight, int inputWidth, int stride = 1, int padding = 0, 
                              IActivationFunction<T>? activation = null)
        : base(CalculateInputShape(inputDepth, inputHeight, inputWidth), 
               CalculateOutputShape(outputDepth, CalculateOutputDimension(inputHeight, kernelSize, stride, padding), 
                   CalculateOutputDimension(inputWidth, kernelSize, stride, padding)), activation ?? new ReLUActivation<T>())
    {
        InputDepth = inputDepth;
        OutputDepth = outputDepth;
        KernelSize = kernelSize;
        Stride = stride;
        Padding = padding;

        _kernels = new Tensor<T>([OutputDepth, InputDepth, KernelSize, KernelSize]);
        _biases = new Vector<T>(OutputDepth);
        _lastInput = new Tensor<T>([OutputDepth, InputDepth, KernelSize, KernelSize]);
        _lastOutput = new Tensor<T>([OutputDepth, InputDepth, KernelSize, KernelSize]);
        _random = new Random();

        InitializeWeights();
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="ConvolutionalLayer{T}"/> class with the specified parameters
    /// and a vector activation function.
    /// </summary>
    /// <param name="inputDepth">The number of channels in the input data.</param>
    /// <param name="outputDepth">The number of filters (output channels) to create.</param>
    /// <param name="kernelSize">The size of each filter kernel (width and height).</param>
    /// <param name="inputHeight">The height of the input data.</param>
    /// <param name="inputWidth">The width of the input data.</param>
    /// <param name="stride">The step size for moving the kernel. Defaults to 1.</param>
    /// <param name="padding">The amount of zero-padding to add around the input. Defaults to 0.</param>
    /// <param name="vectorActivation">The vector activation function to apply. Defaults to ReLU if not specified.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a convolutional layer with the specified configuration and a vector activation function,
    /// which operates on entire vectors rather than individual elements. This can be useful when applying more complex
    /// activation functions or when performance is a concern.
    /// </para>
    /// <para><b>For Beginners:</b> This setup method is similar to the previous one, but uses a different type of
    /// activation function.
    /// 
    /// A vector activation function:
    /// - Works on entire groups of numbers at once
    /// - Can be more efficient for certain types of calculations
    /// - Otherwise works the same as the regular activation function
    /// 
    /// You would choose this option if you have a specific mathematical operation that
    /// needs to be applied to groups of outputs rather than individual values.
    /// </para>
    /// </remarks>
    public ConvolutionalLayer(int inputDepth, int outputDepth, int kernelSize, int inputHeight, int inputWidth, int stride = 1, int padding = 0, 
                              IVectorActivationFunction<T>? vectorActivation = null)
        : base(CalculateInputShape(inputDepth, inputHeight, inputWidth), 
               CalculateOutputShape(outputDepth, CalculateOutputDimension(inputHeight, kernelSize, stride, padding), 
                   CalculateOutputDimension(inputWidth, kernelSize, stride, padding)), vectorActivation ?? new ReLUActivation<T>())
    {
        InputDepth = inputDepth;
        OutputDepth = outputDepth;
        KernelSize = kernelSize;
        Stride = stride;
        Padding = padding;

        _kernels = new Tensor<T>([OutputDepth, InputDepth, KernelSize, KernelSize]);
        _biases = new Vector<T>(OutputDepth);
        _lastInput = new Tensor<T>([OutputDepth, InputDepth, KernelSize, KernelSize]);
        _lastOutput = new Tensor<T>([OutputDepth, InputDepth, KernelSize, KernelSize]);
        _random = new Random();

        InitializeWeights();
    }

    /// <summary>
    /// Creates a convolutional layer with the specified configuration using a fluent interface.
    /// </summary>
    /// <param name="inputShape">The shape of the input data as [depth, height, width].</param>
    /// <param name="kernelSize">The size of each filter kernel (width and height).</param>
    /// <param name="numberOfFilters">The number of filters (output channels) to create.</param>
    /// <param name="stride">The step size for moving the kernel. Defaults to 1.</param>
    /// <param name="padding">The amount of zero-padding to add around the input. Defaults to 0.</param>
    /// <param name="activation">The activation function to apply. Defaults to ReLU if not specified.</param>
    /// <returns>A new instance of the <see cref="ConvolutionalLayer{T}"/> class.</returns>
    /// <exception cref="ArgumentException">Thrown when the input shape does not have exactly 3 dimensions.</exception>
    /// <remarks>
    /// <para>
    /// This static method provides a more convenient way to create a convolutional layer by specifying the input shape
    /// as an array rather than individual dimensions. It extracts the depth, height, and width from the input shape
    /// array and passes them to the constructor.
    /// </para>
    /// <para><b>For Beginners:</b> This is a simpler way to create a convolutional layer when you already know
    /// your input data's shape.
    /// 
    /// Instead of providing separate numbers for depth, height, and width, you can:
    /// - Pass all three dimensions in a single array
    /// - Specify the other settings in a more intuitive way
    /// 
    /// For example, if your input is 3-channel images that are 28�28 pixels:
    /// - You would use inputShape = [3, 28, 28]
    /// - Rather than listing all dimensions separately
    /// 
    /// This makes your code cleaner and easier to read.
    /// </para>
    /// </remarks>
    public static ConvolutionalLayer<T> Configure(int[] inputShape, int kernelSize, int numberOfFilters, int stride = 1, int padding = 0, 
        IActivationFunction<T>? activation = null)
    {
        if (inputShape.Length != 3)
        {
            throw new ArgumentException("Input shape must have 3 dimensions: depth, height, width");
        }

        int inputDepth = inputShape[0];
        int inputHeight = inputShape[1];
        int inputWidth = inputShape[2];

        return new ConvolutionalLayer<T>(
            inputDepth: inputDepth,
            outputDepth: numberOfFilters,
            kernelSize: kernelSize,
            inputHeight: inputHeight,
            inputWidth: inputWidth,
            stride: stride,
            padding: padding,
            activation: activation
        );
    }

    /// <summary>
    /// Creates a convolutional layer with the specified configuration and a vector activation function using a fluent interface.
    /// </summary>
    /// <param name="inputShape">The shape of the input data as [depth, height, width].</param>
    /// <param name="kernelSize">The size of each filter kernel (width and height).</param>
    /// <param name="numberOfFilters">The number of filters (output channels) to create.</param>
    /// <param name="stride">The step size for moving the kernel. Defaults to 1.</param>
    /// <param name="padding">The amount of zero-padding to add around the input. Defaults to 0.</param>
    /// <param name="vectorActivation">The vector activation function to apply. Defaults to ReLU if not specified.</param>
    /// <returns>A new instance of the <see cref="ConvolutionalLayer{T}"/> class with a vector activation function.</returns>
    /// <exception cref="ArgumentException">Thrown when the input shape does not have exactly 3 dimensions.</exception>
    /// <remarks>
    /// <para>
    /// This static method provides a more convenient way to create a convolutional layer with a vector activation function
    /// by specifying the input shape as an array rather than individual dimensions. It is similar to the Configure method
    /// with a scalar activation function, but uses a vector activation function instead.
    /// </para>
    /// <para><b>For Beginners:</b> This is similar to the previous Configure method, but uses a vector activation function.
    /// 
    /// This method:
    /// - Makes it easier to create a layer with an input shape array
    /// - Uses a vector activation function (works on groups of numbers)
    /// - Is otherwise identical to the previous Configure method
    /// 
    /// You would choose this if you need a specific type of mathematical operation
    /// applied to groups of values rather than individual numbers.
    /// </para>
    /// </remarks>
    public static ConvolutionalLayer<T> Configure(int[] inputShape, int kernelSize, int numberOfFilters, int stride = 1, int padding = 0, 
        IVectorActivationFunction<T>? vectorActivation = null)
    {
        if (inputShape.Length != 3)
        {
            throw new ArgumentException("Input shape must have 3 dimensions: depth, height, width");
        }

        int inputDepth = inputShape[0];
        int inputHeight = inputShape[1];
        int inputWidth = inputShape[2];

        return new ConvolutionalLayer<T>(
            inputDepth: inputDepth,
            outputDepth: numberOfFilters,
            kernelSize: kernelSize,
            inputHeight: inputHeight,
            inputWidth: inputWidth,
            stride: stride,
            padding: padding,
            vectorActivation: vectorActivation
        );
    }

    /// <summary>
    /// Saves the layer's configuration and parameters to a binary writer.
    /// </summary>
    /// <param name="writer">The binary writer to save to.</param>
    /// <remarks>
    /// <para>
    /// This method saves the layer's configuration (input depth, output depth, kernel size, stride, padding)
    /// and parameters (kernel weights and biases) to a binary writer. This allows the layer to be saved to
    /// a file and loaded later.
    /// </para>
    /// <para><b>For Beginners:</b> This method saves all the layer's settings and learned patterns to a file.
    /// 
    /// When saving a layer:
    /// - First, it saves the basic configuration (size, stride, etc.)
    /// - Then it saves all the learned pattern detectors (kernels)
    /// - Finally, it saves the bias values
    /// 
    /// This allows you to:
    /// - Save a trained model to use later
    /// - Share your trained model with others
    /// - Store multiple versions of your model
    /// 
    /// Think of it like taking a snapshot of everything the model has learned.
    /// </para>
    /// </remarks>
    public override void Serialize(BinaryWriter writer)
    {
        base.Serialize(writer);
        writer.Write(InputDepth);
        writer.Write(OutputDepth);
        writer.Write(KernelSize);
        writer.Write(Stride);
        writer.Write(Padding);
    
        // Serialize _kernels
        for (int i = 0; i < _kernels.Shape[0]; i++)
        {
            for (int j = 0; j < _kernels.Shape[1]; j++)
            {
                for (int k = 0; k < _kernels.Shape[2]; k++)
                {
                    for (int l = 0; l < _kernels.Shape[3]; l++)
                    {
                        writer.Write(Convert.ToDouble(_kernels[i, j, k, l]));
                    }
                }
            }
        }

        // Serialize _biases
        for (int i = 0; i < _biases.Length; i++)
        {
            writer.Write(Convert.ToDouble(_biases[i]));
        }
    }

    /// <summary>
    /// Loads the layer's configuration and parameters from a binary reader.
    /// </summary>
    /// <param name="reader">The binary reader to load from.</param>
    /// <remarks>
    /// <para>
    /// This method loads the layer's configuration (input depth, output depth, kernel size, stride, padding)
    /// and parameters (kernel weights and biases) from a binary reader. This allows a previously saved layer
    /// to be loaded from a file.
    /// </para>
    /// <para><b>For Beginners:</b> This method loads a previously saved layer from a file.
    /// 
    /// When loading a layer:
    /// - First, it reads the basic configuration
    /// - Then it recreates all the pattern detectors (kernels)
    /// - Finally, it loads the bias values
    /// 
    /// This allows you to:
    /// - Continue using a model you trained earlier
    /// - Use a model someone else trained
    /// - Compare different versions of your model
    /// 
    /// It's like restoring a snapshot of a trained model exactly as it was.
    /// </para>
    /// </remarks>
    public override void Deserialize(BinaryReader reader)
    {
        base.Deserialize(reader);
        InputDepth = reader.ReadInt32();
        OutputDepth = reader.ReadInt32();
        KernelSize = reader.ReadInt32();
        Stride = reader.ReadInt32();
        Padding = reader.ReadInt32();

        // Deserialize _kernels
        _kernels = new Tensor<T>([OutputDepth, InputDepth, KernelSize, KernelSize]);
        for (int i = 0; i < _kernels.Shape[0]; i++)
        {
            for (int j = 0; j < _kernels.Shape[1]; j++)
            {
                for (int k = 0; k < _kernels.Shape[2]; k++)
                {
                    for (int l = 0; l < _kernels.Shape[3]; l++)
                    {
                        double value = reader.ReadDouble();
                        _kernels[i, j, k, l] = NumOps.FromDouble(value);
                    }
                }
            }
        }

        // Deserialize _biases
        _biases = new Vector<T>(OutputDepth);
        for (int i = 0; i < _biases.Length; i++)
        {
            double value = reader.ReadDouble();
            _biases[i] = NumOps.FromDouble(value);
        }

        // Reinitialize _lastInput and _lastOutput
        _lastInput = new Tensor<T>([OutputDepth, InputDepth, KernelSize, KernelSize]);
        _lastOutput = new Tensor<T>([OutputDepth, InputDepth, KernelSize, KernelSize]);
    }

    /// <summary>
    /// Calculates the output dimension after applying a convolution operation.
    /// </summary>
    /// <param name="inputDim">The input dimension (height or width).</param>
    /// <param name="kernelSize">The size of the kernel (filter).</param>
    /// <param name="stride">The stride (step size) of the convolution.</param>
    /// <param name="padding">The amount of padding added to the input.</param>
    /// <returns>The calculated output dimension.</returns>
    /// <remarks>
    /// <para>
    /// This method calculates the output dimension (height or width) after applying a convolution operation
    /// with the specified parameters. The formula used is (inputDim - kernelSize + 2 * padding) / stride + 1.
    /// </para>
    /// <para><b>For Beginners:</b> This calculates how big the output will be after applying the layer.
    /// 
    /// The output size depends on:
    /// - How big your input is
    /// - How big your pattern detector (kernel) is
    /// - How much you move the detector each step (stride)
    /// - How much extra border you add (padding)
    /// 
    /// Generally:
    /// - Larger stride = smaller output
    /// - More padding = larger output
    /// - Larger kernel = smaller output
    /// 
    /// This method uses a standard formula to calculate the exact output size.
    /// </para>
    /// </remarks>
    private static int CalculateOutputDimension(int inputDim, int kernelSize, int stride, int padding)
    {
        return (inputDim - kernelSize + 2 * padding) / stride + 1;
    }

    /// <summary>
    /// Initializes the kernel weights and biases with random values.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method initializes the kernel weights using the He initialization method, which scales the random
    /// values based on the number of input and output connections. This helps improve training convergence.
    /// The biases are initialized to zero.
    /// </para>
    /// <para><b>For Beginners:</b> This method sets up the starting values for the pattern detectors.
    /// 
    /// When initializing weights:
    /// - Random values are created for each pattern detector
    /// - The values are carefully scaled to work well for training
    /// - _biases start at zero
    /// 
    /// Good initialization is important because:
    /// - It helps the network learn faster
    /// - It prevents certain mathematical problems during training
    /// - It gives each pattern detector a different starting point
    /// 
    /// This uses a technique called "He initialization" which works well
    /// with modern neural networks.
    /// </para>
    /// </remarks>
    private void InitializeWeights()
    {
        T scale = NumOps.Sqrt(NumOps.FromDouble(2.0 / (InputDepth * KernelSize * KernelSize + OutputDepth)));
    
        for (int i = 0; i < OutputDepth; i++)
        {
            for (int j = 0; j < InputDepth; j++)
            {
                for (int k = 0; k < KernelSize; k++)
                {
                    for (int l = 0; l < KernelSize; l++)
                        {
                        _kernels[i, j, k, l] = NumOps.Multiply(scale, NumOps.FromDouble(Random.NextDouble() * 2 - 1));
                    }
                }
            }

            _biases[i] = NumOps.Zero;
        }
    }

    /// <summary>
    /// Processes the input data through the convolutional layer.
    /// </summary>
    /// <param name="input">The input tensor to process, with shape [batchSize, inputDepth, height, width].</param>
    /// <returns>The output tensor after convolution and activation, with shape [batchSize, outputDepth, outputHeight, outputWidth].</returns>
    /// <remarks>
    /// <para>
    /// This method performs the forward pass of the convolutional layer. For each position of the kernel on the
    /// input data, it computes the element-wise product of the kernel weights and the corresponding input values,
    /// sums the results, adds the bias, and applies the activation function. The result is a tensor where each
    /// channel represents the activation of a different filter.
    /// </para>
    /// <para><b>For Beginners:</b> This method applies the pattern detectors to your input data.
    /// 
    /// During the forward pass:
    /// - Each pattern detector (kernel) slides across the input
    /// - At each position, it looks for its specific pattern
    /// - If it finds a match, it produces a high value in the output
    /// - The activation function then adjusts these values
    /// 
    /// Think of it like a series of spotlights scanning across your data,
    /// each one lighting up when it finds the pattern it's looking for.
    /// The result shows where each pattern was found in the input.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        _lastInput = input;
        int batchSize = input.Shape[0];
        int inputHeight = input.Shape[2];
        int inputWidth = input.Shape[3];
        int outputHeight = (inputHeight - KernelSize + 2 * Padding) / Stride + 1;
        int outputWidth = (inputWidth - KernelSize + 2 * Padding) / Stride + 1;

        Tensor<T> output = new Tensor<T>([batchSize, OutputDepth, outputHeight, outputWidth]);

        for (int b = 0; b < batchSize; b++)
        {
            for (int o = 0; o < OutputDepth; o++)
            {
                for (int y = 0; y < outputHeight; y++)
                {
                    for (int x = 0; x < outputWidth; x++)
                    {
                        T sum = _biases[o];
                        for (int i = 0; i < InputDepth; i++)
                        {
                            for (int ky = 0; ky < KernelSize; ky++)
                            {
                                for (int kx = 0; kx < KernelSize; kx++)
                                {
                                    int inputY = y * Stride + ky - Padding;
                                    int inputX = x * Stride + kx - Padding;
                                    if (inputY >= 0 && inputY < inputHeight && inputX >= 0 && inputX < inputWidth)
                                    {
                                        sum = NumOps.Add(sum, NumOps.Multiply(input[b, i, inputY, inputX], _kernels[o, i, ky, kx]));
                                    }
                                }
                            }
                        }

                        output[b, o, y, x] = sum;
                    }
                }
            }
        }

        _lastOutput = ApplyActivation(output);
        return _lastOutput;
    }

    /// <summary>
    /// Calculates gradients for the input, kernels, and biases during backpropagation.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's input.</returns>
    /// <remarks>
    /// <para>
    /// This method performs the backward pass of the convolutional layer during training. It calculates
    /// the gradient of the loss with respect to the input, kernel weights, and biases, and updates the
    /// weights and biases accordingly. The calculated input gradient is returned for propagation to
    /// earlier layers.
    /// </para>
    /// <para><b>For Beginners:</b> This method helps the layer learn from its mistakes.
    /// 
    /// During the backward pass:
    /// - The layer receives information about how wrong its output was
    /// - It calculates how to adjust its pattern detectors to be more accurate
    /// - It updates the kernels and biases to improve future predictions
    /// - It passes information back to previous layers so they can learn too
    /// 
    /// This is where the actual "learning" happens in the neural network.
    /// The layer gradually improves its pattern recognition based on feedback
    /// about its performance.
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        Tensor<T> activationGradient = ApplyActivationDerivative(_lastOutput, outputGradient);
        outputGradient = Tensor<T>.ElementwiseMultiply(outputGradient, activationGradient);

        int batchSize = _lastInput.Shape[0];
        int inputHeight = _lastInput.Shape[2];
        int inputWidth = _lastInput.Shape[3];
        int outputHeight = outputGradient.Shape[2];
        int outputWidth = outputGradient.Shape[3];

        Tensor<T> inputGradient = new Tensor<T>(_lastInput.Shape);
        Tensor<T> kernelGradients = new Tensor<T>(_kernels.Shape);
        Vector<T> biasGradients = new Vector<T>(OutputDepth);

        for (int b = 0; b < batchSize; b++)
        {
            for (int o = 0; o < OutputDepth; o++)
            {
                for (int y = 0; y < outputHeight; y++)
                {
                    for (int x = 0; x < outputWidth; x++)
                    {
                        T outputGrad = outputGradient[b, o, y, x];
                        biasGradients[o] = NumOps.Add(biasGradients[o], outputGrad);

                        for (int i = 0; i < InputDepth; i++)
                        {
                            for (int ky = 0; ky < KernelSize; ky++)
                            {
                                for (int kx = 0; kx < KernelSize; kx++)
                                {
                                    int inputY = y * Stride + ky - Padding;
                                    int inputX = x * Stride + kx - Padding;
                                    if (inputY >= 0 && inputY < inputHeight && inputX >= 0 && inputX < inputWidth)
                                    {
                                        T inputValue = _lastInput[b, i, inputY, inputX];
                                        kernelGradients[o, i, ky, kx] = NumOps.Add(kernelGradients[o, i, ky, kx], NumOps.Multiply(outputGrad, inputValue));
                                        inputGradient[b, i, inputY, inputX] = NumOps.Add(inputGradient[b, i, inputY, inputX], NumOps.Multiply(outputGrad, _kernels[o, i, ky, kx]));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Update kernels and biases
        for (int i = 0; i < _kernels.Length; i++)
        {
            _kernels[i] = NumOps.Subtract(_kernels[i], NumOps.Multiply(NumOps.FromDouble(0.01), kernelGradients[i])); // Learning rate of 0.01
        }

        for (int i = 0; i < _biases.Length; i++)
        {
            _biases[i] = NumOps.Subtract(_biases[i], NumOps.Multiply(NumOps.FromDouble(0.01), biasGradients[i])); // Learning rate of 0.01
        }

        return inputGradient;
    }

    /// <summary>
    /// Updates the layer's parameters (kernel weights and biases) using the specified learning rate.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the update.</param>
    /// <remarks>
    /// <para>
    /// This method updates the layer's parameters (kernel weights and biases) based on the gradients
    /// calculated during the backward pass. The learning rate controls the step size of the update,
    /// with a smaller learning rate resulting in smaller, more cautious updates.
    /// </para>
    /// <para><b>For Beginners:</b> This method applies the lessons learned during training.
    /// 
    /// When updating parameters:
    /// - The learning rate controls how big each adjustment is
    /// - Small learning rate = small, careful changes
    /// - Large learning rate = big, faster changes (but might overshoot)
    /// 
    /// Think of it like adjusting your position in a game:
    /// - If you're far from the target, you might take big steps
    /// - As you get closer, you take smaller, more precise steps
    /// 
    /// The learning rate helps balance between learning quickly and learning accurately.
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        // Update kernels
        for (int o = 0; o < OutputDepth; o++)
        {
            for (int i = 0; i < InputDepth; i++)
            {
                for (int ky = 0; ky < KernelSize; ky++)
                {
                    for (int kx = 0; kx < KernelSize; kx++)
                    {
                        T update = NumOps.Multiply(learningRate, _kernels[o, i, ky, kx]);
                        _kernels[o, i, ky, kx] = NumOps.Subtract(_kernels[o, i, ky, kx], update);
                    }
                }
            }
        }

        // Update biases
        for (int o = 0; o < OutputDepth; o++)
        {
            T update = NumOps.Multiply(learningRate, _biases[o]);
            _biases[o] = NumOps.Subtract(_biases[o], update);
        }
    }

    /// <summary>
    /// Gets all trainable parameters of the layer as a single vector.
    /// </summary>
    /// <returns>A vector containing all kernel weights and biases.</returns>
    /// <remarks>
    /// <para>
    /// This method extracts all trainable parameters (kernel weights and biases) from the layer
    /// and returns them as a single vector. This is useful for optimization algorithms that operate
    /// on all parameters at once, or for saving and loading model weights.
    /// </para>
    /// <para><b>For Beginners:</b> This method gathers all the learned values from the layer.
    /// 
    /// The parameters include:
    /// - All values from all pattern detectors (kernels)
    /// - All bias values
    /// 
    /// These are combined into a single long list (vector), which can be used for:
    /// - Saving the model
    /// - Sharing parameters between layers
    /// - Advanced optimization techniques
    /// 
    /// This provides access to all the "knowledge" the layer has learned.
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // Calculate total number of parameters
        int totalParams = _kernels.Length + _biases.Length;
        var parameters = new Vector<T>(totalParams);
    
        int index = 0;
    
        // Copy kernel parameters
        for (int o = 0; o < OutputDepth; o++)
        {
            for (int i = 0; i < InputDepth; i++)
            {
                for (int ky = 0; ky < KernelSize; ky++)
                {
                    for (int kx = 0; kx < KernelSize; kx++)
                    {
                        parameters[index++] = _kernels[o, i, ky, kx];
                    }
                }
            }
        }
    
        // Copy bias parameters
        for (int o = 0; o < OutputDepth; o++)
        {
            parameters[index++] = _biases[o];
        }
    
        return parameters;
    }

    /// <summary>
    /// Sets all trainable parameters of the layer from a single vector.
    /// </summary>
    /// <param name="parameters">A vector containing all parameters to set.</param>
    /// <exception cref="ArgumentException">Thrown when the parameters vector has incorrect length.</exception>
    /// <remarks>
    /// <para>
    /// This method sets all trainable parameters (kernel weights and biases) of the layer from a single
    /// vector. The vector must have the exact length required for all parameters of the layer.
    /// </para>
    /// <para><b>For Beginners:</b> This method updates all the layer's learned values at once.
    /// 
    /// When setting parameters:
    /// - The vector must have exactly the right number of values
    /// - The values are assigned to the kernels and biases in a specific order
    /// 
    /// This is useful for:
    /// - Loading a previously saved model
    /// - Copying parameters from another model
    /// - Setting parameters that were optimized externally
    /// 
    /// It's like replacing all the "knowledge" in the layer with new information.
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
        for (int o = 0; o < OutputDepth; o++)
        {
            for (int i = 0; i < InputDepth; i++)
            {
                for (int ky = 0; ky < KernelSize; ky++)
                {
                    for (int kx = 0; kx < KernelSize; kx++)
                    {
                        _kernels[o, i, ky, kx] = parameters[index++];
                    }
                }
            }
        }
    
        // Set bias parameters
        for (int o = 0; o < OutputDepth; o++)
        {
            _biases[o] = parameters[index++];
        }
    }

    /// <summary>
    /// Resets the internal state of the layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method clears the cached input and output values from the most recent forward pass.
    /// This is useful when starting to process a new sequence or when implementing stateful layers.
    /// </para>
    /// <para><b>For Beginners:</b> This method clears the layer's memory to start fresh.
    /// 
    /// When resetting the state:
    /// - The layer forgets the last input it processed
    /// - It forgets the last output it produced
    /// 
    /// This is useful for:
    /// - Processing a new, unrelated set of data
    /// - Preventing information from one batch affecting another
    /// - Starting a new training episode
    /// 
    /// Think of it like wiping a whiteboard clean before starting a new calculation.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // Clear cached values from forward pass
        _lastInput = new Tensor<T>([OutputDepth, InputDepth, KernelSize, KernelSize]);
        _lastOutput = new Tensor<T>([OutputDepth, InputDepth, KernelSize, KernelSize]);
    }
}