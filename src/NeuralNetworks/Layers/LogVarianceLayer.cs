namespace AiDotNet.NeuralNetworks.Layers;

/// <summary>
/// Represents a layer that computes the logarithm of variance along a specified axis in the input tensor.
/// </summary>
/// <remarks>
/// <para>
/// The LogVarianceLayer calculates the statistical variance of values along a specified axis of the input tensor,
/// and then computes the natural logarithm of that variance. This is often used in neural networks for calculating
/// statistical measures, normalizing data, or as part of variational autoencoders (VAEs).
/// </para>
/// <para><b>For Beginners:</b> This layer measures how much the values in your data spread out from their average (variance),
/// and then takes the logarithm of that spread.
/// 
/// Think of it like measuring how consistent or varied your data is:
/// - Low values mean the data points are very similar to each other
/// - High values mean the data points vary widely
/// 
/// For example, if you have a set of images:
/// - Images that are very similar would produce low log-variance
/// - Images that are very different would produce high log-variance
/// 
/// This is often used in AI models that need to understand the variation in the data,
/// such as in models that generate new data similar to what they've been trained on.
/// </para>
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations, typically float or double.</typeparam>
public class LogVarianceLayer<T> : LayerBase<T>
{
    /// <summary>
    /// Gets the axis along which the variance is calculated.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This property indicates the dimension of the input tensor along which the variance will be calculated.
    /// For example, if Axis is 1 and the input tensor has shape [batch, features], the variance will be calculated
    /// across the features dimension, resulting in one variance value per batch item.
    /// </para>
    /// <para><b>For Beginners:</b> This tells the layer which direction to look when calculating variance.
    /// 
    /// For example, with a 2D data array (like a table):
    /// - Axis 0 means calculate variance down each column
    /// - Axis 1 means calculate variance across each row
    /// 
    /// The value depends on how your data is organized and what kind of variance you want to measure.
    /// </para>
    /// </remarks>
    public int Axis { get; private set; }

    /// <summary>
    /// Gets a value indicating whether this layer supports training through backpropagation.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This property returns false because the LogVarianceLayer does not have any trainable parameters,
    /// though it does support backward pass for gradient propagation through the network.
    /// </para>
    /// <para><b>For Beginners:</b> This tells you if the layer can learn from training data.
    /// 
    /// A value of false means:
    /// - This layer doesn't have any values that get updated during training
    /// - It performs a fixed mathematical calculation (log of variance)
    /// - However, during training, it still helps gradients flow backward through the network
    /// </para>
    /// </remarks>
    public override bool SupportsTraining => false;

    /// <summary>
    /// The input tensor from the last forward pass.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field stores the input tensor from the most recent forward pass. It is needed during the backward pass
    /// to compute gradients correctly. This field is reset when ResetState is called.
    /// </para>
    /// <para><b>For Beginners:</b> This stores the most recent data that was fed into the layer.
    /// 
    /// The layer needs to remember the input:
    /// - To calculate how each input value affected the output
    /// - To determine how to propagate gradients during training
    /// - To ensure the backward pass works correctly
    /// </para>
    /// </remarks>
    private Tensor<T>? _lastInput;

    /// <summary>
    /// The output tensor from the last forward pass.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field stores the output tensor from the most recent forward pass. It is needed during the backward pass
    /// because the derivative of the logarithm function depends on the output value. This field is reset when ResetState is called.
    /// </para>
    /// <para><b>For Beginners:</b> This stores the most recent result that came out of the layer.
    /// 
    /// The layer needs to remember its output:
    /// - Because the derivative of log(x) is 1/x, so we need x (our output) during backpropagation
    /// - To avoid recalculating values during the backward pass
    /// - To make the training process more efficient
    /// </para>
    /// </remarks>
    private Tensor<T>? _lastOutput;

