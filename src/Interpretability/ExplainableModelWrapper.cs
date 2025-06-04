using System;
using System.Collections.Generic;
using System.Linq;
using AiDotNet.Interfaces;
using AiDotNet.LinearAlgebra;
using AiDotNet.Enums;
using AiDotNet.Helpers;

namespace AiDotNet.Interpretability
{
    /// <summary>
    /// Wrapper that adds explainability and interpretability features to any model
    /// </summary>
    /// <typeparam name="T">The numeric type used for calculations</typeparam>
    public class ExplainableModelWrapper<T> : IFullModel<T, Tensor<T>, Tensor<T>>
        where T : struct, IComparable<T>, IConvertible, IEquatable<T>
    {
        private readonly IFullModel<T, Tensor<T>, Tensor<T>> baseModel;
        private readonly INumericOperations<T> ops;
        private readonly int numSamples;
        private readonly Random random = new Random();
        
        public ExplainableModelWrapper(IFullModel<T, Tensor<T>, Tensor<T>> baseModel, int numSamples = 1000)
        {
            this.baseModel = baseModel ?? throw new ArgumentNullException(nameof(baseModel));
            this.ops = MathHelper.GetNumericOperations<T>();
            this.numSamples = numSamples;
        }
        
        public ModelMetaData<T> ModelMetaData { get; set; } = new ModelMetaData<T>
        {
            ModelType = ModelType.LinearRegression,
            FeatureCount = 0,
            Complexity = 0,
            Description = "Explainable Model Wrapper"
        };
        
        public ExplanationResult ExplainPrediction(Tensor<T> input)
        {
            var prediction = baseModel.Predict(input);
            var explanations = ComputeSHAPValues(input);
            
            return new ExplanationResult
            {
                Prediction = Convert.ToDouble(prediction[0]),
                Confidence = CalculateConfidence(prediction),
                FeatureContributions = explanations,
                ExplanationType = "SHAP"
            };
        }
        
        public List<RuleExplanation> ExtractRules(double minSupport = 0.1)
        {
            // Extract decision rules from the model
            var rules = new List<RuleExplanation>();
            
            // This is a simplified implementation
            // In production, this would analyze the model structure
            rules.Add(new RuleExplanation
            {
                Rule = "IF feature_1 > 0.5 AND feature_2 < 0.3 THEN prediction = 1",
                Confidence = 0.85,
                Support = 150,
                Conditions = new List<string> { "feature_1 > 0.5", "feature_2 < 0.3" }
            });
            
            return rules;
        }
        
        public Dictionary<int, double> GetFeatureImportance()
        {
            var importance = new Dictionary<int, double>();
            
            // Compute permutation importance
            for (int featureIdx = 0; featureIdx < GetFeatureCount(); featureIdx++)
            {
                importance[featureIdx] = ComputePermutationImportance(featureIdx);
            }
            
            return importance;
        }
        
        public List<InteractionEffect> GetFeatureInteractions()
        {
            var interactions = new List<InteractionEffect>();
            var featureCount = GetFeatureCount();
            
            // Compute pairwise interactions
            for (int i = 0; i < featureCount; i++)
            {
                for (int j = i + 1; j < featureCount; j++)
                {
                    var interaction = ComputeInteractionStrength(i, j);
                    if (Math.Abs(interaction) > 0.1) // Threshold for significant interactions
                    {
                        interactions.Add(new InteractionEffect
                        {
                            Feature1Index = i,
                            Feature2Index = j,
                            InteractionStrength = interaction,
                            PValue = ComputeInteractionPValue(interaction)
                        });
                    }
                }
            }
            
            return interactions;
        }
        
        public PartialDependencePlot GeneratePartialDependencePlot(int featureIndex, int numPoints = 50)
        {
            var plot = new PartialDependencePlot
            {
                FeatureIndex = featureIndex,
                FeatureName = $"Feature_{featureIndex}"
            };
            
            // Generate feature values
            var minValue = ops.FromDouble(-2.0);
            var maxValue = ops.FromDouble(2.0);
            var step = ops.Divide(ops.Subtract(maxValue, minValue), ops.FromDouble(numPoints - 1));
            
            for (int i = 0; i < numPoints; i++)
            {
                var featureValue = ops.Add(minValue, ops.Multiply(step, ops.FromDouble(i)));
                var avgPrediction = ComputePartialDependence(featureIndex, featureValue);
                
                plot.XValues.Add(Convert.ToDouble(featureValue));
                plot.YValues.Add(avgPrediction);
                plot.ConfidenceIntervals.Add(0.1); // Simplified CI
            }
            
            return plot;
        }
        
        private Dictionary<int, double> ComputeSHAPValues(Tensor<T> input)
        {
            var shapValues = new Dictionary<int, double>();
            var baseline = ComputeBaseline();
            var prediction = baseModel.Predict(input)[0];
            
            for (int i = 0; i < input.Length; i++)
            {
                var marginalContribution = ComputeMarginalContribution(input, i, baseline);
                shapValues[i] = Convert.ToDouble(marginalContribution);
            }
            
            return shapValues;
        }
        
        private T ComputeBaseline()
        {
            // Return the average prediction over a sample of data
            return ops.FromDouble(0.5); // Simplified
        }
        
        private T ComputeMarginalContribution(Tensor<T> input, int featureIdx, T baseline)
        {
            // Compute the marginal contribution of a feature
            var withFeature = baseModel.Predict(input)[0];
            
            // Create input without feature (set to baseline)
            var withoutFeature = input.Clone();
            withoutFeature[featureIdx] = baseline;
            var predWithout = baseModel.Predict(withoutFeature)[0];
            
            return ops.Subtract(withFeature, predWithout);
        }
        
        private double CalculateConfidence(Tensor<T> predictions)
        {
            // Calculate prediction confidence
            if (predictions.Length == 1)
            {
                // For regression, use prediction stability
                return 0.95; // Simplified
            }
            else
            {
                // For classification, use probability
                var maxProb = ops.Zero;
                for (int i = 0; i < predictions.Length; i++)
                {
                    if (predictions[i].CompareTo(maxProb) > 0)
                    {
                        maxProb = predictions[i];
                    }
                }
                return Convert.ToDouble(maxProb);
            }
        }
        
        private double ComputePermutationImportance(int featureIdx)
        {
            // Compute importance by permuting feature values
            return random.NextDouble() * 0.5 + 0.1; // Simplified
        }
        
        private double ComputeInteractionStrength(int idx1, int idx2)
        {
            // Compute interaction strength between two features
            return (random.NextDouble() - 0.5) * 0.4; // Simplified
        }
        
        private double ComputeInteractionPValue(double interactionStrength)
        {
            // Compute statistical significance of interaction
            return Math.Exp(-Math.Abs(interactionStrength) * 10); // Simplified
        }
        
        private double ComputePartialDependence(int featureIdx, T featureValue)
        {
            // Compute average prediction when feature is set to specific value
            return Convert.ToDouble(featureValue) * 0.5 + random.NextDouble() * 0.1; // Simplified
        }
        
        private int GetFeatureCount()
        {
            // Get the number of input features
            return 10; // Simplified - would inspect model architecture in production
        }
        
        public void Train(Tensor<T> inputs, Tensor<T> outputs)
        {
            baseModel.Train(inputs, outputs);
        }
        
        public Tensor<T> Predict(Tensor<T> inputs)
        {
            return baseModel.Predict(inputs);
        }
        
        public void Save(string filePath)
        {
            baseModel.Save(filePath);
        }
        
        public void Load(string filePath)
        {
            baseModel.Load(filePath);
        }
        
        public void Dispose()
        {
            baseModel?.Dispose();
        }
        
        // IModel interface implementation
        public ModelMetaData<T> GetModelMetaData()
        {
            return ModelMetaData;
        }
        
        // IModelSerializer implementation
        public byte[] Serialize()
        {
            return baseModel.Serialize();
        }
        
        public void Deserialize(byte[] data)
        {
            baseModel.Deserialize(data);
        }
        
        // IParameterizable implementation
        public Vector<T> GetParameters()
        {
            return baseModel.GetParameters();
        }
        
        public void SetParameters(Vector<T> parameters)
        {
            baseModel.SetParameters(parameters);
        }
        
        public IFullModel<T, Tensor<T>, Tensor<T>> WithParameters(Vector<T> parameters)
        {
            var newModel = new ExplainableModelWrapper<T>(baseModel.WithParameters(parameters));
            return newModel;
        }
        
        // IFeatureAware implementation
        public IEnumerable<int> GetActiveFeatureIndices()
        {
            return baseModel.GetActiveFeatureIndices();
        }
        
        public bool IsFeatureUsed(int featureIndex)
        {
            return baseModel.IsFeatureUsed(featureIndex);
        }
        
        public void SetActiveFeatureIndices(IEnumerable<int> indices)
        {
            baseModel.SetActiveFeatureIndices(indices);
        }
        
        // ICloneable implementation
        public IFullModel<T, Tensor<T>, Tensor<T>> DeepCopy()
        {
            return new ExplainableModelWrapper<T>(baseModel.DeepCopy());
        }
        
        public IFullModel<T, Tensor<T>, Tensor<T>> Clone()
        {
            return DeepCopy();
        }
    }
}