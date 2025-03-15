namespace AiDotNet.Interpolation;

/// <summary>
/// Implements monotone cubic interpolation for one-dimensional data points.
/// </summary>
/// <remarks>
/// Monotone cubic interpolation creates a smooth curve through data points while preserving
/// the monotonicity of the data (meaning if your data is increasing, the interpolation will also
/// be increasing, and similarly for decreasing data).
/// 
/// For Beginners: Monotone cubic interpolation is like drawing a smooth curve through points
/// on a graph, but with a special property: if your original data is always going up (or always going down)
/// between certain points, the curve will also always go up (or down) between those points. This avoids
/// unwanted "wiggles" or oscillations that can happen with other smooth interpolation methods.
/// It's particularly useful when you know your data should never "change direction" between points.
/// </remarks>
/// <typeparam name="T">The numeric type used for calculations.</typeparam>
public class MonotoneCubicInterpolation<T> : IInterpolation<T>
{
    /// <summary>
    /// The x-coordinates of the known data points.
    /// </summary>
    private readonly Vector<T> _x;
    
    /// <summary>
    /// The y-coordinates (values) of the known data points.
    /// </summary>
    private readonly Vector<T> _y;
    
    /// <summary>
    /// The slopes at each data point, calculated to ensure monotonicity.
    /// </summary>
    /// <remarks>
    /// For Beginners: The slope at each point tells us the direction and steepness of the curve
    /// at that exact point. These slopes are carefully calculated to make sure our curve remains
    /// smooth but doesn't create unwanted oscillations.
    /// </remarks>
    private readonly Vector<T> _m;
    
    /// <summary>
    /// Operations for performing numeric calculations with type T.
    /// </summary>
    private readonly INumericOperations<T> _numOps;

    /// <summary>
    /// Creates a new instance of the monotone cubic interpolation algorithm.
    /// </summary>
    /// <remarks>
    /// This constructor initializes the interpolator with your data points and calculates
    /// the necessary slopes to ensure monotonicity.
    /// 
    /// For Beginners: When you create a monotone cubic interpolator, you provide the x-coordinates
    /// and corresponding y-values of your known data points. The interpolator then calculates
    /// special values (slopes) at each point to ensure the resulting curve is both smooth and
    /// preserves the "always increasing" or "always decreasing" property of your original data.
    /// </remarks>
    /// <param name="x">The x-coordinates of the known data points.</param>
    /// <param name="y">The y-values of the known data points.</param>
    /// <exception cref="ArgumentException">Thrown when input vectors have different lengths or fewer than 2 points.</exception>
    public MonotoneCubicInterpolation(Vector<T> x, Vector<T> y)
    {
        if (x.Length != y.Length)
        {
            throw new ArgumentException("Input vectors must have the same length.");
        }

        if (x.Length < 2)
        {
            throw new ArgumentException("Monotone cubic interpolation requires at least 2 points.");
        }

        _x = x;
        _y = y;
        _numOps = MathHelper.GetNumericOperations<T>();
        _m = new Vector<T>(x.Length);

        CalculateSlopes();
    }

    /// <summary>
    /// Interpolates the y-value at a given x-coordinate using monotone cubic interpolation.
    /// </summary>
    /// <remarks>
    /// This method calculates the y-value at any x-coordinate using cubic Hermite splines
    /// with slopes that ensure monotonicity.
    /// 
    /// For Beginners: Once you've set up the interpolator with your known points, this method
    /// lets you ask "What would the y-value be at this specific x-coordinate?" It finds the two
    /// known points that are closest to your target x-coordinate (one on each side), and then
    /// creates a smooth curve between them that respects the overall shape of your data.
    /// 
    /// The formula used is based on cubic Hermite polynomials, which are mathematical functions
    /// that create smooth transitions between points while respecting the slopes at those points.
    /// </remarks>
    /// <param name="x">The x-coordinate at which to interpolate.</param>
    /// <returns>The interpolated y-value at the specified x-coordinate.</returns>
    public T Interpolate(T x)
    {
        int i = FindInterval(x);

        T h = _numOps.Subtract(_x[i + 1], _x[i]);
        T t = _numOps.Divide(_numOps.Subtract(x, _x[i]), h);

        T t2 = _numOps.Multiply(t, t);
        T t3 = _numOps.Multiply(t2, t);

        T h00 = _numOps.Add(_numOps.Multiply(_numOps.FromDouble(2), t3), _numOps.Subtract(_numOps.Multiply(_numOps.FromDouble(-3), t2), _numOps.FromDouble(1)));
        T h10 = _numOps.Add(t3, _numOps.Subtract(_numOps.Multiply(_numOps.FromDouble(-2), t2), t));
        T h01 = _numOps.Add(_numOps.Multiply(_numOps.FromDouble(-2), t3), _numOps.Multiply(_numOps.FromDouble(3), t2));
        T h11 = _numOps.Subtract(t3, t2);

        return _numOps.Add(
            _numOps.Add(
                _numOps.Multiply(h00, _y[i]),
                _numOps.Multiply(h10, _numOps.Multiply(h, _m[i]))
            ),
            _numOps.Add(
                _numOps.Multiply(h01, _y[i + 1]),
                _numOps.Multiply(h11, _numOps.Multiply(h, _m[i + 1]))
            )
        );
    }