    /// <summary>
    /// The mean values calculated during the last forward pass.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This field stores the mean values calculated during the most recent forward pass. These values are needed
    /// during both the variance calculation and the backward pass. This field is reset when ResetState is called.
    /// </para>
    /// <para><b>For Beginners:</b> This stores the average values calculated during the first step.
    /// 
    /// The layer needs to remember these mean values:
    /// - They're used when calculating the variance (which measures deviation from the mean)
    /// - They're needed again during the backward pass
    /// - Storing them avoids having to recalculate them multiple times
    /// 
    /// Think of it as saving an intermediate result that will be reused later.
    /// </para>
    /// </remarks>
    private Tensor<T>? _meanValues;

    /// <summary>
    /// Initializes a new instance of the <see cref="LogVarianceLayer{T}"/> class.
    /// </summary>
    /// <param name="inputShape">The shape of the input tensor.</param>
    /// <param name="axis">The axis along which to calculate variance.</param>
    /// <remarks>
    /// <para>
    /// This constructor creates a LogVarianceLayer that will calculate the variance along the specified axis
    /// of the input tensor. The output shape is determined by removing the specified axis from the input shape.
    /// </para>
    /// <para><b>For Beginners:</b> This creates a new log-variance layer with your desired settings.
    /// 
    /// When setting up this layer:
    /// - inputShape defines the expected size and dimensions of your data
    /// - axis specifies which dimension to calculate variance along
    /// 
    /// The layer will reduce the data along the specified axis, meaning the output
    /// will have one fewer dimension than the input.
    /// </para>
    /// </remarks>
    public LogVarianceLayer(int[] inputShape, int axis)
        : base(inputShape, CalculateOutputShape(inputShape, axis))
    {
        Axis = axis;
    }

    /// <summary>
    /// Calculates the output shape of the log-variance layer based on the input shape and the axis along which variance is calculated.
    /// </summary>
    /// <param name="inputShape">The shape of the input tensor.</param>
    /// <param name="axis">The axis along which to calculate variance.</param>
    /// <returns>The calculated output shape for the log-variance layer.</returns>
    /// <remarks>
    /// <para>
    /// This method calculates the output shape by removing the dimension specified by the axis parameter
    /// from the input shape. This is because the variance calculation reduces the data along that axis.
    /// </para>
    /// <para><b>For Beginners:</b> This method figures out the shape of the data that will come out of this layer.
    /// 
    /// When calculating variance along an axis:
    /// - That dimension gets "collapsed" into a single value
    /// - The output shape has one fewer dimension than the input
    /// 
    /// For example, if your input has shape [10, 20, 30] (a 3D array) and you calculate 
    /// variance along axis 1, the output shape would be [10, 30].
    /// </para>
    /// </remarks>
    private static int[] CalculateOutputShape(int[] inputShape, int axis)
    {
        var outputShape = new int[inputShape.Length - 1];
        int outputIndex = 0;
        for (int i = 0; i < inputShape.Length; i++)
        {
            if (i != axis)
            {
                outputShape[outputIndex++] = inputShape[i];
            }
        }

        return outputShape;
    }

