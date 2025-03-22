namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a flatten layer that reshapes multi-dimensional input data into a 1D vector.
/// </summary>
/// <remarks>
/// <para>
/// A flatten layer transforms multi-dimensional input data (such as images or feature maps) into a one-dimensional
/// vector. This is often necessary when transitioning from convolutional layers to fully connected layers
/// in a neural network. The flatten operation preserves all values and their order, just changing the way
/// they are arranged from a multi-dimensional tensor to a single vector.
/// </para>
/// <para><b>For Beginners:</b> A flatten layer converts multi-dimensional data into a simple list of numbers.
/// 
/// Imagine you have a 2D grid of numbers (like a small image):
/// ```
/// [
///   [1, 2, 3],
///   [4, 5, 6]
/// ]
/// ```
/// 
/// The flatten layer turns this into a single row:
/// ```
/// [1, 2, 3, 4, 5, 6]
/// ```
/// 
/// This transformation is needed because:
/// - Convolutional layers work with 2D or 3D data (like images)
/// - Fully connected layers expect a simple list of numbers
/// - Flatten layers bridge these two types of layers
/// 
/// Think of it like taking a book (a 3D object with pages) and reading all the text 
/// in order from beginning to end (a 1D sequence). All the information is preserved,
/// but it's rearranged into a different shape.
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class FlattenLayer<T> : LayerBase<T>
{
    /// <summary>
    /// The shape of the input tensor.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This array stores the dimensions of the input tensor (excluding the batch dimension).
    /// It is used during the forward and backward passes to correctly flatten and unflatten the tensors.
    /// </para>
    /// <para><b>For Beginners:</b> This remembers the original shape of the input data.
    /// 
    /// For example:
    /// - For a 28�28 grayscale image: [28, 28, 1]
    /// - For RGB color channels: [height, width, 3]
    /// - For a feature map with multiple channels: [height, width, channels]
    /// 
    /// The layer needs to store this original shape:
    /// - To correctly convert multi-dimensional data to a flat vector
    /// - To convert gradients back to the original shape during training
    /// 
    /// It's like keeping a map of how the data was originally organized so you
    /// can "unfold" it in exactly the same way later.
    /// </para>
    /// </remarks>
    private int[] _inputShape;

    /// <summary>
    /// The size of the output vector.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field stores the total size of the flattened output vector, which is the product of all
    /// dimensions in the input shape. It represents the number of elements in the input tensor
    /// for a single example.
    /// </para>
    /// <para><b>For Beginners:</b> This is the total number of values after flattening.
    /// 
    /// The output size is calculated by multiplying all the dimensions of the input:
    /// - For a 28�28 image: 28 � 28 = 784 values
    /// - For a 16�16�32 feature map: 16 � 16 � 32 = 8,192 values
    /// 
    /// This number tells us:
    /// - How long the flattened vector will be
    /// - How many neurons the next layer (usually a fully connected layer) will receive
    /// 
    /// Pre-calculating this size makes processing more efficient.
    /// </para>
    /// </remarks>
    private int _outputSize;

    /// <summary>
    /// The input tensor from the last forward pass, saved for backpropagation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This tensor stores the input received during the last forward pass. It is necessary
    /// for computing gradients during the backward pass, as it provides information about
    /// the original shape of the data.
    /// </para>
    /// <para><b>For Beginners:</b> This remembers what input data was processed most recently.
    /// 
    /// During training:
    /// - The layer needs to remember the shape and organization of its input
    /// - This helps when calculating how to send gradients back to previous layers
    /// - Without this information, the layer couldn't "unflatten" the gradients correctly
    /// 
    /// This is automatically cleared between training batches to save memory.
    /// </para>
    /// </remarks>
    private Tensor<T>? _lastInput;

    /// <summary>
    /// Gets a value indicating whether this layer supports training.
    /// </summary>
    /// <value>
    /// Always <c>false</c> because flatten layers have no trainable parameters.
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates that the flatten layer does not have any trainable parameters.
    /// The layer simply performs a reshape operation and does not learn during training.
    /// However, it still participates in backpropagation by passing gradients back to previous
    /// layers in the correct shape.
    /// </para>
    /// <para><b>For Beginners:</b> This property tells you that this layer doesn't learn or change during training.
    /// 
    /// A value of false means:
    /// - The layer has no weights or biases to adjust
    /// - It performs the same operation regardless of training
    /// - It's a fixed transformation layer, not a learning layer
    /// 
    /// Unlike convolutional or fully connected layers (which learn patterns from data),
    /// the flatten layer just reorganizes data without changing its content.
    /// 
    /// It's like rearranging furniture in a room - you're not adding or removing
    /// anything, just changing how it's organized.
    /// </para>
    /// </remarks>
    public override bool SupportsTraining => false;

    /// <summary>
    /// Initializes a new instance of the <see cref="FlattenLayer{T}"/> class.
    /// </summary>
    /// <param name="inputShape">The shape of the input tensor (excluding the batch dimension).</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a new flatten layer that will reshape input data with the specified shape
    /// into a one-dimensional vector. The output size is calculated as the product of all dimensions in
    /// the input shape. The layer expects input tensors with shape [batchSize, ...inputShape].
    /// </para>
    /// <para><b>For Beginners:</b> This sets up the flatten layer by specifying what shape of data it will receive.
    /// 
    /// When creating a flatten layer, you need to specify:
    /// - The dimensions of your input data (not counting the batch size)
    /// 
    /// For example:
    /// ```csharp
    /// // Create a flatten layer for 28�28 grayscale images
    /// var flattenLayer = new FlattenLayer<float>(new int[] { 28, 28, 1 });
    /// 
    /// // Create a flatten layer for output from a convolutional layer with 64 feature maps of size 7�7
    /// var flattenConvOutput = new FlattenLayer<float>(new int[] { 7, 7, 64 });
    /// ```
    /// 
    /// The constructor automatically calculates how large the output vector will be
    /// by multiplying all the dimensions together.
    /// </para>
    /// </remarks>
    public FlattenLayer(int[] inputShape)
        : base(inputShape, [inputShape.Aggregate(1, (a, b) => a * b)])
    {
        _inputShape = inputShape;
        _outputSize = inputShape.Aggregate(1, (a, b) => a * b);
    }

    /// <summary>
    /// Performs the forward pass of the flatten layer, reshaping multi-dimensional data into a vector.
    /// </summary>
    /// <param name="input">The input tensor to flatten. Shape: [batchSize, ...inputShape].</param>
    /// <returns>The flattened output tensor. Shape: [batchSize, outputSize].</returns>
    /// <remarks>
    /// <para>
    /// This method implements the forward pass of the flatten layer. It takes a multi-dimensional tensor
    /// and reshapes it into a 2D tensor where each row corresponds to a flattened example from the batch.
    /// The values are preserved and their order is maintained according to a row-major traversal of the
    /// input tensor. The input tensor is cached for use during the backward pass.
    /// </para>
    /// <para><b>For Beginners:</b> This method converts multi-dimensional data into simple vectors.
    /// 
    /// The forward pass works like this:
    /// 1. Take multi-dimensional input (like a 3D image)
    /// 2. For each example in the batch:
    ///    - Go through all positions in the multi-dimensional input
    ///    - Place each value into the corresponding position in a flat vector
    /// 3. Return a tensor with shape [batchSize, flattenedSize]
    /// 
    /// For example, with a batch of 3D data like [batchSize, height, width, channels]:
    /// - Input shape: [32, 7, 7, 64] (32 examples, each 7�7 with 64 channels)
    /// - Output shape: [32, 3136] (32 examples, each with 7�7�64=3136 values)
    /// 
    /// The method carefully preserves the order of values so they can be
    /// "unflattened" back to the original shape during backpropagation.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        _lastInput = input;
        int batchSize = input.Shape[0];
        var output = new Tensor<T>([batchSize, _outputSize]);
        for (int i = 0; i < batchSize; i++)
        {
            int flatIndex = 0;
            FlattenRecursive(input, i, new int[_inputShape.Length], ref flatIndex, output);
        }
        return output;
    }

    /// <summary>
    /// Recursively flattens a multi-dimensional tensor into a 1D vector.
    /// </summary>
    /// <param name="input">The input tensor to flatten.</param>
    /// <param name="batchIndex">The index of the current batch example.</param>
    /// <param name="indices">The current indices in the multi-dimensional tensor.</param>
    /// <param name="flatIndex">Reference to the current index in the flattened output.</param>
    /// <param name="output">The output tensor to store the flattened values.</param>
    /// <remarks>
    /// <para>
    /// This helper method recursively traverses the multi-dimensional input tensor and copies each value
    /// to the corresponding position in the flattened output tensor. It uses a depth-first traversal
    /// strategy to maintain a consistent ordering of the elements.
    /// </para>
    /// <para><b>For Beginners:</b> This helper method walks through all positions in the multi-dimensional input.
    /// 
    /// The method works like this:
    /// - It visits every position in the multi-dimensional input one by one
    /// - For each position, it copies the value to the flattened output
    /// - It uses recursion (a function calling itself) to handle any number of dimensions
    /// 
    /// Think of it like reading a book:
    /// - You read page by page, line by line, word by word
    /// - The method does the same with multi-dimensional data
    /// - It follows a specific order (like left-to-right, top-to-bottom) to ensure consistency
    /// 
    /// This organized traversal ensures that when we need to "unflatten" during
    /// backpropagation, we know exactly where each value should go.
    /// </para>
    /// </remarks>
    private void FlattenRecursive(Tensor<T> input, int batchIndex, int[] indices, ref int flatIndex, Tensor<T> output)
    {
        if (indices.Length == _inputShape.Length)
        {
            output[batchIndex, flatIndex++] = input[new int[] { batchIndex }.Concat(indices).ToArray()];
            return;
        }
        for (int i = 0; i < _inputShape[indices.Length]; i++)
        {
            indices[indices.Length - 1] = i;
            FlattenRecursive(input, batchIndex, indices, ref flatIndex, output);
        }
    }

    /// <summary>
    /// Performs the backward pass of the flatten layer, reshaping gradients back to the original input shape.
    /// </summary>
    /// <param name="outputGradient">The gradient tensor from the next layer. Shape: [batchSize, outputSize].</param>
    /// <returns>The gradient tensor reshaped to the original input shape. Shape: [batchSize, ...inputShape].</returns>
    /// <exception cref="InvalidOperationException">Thrown when backward is called before forward.</exception>
    /// <remarks>
    /// <para>
    /// This method implements the backward pass (backpropagation) of the flatten layer. It takes the gradient
    /// tensor from the next layer, which is a 2D tensor with flattened gradients, and reshapes it back to
    /// the original input shape. This allows the gradients to flow back to previous layers with the correct shape.
    /// </para>
    /// <para><b>For Beginners:</b> This method converts the flat gradients back to the original multi-dimensional shape.
    /// 
    /// During the backward pass:
    /// 1. Take the gradient vector from the next layer
    /// 2. For each example in the batch:
    ///    - Go through all positions in the flat gradient vector
    ///    - Place each value back into the corresponding position in a multi-dimensional tensor
    /// 3. Return a gradient tensor with the same shape as the original input
    /// 
    /// This "unflattening" is essential because:
    /// - Previous layers (like convolutional layers) expect gradients in multi-dimensional form
    /// - Each gradient value needs to go back to its original position
    /// - The layer must maintain the exact inverse mapping of the forward pass
    /// 
    /// It's like taking a long string of text and reformatting it back into pages,
    /// paragraphs, and lines of a book.
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        if (_lastInput == null)
            throw new InvalidOperationException("Forward pass must be called before backward pass.");
        var inputGradient = new Tensor<T>(_lastInput.Shape);
        int batchSize = outputGradient.Shape[0];
        for (int i = 0; i < batchSize; i++)
        {
            int flatIndex = 0;
            UnflattenRecursive(outputGradient, i, new int[_inputShape.Length], ref flatIndex, inputGradient);
        }
        return inputGradient;
    }

    /// <summary>
    /// Recursively unflattens a 1D vector into a multi-dimensional tensor.
    /// </summary>
    /// <param name="outputGradient">The output gradient tensor to unflatten.</param>
    /// <param name="batchIndex">The index of the current batch example.</param>
    /// <param name="indices">The current indices in the multi-dimensional tensor.</param>
    /// <param name="flatIndex">Reference to the current index in the flattened gradient.</param>
    /// <param name="inputGradient">The input gradient tensor to store the unflattened values.</param>
    /// <remarks>
    /// <para>
    /// This helper method recursively traverses the flattened gradient tensor and copies each value
    /// back to the corresponding position in the multi-dimensional input gradient tensor. It uses
    /// the same traversal strategy as the flattening process to ensure consistency.
    /// </para>
    /// <para><b>For Beginners:</b> This helper method reverses the flattening process for gradients.
    /// 
    /// The method works like this:
    /// - It visits every position in the flattened gradient one by one
    /// - For each position, it copies the gradient value back to the multi-dimensional form
    /// - It follows the exact same path as the flattening process, but in reverse
    /// 
    /// Think of it like reassembling a puzzle:
    /// - Each piece (gradient value) has a specific place it needs to go
    /// - The method knows the exact location for each value based on the original flattening
    /// - It carefully places each value back where it belongs
    /// 
    /// This precise reconstruction ensures that gradient information flows correctly to earlier layers.
    /// </para>
    /// </remarks>
    private void UnflattenRecursive(Tensor<T> outputGradient, int batchIndex, int[] indices, ref int flatIndex, Tensor<T> inputGradient)
    {
        if (indices.Length == _inputShape.Length)
        {
            inputGradient[new int[] { batchIndex }.Concat(indices).ToArray()] = outputGradient[batchIndex, flatIndex++];
            return;
        }
        for (int i = 0; i < _inputShape[indices.Length]; i++)
        {
            indices[indices.Length - 1] = i;
            UnflattenRecursive(outputGradient, batchIndex, indices, ref flatIndex, inputGradient);
        }
    }

    /// <summary>
    /// Updates the parameters of the layer based on the calculated gradients.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for parameter updates.</param>
    /// <remarks>
    /// <para>
    /// This method is a required override from the base class, but the flatten layer has no
    /// trainable parameters to update, so it performs no operation.
    /// </para>
    /// <para><b>For Beginners:</b> This method does nothing for flatten layers because they have no adjustable weights.
    /// 
    /// Unlike most layers (like convolutional or fully connected layers):
    /// - Flatten layers don't have weights or biases to learn
    /// - They just rearrange the data without modifying it
    /// - There's nothing to update during training
    /// 
    /// This method exists only to fulfill the requirements of the base layer class.
    /// The flatten layer participates in training by reorganizing activations and gradients,
    /// not by updating internal parameters.
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        // FlattenLayer has no parameters to update
    }

    /// <summary>
    /// Gets the trainable parameters of the layer.
    /// </summary>
    /// <returns>
    /// An empty vector since flatten layers have no trainable parameters.
    /// </returns>
    /// <remarks>
    /// <para>
    /// This method is a required override from the base class, but the flatten layer has no
    /// trainable parameters to retrieve, so it returns an empty vector.
    /// </para>
    /// <para><b>For Beginners:</b> This method returns an empty list because flatten layers have no learnable values.
    /// 
    /// Unlike layers with weights and biases:
    /// - Flatten layers don't have any parameters that change during training
    /// - They perform a fixed operation (reshaping) that doesn't involve learning
    /// - There are no values to save when storing a trained model
    /// 
    /// This method returns an empty vector, indicating there are no parameters to collect.
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // FlattenLayer has no trainable parameters
        return Vector<T>.Empty();
    }

    /// <summary>
    /// Resets the internal state of the layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method resets the internal state of the layer by clearing the cached input
    /// from the previous forward pass. This is useful when starting to process a new batch of
    /// data or when switching between training and inference modes.
    /// </para>
    /// <para><b>For Beginners:</b> This method clears the layer's memory to start fresh.
    /// 
    /// When resetting the state:
    /// - The saved input is cleared
    /// - The layer forgets the previous data it processed
    /// - This frees up memory and prepares for new data
    /// 
    /// This is typically called:
    /// - Between training batches
    /// - When switching from training to evaluation mode
    /// - When starting to process completely new data
    /// 
    /// It's like wiping a whiteboard clean before starting a new calculation.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // Clear cached values from forward pass
        _lastInput = null;
    }
}