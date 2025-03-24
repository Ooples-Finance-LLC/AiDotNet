namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a layer that masks specified values in the input tensor, typically used to ignore padding in sequential data.
/// </summary>
/// <remarks>
/// <para>
/// The MaskingLayer is used to skip certain time steps in sequential data by masking out specific values. 
/// During the forward pass, time steps with values equal to the mask value are multiplied by zero, effectively 
/// removing them from consideration by subsequent layers. This is particularly useful for handling variable-length 
/// sequences where padding is used to make all sequences the same length.
/// </para>
/// <para><b>For Beginners:</b> This layer helps the network ignore certain parts of your data.
/// 
/// Think of it like a highlighter that marks which parts of your data are important:
/// - Any value matching the "mask value" (usually 0) gets ignored
/// - All other values pass through unchanged
/// - This is especially useful for sequences of different lengths
/// 
/// For example, if you have sentences of different lengths:
/// - Short sentences might be padded with zeros to match longer ones
/// - The masking layer tells the network to ignore those zeros
/// - This helps the network focus only on the real data
/// 
/// Without masking, the network would try to learn patterns from the padding values,
/// which would confuse the learning process.
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class MaskingLayer<T> : LayerBase<T>
{
    /// <summary>
    /// The value to be masked out in the input tensor.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field stores the value that should be masked out (typically 0) when it appears in the input tensor.
    /// During the forward pass, all values equal to this mask value will be effectively removed from consideration
    /// by subsequent layers.
    /// </para>
    /// <para><b>For Beginners:</b> This is the specific value that the layer will ignore.
    /// 
    /// The mask value:
    /// - Is typically set to 0 (the default)
    /// - Indicates which values should be masked out (ignored)
    /// - Could be set to a different value depending on your data
    /// 
    /// For example, if your data uses -1 as padding instead of 0, you would set
    /// the mask value to -1 so the layer knows to ignore those specific values.
    /// </para>
    /// </remarks>
    private readonly T _maskValue;

    /// <summary>
    /// The input tensor from the last forward pass.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field stores the input tensor from the most recent forward pass. It is kept for potential future use,
    /// though the current implementation doesn't directly use it after storing it. This field is reset when
    /// ResetState is called.
    /// </para>
    /// <para><b>For Beginners:</b> This stores the most recent data that was fed into the layer.
    /// 
    /// The layer keeps track of:
    /// - The input it received in the most recent forward pass
    /// - This information might be needed for future operations
    /// - It gets cleared when you reset the layer's state
    /// 
    /// Storing the last input is a common pattern in neural network layers,
    /// even when not immediately needed for calculations.
    /// </para>
    /// </remarks>
    private Tensor<T>? _lastInput;

    /// <summary>
    /// The mask tensor from the last forward pass.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field stores the binary mask tensor created during the most recent forward pass. It is needed during
    /// the backward pass to apply the same masking pattern to the output gradients. This field is reset when
    /// ResetState is called.
    /// </para>
    /// <para><b>For Beginners:</b> This stores the pattern of 0s and 1s created in the last forward pass.
    /// 
    /// The layer remembers:
    /// - Which positions were masked (set to 0) in the forward pass
    /// - This same pattern must be applied during the backward pass
    /// - This ensures consistency between forward and backward operations
    /// 
    /// By keeping the mask, the layer doesn't need to recalculate it during
    /// the backward pass, which saves computation time.
    /// </para>
    /// </remarks>
    private Tensor<T>? _lastMask;

    /// <summary>
    /// Gets a value indicating whether this layer supports training through backpropagation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This property returns false because the MaskingLayer does not have any trainable parameters,
    /// though it does support backward pass for gradient propagation through the network.
    /// </para>
    /// <para><b>For Beginners:</b> This tells you if the layer can learn from training data.
    /// 
    /// A value of false means:
    /// - This layer doesn't have any values that get updated during training
    /// - It performs a fixed operation (masking)
    /// - However, during training, it still helps gradients flow backward through the network
    /// 
    /// The masking layer doesn't need to learn anything - it just follows a simple rule:
    /// mask out specific values and pass everything else through.
    /// </para>
    /// </remarks>
    public override bool SupportsTraining => false;

    /// <summary>
    /// Initializes a new instance of the <see cref="MaskingLayer{T}"/> class.
    /// </summary>
    /// <param name="inputShape">The shape of the input tensor.</param>
    /// <param name="maskValue">The value to be masked out. Defaults to 0.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a MaskingLayer that will mask out all values equal to the specified mask value.
    /// The output shape is the same as the input shape, as the masking operation doesn't change the dimensions.
    /// </para>
    /// <para><b>For Beginners:</b> This creates a new masking layer with your desired settings.
    /// 
    /// When setting up this layer:
    /// - inputShape defines the expected size and dimensions of your data
    /// - maskValue is the specific value you want to ignore (typically 0)
    /// 
    /// For example, if you have sequences padded with zeros, you would set maskValue to 0
    /// so that the network ignores those padding values.
    /// </para>
    /// </remarks>
    public MaskingLayer(int[] inputShape, double maskValue = 0) : base(inputShape, inputShape)
    {
        _maskValue = NumOps.FromDouble(maskValue);
    }

    /// <summary>
    /// Performs the forward pass of the masking layer.
    /// </summary>
    /// <param name="input">The input tensor to process.</param>
    /// <returns>The output tensor after masking.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the forward pass of the masking layer. It creates a binary mask where values
    /// equal to the mask value are set to 0 and other values are set to 1. This mask is then applied to the
    /// input tensor by element-wise multiplication, effectively removing the masked values from consideration.
    /// </para>
    /// <para><b>For Beginners:</b> This method processes your data through the masking layer.
    /// 
    /// During the forward pass:
    /// 1. The layer creates a "mask" - a matching array where:
    ///    - Values equal to the mask value (usually 0) become 0 in the mask
    ///    - All other values become 1 in the mask
    /// 2. The original input is multiplied by this mask
    ///    - Where the mask is 1, the original value passes through
    ///    - Where the mask is 0, the result becomes 0
    /// 
    /// For example, if you have data [5, 0, 7, 0, 9] and a mask value of 0:
    /// - The mask would be [1, 0, 1, 0, 1]
    /// - After applying the mask: [5, 0, 7, 0, 9] * [1, 0, 1, 0, 1] = [5, 0, 7, 0, 9]
    /// - But the zeros now have special meaning - they'll be ignored by subsequent layers
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        _lastInput = input;
        _lastMask = CreateMask(input);
        return ApplyMask(input, _lastMask);
    }

    /// <summary>
    /// Performs the backward pass of the masking layer.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's input.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the backward pass of the masking layer, which is used during training to propagate
    /// error gradients back through the network. It applies the same mask to the output gradient that was used
    /// in the forward pass, ensuring that gradients for masked values remain zero.
    /// </para>
    /// <para><b>For Beginners:</b> This method handles the flow of error information during training.
    /// 
    /// During the backward pass:
    /// - The layer receives information about how its output affected the overall error
    /// - It applies the same mask to this gradient information
    /// - This ensures that no gradient flows back through the masked values
    /// 
    /// This process is important because:
    /// - We don't want the network to learn from the masked (padding) values
    /// - The mask stops error information from flowing back through those values
    /// - This helps keep the training focused only on the real data
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        if (_lastMask == null)
            throw new InvalidOperationException("Forward pass must be called before backward pass.");

        return ApplyMask(outputGradient, _lastMask);
    }

    /// <summary>
    /// Creates a binary mask from the input tensor based on the mask value.
    /// </summary>
    /// <param name="input">The input tensor to create a mask from.</param>
    /// <returns>A binary mask tensor where values equal to the mask value are 0, all others are 1.</returns>
    /// <remarks>
    /// <para>
    /// This method creates a binary mask tensor with the same shape as the input. For each element in the input,
    /// if the value equals the mask value, the corresponding element in the mask is set to 0. Otherwise, it is set to 1.
    /// This binary mask is used to filter out specific values from the input.
    /// </para>
    /// <para><b>For Beginners:</b> This method creates a pattern of 0s and 1s to mark which data to ignore.
    /// 
    /// For each value in your data:
    /// - If the value equals the mask value (usually 0), the mask gets a 0
    /// - If the value is different from the mask value, the mask gets a 1
    /// 
    /// This creates a binary (0s and 1s) pattern that matches your data in shape.
    /// The 0s in the mask will tell the network "ignore this position" while
    /// the 1s tell it "pay attention to this position."
    /// </para>
    /// </remarks>
    private Tensor<T> CreateMask(Tensor<T> input)
    {
        var mask = new Tensor<T>(input.Shape);
        for (int i = 0; i < input.Shape[0]; i++)
        {
            for (int j = 0; j < input.Shape[1]; j++)
            {
                for (int k = 0; k < input.Shape[2]; k++)
                {
                    mask[i, j, k] = !NumOps.Equals(input[i, j, k], _maskValue) ? NumOps.One : NumOps.Zero;
                }
            }
        }

        return mask;
    }

    /// <summary>
    /// Applies a binary mask to an input tensor through element-wise multiplication.
    /// </summary>
    /// <param name="input">The input tensor to mask.</param>
    /// <param name="mask">The binary mask to apply.</param>
    /// <returns>The masked tensor with values corresponding to 0s in the mask set to 0.</returns>
    /// <remarks>
    /// <para>
    /// This method applies a binary mask to an input tensor through element-wise multiplication. Each element in the
    /// input is multiplied by the corresponding element in the mask. Since the mask contains only 0s and 1s, this
    /// effectively zeros out values where the mask is 0 and leaves other values unchanged.
    /// </para>
    /// <para><b>For Beginners:</b> This method applies the mask to your data.
    /// 
    /// For each position in your data and the matching mask:
    /// - The data value is multiplied by the mask value (either 0 or 1)
    /// - If the mask is 1, the result equals the original value (x * 1 = x)
    /// - If the mask is 0, the result becomes 0 (x * 0 = 0)
    /// 
    /// This multiplication "zeros out" any position where the mask is 0,
    /// effectively telling subsequent layers to ignore those positions,
    /// while allowing other values to pass through unchanged.
    /// </para>
    /// </remarks>
    private Tensor<T> ApplyMask(Tensor<T> input, Tensor<T> mask)
    {
        var output = new Tensor<T>(input.Shape);
        for (int i = 0; i < input.Shape[0]; i++)
        {
            for (int j = 0; j < input.Shape[1]; j++)
            {
                for (int k = 0; k < input.Shape[2]; k++)
                {
                    output[i, j, k] = NumOps.Multiply(input[i, j, k], mask[i, j, k]);
                }
            }
        }

        return output;
    }

    /// <summary>
    /// Updates the parameters of the layer based on the calculated gradients.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the parameter updates.</param>
    /// <remarks>
    /// <para>
    /// This method is empty because the MaskingLayer has no trainable parameters to update.
    /// However, it must be implemented to satisfy the base class contract.
    /// </para>
    /// <para><b>For Beginners:</b> This method would normally update the layer's internal values during training.
    /// 
    /// However, since this layer doesn't have any trainable parameters:
    /// - There's nothing to update
    /// - The method exists but doesn't do anything
    /// - This is normal for layers that perform fixed operations
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
    /// This method returns an empty vector because the MaskingLayer has no trainable parameters.
    /// However, it must be implemented to satisfy the base class contract.
    /// </para>
    /// <para><b>For Beginners:</b> This method would normally return all the values that can be learned during training.
    /// 
    /// Since this layer has no learnable values:
    /// - It returns an empty list (vector with length 0)
    /// - This is expected for layers that perform fixed operations
    /// - Other layers, like those with weights, would return those weights
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // MaskingLayer has no trainable parameters
        return Vector<T>.Empty();
    }

    /// <summary>
    /// Resets the internal state of the layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method clears any cached data from previous forward passes, essentially resetting the layer
    /// to its initial state. This is useful when starting to process a new batch of data.
    /// </para>
    /// <para><b>For Beginners:</b> This method clears the layer's memory to start fresh.
    /// 
    /// When resetting the state:
    /// - Stored inputs and masks are cleared
    /// - The layer forgets any information from previous data
    /// - This is important when processing a new, unrelated batch of data
    /// 
    /// Think of it like wiping a slate clean before writing new information.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // Clear cached values from forward pass
        _lastInput = null;
        _lastMask = null;
    }
}