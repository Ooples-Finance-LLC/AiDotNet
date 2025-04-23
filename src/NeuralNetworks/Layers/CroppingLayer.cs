namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a cropping layer that removes portions of input tensors from the edges.
/// </summary>
/// <remarks>
/// <para>
/// A cropping layer removes specified portions from the edges of an input tensor. This is useful for
/// removing border artifacts, adjusting dimensions between layers, or focusing on specific regions
/// of input data. The cropping can be applied differently to each dimension of the input.
/// </para>
/// <para><b>For Beginners:</b> A cropping layer cuts off the edges of your data.
///
/// Think of it like cropping a photo:
/// - You can trim different amounts from the top, bottom, left, and right
/// - The middle portion (the important part) is kept
/// - The trimmed edges are discarded
///
/// For example, in image processing:
/// - You might crop off padding added by previous layers
/// - You might focus on the central region where the important features are
/// - You might adjust the size to match what the next layer expects
///
/// Cropping layers are simple but useful for controlling exactly what part of the data
/// flows through your neural network.
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class CroppingLayer<T> : LayerBase<T>
{
    /// <summary>
    /// The amount to crop from the top of each dimension.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This array specifies how many elements to remove from the "top" of each dimension in the input tensor.
    /// The length of the array matches the number of dimensions in the input tensor.
    /// </para>
    /// <para><b>For Beginners:</b> This specifies how much to trim from the "top" or "beginning" of each dimension.
    /// 
    /// For image data (with dimensions [batch, height, width, channels]):
    /// - cropTop[0] would crop from the batch dimension (rarely used)
    /// - cropTop[1] would crop rows from the top of the image
    /// - cropTop[2] would crop columns from the left side of the image
    /// - cropTop[3] would crop from the channel dimension (rarely used)
    ///
    /// Think of it as cutting off the first few rows or columns from your data.
    /// </para>
    /// </remarks>
    private readonly int[] _cropTop;

    /// <summary>
    /// The amount to crop from the bottom of each dimension.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This array specifies how many elements to remove from the "bottom" of each dimension in the input tensor.
    /// The length of the array matches the number of dimensions in the input tensor.
    /// </para>
    /// <para><b>For Beginners:</b> This specifies how much to trim from the "bottom" or "end" of each dimension.
    /// 
    /// For image data (with dimensions [batch, height, width, channels]):
    /// - cropBottom[0] would crop from the batch dimension (rarely used)
    /// - cropBottom[1] would crop rows from the bottom of the image
    /// - cropBottom[2] would crop columns from the right side of the image
    /// - cropBottom[3] would crop from the channel dimension (rarely used)
    ///
    /// Think of it as cutting off the last few rows or columns from your data.
    /// </para>
    /// </remarks>
    private readonly int[] _cropBottom;

    /// <summary>
    /// The amount to crop from the left of each dimension.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This array specifies how many elements to remove from the "left" of each dimension in the input tensor.
    /// This parameter is typically used together with cropRight to crop along the width dimension.
    /// </para>
    /// <para><b>For Beginners:</b> This specifies how much to trim from the left side of your data.
    /// 
    /// For image data, this primarily affects the width dimension:
    /// - cropLeft[2] would crop columns from the left side of the image
    ///
    /// In many cases, cropLeft and cropRight are used together with cropTop and cropBottom
    /// to specify cropping on all sides of the data.
    /// </para>
    /// </remarks>
    private readonly int[] _cropLeft;

    /// <summary>
    /// The amount to crop from the right of each dimension.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This array specifies how many elements to remove from the "right" of each dimension in the input tensor.
    /// This parameter is typically used together with cropLeft to crop along the width dimension.
    /// </para>
    /// <para><b>For Beginners:</b> This specifies how much to trim from the right side of your data.
    /// 
    /// For image data, this primarily affects the width dimension:
    /// - cropRight[2] would crop columns from the right side of the image
    ///
    /// Together with cropTop, cropBottom, and cropLeft, this allows you to 
    /// specify cropping on all sides of your data.
    /// </para>
    /// </remarks>
    private readonly int[] _cropRight;

    /// <summary>
    /// Gets a value indicating whether this layer supports training through backpropagation.
    /// </summary>
    /// <value>
    /// Always returns <c>false</c> for cropping layers, as they have no trainable parameters.
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates whether the layer can be trained through backpropagation. Cropping layers
    /// have no trainable parameters, so they cannot be trained directly.
    /// </para>
    /// <para><b>For Beginners:</b> This property tells you if the layer can learn from data.
    /// 
    /// For cropping layers:
    /// - The value is always false
    /// - This means the layer doesn't have any adjustable values
    /// - It performs the same operation regardless of training
    ///
    /// The cropping layer simply passes data through (after trimming the edges),
    /// without changing its behavior based on training examples.
    /// </para>
    /// </remarks>
    public override bool SupportsTraining => false;

    /// <summary>
    /// Initializes a new instance of the <see cref="CroppingLayer{T}"/> class with the specified 
    /// cropping parameters and a scalar activation function.
    /// </summary>
    /// <param name="inputShape">The shape of the input data.</param>
    /// <param name="cropTop">The amount to crop from the top of each dimension.</param>
    /// <param name="cropBottom">The amount to crop from the bottom of each dimension.</param>
    /// <param name="cropLeft">The amount to crop from the left of each dimension.</param>
    /// <param name="cropRight">The amount to crop from the right of each dimension.</param>
    /// <param name="scalarActivation">The activation function to apply. Defaults to Identity if not specified.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a cropping layer with the specified cropping parameters and activation function.
    /// The output shape is calculated based on the input shape and cropping parameters. The Identity activation
    /// function is used by default, which means no transformation is applied to the cropped output.
    /// </para>
    /// <para><b>For Beginners:</b> This setup method creates a new cropping layer with specific settings.
    /// 
    /// When creating the layer, you specify:
    /// - The size and shape of your input data
    /// - How much to crop from each side/dimension
    /// - What mathematical function to apply after cropping (usually none)
    ///
    /// The layer automatically calculates how big the output will be after cropping.
    /// By default, it uses the "Identity" activation, which means the values don't change
    /// after cropping - they just pass through unchanged.
    /// </para>
    /// </remarks>
    public CroppingLayer(
        int[] inputShape,
        int[] cropTop,
        int[] cropBottom,
        int[] cropLeft,
        int[] cropRight,
        IActivationFunction<T>? scalarActivation = null)
        : base(inputShape, CalculateOutputShape(inputShape, cropTop, cropBottom, cropLeft, cropRight), scalarActivation ?? new IdentityActivation<T>())
    {
        _cropTop = cropTop;
        _cropBottom = cropBottom;
        _cropLeft = cropLeft;
        _cropRight = cropRight;
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="CroppingLayer{T}"/> class with the specified 
    /// cropping parameters and a vector activation function.
    /// </summary>
    /// <param name="inputShape">The shape of the input data.</param>
    /// <param name="cropTop">The amount to crop from the top of each dimension.</param>
    /// <param name="cropBottom">The amount to crop from the bottom of each dimension.</param>
    /// <param name="cropLeft">The amount to crop from the left of each dimension.</param>
    /// <param name="cropRight">The amount to crop from the right of each dimension.</param>
    /// <param name="vectorActivation">The vector activation function to apply. Defaults to Identity if not specified.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a cropping layer with the specified cropping parameters and a vector activation function.
    /// The output shape is calculated based on the input shape and cropping parameters. The Identity activation
    /// function is used by default, which means no transformation is applied to the cropped output.
    /// </para>
    /// <para><b>For Beginners:</b> This setup method is similar to the previous one, but uses a different type of
    /// activation function.
    /// 
    /// A vector activation function:
    /// - Works on entire groups of numbers at once
    /// - Can be more efficient for certain types of calculations
    /// - Otherwise works the same as the regular activation function
    ///
    /// Most of the time with cropping layers, you'll use the Identity activation (no change),
    /// but this option gives you flexibility if you need it.
    /// </para>
    /// </remarks>
    public CroppingLayer(
        int[] inputShape,
        int[] cropTop,
        int[] cropBottom,
        int[] cropLeft,
        int[] cropRight,
        IVectorActivationFunction<T>? vectorActivation = null)
        : base(inputShape, CalculateOutputShape(inputShape, cropTop, cropBottom, cropLeft, cropRight), vectorActivation ?? new IdentityActivation<T>())
    {
        _cropTop = cropTop;
        _cropBottom = cropBottom;
        _cropLeft = cropLeft;
        _cropRight = cropRight;
    }

    /// <summary>
    /// Calculates the output shape after applying the cropping operations.
    /// </summary>
    /// <param name="inputShape">The shape of the input data.</param>
    /// <param name="cropTop">The amount to crop from the top of each dimension.</param>
    /// <param name="cropBottom">The amount to crop from the bottom of each dimension.</param>
    /// <param name="cropLeft">The amount to crop from the left of each dimension.</param>
    /// <param name="cropRight">The amount to crop from the right of each dimension.</param>
    /// <returns>The calculated output shape after cropping.</returns>
    /// <remarks>
    /// <para>
    /// This method calculates the output shape of the data after applying all the specified cropping operations.
    /// The shape of each dimension is reduced by the sum of the corresponding cropping values.
    /// </para>
    /// <para><b>For Beginners:</b> This calculates how big your data will be after trimming the edges.
    /// 
    /// For each dimension of your data:
    /// - Start with the original size
    /// - Subtract how much you're trimming from the top
    /// - Subtract how much you're trimming from the bottom
    /// - Subtract how much you're trimming from the left
    /// - Subtract how much you're trimming from the right
    /// - The result is the new size for that dimension
    ///
    /// For example, if you start with an image that's 28�28 pixels and crop 2 pixels from each side,
    /// the output will be 24�24 pixels (28 - 2 - 2 = 24).
    /// </para>
    /// </remarks>
    private static int[] CalculateOutputShape(int[] inputShape, int[] cropTop, int[] cropBottom, int[] cropLeft, int[] cropRight)
    {
        int[] outputShape = new int[inputShape.Length];
        for (int i = 0; i < inputShape.Length; i++)
        {
            outputShape[i] = inputShape[i] - cropTop[i] - cropBottom[i] - cropLeft[i] - cropRight[i];
        }

        return outputShape;
    }

    /// <summary>
    /// Processes the input data through the cropping layer.
    /// </summary>
    /// <param name="input">The input tensor to process.</param>
    /// <returns>The output tensor after cropping and activation.</returns>
    /// <remarks>
    /// <para>
    /// This method performs the forward pass of the cropping layer. It creates a new tensor with the calculated
    /// output shape and copies the non-cropped portion of the input tensor to it. Then it applies the activation
    /// function to the result.
    /// </para>
    /// <para><b>For Beginners:</b> This method applies the cropping to your input data.
    /// 
    /// During the forward pass:
    /// - A new, smaller output is created based on the calculated size
    /// - The layer copies the central portion of the input to the output
    /// - The edges specified by the cropping parameters are left out
    /// - The activation function is applied to the result (usually no change)
    ///
    /// Think of it like cutting out the center of a photo and discarding the edges.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        int[] inputShape = input.Shape;
        int[] outputShape = GetOutputShape();
        Tensor<T> output = new Tensor<T>(outputShape);
        int batchSize = inputShape[0];
        int channels = inputShape[3];
        for (int b = 0; b < batchSize; b++)
        {
            for (int y = 0; y < outputShape[1]; y++)
            {
                for (int x = 0; x < outputShape[2]; x++)
                {
                    for (int c = 0; c < channels; c++)
                    {
                        output[b, y, x, c] = input[b, y + _cropTop[1], x + _cropLeft[2], c];
                    }
                }
            }
        }

        return ApplyActivation(output);
    }

    /// <summary>
    /// Calculates gradients during backpropagation.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's input.</returns>
    /// <remarks>
    /// <para>
    /// This method performs the backward pass of the cropping layer during training. It creates a tensor with
    /// the same shape as the input and places the output gradient in the non-cropped region, leaving the
    /// cropped regions as zero. This effectively passes the gradient back through only the portions of the
    /// input that were kept during the forward pass.
    /// </para>
    /// <para><b>For Beginners:</b> This method helps pass error information backward through the network during training.
    /// 
    /// During the backward pass:
    /// - A tensor the same size as the original input is created
    /// - The gradient information is placed in the center (non-cropped) region
    /// - The cropped regions get zero gradient (since they didn't contribute to the output)
    /// - This allows the network to learn only from the parts of the input that were actually used
    ///
    /// Even though the cropping layer itself doesn't learn, it needs to properly pass
    /// gradient information back to previous layers that do learn.
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        int[] inputShape = GetInputShape();
        Tensor<T> inputGradient = new Tensor<T>(inputShape);
        int batchSize = inputShape[0];
        int channels = inputShape[3];
        for (int b = 0; b < batchSize; b++)
        {
            for (int y = 0; y < outputGradient.Shape[1]; y++)
            {
                for (int x = 0; x < outputGradient.Shape[2]; x++)
                {
                    for (int c = 0; c < channels; c++)
                    {
                        inputGradient[b, y + _cropTop[1], x + _cropLeft[2], c] = outputGradient[b, y, x, c];
                    }
                }
            }
        }
        return ApplyActivationDerivative(inputGradient, outputGradient);
    }
   
    /// <summary>
    /// Updates the layer's parameters using the specified learning rate.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the update.</param>
    /// <remarks>
    /// <para>
    /// This method is a no-operation for cropping layers, as they have no trainable parameters to update.
    /// It is implemented to satisfy the abstract method requirement from the base class.
    /// </para>
    /// <para><b>For Beginners:</b> This method is empty because cropping layers don't learn.
    /// 
    /// Since cropping layers:
    /// - Have no adjustable parameters
    /// - Always perform the same fixed operation
    /// - Don't change their behavior based on training
    ///
    /// This method exists but does nothing. It's like having a bike pedal
    /// that's not connected to the chain - you can push it, but it won't change anything.
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        // No parameters to update in a cropping layer
    }

    /// <summary>
    /// Gets all trainable parameters of the layer as a single vector.
    /// </summary>
    /// <returns>An empty vector, as cropping layers have no trainable parameters.</returns>
    /// <remarks>
    /// <para>
    /// This method returns an empty vector for cropping layers, as they have no trainable parameters.
    /// It is implemented to satisfy the abstract method requirement from the base class.
    /// </para>
    /// <para><b>For Beginners:</b> This method returns an empty list because there are no values to learn.
    /// 
    /// Since cropping layers:
    /// - Have no weights or biases
    /// - Don't learn from data
    /// - Just perform a fixed cropping operation
    ///
    /// The method returns an empty vector (list) to indicate there's nothing to adjust.
    /// This is like a recipe that has no ingredients that can be changed - it's always the same.
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // Cropping layer has no trainable parameters
        return Vector<T>.Empty();
    }

    /// <summary>
    /// Resets the internal state of the layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method is a no-operation for cropping layers, as they maintain no internal state that needs to be reset.
    /// It is implemented to satisfy the abstract method requirement from the base class.
    /// </para>
    /// <para><b>For Beginners:</b> This method is empty because cropping layers don't store any temporary information.
    /// 
    /// Since cropping layers:
    /// - Don't keep track of past inputs
    /// - Don't remember anything between operations
    /// - Simply crop each input as it comes
    ///
    /// There's nothing to reset. This is like a paper cutter - it doesn't remember
    /// the last paper it cut, so there's nothing to clear between uses.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // No state to reset in a cropping layer
    }

    /// <summary>
    /// Sets the trainable parameters of the layer from a single vector.
    /// </summary>
    /// <param name="parameters">A vector containing parameters to set.</param>
    /// <remarks>
    /// <para>
    /// This method is a no-operation for cropping layers, as they have no trainable parameters to set.
    /// It is implemented to satisfy the abstract method requirement from the base class.
    /// </para>
    /// <para><b>For Beginners:</b> This method is empty because cropping layers don't have adjustable values.
    /// 
    /// Since cropping layers:
    /// - Have no weights or biases to update
    /// - Perform a fixed operation that doesn't change
    /// - Don't learn from training
    ///
    /// There's nothing to set. It's like trying to change the color settings
    /// on a black and white printer - the feature doesn't exist.
    /// </para>
    /// </remarks>
    public override void SetParameters(Vector<T> parameters)
    {
        // Cropping layer has no parameters to set
    }
}