    /// <summary>
    /// Calculates the slopes at each data point to ensure monotonicity.
    /// </summary>
    /// <remarks>
    /// This method computes the slopes at each data point using a technique that ensures
    /// the resulting interpolation preserves monotonicity.
    /// 
    /// For Beginners: This method does the important work of figuring out how steep the curve
    /// should be at each of your known points. It first calculates the simple slope between each
    /// pair of adjacent points (rise divided by run). Then, for points in the middle, it adjusts
    /// these slopes to ensure the resulting curve doesn't create unwanted wiggles or oscillations.
    /// 
    /// The algorithm specifically ensures that if your data is always increasing (or decreasing)
    /// between certain points, the interpolated curve will also always increase (or decrease)
    /// between those points.
    /// </remarks>
    private void CalculateSlopes()
    {
        int n = _x.Length;

        // Calculate secant slopes
        Vector<T> delta = new Vector<T>(n - 1);
        for (int i = 0; i < n - 1; i++)
        {
            delta[i] = _numOps.Divide(
                _numOps.Subtract(_y[i + 1], _y[i]),
                _numOps.Subtract(_x[i + 1], _x[i])
            );
        }

        // Initialize slopes
        _m[0] = delta[0];
        _m[n - 1] = delta[n - 2];

        // Calculate interior slopes
        for (int i = 1; i < n - 1; i++)
        {
            T m = _numOps.Divide(_numOps.Add(delta[i - 1], delta[i]), _numOps.FromDouble(2));

            // Ensure monotonicity
            if (!_numOps.Equals(delta[i - 1], _numOps.Zero) && !_numOps.Equals(delta[i], _numOps.Zero))
            {
                T alpha = _numOps.Divide(delta[i - 1], delta[i]);
                T beta = _numOps.Divide(_numOps.FromDouble(3), _numOps.Add(_numOps.FromDouble(2), alpha));

                if (_numOps.GreaterThan(_numOps.Multiply(beta, m), delta[i - 1]))
                {
                    m = _numOps.Divide(delta[i - 1], beta);
                }
                else if (_numOps.GreaterThan(_numOps.Multiply(beta, m), delta[i]))
                {
                    m = _numOps.Divide(delta[i], beta);
                }
            }

            _m[i] = m;
        }
    }

    /// <summary>
    /// Finds the interval in the x-coordinates array that contains the given x-value.
    /// </summary>
    /// <remarks>
    /// This method uses binary search to efficiently find which pair of known points
    /// the target x-coordinate falls between.
    /// 
    /// For Beginners: Before we can interpolate, we need to know which two known points
    /// to draw a curve between. This method efficiently finds the right pair of points by
    /// using a technique called "binary search" (like when you search for a word in a dictionary
    /// by repeatedly dividing the book in half). It returns the index of the known point
    /// that comes just before your target x-coordinate.
    /// 
    /// If your target x is smaller than all known x-coordinates, it returns 0.
    /// If your target x is larger than all known x-coordinates, it returns the index of the second-to-last point.
    /// </remarks>
    /// <param name="x">The x-coordinate to find the interval for.</param>
    /// <returns>The index of the lower bound of the interval containing x.</returns>
    private int FindInterval(T x)
    {
        if (_numOps.LessThanOrEquals(x, _x[0]))
            return 0;
        if (_numOps.GreaterThanOrEquals(x, _x[_x.Length - 1]))
            return _x.Length - 2;

        int low = 0;
        int high = _x.Length - 1;

        while (low < high - 1)
        {
            int mid = (low + high) / 2;
            if (_numOps.LessThanOrEquals(_x[mid], x))
                low = mid;
            else
                high = mid;
        }

        return low;
    }
}