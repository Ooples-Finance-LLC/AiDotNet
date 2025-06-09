using AiDotNet.Enums;
using AiDotNet.Interfaces;
using AiDotNet.LinearAlgebra;
using AiDotNet.Models;
using AiDotNet.Models.Inputs;
using AiDotNet.Evaluation;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace AiDotNet.AutoML
{
    /// <summary>
    /// Base class for AutoML models that automatically search for optimal model configurations
    /// </summary>
    /// <typeparam name="T">The numeric type used for calculations</typeparam>
    /// <typeparam name="TInput">The input data type</typeparam>
    /// <typeparam name="TOutput">The output data type</typeparam>
    public abstract class AutoMLModelBase<T, TInput, TOutput> : IAutoMLModel<T, TInput, TOutput>
    {
        protected readonly List<TrialResult> _trialHistory = new();
        protected readonly Dictionary<string, ParameterRange> _searchSpace = new();
        protected readonly List<ModelType> _candidateModels = new();
        protected readonly List<SearchConstraint> _constraints = new();
        protected readonly object _lock = new();
        
        protected MetricType _optimizationMetric = MetricType.Accuracy;
        protected bool _maximize = true;
        protected int? _earlyStoppingPatience;
        protected double _earlyStoppingMinDelta = 0.001;
        protected int _trialsSinceImprovement = 0;
        protected IModelEvaluator<T, TInput, TOutput>? _modelEvaluator;

        /// <summary>
        /// Gets the model type
        /// </summary>
        public virtual ModelType Type => ModelType.AutoML;

        /// <summary>
        /// Gets the current optimization status
        /// </summary>
        public AutoMLStatus Status { get; protected set; } = AutoMLStatus.NotStarted;

        /// <summary>
        /// Gets the best model found so far
        /// </summary>
        public IFullModel<T, TInput, TOutput>? BestModel { get; protected set; }

        /// <summary>
        /// Gets the best score achieved
        /// </summary>
        public double BestScore { get; protected set; } = double.NegativeInfinity;

        /// <summary>
        /// Searches for the best model configuration
        /// </summary>
        public abstract Task<IFullModel<T, TInput, TOutput>> SearchAsync(
            TInput inputs,
            TOutput targets,
            TInput validationInputs,
            TOutput validationTargets,
            TimeSpan timeLimit,
            CancellationToken cancellationToken = default);

        /// <summary>
        /// Sets the search space for hyperparameters
        /// </summary>
        public virtual void SetSearchSpace(Dictionary<string, ParameterRange> searchSpace)
        {
            lock (_lock)
            {
                _searchSpace.Clear();
                foreach (var kvp in searchSpace)
                {
                    _searchSpace[kvp.Key] = kvp.Value;
                }
            }
        }

        /// <summary>
        /// Sets the models to consider in the search
        /// </summary>
        public virtual void SetCandidateModels(List<ModelType> modelTypes)
        {
            lock (_lock)
            {
                _candidateModels.Clear();
                _candidateModels.AddRange(modelTypes);
            }
        }

        /// <summary>
        /// Sets the optimization metric
        /// </summary>
        public virtual void SetOptimizationMetric(MetricType metric, bool maximize = true)
        {
            _optimizationMetric = metric;
            _maximize = maximize;
            
            // Reset best score when metric changes
            BestScore = maximize ? double.NegativeInfinity : double.PositiveInfinity;
        }

        /// <summary>
        /// Gets the history of all trials
        /// </summary>
        public virtual List<TrialResult> GetTrialHistory()
        {
            lock (_lock)
            {
                return _trialHistory.Select(t => t.Clone()).ToList();
            }
        }

        /// <summary>
        /// Gets feature importance from the best model
        /// </summary>
        public virtual async Task<Dictionary<int, double>> GetFeatureImportanceAsync()
        {
            if (BestModel == null)
                throw new InvalidOperationException("No best model available. Run search first.");

            // Default implementation returns uniform importance
            return await Task.Run(() =>
            {
                var importance = new Dictionary<int, double>();
                // This would be overridden by specific implementations
                return importance;
            });
        }

        /// <summary>
        /// Suggests the next hyperparameters to try
        /// </summary>
        public abstract Task<Dictionary<string, object>> SuggestNextTrialAsync();

        /// <summary>
        /// Reports the result of a trial
        /// </summary>
        public virtual async Task ReportTrialResultAsync(Dictionary<string, object> parameters, double score, TimeSpan duration)
        {
            await Task.Run(() =>
            {
                lock (_lock)
                {
                    var trial = new TrialResult
                    {
                        TrialId = _trialHistory.Count + 1,
                        Parameters = new Dictionary<string, object>(parameters),
                        Score = score,
                        Duration = duration,
                        Timestamp = DateTime.UtcNow,
                        Status = TrialStatus.Completed
                    };

                    _trialHistory.Add(trial);

                    // Update best score and model
                    bool isBetter = _maximize ? score > BestScore : score < BestScore;
                    
                    if (isBetter)
                    {
                        BestScore = score;
                        _trialsSinceImprovement = 0;
                    }
                    else
                    {
                        _trialsSinceImprovement++;
                    }
                }
            });
        }

        /// <summary>
        /// Enables early stopping
        /// </summary>
        public virtual void EnableEarlyStopping(int patience, double minDelta = 0.001)
        {
            _earlyStoppingPatience = patience;
            _earlyStoppingMinDelta = minDelta;
            _trialsSinceImprovement = 0;
        }

        /// <summary>
        /// Sets constraints for the search
        /// </summary>
        public virtual void SetConstraints(List<SearchConstraint> constraints)
        {
            lock (_lock)
            {
                _constraints.Clear();
                _constraints.AddRange(constraints);
            }
        }

        /// <summary>
        /// Configures the search space for hyperparameters
        /// </summary>
        public virtual void ConfigureSearchSpace(HyperparameterSearchSpace config)
        {
            // Convert HyperparameterSearchSpace to internal format
            // This would be implemented by specific AutoML implementations
            throw new NotImplementedException("ConfigureSearchSpace must be implemented by derived classes");
        }

        /// <summary>
        /// Sets the time limit for the search
        /// </summary>
        public virtual void SetTimeLimit(TimeSpan timeLimit)
        {
            // Store time limit for search
            // This would be used by the SearchAsync implementation
        }

        /// <summary>
        /// Sets the trial limit for the search
        /// </summary>
        public virtual void SetTrialLimit(int trialLimit)
        {
            // Store trial limit for search
            // This would be used by the SearchAsync implementation
        }

        /// <summary>
        /// Enables Neural Architecture Search
        /// </summary>
        public virtual void EnableNAS(bool enabled)
        {
            // Enable or disable NAS
            // This would be implemented by specific AutoML implementations
        }

        /// <summary>
        /// Searches for the best model synchronously
        /// </summary>
        public virtual IFullModel<T, TInput, TOutput> SearchBestModel(TInput inputs, TOutput targets)
        {
            // Synchronous wrapper for SearchAsync
            var searchTask = SearchAsync(inputs, targets, inputs, targets, TimeSpan.FromMinutes(10));
            searchTask.Wait();
            return BestModel ?? throw new InvalidOperationException("Search failed to find a model");
        }


        /// <summary>
        /// Gets model metadata
        /// </summary>
        public virtual ModelMetaData<T> GetModelMetaData()
        {
            return new ModelMetaData<T>
            {
                ModelType = Type,
                Description = $"AutoML with {_candidateModels.Count} candidate models",
                FeatureCount = BestModel?.GetModelMetaData().FeatureCount ?? 0,
                Complexity = _trialHistory.Count,
                AdditionalInfo = new Dictionary<string, object>
                {
                    ["Name"] = "AutoML",
                    ["Version"] = "1.0",
                    ["TrainingDate"] = DateTime.UtcNow,
                    ["Type"] = Type.ToString(),
                    ["Status"] = Status.ToString(),
                    ["BestScore"] = BestScore,
                    ["TrialsCompleted"] = _trialHistory.Count,
                    ["OptimizationMetric"] = _optimizationMetric.ToString(),
                    ["Maximize"] = _maximize,
                    ["CandidateModels"] = _candidateModels.Select(m => m.ToString()).ToList(),
                    ["SearchSpaceSize"] = _searchSpace.Count,
                    ["Constraints"] = _constraints.Count
                }
            };
        }
        

        
        #region IModelSerializer Implementation
        
        public virtual byte[] Serialize()
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model to serialize");
            return BestModel.Serialize();
        }
        
        public virtual void Deserialize(byte[] data)
        {
            throw new NotSupportedException("AutoML models cannot be directly deserialized. Deserialize the best model instead.");
        }
        
        #endregion
        
        #region IParameterizable Implementation
        
        public virtual Vector<T> GetParameters()
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available");
            return BestModel.GetParameters();
        }
        
        public virtual void SetParameters(Vector<T> parameters)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available");
            BestModel.SetParameters(parameters);
        }
        
        public virtual IFullModel<T, TInput, TOutput> WithParameters(Vector<T> parameters)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available");
            var newBestModel = BestModel.WithParameters(parameters);
            var newAutoML = (AutoMLModelBase<T, TInput, TOutput>)MemberwiseClone();
            newAutoML.BestModel = newBestModel;
            return newAutoML;
        }
        
        #endregion
        
        #region IFeatureAware Implementation
        
        public virtual IEnumerable<int> GetActiveFeatureIndices()
        {
            if (BestModel == null)
                return Enumerable.Empty<int>();
            return BestModel.GetActiveFeatureIndices();
        }
        
        public virtual bool IsFeatureUsed(int featureIndex)
        {
            if (BestModel == null)
                return false;
            return BestModel.IsFeatureUsed(featureIndex);
        }
        
        public virtual void SetActiveFeatureIndices(IEnumerable<int> activeIndices)
        {
            if (BestModel != null)
                BestModel.SetActiveFeatureIndices(activeIndices);
        }
        
        #endregion
        
        #region ICloneable Implementation
        
        public virtual IFullModel<T, TInput, TOutput> DeepCopy()
        {
            var clone = (AutoMLModelBase<T, TInput, TOutput>)MemberwiseClone();
            if (BestModel != null)
                clone.BestModel = BestModel.DeepCopy();
            clone._trialHistory.Clear();
            clone._trialHistory.AddRange(_trialHistory);
            return clone;
        }
        
        public virtual IFullModel<T, TInput, TOutput> Clone()
        {
            return DeepCopy();
        }
        
        #endregion
        
        #region IInterpretableModel Implementation
        
        public virtual async Task<Dictionary<int, T>> GetGlobalFeatureImportanceAsync()
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available for interpretation");
            return await BestModel.GetGlobalFeatureImportanceAsync();
        }
        
        public virtual async Task<Matrix<T>> GetShapValuesAsync(TInput input)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available for interpretation");
            return await BestModel.GetShapValuesAsync(input);
        }
        
        public virtual async Task<Dictionary<int, T>> GetLocalFeatureImportanceAsync(TInput input)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available for interpretation");
            return await BestModel.GetLocalFeatureImportanceAsync(input);
        }
        
        public virtual async Task<LimeExplanation<T>> GetLimeExplanationAsync(TInput input, int numFeatures = 10)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available for interpretation");
            return await BestModel.GetLimeExplanationAsync(input, numFeatures);
        }
        
        public virtual async Task<CounterfactualExplanation<T>> GetCounterfactualAsync(TInput input, TOutput desiredOutput, int maxChanges = 5)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available for interpretation");
            return await BestModel.GetCounterfactualAsync(input, desiredOutput, maxChanges);
        }
        
        public virtual async Task<PartialDependenceData<T>> GetPartialDependenceAsync(Vector<int> featureIndices, int gridResolution = 20)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available for interpretation");
            return await BestModel.GetPartialDependenceAsync(featureIndices, gridResolution);
        }
        
        public virtual async Task<FairnessMetrics<T>> ValidateFairnessAsync(TInput inputs, int sensitiveFeatureIndex)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available for interpretation");
            return await BestModel.ValidateFairnessAsync(inputs, sensitiveFeatureIndex);
        }
        
        public virtual async Task<Dictionary<string, object>> GetModelSpecificInterpretabilityAsync()
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available for interpretation");
            return await BestModel.GetModelSpecificInterpretabilityAsync();
        }
        
        public virtual async Task<string> GenerateTextExplanationAsync(TInput input, TOutput prediction)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available for interpretation");
            return await BestModel.GenerateTextExplanationAsync(input, prediction);
        }
        
        public virtual async Task<T> GetFeatureInteractionAsync(int feature1Index, int feature2Index)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available for interpretation");
            return await BestModel.GetFeatureInteractionAsync(feature1Index, feature2Index);
        }
        
        public virtual async Task<AnchorExplanation<T>> GetAnchorExplanationAsync(TInput input, T threshold)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No model available for interpretation");
            return await BestModel.GetAnchorExplanationAsync(input, threshold);
        }
        
        public virtual void SetBaseModel(IModel<TInput, TOutput, ModelMetaData<T>> model)
        {
            if (BestModel != null)
                BestModel.SetBaseModel(model);
        }
        
        public virtual void EnableMethod(params InterpretationMethod[] methods)
        {
            if (BestModel != null)
                BestModel.EnableMethod(methods);
        }
        
        public virtual void ConfigureFairness(Vector<int> sensitiveFeatures, params FairnessMetric[] fairnessMetrics)
        {
            if (BestModel != null)
                BestModel.ConfigureFairness(sensitiveFeatures, fairnessMetrics);
        }
        
        #endregion

        /// <summary>
        /// Checks if early stopping criteria is met
        /// </summary>
        protected bool ShouldStop()
        {
            if (!_earlyStoppingPatience.HasValue)
                return false;

            return _trialsSinceImprovement >= _earlyStoppingPatience.Value;
        }

        /// <summary>
        /// Validates constraints for a given configuration
        /// </summary>
        protected bool ValidateConstraints(Dictionary<string, object> parameters, IFullModel<T, TInput, TOutput>? model = null)
        {
            // This would be implemented by specific AutoML implementations
            // based on the constraint types and model properties
            return true;
        }

        /// <summary>
        /// Creates a model instance for the given type and parameters
        /// </summary>
        protected abstract Task<IFullModel<T, TInput, TOutput>> CreateModelAsync(ModelType modelType, Dictionary<string, object> parameters);

        /// <summary>
        /// Evaluates a model on the validation set
        /// </summary>
        protected virtual async Task<double> EvaluateModelAsync(
            IFullModel<T, TInput, TOutput> model,
            TInput validationInputs,
            TOutput validationTargets)
        {
            return await Task.Run(() =>
            {
                // Use the model evaluator if available
                if (_modelEvaluator != null)
                {
                    var evaluationInput = new ModelEvaluationInput<T, TInput, TOutput>
                    {
                        Model = model,
                        InputData = new OptimizationInputData<T, TInput, TOutput>
                        {
                            XValidation = validationInputs,
                            YValidation = validationTargets
                        }
                    };
                    
                    var evaluationResult = _modelEvaluator.EvaluateModel(evaluationInput);
                    
                    // Extract the appropriate metric based on optimization metric
                    return ExtractMetricFromEvaluation(evaluationResult);
                }
                else
                {
                    // Fallback to simple prediction-based evaluation
                    var predictions = model.Predict(validationInputs);
                    // For now, return a placeholder score
                    // In a real implementation, this would calculate the metric based on the data types
                    return 0.0;
                }
            });
        }

        /// <summary>
        /// Gets the default search space for a model type
        /// </summary>
        protected abstract Dictionary<string, ParameterRange> GetDefaultSearchSpace(ModelType modelType);

        #region IModel Implementation

        /// <summary>
        /// Trains the AutoML model by searching for the best configuration
        /// </summary>
        public virtual void Train(TInput input, TOutput expectedOutput)
        {
            // For AutoML, training means running the search
            var searchTask = SearchAsync(input, expectedOutput, input, expectedOutput, TimeSpan.FromMinutes(10));
            searchTask.Wait();
        }

        /// <summary>
        /// Makes predictions using the best model found
        /// </summary>
        public virtual TOutput Predict(TInput input)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No best model found. Run SearchAsync first.");
            
            return BestModel.Predict(input);
        }

        #endregion

        /// <summary>
        /// Saves the model to a file
        /// </summary>
        public virtual void SaveModel(string filePath)
        {
            if (BestModel == null)
                throw new InvalidOperationException("No best model to save.");
            
            // IFullModel implements IModelSerializer, serialize and save to file
            var data = BestModel.Serialize();
            System.IO.File.WriteAllBytes(filePath, data);
        }

        /// <summary>
        /// Loads the model from a file
        /// </summary>
        public virtual void LoadModel(string filePath)
        {
            throw new NotImplementedException("AutoML models should be recreated with SearchAsync");
        }

        /// <summary>
        /// Gets the number of parameters
        /// </summary>
        public virtual int ParameterCount => BestModel?.GetParameters()?.Length ?? 0;

        /// <summary>
        /// Gets the feature names
        /// </summary>
        public virtual string[] FeatureNames { get; set; } = Array.Empty<string>();

        /// <summary>
        /// Gets the feature importance scores
        /// </summary>
        public virtual double[] GetFeatureImportance()
        {
            if (BestModel == null)
                throw new InvalidOperationException("No best model found.");
            
            // IFullModel doesn't have GetFeatureImportance directly, need to use model-specific implementation
            // For now, return empty array as this would be model-specific
            var paramCount = BestModel.GetParameters()?.Length ?? 0;
            return new double[paramCount];
        }

        /// <summary>
        /// Sets the model evaluator to use for evaluating candidate models
        /// </summary>
        public virtual void SetModelEvaluator(IModelEvaluator<T, TInput, TOutput> evaluator)
        {
            _modelEvaluator = evaluator;
        }

        /// <summary>
        /// Extracts the appropriate metric value from the evaluation results
        /// </summary>
        protected virtual double ExtractMetricFromEvaluation(ModelEvaluationData<T, TInput, TOutput> evaluationData)
        {
            var validationStats = evaluationData.ValidationSet;
            
            return _optimizationMetric switch
            {
                MetricType.Accuracy => validationStats.ErrorStats != null ? Convert.ToDouble(validationStats.ErrorStats.GetMetric(MetricType.Accuracy)) : 0.0,
                MetricType.RMSE => validationStats.ErrorStats != null ? Convert.ToDouble(validationStats.ErrorStats.RMSE) : double.MaxValue,
                MetricType.MAE => validationStats.ErrorStats != null ? Convert.ToDouble(validationStats.ErrorStats.MAE) : double.MaxValue,
                MetricType.R2 => validationStats.PredictionStats != null ? Convert.ToDouble(validationStats.PredictionStats.GetMetric(MetricType.R2)) : 0.0,
                MetricType.AdjustedR2 => validationStats.PredictionStats != null ? Convert.ToDouble(validationStats.PredictionStats.GetMetric(MetricType.AdjustedR2)) : 0.0,
                MetricType.F1Score => validationStats.ErrorStats != null ? Convert.ToDouble(validationStats.ErrorStats.GetMetric(MetricType.F1Score)) : 0.0,
                MetricType.Precision => validationStats.ErrorStats != null ? Convert.ToDouble(validationStats.ErrorStats.GetMetric(MetricType.Precision)) : 0.0,
                MetricType.Recall => validationStats.ErrorStats != null ? Convert.ToDouble(validationStats.ErrorStats.GetMetric(MetricType.Recall)) : 0.0,
                MetricType.AUCROC => validationStats.ErrorStats != null ? Convert.ToDouble(validationStats.ErrorStats.AUCROC) : 0.0,
                _ => 0.0
            };
        }
    }
}