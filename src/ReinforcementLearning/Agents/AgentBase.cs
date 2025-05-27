using AiDotNet.Helpers;
using AiDotNet.Interfaces;
using AiDotNet.LinearAlgebra;
using AiDotNet.ReinforcementLearning.Interfaces;
using System;

namespace AiDotNet.ReinforcementLearning.Agents
{
    /// <summary>
    /// Base class for reinforcement learning agents that provides common functionality.
    /// </summary>
    /// <typeparam name="TState">The type used to represent the environment state, typically Tensor&lt;T&gt;.</typeparam>
    /// <typeparam name="TAction">The type used to represent actions, typically int for discrete actions or Vector&lt;T&gt; for continuous.</typeparam>
    /// <typeparam name="T">The numeric type used for calculations (float, double, etc.).</typeparam>
    public abstract class AgentBase<TState, TAction, T> : IAgent<TState, TAction, T>
        where TState : Tensor<T>
    {
        /// <summary>
        /// Gets the numeric operations for type T.
        /// </summary>
        protected INumericOperations<T> NumOps => MathHelper.GetNumericOperations<T>();

        /// <summary>
        /// Gets the random number generator used by the agent.
        /// </summary>
        protected Random Random { get; }

        /// <summary>
        /// Gets the discount factor (gamma) used for future rewards.
        /// </summary>
        protected T Gamma { get; }

        /// <summary>
        /// Gets the soft update factor (tau) used for target network updates.
        /// </summary>
        protected T Tau { get; }

        /// <summary>
        /// Gets the batch size used for training.
        /// </summary>
        protected int BatchSize { get; }

        /// <summary>
        /// Gets the total number of steps the agent has taken.
        /// </summary>
        protected int TotalSteps { get; private set; }

        /// <summary>
        /// Gets a value indicating whether the agent is currently in training mode.
        /// </summary>
        public bool IsTraining { get; private set; }
        
        /// <summary>
        /// Gets the last computed loss value.
        /// </summary>
        protected T LastLoss { get; set; }

        /// <summary>
        /// Initializes a new instance of the <see cref="AgentBase{TState, TAction, T}"/> class.
        /// </summary>
        /// <param name="gamma">The discount factor for future rewards.</param>
        /// <param name="tau">The soft update factor for target networks.</param>
        /// <param name="batchSize">The batch size for training.</param>
        /// <param name="seed">Optional seed for the random number generator.</param>
        protected AgentBase(double gamma, double tau, int batchSize, int? seed = null)
        {
            Gamma = NumOps.FromDouble(gamma);
            Tau = NumOps.FromDouble(tau);
            BatchSize = batchSize;
            TotalSteps = 0;
            IsTraining = true;
            LastLoss = NumOps.Zero;
            Random = seed.HasValue ? new Random(seed.Value) : new Random();
        }

        /// <summary>
        /// Increments the total step counter.
        /// </summary>
        protected void IncrementStepCounter()
        {
            TotalSteps++;
        }

        /// <summary>
        /// Selects an action based on the current state.
        /// </summary>
        /// <param name="state">The current state observation.</param>
        /// <param name="isTraining">A flag indicating whether the agent is in training mode.</param>
        /// <returns>The selected action.</returns>
        public abstract TAction SelectAction(TState state, bool isTraining = true);

        /// <summary>
        /// Updates the agent's knowledge based on an experience tuple.
        /// </summary>
        /// <param name="state">The state before the action was taken.</param>
        /// <param name="action">The action that was taken.</param>
        /// <param name="reward">The reward received after taking the action.</param>
        /// <param name="nextState">The state after the action was taken.</param>
        /// <param name="done">A flag indicating whether the episode ended after this action.</param>
        public abstract void Learn(TState state, TAction action, T reward, TState nextState, bool done);

        /// <summary>
        /// Saves the agent's state to a file.
        /// </summary>
        /// <param name="filePath">The path where the agent's state should be saved.</param>
        public virtual void Save(string filePath)
        {
            throw new NotImplementedException($"Save method not implemented for {GetType().Name}");
        }

        /// <summary>
        /// Loads the agent's state from a file.
        /// </summary>
        /// <param name="filePath">The path from which to load the agent's state.</param>
        public virtual void Load(string filePath)
        {
            throw new NotImplementedException($"Load method not implemented for {GetType().Name}");
        }

        /// <summary>
        /// Sets the agent's training mode.
        /// </summary>
        /// <param name="isTraining">A flag indicating whether the agent should be in training mode.</param>
        public virtual void SetTrainingMode(bool isTraining)
        {
            IsTraining = isTraining;
        }
        
        /// <summary>
        /// Gets the last computed loss value.
        /// </summary>
        /// <returns>The last computed loss value.</returns>
        public virtual T GetLatestLoss()
        {
            return LastLoss;
        }

        // Using MathHelper.Clamp instead of a local implementation
    }
}