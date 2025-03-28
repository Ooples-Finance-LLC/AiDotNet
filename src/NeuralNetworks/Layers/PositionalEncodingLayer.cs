namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a layer that adds positional encodings to input sequences.
/// </summary>
/// <remarks>
/// <para>
/// The PositionalEncodingLayer adds position-dependent signals to input embeddings, which helps
/// sequence models like Transformers understand the order of elements in a sequence. Since
/// attention-based models have no inherent notion of sequence order, positional encodings
/// provide this critical information. The encodings use sine and cosine functions of different
/// frequencies to create unique position-dependent patterns.
/// </para>
/// <para><b>For Beginners:</b> This layer adds information about position to your sequence data.
/// 
/// Think of it like numbering the words in a sentence:
/// - Without position information, a model only knows which words are in the sentence
/// - With position information, it knows which word comes first, second, third, etc.
/// 
/// For example, the sentences "dog bites man" and "man bites dog" contain the same words
/// but have completely different meanings because of word order. Positional encoding
/// helps models understand this difference.
/// 
/// The layer uses a clever mathematical pattern of sine and cosine waves to encode positions.
/// This approach has several advantages:
/// - It creates a unique pattern for each position
/// - Similar positions have similar encodings (helpful for generalization)
/// - It can potentially handle sequences longer than those seen during training
/// - The encodings have consistent patterns that models can learn from
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class PositionalEncodingLayer<T> : LayerBase<T>
{
    /// <summary>
    /// The maximum sequence length that this layer can handle.
    /// </summary>
    /// <remarks>
    /// This field defines the upper limit on sequence length. Sequences longer than this value
    /// will cause an exception when passed through the layer.
    /// </remarks>
    private readonly int maxSequenceLength;
    
    /// <summary>
    /// The size of each embedding vector.
    /// </summary>
    /// <remarks>
    /// This field specifies the dimensionality of the embedding vectors to which
    /// positional encodings will be added.
    /// </remarks>
    private readonly int embeddingSize;
    
    /// <summary>
    /// The pre-computed positional encodings tensor.
    /// </summary>
    /// <remarks>
    /// This tensor stores the pre-computed positional encodings for all possible positions
    /// up to maxSequenceLength. The encodings are calculated once during initialization
    /// and reused for all forward passes.
    /// </remarks>
    private Tensor<T> encodings;
    
    /// <summary>
    /// Gets a value indicating whether this layer supports training.
    /// </summary>
    /// <value>
    /// Always <c>true</c> because the PositionalEncodingLayer supports backpropagation, even though it has no trainable parameters.
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates whether the layer supports backpropagation during training. Although
    /// the PositionalEncodingLayer has no trainable parameters, it still supports the backward pass to propagate
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
    /// Initializes a new instance of the <see cref="PositionalEncodingLayer{T}"/> class with the specified maximum sequence length and embedding size.
    /// </summary>
    /// <param name="maxSequenceLength">The maximum sequence length that this layer can handle.</param>
    /// <param name="embeddingSize">The size of each embedding vector.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a PositionalEncodingLayer with the specified maximum sequence length and embedding size.
    /// It initializes the positional encodings using sine and cosine functions of different frequencies, following
    /// the formula from the "Attention Is All You Need" paper.
    /// </para>
    /// <para><b>For Beginners:</b> This constructor sets up the layer with the necessary dimensions.
    /// 
    /// When creating a PositionalEncodingLayer, you need to specify:
    /// - maxSequenceLength: The longest sequence your model will handle (e.g., 512 for text processing)
    /// - embeddingSize: The size of your embedding vectors (e.g., 512 or 768 dimensions)
    /// 
    /// During initialization, the layer pre-calculates all the positional encodings using
    /// the sine/cosine formula. This is more efficient than calculating them each time.
    /// 
    /// The formula alternates between sine and cosine functions across the embedding dimensions,
    /// with different frequencies for different dimensions. This creates a unique pattern for each
    /// position that the model can learn to recognize.
    /// </para>
    /// </remarks>
    public PositionalEncodingLayer(int maxSequenceLength, int embeddingSize)
        : base([maxSequenceLength, embeddingSize], [maxSequenceLength, embeddingSize])
    {
        this.maxSequenceLength = maxSequenceLength;
        this.embeddingSize = embeddingSize;
        encodings = new Tensor<T>([maxSequenceLength, embeddingSize]);
        InitializeEncodings();
    }
    
    /// <summary>
    /// Initializes the positional encodings using sine and cosine functions.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method initializes the positional encodings tensor using sine and cosine functions
    /// of different frequencies. For each position and embedding dimension, it calculates the
    /// appropriate value based on the formula from the "Attention Is All You Need" paper:
    /// PE(pos, 2i) = sin(pos / 10000^(2i/d_model))
    /// PE(pos, 2i+1) = cos(pos / 10000^(2i/d_model))
    /// </para>
    /// <para><b>For Beginners:</b> This method creates the pattern of numbers that encodes position information.
    /// 
    /// The method uses a specific mathematical formula to create a unique pattern for each position:
    /// - Even-indexed dimensions (0, 2, 4, ...) use sine functions
    /// - Odd-indexed dimensions (1, 3, 5, ...) use cosine functions
    /// - Different dimensions use different frequencies
    /// 
    /// This creates a unique "fingerprint" for each position that:
    /// - Changes smoothly as you move along the sequence
    /// - Has different patterns across different dimensions
    /// - Can be easily learned by neural networks
    /// 
    /// The formula with 10000 and sine/cosine was carefully chosen by researchers
    /// to have good mathematical properties for representing sequence positions.
    /// </para>
    /// </remarks>
    private void InitializeEncodings()
    {
        for (int pos = 0; pos < maxSequenceLength; pos++)
        {
            for (int i = 0; i < embeddingSize; i++)
            {
                double angle = pos / Math.Pow(10000, (2 * (i / 2)) / (double)embeddingSize);
                if (i % 2 == 0)
                {
                    encodings[pos, i] = NumOps.FromDouble(Math.Sin(angle));
                }
                else
                {
                    encodings[pos, i] = NumOps.FromDouble(Math.Cos(angle));
                }
            }
        }
    }
    
    /// <summary>
    /// Performs the forward pass of the positional encoding layer.
    /// </summary>
    /// <param name="input">The input tensor to process.</param>
    /// <returns>The output tensor with positional encodings added.</returns>
    /// <exception cref="ArgumentException">Thrown when the input sequence length exceeds the maximum sequence length.</exception>
    /// <remarks>
    /// <para>
    /// This method implements the forward pass of the positional encoding layer. It first checks that
    /// the input sequence length does not exceed the maximum allowed length. Then, it slices the
    /// pre-computed encodings tensor to match the input sequence length and adds the encodings to
    /// the input tensor element-wise.
    /// </para>
    /// <para><b>For Beginners:</b> This method adds the position information to your input data.
    /// 
    /// During the forward pass:
    /// - The method checks that your sequence isn't too long
    /// - It takes the appropriate slice of the pre-computed encodings
    ///   (matching the length of your input sequence)
    /// - It adds these encodings directly to your input data
    /// 
    /// The addition operation combines your original data (like word embeddings)
    /// with the position information, allowing the model to use both.
    /// 
    /// For example, if your input is word embeddings for "The cat sat on the mat",
    /// after this layer, each word's embedding will also contain information about
    /// which position in the sentence it occupies.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        if (input.Shape[0] > maxSequenceLength)
        {
            throw new ArgumentException($"Input sequence length {input.Shape[0]} exceeds maximum sequence length {maxSequenceLength}");
        }
        var slicedEncodings = encodings.Slice(0, 0, input.Shape[0], embeddingSize);
        return input + slicedEncodings;
    }
    
    /// <summary>
    /// Performs the backward pass of the positional encoding layer.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's input.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the backward pass of the positional encoding layer. Since the layer
    /// simply adds fixed positional encodings to the input, the gradient flows through unchanged.
    /// The gradient of the addition operation with respect to the input is just the gradient of
    /// the output.
    /// </para>
    /// <para><b>For Beginners:</b> This method handles how gradients flow backward through this layer.
    /// 
    /// During the backward pass:
    /// - The layer receives gradients indicating how the output should change
    /// - Since this layer just adds fixed positional encodings to the input,
    ///   any change in the output should directly affect the input in the same way
    /// - So the gradients are passed back unchanged
    /// 
    /// This makes sense because:
    /// - The derivative of (x + constant) with respect to x is 1
    /// - So the gradient flows through addition operations unchanged
    /// - The positional encodings are constants that don't change during training
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        // The gradient flows through unchanged
        return outputGradient;
    }
    
    /// <summary>
    /// Updates the parameters of the positional encoding layer using the calculated gradients.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the parameter updates.</param>
    /// <remarks>
    /// <para>
    /// This method is part of the training process, but since PositionalEncodingLayer has no trainable parameters,
    /// this method does nothing. The positional encodings are fixed and do not change during training.
    /// </para>
    /// <para><b>For Beginners:</b> This method would normally update a layer's internal values during training.
    /// 
    /// However, since PositionalEncodingLayer uses fixed encodings that are calculated once at initialization
    /// and don't change during training, this method is empty.
    /// 
    /// This is different from layers like Dense or Convolutional layers, which have weights and biases
    /// that get updated during training. The positional encodings are based on a mathematical formula
    /// rather than learned from data.
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        // No parameters to update in this layer
    }
    
    /// <summary>
    /// Gets all trainable parameters from the positional encoding layer as a single vector.
    /// </summary>
    /// <returns>An empty vector since PositionalEncodingLayer has no trainable parameters.</returns>
    /// <remarks>
    /// <para>
    /// This method retrieves all trainable parameters from the layer as a single vector. Since PositionalEncodingLayer
    /// has no trainable parameters, it returns an empty vector. The positional encodings are fixed values
    /// determined by a mathematical formula, not learnable parameters.
    /// </para>
    /// <para><b>For Beginners:</b> This method returns all the learnable values in the layer.
    /// 
    /// Since PositionalEncodingLayer:
    /// - Uses fixed encodings based on a mathematical formula
    /// - Has no weights, biases, or other learnable parameters
    /// - The method returns an empty list
    /// 
    /// This is different from layers like Dense layers, which would return their weights and biases.
    /// The positional encodings are fixed by design and don't need to be learned from data.
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // PositionalEncodingLayer has no trainable parameters
        return Vector<T>.Empty();
    }
    
    /// <summary>
    /// Resets the internal state of the positional encoding layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method is intended to reset any internal state that might change during training or inference.
    /// However, since PositionalEncodingLayer has no state that changes (the encodings are fixed),
    /// this method does nothing.
    /// </para>
    /// <para><b>For Beginners:</b> This method would normally clear the layer's memory to start fresh.
    /// 
    /// However, since PositionalEncodingLayer doesn't maintain any changing state during processing
    /// (the encodings are fixed at initialization and don't change), this method is empty.
    /// 
    /// The encodings tensor is a fixed part of the layer that remains constant throughout
    /// the lifetime of the layer, so there's nothing to reset.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // No state to reset in this layer
        // The encodings are fixed and don't change during training
    }
}