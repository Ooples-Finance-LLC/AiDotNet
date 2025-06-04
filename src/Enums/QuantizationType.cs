namespace AiDotNet.Enums
{
    /// <summary>
    /// Types of quantization for model compression
    /// </summary>
    public enum QuantizationType
    {
        /// <summary>
        /// 8-bit integer quantization
        /// </summary>
        Int8,
        
        /// <summary>
        /// 16-bit integer quantization
        /// </summary>
        Int16,
        
        /// <summary>
        /// Dynamic quantization
        /// </summary>
        Dynamic,
        
        /// <summary>
        /// Quantization-aware training
        /// </summary>
        QuantizationAwareTraining,
        
        /// <summary>
        /// Post-training quantization
        /// </summary>
        PostTraining,
        
        /// <summary>
        /// Mixed precision quantization
        /// </summary>
        MixedPrecision
    }
}