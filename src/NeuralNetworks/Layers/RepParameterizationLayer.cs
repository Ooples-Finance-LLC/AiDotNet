namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a reparameterization layer used in variational autoencoders (VAEs) to enable backpropagation through random sampling.
/// </summary>
/// <remarks>
/// <para>
/// The RepParameterizationLayer implements the reparameterization trick commonly used in variational autoencoders.
/// It takes an input tensor that contains means and log variances of a latent distribution, samples from this
/// distribution using the reparameterization trick, and outputs the sampled values. This approach allows
/// gradients to flow through the random sampling process, which is essential for training VAEs.
/// </para>
/// <para><b>For Beginners:</b> This layer is a special component used in variational autoencoders (VAEs).
/// 
/// Think of the RepParameterizationLayer as a clever randomizer with memory:
/// - It takes information about a range of possible values (represented by mean and variance)
/// - It generates random samples from this range
/// - It remembers how it generated these samples so it can learn during training
/// 
/// For example, in a VAE generating faces:
/// - Input might represent "average nose size is 5 with variation of �2"
/// - This layer randomly picks a specific nose size (like 6.3) based on those statistics
/// - But it does this in a way that allows the network to learn better statistics
/// 
/// The "reparameterization trick" is what makes this possible - it separates the random sampling
/// (which can't be directly learned from) from the statistical parameters (which can be learned).
/// 
/// This layer is crucial for variational autoencoders to learn meaningful latent representations
/// while still incorporating randomness, which helps with generating diverse outputs.
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class RepParameterizationLayer<T> : LayerBase<T>
{
    /// <summary>
    /// Stores the mean values extracted from the input tensor during the forward pass.
    /// </summary>
    /// <remarks>
    /// This tensor holds the mean values for each dimension of the latent space for each item in the batch.
    /// It represents the center of the distribution from which samples are drawn. The tensor is null
    /// before the first forward pass or after a reset.
    /// </remarks>
    private Tensor<T>? _lastMean;
    
    /// <summary>
    /// Stores the log variance values extracted from the input tensor during the forward pass.
    /// </summary>
    /// <remarks>
    /// This tensor holds the log variance values for each dimension of the latent space for each item in the batch.
    /// Log variance is used instead of variance for numerical stability. It represents the spread of the
    /// distribution from which samples are drawn. The tensor is null before the first forward pass or after a reset.
    /// </remarks>
    private Tensor<T>? _lastLogVar;
    
    /// <summary>
    /// Stores the random noise values used during the sampling process in the forward pass.
    /// </summary>
    /// <remarks>
    /// This tensor holds the random noise values (epsilon) drawn from a standard normal distribution
    /// during the forward pass. These values are used to generate samples from the parameterized
    /// distribution. Saving these values is necessary for the backward pass. The tensor is null
    /// before the first forward pass or after a reset.
    /// </remarks>
    private Tensor<T>? _lastEpsilon;

    /// <summary>
    /// Gets a value indicating whether this layer supports training.
    /// </summary>
    /// <value>
    /// Always <c>true</c> for RepParameterizationLayer, indicating that the layer can be trained through backpropagation.
    /// </value>
    /// <remarks>
    /// <para>
    /// This property indicates that the RepParameterizationLayer can propagate gradients during backpropagation.
    /// Although this layer does not have trainable parameters itself, it needs to participate in the training process
    /// by correctly propagating gradients to previous layers.
    /// </para>
    /// <para><b>For Beginners:</b> This property tells you if the layer can participate in the learning process.
    /// 
    /// A value of true means:
    /// - The layer can pass learning signals (gradients) backward through it
    /// - It contributes to the training of the entire network
    /// 
    /// While this layer doesn't have any internal values that it learns directly,
    /// it's designed to let learning signals flow through it to previous layers.
    /// This is critical for training a variational autoencoder.
    /// </para>
    /// </remarks>
    public override bool SupportsTraining => true;

    /// <summary>
    /// Initializes a new instance of the <see cref="RepParameterizationLayer{T}"/> class.
    /// </summary>
    /// <param name="inputShape">The shape of the input tensor. The first dimension is the batch size, and the second dimension must be even (half for means, half for log variances).</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a new RepParameterizationLayer with the specified input shape. The output shape
    /// is set to match the input shape except for the second dimension, which is halved since the output
    /// contains only the sampled values, not both means and log variances.
    /// </para>
    /// <para><b>For Beginners:</b> This creates a new reparameterization layer for your variational autoencoder.
    /// 
    /// When you create this layer, you specify:
    /// - inputShape: The shape of the data coming into the layer
    /// 
    /// The input is expected to contain two parts:
    /// - The first half contains the mean values for each latent dimension
    /// - The second half contains the log variance values for each latent dimension
    /// 
    /// For example, if inputShape[1] is 100, then:
    /// - The first 50 values represent means
    /// - The last 50 values represent log variances
    /// - The output will have 50 values (the sampled points)
    /// 
    /// This layer doesn't have any trainable parameters - it just performs the reparameterization operation.
    /// </para>
    /// </remarks>
    public RepParameterizationLayer(int[] inputShape)
        : base(inputShape, inputShape)
    {
    }

    /// <summary>
    /// Performs the forward pass of the reparameterization layer.
    /// </summary>
    /// <param name="input">The input tensor containing concatenated mean and log variance values.</param>
    /// <returns>The output tensor containing sampled points from the latent distribution.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the forward pass of the reparameterization layer. It splits the input tensor
    /// into mean and log variance parts, generates random noise (epsilon) from a standard normal distribution,
    /// and uses the reparameterization trick (z = mean + std_dev * epsilon) to sample from the latent distribution.
    /// The input, means, log variances, and epsilon values are cached for use during the backward pass.
    /// </para>
    /// <para><b>For Beginners:</b> This method samples random points from your specified distribution.
    /// 
    /// During the forward pass:
    /// 1. The layer separates the input into mean values and log variance values
    /// 2. It generates random noise values (epsilon) from a standard normal distribution
    /// 3. It calculates standard deviation values from the log variances
    /// 4. It produces samples using the formula: sample = mean + (std_dev * epsilon)
    /// 
    /// This reparameterization trick is clever because:
    /// - The randomness comes from epsilon, which is independent of what the network is learning
    /// - The mean and standard deviation can be learned and improved through backpropagation
    /// - During inference, you can either use random samples or just use the mean values
    /// 
    /// The layer saves all intermediate values for later use during training.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        int batchSize = input.Shape[0];
        int latentSize = input.Shape[1] / 2;
        _lastMean = new Tensor<T>([batchSize, latentSize]);
        _lastLogVar = new Tensor<T>([batchSize, latentSize]);
        for (int i = 0; i < batchSize; i++)
        {
            for (int j = 0; j < latentSize; j++)
            {
                _lastMean[i, j] = input[i, j];
                _lastLogVar[i, j] = input[i, j + latentSize];
            }
        }
        _lastEpsilon = new Tensor<T>([batchSize, latentSize]);
        var output = new Tensor<T>([batchSize, latentSize]);
        for (int i = 0; i < batchSize; i++)
        {
            for (int j = 0; j < latentSize; j++)
            {
                _lastEpsilon[i, j] = NumOps.FromDouble(Random.NextDouble());
                T stdDev = NumOps.Exp(NumOps.Multiply(_lastLogVar[i, j], NumOps.FromDouble(0.5)));
                output[i, j] = NumOps.Add(_lastMean[i, j], NumOps.Multiply(stdDev, _lastEpsilon[i, j]));
            }
        }
        return output;
    }

    /// <summary>
    /// Performs the backward pass of the reparameterization layer.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's input (means and log variances).</returns>
    /// <exception cref="InvalidOperationException">Thrown when backward is called before forward.</exception>
    /// <remarks>
    /// <para>
    /// This method implements the backward pass of the reparameterization layer, which is used during training
    /// to propagate error gradients back through the network. It calculates the gradients with respect to
    /// the means and log variances based on the gradients of the output. The gradient flow through the
    /// random sampling process is what makes the reparameterization trick valuable for training.
    /// </para>
    /// <para><b>For Beginners:</b> This method calculates how changes in the means and variances would affect the loss.
    /// 
    /// During the backward pass:
    /// 1. The layer receives gradients indicating how the network's output should change
    /// 2. It calculates how changes in the mean values would affect the output
    /// 3. It calculates how changes in the log variance values would affect the output
    /// 4. It combines these into gradients for the original input (means and log variances)
    /// 
    /// The gradient for means is straightforward - changes in the mean directly affect the output.
    /// The gradient for log variances is more complex because it controls the scale of the random noise.
    /// 
    /// This backward flow of information is what allows a VAE to learn good latent representations
    /// even though it involves random sampling.
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        if (_lastMean == null || _lastLogVar == null || _lastEpsilon == null)
            throw new InvalidOperationException("Forward pass must be called before backward pass.");
        int batchSize = outputGradient.Shape[0];
        int latentSize = outputGradient.Shape[1];
        var inputGradient = new Tensor<T>([batchSize, latentSize * 2]);
        for (int i = 0; i < batchSize; i++)
        {
            for (int j = 0; j < latentSize; j++)
            {
                T stdDev = NumOps.Exp(NumOps.Multiply(_lastLogVar[i, j], NumOps.FromDouble(0.5)));
                
                // Gradient for mean
                inputGradient[i, j] = outputGradient[i, j];
                // Gradient for log variance
                T gradLogVar = NumOps.Multiply(
                    NumOps.Multiply(outputGradient[i, j], _lastEpsilon[i, j]),
                    NumOps.Multiply(stdDev, NumOps.FromDouble(0.5))
                );
                inputGradient[i, j + latentSize] = gradLogVar;
            }
        }
        return inputGradient;
    }

    /// <summary>
    /// Updates the parameters of the reparameterization layer.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the parameter updates.</param>
    /// <remarks>
    /// <para>
    /// This method is required by the LayerBase class but does nothing in the RepParameterizationLayer
    /// because this layer has no trainable parameters to update. The learning happens in the encoder
    /// network that produces the means and log variances.
    /// </para>
    /// <para><b>For Beginners:</b> This method is empty because the layer has no internal values to update.
    /// 
    /// Unlike most layers in a neural network, the reparameterization layer doesn't have any
    /// weights or biases that need to be adjusted during training. It's more like a mathematical
    /// operation that passes gradients through.
    /// 
    /// The actual learning happens in:
    /// - The encoder network that produces the means and log variances
    /// - The decoder network that processes the samples this layer produces
    /// 
    /// This method exists only because all layers in the network must implement it.
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        // No parameters to update in this layer
    }

    /// <summary>
    /// Gets all trainable parameters of the reparameterization layer as a single vector.
    /// </summary>
    /// <returns>An empty vector since this layer has no trainable parameters.</returns>
    /// <remarks>
    /// <para>
    /// This method returns an empty vector because the RepParameterizationLayer has no trainable parameters.
    /// The method is required by the LayerBase class but is essentially a no-op for this layer.
    /// </para>
    /// <para><b>For Beginners:</b> This method returns an empty list because the layer has no learnable values.
    /// 
    /// As mentioned earlier, the reparameterization layer doesn't have any weights or biases
    /// that it learns during training. It just performs the sampling operation and passes
    /// gradients through.
    /// 
    /// This method returns an empty vector to indicate that there are no parameters to retrieve.
    /// It exists only because all layers in the network must implement it.
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // This layer has no trainable parameters, so return an empty vector
        return Vector<T>.Empty();
    }

    /// <summary>
    /// Resets the internal state of the reparameterization layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method resets the internal state of the reparameterization layer, including the cached means,
    /// log variances, and epsilon values from the forward pass. This is useful when starting to process
    /// a new batch of data.
    /// </para>
    /// <para><b>For Beginners:</b> This method clears the layer's memory to start fresh.
    /// 
    /// When resetting the state:
    /// - Stored means, log variances, and random noise values are cleared
    /// - The layer forgets any information from previous batches
    /// 
    /// This is important for:
    /// - Processing a new, unrelated batch of data
    /// - Preventing information from one batch affecting another
    /// - Starting a new training episode
    /// 
    /// Since this layer has no learned parameters, resetting just clears the temporary
    /// values used during the forward and backward passes.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // Clear cached values from forward and backward passes
        _lastMean = null;
        _lastLogVar = null;
        _lastEpsilon = null;
    }
}