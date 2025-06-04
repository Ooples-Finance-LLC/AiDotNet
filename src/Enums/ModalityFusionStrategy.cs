namespace AiDotNet.Enums
{
    /// <summary>
    /// Strategies for fusing multiple modalities in multimodal models
    /// </summary>
    public enum ModalityFusionStrategy
    {
        /// <summary>
        /// Early fusion - combine modalities at input level
        /// </summary>
        EarlyFusion,

        /// <summary>
        /// Late fusion - combine modalities at output/decision level
        /// </summary>
        LateFusion,

        /// <summary>
        /// Cross-attention mechanism for modality fusion
        /// </summary>
        CrossAttention,

        /// <summary>
        /// Hierarchical fusion with multiple levels
        /// </summary>
        Hierarchical,

        /// <summary>
        /// Transformer-based fusion
        /// </summary>
        Transformer,

        /// <summary>
        /// Gated fusion with learnable gates
        /// </summary>
        Gated,

        /// <summary>
        /// Tensor fusion network
        /// </summary>
        TensorFusion,

        /// <summary>
        /// Bilinear pooling fusion
        /// </summary>
        BilinearPooling,

        /// <summary>
        /// Attention-weighted averaging
        /// </summary>
        AttentionWeighted,

        /// <summary>
        /// Simple concatenation
        /// </summary>
        Concatenation
    }
}