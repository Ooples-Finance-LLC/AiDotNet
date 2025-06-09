using AiDotNet.Enums;
using AiDotNet.Interfaces;
using AiDotNet.LinearAlgebra;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace AiDotNet.Pipeline
{
    /// <summary>
    /// Represents a branch in a pipeline that can execute steps conditionally or in parallel
    /// </summary>
    /// <typeparam name="T">The numeric type for computations</typeparam>
    public class PipelineBranch<T>
    {
        private readonly List<IPipelineStep<T>> _steps;
        private readonly Predicate<Matrix<T>>? _condition;
        private BranchMergeStrategy _mergeStrategy;
        private Dictionary<string, object>? _mergeParameters;

        /// <summary>
        /// Gets the unique identifier for this branch
        /// </summary>
        public string Id { get; }

        /// <summary>
        /// Gets or sets the name of this branch
        /// </summary>
        public string Name { get; set; }

        /// <summary>
        /// Gets the steps in this branch
        /// </summary>
        public IReadOnlyList<IPipelineStep<T>> Steps => _steps.AsReadOnly();

        /// <summary>
        /// Gets whether this branch is conditional
        /// </summary>
        public bool IsConditional => _condition != null;

        /// <summary>
        /// Gets or sets the merge strategy for this branch
        /// </summary>
        public BranchMergeStrategy MergeStrategy
        {
            get => _mergeStrategy;
            set => _mergeStrategy = value;
        }

        /// <summary>
        /// Gets or sets whether this branch should execute in parallel with others
        /// </summary>
        public bool ExecuteInParallel { get; set; }

        /// <summary>
        /// Gets or sets the priority of this branch (higher priority executes first)
        /// </summary>
        public int Priority { get; set; }

        /// <summary>
        /// Gets or sets whether this branch is enabled
        /// </summary>
        public bool IsEnabled { get; set; }

        /// <summary>
        /// Gets execution statistics for this branch
        /// </summary>
        public BranchStatistics Statistics { get; }

        /// <summary>
        /// Branch execution statistics
        /// </summary>
        public class BranchStatistics
        {
            public int ExecutionCount { get; set; }
            public int SkippedCount { get; set; }
            public TimeSpan TotalExecutionTime { get; set; }
            public TimeSpan AverageExecutionTime => ExecutionCount > 0 
                ? TimeSpan.FromMilliseconds(TotalExecutionTime.TotalMilliseconds / ExecutionCount) 
                : TimeSpan.Zero;
            public DateTime? LastExecutedAt { get; set; }
        }

        /// <summary>
        /// Initializes a new instance of the PipelineBranch class
        /// </summary>
        /// <param name="name">Name of the branch</param>
        /// <param name="condition">Optional condition for branch execution</param>
        public PipelineBranch(string name, Predicate<Matrix<T>>? condition = null)
        {
            Id = Guid.NewGuid().ToString();
            Name = name;
            _steps = new List<IPipelineStep<T>>();
            _condition = condition;
            _mergeStrategy = BranchMergeStrategy.Concatenate;
            ExecuteInParallel = false;
            Priority = 0;
            IsEnabled = true;
            Statistics = new BranchStatistics();
        }

        /// <summary>
        /// Adds a step to this branch
        /// </summary>
        /// <param name="step">The pipeline step to add</param>
        public void AddStep(IPipelineStep<T> step)
        {
            if (step == null)
            {
                throw new ArgumentNullException(nameof(step));
            }

            _steps.Add(step);
        }

        /// <summary>
        /// Removes a step from this branch
        /// </summary>
        /// <param name="step">The pipeline step to remove</param>
        /// <returns>True if the step was removed, false otherwise</returns>
        public bool RemoveStep(IPipelineStep<T> step)
        {
            return _steps.Remove(step);
        }

        /// <summary>
        /// Clears all steps from this branch
        /// </summary>
        public void ClearSteps()
        {
            _steps.Clear();
        }

        /// <summary>
        /// Sets the merge parameters for this branch
        /// </summary>
        /// <param name="parameters">Merge parameters</param>
        public void SetMergeParameters(Dictionary<string, object> parameters)
        {
            _mergeParameters = parameters ?? new Dictionary<string, object>();
        }

        /// <summary>
        /// Evaluates whether this branch should execute for the given data
        /// </summary>
        /// <param name="data">Input data</param>
        /// <returns>True if the branch should execute, false otherwise</returns>
        public bool ShouldExecute(Matrix<T> data)
        {
            if (!IsEnabled)
            {
                return false;
            }

            if (_condition == null)
            {
                return true;
            }

            return _condition(data);
        }

        /// <summary>
        /// Executes all steps in this branch
        /// </summary>
        /// <param name="inputs">Input data</param>
        /// <param name="targets">Target data (optional)</param>
        /// <returns>Transformed data from the branch</returns>
        public async Task<Matrix<T>> ExecuteAsync(Matrix<T> inputs, Vector<T>? targets = null)
        {
            if (!ShouldExecute(inputs))
            {
                Statistics.SkippedCount++;
                return inputs;
            }

            var startTime = DateTime.UtcNow;
            Statistics.ExecutionCount++;

            var currentData = inputs;

            try
            {
                // Execute all steps in sequence
                foreach (var step in _steps)
                {
                    if (!step.IsFitted)
                    {
                        await step.FitAsync(currentData, targets);
                    }
                    currentData = await step.TransformAsync(currentData);
                }

                var executionTime = DateTime.UtcNow - startTime;
                Statistics.TotalExecutionTime = Statistics.TotalExecutionTime.Add(executionTime);
                Statistics.LastExecutedAt = DateTime.UtcNow;

                return currentData;
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Branch '{Name}' execution failed: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Gets merge parameters
        /// </summary>
        /// <returns>Dictionary of merge parameters</returns>
        public Dictionary<string, object> GetMergeParameters()
        {
            return _mergeParameters ?? new Dictionary<string, object>();
        }

        /// <summary>
        /// Validates the branch configuration
        /// </summary>
        /// <returns>Validation result</returns>
        public (bool IsValid, string? ErrorMessage) Validate()
        {
            if (string.IsNullOrWhiteSpace(Name))
            {
                return (false, "Branch name cannot be empty");
            }

            if (_steps.Count == 0)
            {
                return (false, "Branch must contain at least one step");
            }

            return (true, null);
        }

        /// <summary>
        /// Creates a deep copy of this branch
        /// </summary>
        /// <returns>A new instance with the same configuration</returns>
        public PipelineBranch<T> Clone()
        {
            var clone = new PipelineBranch<T>(Name + "_Clone", _condition)
            {
                MergeStrategy = MergeStrategy,
                ExecuteInParallel = ExecuteInParallel,
                Priority = Priority,
                IsEnabled = IsEnabled
            };

            foreach (var step in _steps)
            {
                clone.AddStep(step);
            }

            if (_mergeParameters != null)
            {
                clone.SetMergeParameters(new Dictionary<string, object>(_mergeParameters));
            }

            return clone;
        }
    }
}