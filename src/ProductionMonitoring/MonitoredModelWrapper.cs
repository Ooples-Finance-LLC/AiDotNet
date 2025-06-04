using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using AiDotNet.Interfaces;
using AiDotNet.LinearAlgebra;
using AiDotNet.Enums;
using AiDotNet.Helpers;

namespace AiDotNet.ProductionMonitoring
{
    /// <summary>
    /// Wrapper that adds monitoring capabilities to any model
    /// </summary>
    /// <typeparam name="T">The numeric type used for calculations</typeparam>
    /// <typeparam name="TInput">The input type for the model</typeparam>
    /// <typeparam name="TOutput">The output type for the model</typeparam>
    public class MonitoredModelWrapper<T, TInput, TOutput> : IFullModel<T, TInput, TOutput>
        where T : struct, IComparable<T>, IConvertible, IEquatable<T>
    {
        private readonly IFullModel<T, TInput, TOutput> wrappedModel;
        private readonly DefaultProductionMonitor<T> monitor;
        private readonly INumericOperations<T> ops;
        
        public MonitoredModelWrapper(IFullModel<T, TInput, TOutput> model)
        {
            this.wrappedModel = model ?? throw new ArgumentNullException(nameof(model));
            this.monitor = new DefaultProductionMonitor<T>();
            this.ops = MathHelper.GetNumericOperations<T>();
            
            // Copy metadata from wrapped model
            var wrappedMetadata = model.GetModelMetaData();
            this.ModelMetaData = new ModelMetaData<T>
            {
                ModelType = wrappedMetadata.ModelType,
                FeatureCount = wrappedMetadata.FeatureCount,
                Complexity = wrappedMetadata.Complexity,
                Description = $"Monitored {wrappedMetadata.Description}"
            };
        }
        
        public ModelMetaData<T> ModelMetaData { get; set; }
        
        public async Task<TOutput> PredictAsync(TInput inputs)
        {
            // Monitor input data if it's a Tensor
            if (inputs is Tensor<T> tensorInput)
            {
                await monitor.MonitorInputDataAsync(tensorInput);
            }
            
            // Get prediction from wrapped model
            var result = wrappedModel.Predict(inputs);
            
            // Monitor predictions if output is a Tensor
            if (result is Tensor<T> tensorOutput)
            {
                await monitor.MonitorPredictionsAsync(tensorOutput);
            }
            
            return result;
        }
        
        public void Train(TInput inputs, TOutput outputs)
        {
            wrappedModel.Train(inputs, outputs);
        }
        
        public TOutput Predict(TInput inputs)
        {
            return PredictAsync(inputs).GetAwaiter().GetResult();
        }
        
        public void Save(string filePath)
        {
            wrappedModel.Save(filePath);
        }
        
        public void Load(string filePath)
        {
            wrappedModel.Load(filePath);
        }
        
        public void Dispose()
        {
            wrappedModel?.Dispose();
            monitor?.Dispose();
        }
        
        /// <summary>
        /// Gets monitoring alerts
        /// </summary>
        public List<DataDriftAlert> GetAlerts()
        {
            return monitor.GetRecentAlerts();
        }
        
        /// <summary>
        /// Checks if retraining is needed
        /// </summary>
        public bool NeedsRetraining()
        {
            return monitor.GetRetrainingRecommendation();
        }
        
        /// <summary>
        /// Gets model health score
        /// </summary>
        public double GetHealthScore()
        {
            return monitor.GetHealthScore();
        }
        
        // IModel interface implementation
        public ModelMetaData<T> GetModelMetaData()
        {
            return ModelMetaData;
        }
        
        // IModelSerializer implementation
        public byte[] Serialize()
        {
            return wrappedModel.Serialize();
        }
        
        public void Deserialize(byte[] data)
        {
            wrappedModel.Deserialize(data);
        }
        
        // IParameterizable implementation
        public Vector<T> GetParameters()
        {
            return wrappedModel.GetParameters();
        }
        
        public void SetParameters(Vector<T> parameters)
        {
            wrappedModel.SetParameters(parameters);
        }
        
        public IFullModel<T, TInput, TOutput> WithParameters(Vector<T> parameters)
        {
            var newWrappedModel = wrappedModel.WithParameters(parameters);
            return new MonitoredModelWrapper<T, TInput, TOutput>(newWrappedModel);
        }
        
        // IFeatureAware implementation
        public IEnumerable<int> GetActiveFeatureIndices()
        {
            return wrappedModel.GetActiveFeatureIndices();
        }
        
        public bool IsFeatureUsed(int featureIndex)
        {
            return wrappedModel.IsFeatureUsed(featureIndex);
        }
        
        public void SetActiveFeatureIndices(IEnumerable<int> activeIndices)
        {
            wrappedModel.SetActiveFeatureIndices(activeIndices);
        }
        
        // ICloneable implementation
        public IFullModel<T, TInput, TOutput> DeepCopy()
        {
            return new MonitoredModelWrapper<T, TInput, TOutput>(wrappedModel.DeepCopy());
        }
        
        public IFullModel<T, TInput, TOutput> Clone()
        {
            return DeepCopy();
        }
    }
}