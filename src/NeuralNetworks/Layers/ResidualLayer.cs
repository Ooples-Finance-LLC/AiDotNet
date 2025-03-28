namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a residual layer that adds the identity mapping (input) to the output of an inner layer.
/// </summary>
/// <remarks>
/// <para>
/// A residual layer implements the core concept of residual networks (ResNets), where the layer learns
/// the residual (difference) between the identity mapping and the desired underlying mapping rather than
/// the complete transformation. This is achieved by adding a skip connection that passes the input directly
/// to the output, where it's added to the transformed output of an inner layer.
/// </para>
/// <para><b>For Beginners:</b> This layer helps neural networks learn more effectively, especially when they're very deep.
/// 
/// Think of it as a "correction mechanism":
/// - The inner layer tries to learn how to improve or adjust the input
/// - The original input is preserved and added back in at the end
/// - This allows the network to focus on learning the changes needed, rather than recreating the entire signal
/// 
/// Benefits include:
/// - Solves the "vanishing gradient problem" that makes deep networks hard to train
/// - Enables training of much deeper networks (hundreds of layers instead of just dozens)
/// - Improves learning speed and accuracy
/// 
/// For example, in image recognition, a residual layer might learn to emphasize important features
/// while preserving the original image information through the skip connection.
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class ResidualLayer<T> : LayerBase<T>
{
    /// <summary>
    /// The inner layer that transforms the input before being added back to the original input.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field holds the optional inner layer that learns the residual mapping. If null, the layer
    /// simply passes the input through the activation function. The output of this inner layer is added
    /// to the original input to form the final output of the residual layer.
    /// </para>
    /// <para><b>For Beginners:</b> This is the "transformation path" of the residual connection.
    /// 
    /// It can be any type of neural network layer (like convolution, dense, etc.) or even
    /// a sequence of multiple layers bundled together. The residual layer adds the output
    /// of this transformation path back to the original input.
    /// 
    /// The inner layer must have the same input and output shape for the residual connection
    /// to work properly, as the outputs need to be added together.
    /// 
    /// If this is null (not set), then the layer simply passes the input through the activation function.
    /// </para>
    /// </remarks>
    private ILayer<T>? _innerLayer;

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
    /// Returns <c>true</c> if the inner layer exists and supports training; otherwise, <c>false</c>.
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates whether the residual layer can be trained using backpropagation.
    /// The layer supports training if it has an inner layer that supports training. If there is no
    /// inner layer, the residual layer is considered not to support training since it would just act
    /// as an identity function.
    /// </para>
    /// <para><b>For Beginners:</b> This property tells you if the layer can learn from data.
    /// 
    /// A value of true means:
    /// - The layer can improve through training
    /// - It has parameters that can be adjusted
    /// 
    /// For residual layers:
    /// - If there's an inner layer that can be trained, this will be true
    /// - If there's no inner layer or the inner layer can't be trained, this will be false
    /// 
    /// Residual layers themselves don't have trainable parameters - all learning happens in the inner layer.
    /// </para>
    /// </remarks>
    public override bool SupportsTraining => _innerLayer?.SupportsTraining ?? false;

    /// <summary>
    /// Initializes a new instance of the <see cref="ResidualLayer{T}"/> class with the specified input shape,
    /// inner layer, and scalar activation function.
    /// </summary>
    /// <param name="inputShape">The shape of the input tensor.</param>
    /// <param name="innerLayer">The optional inner layer that learns the residual mapping.</param>
    /// <param name="activation">The scalar activation function to apply after addition. Defaults to Identity if not specified.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a residual layer with the specified input shape, inner layer, and scalar activation function.
    /// The output shape is set to be the same as the input shape, as required for residual connections. If the inner layer
    /// has different input and output shapes, an exception will be thrown.
    /// </para>
    /// <para><b>For Beginners:</b> This creates a new residual layer with basic settings.
    /// 
    /// When you create a residual layer this way:
    /// - You specify the size and shape of the data it will process
    /// - You can provide an inner layer that will learn the transformation
    /// - You can specify an activation function that operates on each value individually
    /// 
    /// The residual layer requires that the inner layer produces output of the same shape as its input,
    /// because the original input and the transformed output need to be added together.
    /// 
    /// This constructor is for the more common case where you want to use a scalar activation function.
    /// </para>
    /// </remarks>
    public ResidualLayer(int[] inputShape, ILayer<T>? innerLayer = null, IActivationFunction<T>? activation = null)
        : base(inputShape, inputShape, activation?? new IdentityActivation<T>())
    {
        _innerLayer = innerLayer;
        ValidateInnerLayer();
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="ResidualLayer{T}"/> class with the specified input shape,
    /// inner layer, and vector activation function.
    /// </summary>
    /// <param name="inputShape">The shape of the input tensor.</param>
    /// <param name="innerLayer">The optional inner layer that learns the residual mapping.</param>
    /// <param name="vectorActivation">The vector activation function to apply after addition. Defaults to Identity if not specified.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a residual layer with the specified input shape, inner layer, and vector activation function.
    /// The output shape is set to be the same as the input shape, as required for residual connections. If the inner layer
    /// has different input and output shapes, an exception will be thrown.
    /// </para>
    /// <para><b>For Beginners:</b> This creates a new residual layer with advanced settings.
    /// 
    /// When you create a residual layer this way:
    /// - You specify the size and shape of the data it will process
    /// - You can provide an inner layer that will learn the transformation
    /// - You can specify a vector activation function that operates on groups of values
    /// 
    /// The residual layer requires that the inner layer produces output of the same shape as its input,
    /// because the original input and the transformed output need to be added together.
    /// 
    /// This constructor is for advanced cases where you want to use a vector activation function
    /// that can capture relationships between different elements in the output.
    /// </para>
    /// </remarks>
    public ResidualLayer(int[] inputShape, ILayer<T>? innerLayer = null, IVectorActivationFunction<T>? vectorActivation = null)
        : base(inputShape, inputShape, vectorActivation ?? new IdentityActivation<T>())
    {
        _innerLayer = innerLayer;
        ValidateInnerLayer();
    }

    /// <summary>
    /// Validates that the inner layer has the same input and output shape.
    /// </summary>
    /// <exception cref="ArgumentException">Thrown when the inner layer has different input and output shapes.</exception>
    /// <remarks>
    /// <para>
    /// This method checks that the inner layer (if present) has the same input and output shape, which is required
    /// for residual connections to work properly. If the shapes are different, an ArgumentException is thrown.
    /// </para>
    /// <para><b>For Beginners:</b> This method makes sure the inner layer is compatible with residual connections.
    /// 
    /// For a residual connection to work:
    /// - The inner layer must produce output of exactly the same shape as its input
    /// - This is because the original input and the transformed output will be added together
    /// - Addition only works when the shapes match exactly
    /// 
    /// If the shapes don't match, this method will throw an error to prevent problems later.
    /// </para>
    /// </remarks>
    private void ValidateInnerLayer()
    {
        if (_innerLayer != null && !Enumerable.SequenceEqual(_innerLayer.GetInputShape(), _innerLayer.GetOutputShape()))
        {
            throw new ArgumentException("Inner layer must have the same input and output shape for residual connections.");
        }
    }

    /// <summary>
    /// Sets a new inner layer for the residual layer.
    /// </summary>
    /// <param name="innerLayer">The new inner layer to use.</param>
    /// <exception cref="ArgumentException">Thrown when the inner layer has different input and output shapes.</exception>
    /// <remarks>
    /// <para>
    /// This method allows changing the inner layer of the residual layer after construction. It validates that the
    /// new inner layer has the same input and output shape before setting it.
    /// </para>
    /// <para><b>For Beginners:</b> This method lets you change the transformation part of the residual layer.
    /// 
    /// You can use this to:
    /// - Replace the current inner layer with a different one
    /// - Add an inner layer if there wasn't one before
    /// 
    /// The method checks that the new inner layer is compatible (has matching input and output shapes)
    /// before making the change. If the shapes don't match, it will throw an error.
    /// 
    /// This is useful for building complex networks where you might want to add or change
    /// parts of the network after initial construction.
    /// </para>
    /// </remarks>
    public void SetInnerLayer(ILayer<T> innerLayer)
    {
        _innerLayer = innerLayer;
        ValidateInnerLayer();
    }

    /// <summary>
    /// Performs the forward pass of the residual layer.
    /// </summary>
    /// <param name="input">The input tensor to process.</param>
    /// <returns>The output tensor after processing through the residual layer.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the forward pass of the residual layer. It passes the input through the inner layer
    /// (if present), adds the result to the original input, and then applies the activation function.
    /// </para>
    /// <para><b>For Beginners:</b> This method processes data through the residual layer.
    /// 
    /// During the forward pass:
    /// - The input is saved for later use in training
    /// - If there's an inner layer, the input is processed through it
    /// - The original input is added to the processed result
    /// - The activation function is applied to the combined result
    /// - The final output is returned
    /// 
    /// If there's no inner layer, the input is simply passed through the activation function.
    /// 
    /// The key to residual learning is the addition step, which allows information to
    /// flow directly from the input to the output, making it easier to train deep networks.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        _lastInput = input;
        var result = _innerLayer == null ? input : input.Add(_innerLayer.Forward(input));

        return ApplyActivation(result);
    }

    /// <summary>
    /// Performs the backward pass of the residual layer.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's input.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the backward pass of the residual layer, which is used during training to propagate
    /// error gradients back through the network. It computes gradients for the inner layer (if present) and returns
    /// the gradient with respect to the input.
    /// </para>
    /// <para><b>For Beginners:</b> This method is used during training to calculate how the layer's input
    /// should change to reduce errors.
    /// 
    /// During the backward pass:
    /// - The method throws an error if the forward pass hasn't been called first
    /// - The gradient is computed for the combined output after the addition
    /// - If there's an inner layer, the gradient is propagated through it
    /// - The original gradient and the inner layer gradient are combined
    /// - The combined gradient is returned for further backpropagation
    /// 
    /// This process ensures that gradient information flows both through the inner layer
    /// and directly back to earlier layers, preventing the vanishing gradient problem
    /// in deep networks.
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        if (_lastInput == null)
            throw new InvalidOperationException("Forward pass must be called before backward pass.");
        var innerOutput = _innerLayer?.Forward(_lastInput) ?? _lastInput;
        var combinedOutput = _lastInput.Add(innerOutput);
        var activationGradient = ApplyActivationDerivative(combinedOutput, outputGradient);
        var combinedGradient = outputGradient.ElementwiseMultiply(activationGradient);

        if (_innerLayer == null)
        {
            return combinedGradient;
        }

        var innerGradient = _innerLayer.Backward(combinedGradient);
        return combinedGradient.Add(innerGradient);
    }

    /// <summary>
    /// Updates the parameters of the inner layer using the calculated gradients.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the parameter updates.</param>
    /// <remarks>
    /// <para>
    /// This method updates the parameters of the inner layer (if present) based on the gradients calculated during the backward pass.
    /// If there is no inner layer, this method does nothing since there are no parameters to update.
    /// </para>
    /// <para><b>For Beginners:</b> This method updates the layer's learnable values during training.
    /// 
    /// When updating parameters:
    /// - If there's an inner layer, its parameters are updated using the specified learning rate
    /// - If there's no inner layer, nothing happens since there are no parameters to update
    /// 
    /// The learning rate controls how big each update step is:
    /// - Smaller learning rates: slower but more stable learning
    /// - Larger learning rates: faster but potentially unstable learning
    /// 
    /// Residual layers themselves don't have parameters to learn - they just pass the
    /// updates to their inner layer if one exists.
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        _innerLayer?.UpdateParameters(learningRate);
    }

    /// <summary>
    /// Gets all trainable parameters from the inner layer as a single vector.
    /// </summary>
    /// <returns>A vector containing all trainable parameters from the inner layer, or an empty vector if there is no inner layer.</returns>
    /// <remarks>
    /// <para>
    /// This method retrieves all trainable parameters from the inner layer (if present) and returns them as a single vector.
    /// If there is no inner layer, it returns an empty vector since there are no parameters to retrieve.
    /// </para>
    /// <para><b>For Beginners:</b> This method collects all the learnable values from the layer.
    /// 
    /// For a residual layer:
    /// - If there's an inner layer, it returns that layer's parameters
    /// - If there's no inner layer, it returns an empty list (no parameters)
    /// 
    /// Residual layers themselves don't have parameters to learn - all learning happens
    /// in the inner layer (if one exists).
    /// 
    /// This method is useful for:
    /// - Saving the model to disk
    /// - Loading parameters from a previously trained model
    /// - Advanced optimization techniques
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        return _innerLayer?.GetParameters() ?? Vector<T>.Empty();
    }

    /// <summary>
    /// Resets the internal state of the residual layer and its inner layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method resets the internal state of the residual layer, including the cached input, as well as
    /// the state of the inner layer (if present). This is useful when starting to process a new batch or when implementing
    /// stateful networks that need to be reset between sequences.
    /// </para>
    /// <para><b>For Beginners:</b> This method clears the layer's memory to start fresh.
    /// 
    /// When resetting the state:
    /// - The stored input from the previous forward pass is cleared
    /// - If there's an inner layer, its state is also reset
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
        _lastInput = null;
        _innerLayer?.ResetState();
    }
}