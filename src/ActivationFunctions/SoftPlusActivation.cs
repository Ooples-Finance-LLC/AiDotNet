namespace AiDotNet.ActivationFunctions;

/// <summary>
/// Implements the SoftPlus activation function, which is a smooth approximation of the ReLU function.
/// </summary>
/// <typeparam name="T">The numeric data type used for calculations.</typeparam>
/// <remarks>
/// <para>
/// The SoftPlus function is defined as: f(x) = ln(1 + e^x), where ln is the natural logarithm.
/// It produces output that is always positive and approaches the ReLU function (max(0,x)) but with a smooth transition at x=0.
/// </para>
/// <para>
/// <b>For Beginners:</b> SoftPlus is like a "softer" version of the popular ReLU activation function. 
/// While ReLU outputs exactly 0 for any negative input and keeps positive values unchanged,
/// SoftPlus creates a smooth curve that's very close to ReLU but without the sharp corner at x=0.
/// 
/// For negative inputs, SoftPlus outputs small positive values (approaching 0).
/// For large positive inputs, SoftPlus outputs values very close to the input itself.
/// 
/// This smoothness can be helpful in some neural networks because it means the function is differentiable
/// everywhere (it has a well-defined slope at every point), which can make training more stable.
/// </para>
/// </remarks>
public class SoftPlusActivation<T> : ActivationFunctionBase<T>
{
    /// <summary>
    /// Indicates whether this activation function supports scalar operations.
    /// </summary>
    /// <returns>Always returns true as SoftPlus can operate on individual values.</returns>
    /// <remarks>
    /// <para>
    /// Unlike functions like Softmax that require a vector of values, SoftPlus can be applied
    /// independently to each individual value.
    /// </para>
    /// <para>
    /// <b>For Beginners:</b> This method returning true means that SoftPlus can work on one number at a time.
    /// Each input value is transformed independently without needing to know about other values.
    /// </para>
    /// </remarks>
    protected override bool SupportsScalarOperations() => true;

    /// <summary>
    /// Applies the SoftPlus activation function to a single input value.
    /// </summary>
    /// <param name="input">The input value.</param>
    /// <returns>The result of applying SoftPlus to the input.</returns>
    /// <remarks>
    /// <para>
    /// Computes ln(1 + e^x) where x is the input value and ln is the natural logarithm.
    /// </para>
    /// <para>
    /// <b>For Beginners:</b> This method transforms an input number using the SoftPlus formula:
    /// 1. Calculate e raised to the power of your input (e^x)
    /// 2. Add 1 to that result (1 + e^x)
    /// 3. Take the natural logarithm of that sum (ln(1 + e^x))
    /// 
    /// The result is always positive. For large positive inputs, the output is very close to the input itself.
    /// For large negative inputs, the output approaches zero but is never exactly zero.
    /// </para>
    /// </remarks>
    public override T Activate(T input)
    {
        // f(x) = ln(1 + e^x)
        T expInput = NumOps.Exp(input);
        T onePlusExp = NumOps.Add(NumOps.One, expInput);

        return NumOps.Log(onePlusExp);
    }

    /// <summary>
    /// Calculates the derivative of the SoftPlus function for a given input.
    /// </summary>
    /// <param name="input">The input value.</param>
    /// <returns>The derivative of SoftPlus at the input point.</returns>
    /// <remarks>
    /// <para>
    /// The derivative of SoftPlus is the logistic sigmoid function: f'(x) = 1 / (1 + e^(-x)).
    /// This derivative is always between 0 and 1.
    /// </para>
    /// <para>
    /// <b>For Beginners:</b> The derivative tells us how quickly the SoftPlus function is changing at any point.
    /// It's calculated as 1 / (1 + e^(-x)), which is actually the sigmoid function.
    /// 
    /// This derivative has these important properties:
    /// - It's always between 0 and 1
    /// - For large negative inputs, it approaches 0
    /// - For large positive inputs, it approaches 1
    /// - At x=0, it equals exactly 0.5
    /// 
    /// During neural network training, this derivative helps determine how much to adjust the weights
    /// based on how sensitive the output is to changes in the input.
    /// </para>
    /// </remarks>
    public override T Derivative(T input)
    {
        // f'(x) = 1 / (1 + e^(-x))
        T negInput = NumOps.Negate(input);
        T expNegInput = NumOps.Exp(negInput);
        T denominator = NumOps.Add(NumOps.One, expNegInput);

        return NumOps.Divide(NumOps.One, denominator);
    }
}