    /// <summary>
    /// Performs the forward pass of the log-variance layer.
    /// </summary>
    /// <param name="input">The input tensor.</param>
    /// <returns>A tensor containing the log-variance values.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the forward pass of the log-variance calculation. It first computes the mean along
    /// the specified axis, then calculates the variance by summing squared differences from the mean, and finally
    /// takes the natural logarithm of the variance (with a small epsilon added for numerical stability).
    /// </para>
    /// <para><b>For Beginners:</b> This method processes your data through the layer, calculating the log-variance.
    /// 
    /// The calculation happens in these steps:
    /// 1. Calculate the average (mean) of values along the specified axis
    /// 2. For each value, find how far it is from the average
    /// 3. Square these differences and add them up
    /// 4. Divide by the number of values to get the variance
    /// 5. Take the natural logarithm of the variance
    /// 
    /// A small value (epsilon) is added to prevent errors when taking the logarithm of zero or very small numbers.
    /// </para>
    /// </remarks>
    public override Tensor<T> Forward(Tensor<T> input)
    {
        _lastInput = input;
        var output = new Tensor<T>(OutputShape);
        _meanValues = new Tensor<T>(OutputShape);

        int axisSize = input.Shape[Axis];
        T axisScale = NumOps.FromDouble(1.0 / axisSize);

        // Compute mean
        var indices = new int[input.Shape.Length];
        IterateOverDimensions(input, _meanValues, indices, 0, Axis, (input, mean, indices) =>
        {
            T sum = NumOps.Zero;
            for (int i = 0; i < axisSize; i++)
            {
                indices[Axis] = i;
                sum = NumOps.Add(sum, input[indices]);
            }
            mean[indices] = NumOps.Multiply(sum, axisScale);
        });

        // Compute log variance
        IterateOverDimensions(input, output, indices, 0, Axis, (input, output, indices) =>
        {
            T sumSquaredDiff = NumOps.Zero;
            T mean = _meanValues[indices];
            for (int i = 0; i < axisSize; i++)
            {
                indices[Axis] = i;
                T diff = NumOps.Subtract(input[indices], mean);
                sumSquaredDiff = NumOps.Add(sumSquaredDiff, NumOps.Square(diff));
            }
            T variance = NumOps.Multiply(sumSquaredDiff, axisScale);
            output[indices] = NumOps.Log(NumOps.Add(variance, NumOps.FromDouble(1e-8))); // Add small epsilon for numerical stability
        });

        _lastOutput = output;
        return output;
    }

    /// <summary>
    /// Performs the backward pass of the log-variance layer.
    /// </summary>
    /// <param name="outputGradient">The gradient of the loss with respect to the layer's output.</param>
    /// <returns>The gradient of the loss with respect to the layer's input.</returns>
    /// <remarks>
    /// <para>
    /// This method implements the backward pass of the log-variance layer, which is used during training to propagate
    /// error gradients backward through the network. It calculates how changes in the output affect the input, 
    /// taking into account the derivatives of the logarithm and variance calculations.
    /// </para>
    /// <para><b>For Beginners:</b> This method is used during training to calculate how changes in the output
    /// would affect the input.
    /// 
    /// During the backward pass:
    /// - The layer receives information about how its output affected the overall error
    /// - It calculates how each input value contributed to that error
    /// - This information is passed backward to earlier layers
    /// 
    /// The mathematics here are complex but involve the chain rule from calculus:
    /// - For the log function: the derivative is 1/x
    /// - For variance: it involves how each value's difference from the mean contributed
    /// 
    /// This process is part of how neural networks learn from their mistakes.
    /// </para>
    /// </remarks>
    public override Tensor<T> Backward(Tensor<T> outputGradient)
    {
        if (_lastInput == null || _lastOutput == null || _meanValues == null)
            throw new InvalidOperationException("Forward pass must be called before backward pass.");

        var inputGradient = new Tensor<T>(_lastInput.Shape);
        int axisSize = _lastInput.Shape[Axis];
        T axisScale = NumOps.FromDouble(1.0 / axisSize);

        var indices = new int[_lastInput.Shape.Length];
        IterateOverDimensions(_lastInput, outputGradient, indices, 0, Axis, (input, outputGrad, indices) =>
        {
            T mean = _meanValues[indices];
            T variance = NumOps.Exp(_lastOutput[indices]);
            T gradScale = NumOps.Divide(outputGrad[indices], variance);

            for (int i = 0; i < axisSize; i++)
            {
                indices[Axis] = i;
                T diff = NumOps.Subtract(input[indices], mean);
                T grad = NumOps.Multiply(NumOps.Multiply(diff, gradScale), NumOps.FromDouble(2.0 / axisSize));
                inputGradient[indices] = grad;
            }
        });

        return inputGradient;
    }

