namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a layer that performs element-wise multiplication of multiple input tensors.
/// </summary>
/// <remarks>
/// <para>
/// The MultiplyLayer performs element-wise multiplication (Hadamard product) of two or more input tensors
/// of identical shape. This operation can be useful for implementing gating mechanisms, attention masks,
/// or feature-wise interactions in neural networks. The layer requires that all input tensors have the
/// same shape, and it produces an output tensor of that same shape.
/// </para>
/// <para><b>For Beginners:</b> This layer multiplies tensors together, element by element.
/// 
/// Think of it like multiplying numbers together in corresponding positions:
/// - If you have two vectors [1, 2, 3] and [4, 5, 6]
/// - The result would be [1�4, 2�5, 3�6] = [4, 10, 18]
/// 
/// This is useful for:
/// - Controlling information flow (like gates in LSTM or GRU cells)
/// - Applying masks (to selectively focus on certain values)
/// - Combining features in a multiplicative way
/// 
/// For example, in an attention mechanism, you might multiply feature values by attention weights
/// to focus on important features and diminish the influence of less relevant ones.
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class MultiplyLayer<T> : LayerBase<T>
{
    /// <summary>
    /// The input tensors from the most recent forward pass.
    /// </summary>
    /// <remarks>
    /// This field stores the input tensors from the most recent forward pass, which are needed
    /// during the backward pass for gradient calculation.
    /// </remarks>
    private Tensor<T>[]? _lastInputs;
    
    /// <summary>
    /// The output tensor from the most recent forward pass.
    /// </summary>
    /// <remarks>
    /// This field stores the output tensor from the most recent forward pass, which is needed
    /// during the backward pass for gradient calculation.
    /// </remarks>
    private Tensor<T>? _lastOutput;
    
    /// <summary>
    /// Gets a value indicating whether this layer supports training.
    /// </summary>
    /// <value>
    /// Always <c>true</c> because the MultiplyLayer supports backpropagation, even though it has no parameters.
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates whether the layer supports backpropagation during training. Although
    /// the MultiplyLayer has no trainable parameters, it still supports the backward pass to propagate
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
    /// Initializes a new instance of the <see cref="MultiplyLayer{T}"/> class with the specified input shapes
    /// and a scalar activation function.
    /// </summary>
    /// <param name="inputShapes">An array of input shapes, all of which must be identical.</param>
    /// <param name="activationFunction">The activation function to apply after processing. Defaults to Identity if not specified.</param>
    /// <exception cref="ArgumentException">Thrown when fewer than two input shapes are provided or when input shapes are not identical.</exception>
    /// <remarks>
    /// <para>
    /// This constructor creates a MultiplyLayer that expects multiple input tensors with identical shapes.
    /// It validates that at least two input shapes are provided and that all shapes are identical, since
    /// element-wise multiplication requires matching dimensions.
    /// </para>
    /// <para><b>For Beginners:</b> This constructor sets up the layer to handle multiple inputs of the same shape.
    /// 
    /// When creating a MultiplyLayer, you need to specify:
    /// - inputShapes: The shapes of all the inputs you'll provide (which must match)
    /// - activationFunction: The function that processes the final output (optional)
    /// 
    /// For example, if you want to multiply three tensors with shape [32, 10, 128]:
    /// - You would specify inputShapes as [[32, 10, 128], [32, 10, 128], [32, 10, 128]]
    /// - The layer would validate that all these shapes match
    /// - The output shape would also be [32, 10, 128]
    /// 
    /// The constructor throws an exception if you provide fewer than two input shapes
    /// or if the shapes don't all match exactly.
    /// </para>
    /// </remarks>
    public MultiplyLayer(int[][] inputShapes, IActivationFunction<T>? activationFunction = null)
        : base(inputShapes, inputShapes[0], activationFunction ?? new IdentityActivation<T>())
    {
        ValidateInputShapes(inputShapes);
    }
    
    /// <summary>
    /// Initializes a new instance of the <see cref="MultiplyLayer{T}"/> class with the specified input shapes
    /// and a vector activation function.
    /// </summary>
    /// <param name="inputShapes">An array of input shapes, all of which must be identical.</param>
    /// <param name="vectorActivationFunction">The vector activation function to apply after processing. Defaults to Identity if not specified.</param>
    /// <exception cref="ArgumentException">Thrown when fewer than two input shapes are provided or when input shapes are not identical.</exception>
    /// <remarks>
    /// <para>
    /// This constructor creates a MultiplyLayer that expects multiple input tensors with identical shapes.
    /// It validates that at least two input shapes are provided and that all shapes are identical, since
    /// element-wise multiplication requires matching dimensions. This overload accepts a vector activation
    /// function, which operates on entire vectors rather than individual elements.
    /// </para>
    /// <para><b>For Beginners:</b> This constructor sets up the layer with a vector-based activation function.
    /// 
    /// A vector activation function:
    /// - Operates on entire groups of numbers at once, rather than one at a time
    /// - Can capture relationships between different elements in the output
    /// - Defaults to the Identity function, which doesn't change the values
    /// 
    /// This constructor is useful when you need more complex activation patterns
    /// that consider the relationships between different values after multiplication.
    /// </para>
    /// </remarks>
    public MultiplyLayer(int[][] inputShapes, IVectorActivationFunction<T>? vectorActivationFunction = null)
        : base(inputShapes, inputShapes[0], vectorActivationFunction ?? new IdentityActivation<T>())
    {
        ValidateInputShapes(inputShapes);
    }
    
    /// <summary>
    /// Validates that the input shapes are appropriate for a multiply layer.
    /// </summary>
    /// <param name="inputShapes">The array of input shapes to validate.</param>
    /// <exception cref="ArgumentException">Thrown when fewer than two input shapes are provided or when input shapes are not identical.</exception>
    /// <remarks>
    /// <para>
    /// This method validates that at least two input shapes are provided and that all shapes are identical.
    /// Element-wise multiplication requires that all tensors have the same dimensions.
    /// </para>
    /// <para><b>For Beginners:</b> This method checks if the input shapes are valid for multiplication.
    /// 
    /// For element-wise multiplication to work:
    /// - You need at least two tensors (you can't multiply just one tensor)
    /// - All tensors must have exactly the same shape (dimensions)
    /// 
    /// For example:
    /// - Valid: Shapes [3,4] and [3,4]
    /// - Invalid: Shapes [3,4] and [3,5] (different second dimension)
    /// - Invalid: Shapes [3,4] and [4,3] (dimensions swapped)
    /// 
    /// If these requirements aren't met, the method throws an exception with a helpful error message.
    /// </para>
    /// </remarks>
    private static void ValidateInputShapes(int[][] inputShapes)
    {
        if (inputShapes.Length < 2)
        {
            throw new ArgumentException("MultiplyLayer requires at least two inputs.");
        }
        for (int i = 1; i < inputShapes.Length; i++)
        {
            if (!inputShapes[i].SequenceEqual(inputShapes[0]))
            {
                throw new ArgumentException("All input shapes must be identical for MultiplyLayer.");
            }
        }
    }
    
    /// <summary>
    /// This method is not supported for MultiplyLayer as it requires multiple input tensors.
    /// </summary>
    /// <param name="input">The input tensor.</param>
    /// <returns>Not applicable as this method throws an exception.</returns>
    /// <exception cref="NotSupportedException">Always thrown when this method is called.</exception>
    /// <remarks>
    /// <para>
    /// This method overrides the base Forward method but is not supported for MultiplyLayer because
    /// element-wise multiplication requires multiple input tensors. Calling this method will always
    /// result in a NotSupportedException.
    /// </para>
    /// <para><b>For Beginners:</b> This method exists to satisfy the base class requirements but should not be used.
    /// 
    /// Since the MultiplyLayer needs multiple input tensors to work properly,
    /// this simplified version that only takes a single input tensor cannot function correctly.
    /// 
    /// If you call this method, you'll get an error message directing you to use the
    /// correct Forward method that accepts multiple input tensors.
    /// 
    /// Always use Forward(params Tensor<T>[] inputs) instead of Forward(input) with this layer.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        throw new NotSupportedException("MultiplyLayer requires multiple inputs. Use Forward(params Tensor<T>[] inputs) instead.");
    }
    
    /// <summary>
    /// Performs the forward pass of the multiply layer with multiple input tensors.
    /// </summary>
    /// <param name="inputs">The array of input tensors to multiply.</param>
    /// <returns>The output tensor after element-wise multiplication and activation.</returns>
    /// <exception cref="ArgumentException">Thrown when fewer than two input tensors are provided.</exception>
    /// <remarks>
    /// <para>
    /// This method implements the forward pass of the multiply layer. It performs element-wise multiplication
    /// of all input tensors, then applies the activation function to the result. The input tensors and output
    /// tensor are cached for use during the backward pass.
    /// </para>
    /// <para><b>For Beginners:</b> This method performs the actual multiplication operation.
    /// 
    /// During the forward pass:
    /// - The method checks that you've provided at least two input tensors
    /// - It makes a copy of the first input tensor as the starting point
    /// - It then multiplies this copy element-by-element with each of the other input tensors
    /// - Finally, it applies the activation function to the result
    /// 
    /// For example, with inputs [1,2,3], [4,5,6], and [0.5,0.5,0.5]:
    /// 1. Start with [1,2,3]
    /// 2. Multiply by [4,5,6] to get [4,10,18]
    /// 3. Multiply by [0.5,0.5,0.5] to get [2,5,9]
    /// 4. Apply activation function (if any)
    /// 
    /// The method also saves all inputs and the output for later use in backpropagation.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(params Tensor<T>[] inputs)
    {
        if (inputs.Length < 2)
        {
            throw new ArgumentException("MultiplyLayer requires at least two inputs.");
        }
        _lastInputs = inputs;
        var result = inputs[0].Copy();
        for (int i = 1; i < inputs.Length; i++)
        {
            result = result.ElementwiseMultiply(inputs[i]);
        }
        _lastOutput = ApplyActivation(result);
        return _lastOutput;
    }
    
    /// <summary>
    /// Performs the backward pass of the multiply layer.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's inputs.</returns>
    /// <exception cref="InvalidOperationException">Thrown when backward is called before forward.</exception>
    /// <remarks>
    /// <para>
    /// This method implements the backward pass of the multiply layer, which is used during training to propagate
    /// error gradients back through the network. For element-wise multiplication, the gradient with respect to
    /// each input is the product of the output gradient and all other inputs. The method calculates and returns
    /// the gradients for all input tensors.
    /// </para>
    /// <para><b>For Beginners:</b> This method calculates how changes in each input affect the final output.
    /// 
    /// During the backward pass:
    /// - The layer receives gradients indicating how the output should change
    /// - It calculates how each input tensor contributed to the output
    /// - For each input, its gradient is the product of:
    ///   - The output gradient (after applying the activation function derivative)
    ///   - All OTHER input tensors (not including itself)
    /// 
    /// This follows the chain rule of calculus for multiplication:
    /// If z = x * y, then:
    /// - dz/dx = y * (gradient flowing back from later layers)
    /// - dz/dy = x * (gradient flowing back from later layers)
    /// 
    /// The method returns a stacked tensor containing gradients for all inputs.
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        if (_lastInputs == null || _lastOutput == null)
        {
            throw new InvalidOperationException("Forward pass must be called before backward pass.");
        }
        var activationGradient = ApplyActivationDerivative(_lastOutput, outputGradient);
        var inputGradients = new Tensor<T>[_lastInputs.Length];
        for (int i = 0; i < _lastInputs.Length; i++)
        {
            inputGradients[i] = activationGradient.Copy();
            for (int j = 0; j < _lastInputs.Length; j++)
            {
                if (i != j)
                {
                    inputGradients[i] = inputGradients[i].ElementwiseMultiply(_lastInputs[j]);
                }
            }
        }
        return Tensor<T>.Stack(inputGradients);
    }
    
    /// <summary>
    /// Updates the parameters of the multiply layer using the calculated gradients.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the parameter updates.</param>
    /// <remarks>
    /// <para>
    /// This method is part of the training process, but since MultiplyLayer has no trainable parameters,
    /// this method does nothing.
    /// </para>
    /// <para><b>For Beginners:</b> This method would normally update a layer's internal values during training.
    /// 
    /// However, since MultiplyLayer just performs a fixed mathematical operation (multiplication) and doesn't
    /// have any internal values that can be learned or adjusted, this method is empty.
    /// 
    /// This is unlike layers such as Dense or Convolutional layers, which have weights and biases
    /// that get updated during training.
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        // No parameters to update in this layer
    }
    
    /// <summary>
    /// Gets all trainable parameters from the multiply layer as a single vector.
    /// </summary>
    /// <returns>An empty vector since MultiplyLayer has no trainable parameters.</returns>
    /// <remarks>
    /// <para>
    /// This method retrieves all trainable parameters from the layer as a single vector. Since MultiplyLayer
    /// has no trainable parameters, it returns an empty vector.
    /// </para>
    /// <para><b>For Beginners:</b> This method returns all the learnable values in the layer.
    /// 
    /// Since MultiplyLayer:
    /// - Only performs fixed mathematical operations (multiplication)
    /// - Has no weights, biases, or other learnable parameters
    /// - The method returns an empty list
    /// 
    /// This is different from layers like Dense layers, which would return their weights and biases.
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // MultiplyLayer has no trainable parameters
        return Vector<T>.Empty();
    }
    
    /// <summary>
    /// Resets the internal state of the multiply layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method resets the internal state of the multiply layer, including the cached inputs and output.
    /// This is useful when starting to process a new sequence or batch of data.
    /// </para>
    /// <para><b>For Beginners:</b> This method clears the layer's memory to start fresh.
    /// 
    /// When resetting the state:
    /// - Stored inputs and outputs from previous processing are cleared
    /// - The layer forgets any information from previous data batches
    /// 
    /// This is important for:
    /// - Processing a new, unrelated batch of data
    /// - Ensuring clean state before a new training epoch
    /// - Preventing information from one batch affecting another
    /// 
    /// While the MultiplyLayer doesn't maintain long-term state across samples,
    /// clearing these cached values helps with memory management and ensuring a clean processing pipeline.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // Clear cached values from forward pass
        _lastInputs = null;
        _lastOutput = null;
    }
}