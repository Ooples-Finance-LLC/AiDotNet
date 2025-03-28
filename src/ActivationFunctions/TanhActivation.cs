namespace AiDotNet.ActivationFunctions;

/// <summary>
/// Implements the Hyperbolic Tangent (tanh) activation function for neural networks.
/// </summary>
/// <typeparam name="T">The numeric type used for calculations (e.g., float, double).</typeparam>
/// <remarks>
/// <para>
/// <b>For Beginners:</b> The Hyperbolic Tangent (tanh) activation function is a popular choice in neural networks.
/// It transforms any input value to an output between -1 and 1, creating an S-shaped curve that's
/// symmetric around the origin.
/// 
/// Key properties of tanh:
/// - Outputs values between -1 and 1
/// - An input of 0 produces an output of 0
/// - Large positive inputs approach +1
/// - Large negative inputs approach -1
/// - It's zero-centered, which often helps with learning
/// 
/// When to use tanh:
/// - When you need outputs centered around zero
/// - For hidden layers in many types of neural networks
/// - When dealing with data that naturally has both positive and negative values
/// 
/// One limitation is the "vanishing gradient problem" - for very large or small inputs,
/// the function's slope becomes very small, which can slow down learning in deep networks.
/// </para>
/// </remarks>
public class TanhActivation<T> : ActivationFunctionBase<T>
{
    /// <summary>
    /// Indicates that this activation function supports operations on individual scalar values.
    /// </summary>
    /// <returns>Always returns true as tanh can be applied to scalar values.</returns>
    protected override bool SupportsScalarOperations() => true;

    /// <summary>
    /// Applies the tanh activation function to a single input value.
    /// </summary>
    /// <param name="input">The input value.</param>
    /// <returns>The activated output value between -1 and 1.</returns>
    /// <remarks>
    /// <para>
    /// <b>For Beginners:</b> This method transforms any input number into an output between -1 and 1.
    /// The transformation follows an S-shaped curve that passes through the origin (0,0).
    /// 
    /// For example:
    /// - An input of 0 gives an output of 0
    /// - An input of 2 gives an output of about 0.96 (close to 1)
    /// - An input of -2 gives an output of about -0.96 (close to -1)
    /// 
    /// This "squashing" property makes tanh useful for normalizing outputs in neural networks.
    /// </para>
    /// </remarks>
    public override T Activate(T input)
    {
        return MathHelper.Tanh(input);
    }

    /// <summary>
    /// Calculates the derivative of the tanh function for a single input value.
    /// </summary>
    /// <param name="input">The input value.</param>
    /// <returns>The derivative value at the input point.</returns>
    /// <remarks>
    /// <para>
    /// <b>For Beginners:</b> The derivative measures how much the tanh function's output changes
    /// when its input changes slightly. This is crucial during neural network training to determine
    /// how to adjust weights.
    /// 
    /// The formula is: f'(x) = 1 - tanh�(x)
    /// 
    /// Key properties of this derivative:
    /// - It's highest (equal to 1) at x = 0, where the function is steepest
    /// - It approaches zero for very large positive or negative inputs
    /// - This means the network learns most effectively from inputs near zero
    /// 
    /// The "vanishing gradient problem" occurs when inputs are very large in magnitude,
    /// causing very small derivatives that slow down learning.
    /// </para>
    /// </remarks>
    public override T Derivative(T input)
    {
        T tanh = MathHelper.Tanh(input);
        return NumOps.Subtract(NumOps.One, NumOps.Multiply(tanh, tanh));
    }
}