    /// <summary>
    /// Updates the parameters of the layer based on the calculated gradients.
    /// </summary>
    /// <param name="learningRate">The learning rate to use for the parameter updates.</param>
    /// <remarks>
    /// <para>
    /// This method is empty because the LogVarianceLayer has no trainable parameters to update.
    /// However, it must be implemented to satisfy the base class contract.
    /// </para>
    /// <para><b>For Beginners:</b> This method would normally update the layer's internal values during training.
    /// 
    /// However, since this layer doesn't have any trainable parameters:
    /// - There's nothing to update
    /// - The method exists but doesn't do anything
    /// - This is normal for layers that perform fixed mathematical operations
    /// </para>
    /// </remarks>
    public override void UpdateParameters(T learningRate)
    {
        // LogVarianceLayer has no learnable parameters, so this method is empty
    }

    /// <summary>
    /// Recursively iterates over all dimensions of a tensor except for the specified dimension to apply an action.
    /// </summary>
    /// <param name="input">The input tensor.</param>
    /// <param name="output">The output tensor.</param>
    /// <param name="indices">The current indices being processed.</param>
    /// <param name="currentDim">The current dimension being processed.</param>
    /// <param name="skipDim">The dimension to skip (the axis along which variance is calculated).</param>
    /// <param name="action">The action to apply at each position.</param>
    /// <remarks>
    /// <para>
    /// This utility method enables efficient processing of multi-dimensional tensors by recursively iterating through
    /// all dimensions except the one specified by skipDim. At each valid position, it applies the provided action
    /// delegate, which performs the actual computation.
    /// </para>
    /// <para><b>For Beginners:</b> This method is a helper that visits every relevant position in your data.
    /// 
    /// Imagine your data as a multi-dimensional grid (like a spreadsheet with extra dimensions):
    /// - This method navigates through all the positions in that grid
    /// - It skips the dimension you're calculating variance along
    /// - At each position, it applies the calculation you specified
    /// 
    /// This is a recursive function, meaning it calls itself repeatedly to handle each dimension.
    /// This approach helps process complex multi-dimensional data efficiently.
    /// </para>
    /// </remarks>
    private void IterateOverDimensions(Tensor<T> input, Tensor<T> output, int[] indices, int currentDim, int skipDim, Action<Tensor<T>, Tensor<T>, int[]> action)
    {
        if (currentDim == input.Shape.Length)
        {
            action(input, output, indices);
            return;
        }

        if (currentDim == skipDim)
        {
            IterateOverDimensions(input, output, indices, currentDim + 1, skipDim, action);
        }
        else
        {
            for (int i = 0; i < input.Shape[currentDim]; i++)
            {
                indices[currentDim] = i;
                IterateOverDimensions(input, output, indices, currentDim + 1, skipDim, action);
            }
        }
    }

    /// <summary>
    /// Gets all trainable parameters of the layer as a single vector.
    /// </summary>
    /// <returns>An empty vector since this layer has no trainable parameters.</returns>
    /// <remarks>
    /// <para>
    /// This method returns an empty vector because the LogVarianceLayer has no trainable parameters.
    /// However, it must be implemented to satisfy the base class contract.
    /// </para>
    /// <para><b>For Beginners:</b> This method would normally return all the values that can be learned during training.
    /// 
    /// Since this layer has no learnable values:
    /// - It returns an empty list (vector with length 0)
    /// - This is expected for mathematical operation layers
    /// - Other layers, like those with weights, would return those weights
    /// </para>
    /// </remarks>
    public override Vector<T> GetParameters()
    {
        // LogVarianceLayer has no trainable parameters
        return new Vector<T>(0);
    }

    /// <summary>
    /// Resets the internal state of the layer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// This method clears any cached data from previous forward passes, essentially resetting the layer
    /// to its initial state. This is useful when starting to process a new batch of data or when
    /// implementing recurrent neural networks.
    /// </para>
    /// <para><b>For Beginners:</b> This method clears the layer's memory to start fresh.
    /// 
    /// When resetting the state:
    /// - Stored inputs and calculated values are cleared
    /// - The layer forgets any information from previous data
    /// - This is important when processing a new, unrelated batch of data
    /// 
    /// Think of it like wiping a calculator's memory before starting a new calculation.
    /// </para>
    /// </remarks>
    public override void ResetState()
    {
        // Clear cached values from forward pass
        _lastInput = null;
        _lastOutput = null;
        _meanValues = null;
    }
}