using System;
using System.Threading.Tasks;

namespace AiDotNet.Examples
{
    /// <summary>
    /// Main program entry point for running AiDotNet examples.
    /// </summary>
    public class Program
    {
        /// <summary>
        /// Main entry point of the application.
        /// </summary>
        /// <param name="args">Command line arguments</param>
        public static async Task Main(string[] args)
        {
            try
            {
                Console.WriteLine("=== AiDotNet Examples Runner ===\n");

                if (args.Length == 0)
                {
                    // Run all examples by default
                    await ComprehensiveModernAIExample.RunAllExamples();
                }
                else
                {
                    // Parse command line arguments
                    var example = args[0].ToLowerInvariant();
                    
                    switch (example)
                    {
                        case "all":
                            await ComprehensiveModernAIExample.RunAllExamples();
                            break;
                        case "pipeline":
                            await RunSpecificExample("Fluent Pipeline API", 
                                ComprehensiveModernAIExample.RunFluentPipelineExample);
                            break;
                        case "vision":
                            await RunSpecificExample("Vision Transformer", 
                                ComprehensiveModernAIExample.RunVisionTransformerExample);
                            break;
                        case "diffusion":
                            await RunSpecificExample("Diffusion Models", 
                                ComprehensiveModernAIExample.RunDiffusionModelExample);
                            break;
                        case "nas":
                            await RunSpecificExample("Neural Architecture Search", 
                                ComprehensiveModernAIExample.RunNeuralArchitectureSearchExample);
                            break;
                        case "automl":
                            await RunSpecificExample("AutoML Pipeline", 
                                ComprehensiveModernAIExample.RunAutoMLPipelineExample);
                            break;
                        case "deployment":
                            await RunSpecificExample("Model Deployment", 
                                ComprehensiveModernAIExample.RunDeploymentExample);
                            break;
                        case "federated":
                            await RunSpecificExample("Federated Learning", 
                                ComprehensiveModernAIExample.RunFederatedLearningExample);
                            break;
                        case "multimodal":
                            await RunSpecificExample("Multimodal AI", 
                                ComprehensiveModernAIExample.RunMultimodalExample);
                            break;
                        case "help":
                        case "--help":
                        case "-h":
                            ShowHelp();
                            break;
                        default:
                            Console.WriteLine($"Unknown example: {example}");
                            ShowHelp();
                            break;
                    }
                }
                
                Console.WriteLine("\nPress any key to exit...");
                Console.ReadKey();
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"\nError: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                Console.ResetColor();
                Environment.Exit(1);
            }
        }

        /// <summary>
        /// Runs a specific example with proper error handling and timing.
        /// </summary>
        private static async Task RunSpecificExample(string exampleName, Func<Task> exampleFunc)
        {
            Console.WriteLine($"\n=== Running {exampleName} Example ===");
            var startTime = DateTime.Now;
            
            try
            {
                await exampleFunc();
                
                var elapsed = DateTime.Now - startTime;
                Console.WriteLine($"\n{exampleName} completed in {elapsed.TotalSeconds:F2} seconds");
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"\nError in {exampleName}: {ex.Message}");
                Console.ResetColor();
                throw;
            }
        }

        /// <summary>
        /// Shows help information for command line usage.
        /// </summary>
        private static void ShowHelp()
        {
            Console.WriteLine("\nUsage: AiDotNet.Examples [example]");
            Console.WriteLine("\nAvailable examples:");
            Console.WriteLine("  all        - Run all examples (default)");
            Console.WriteLine("  pipeline   - Fluent Pipeline API example");
            Console.WriteLine("  vision     - Vision Transformer example");
            Console.WriteLine("  diffusion  - Diffusion Models example");
            Console.WriteLine("  nas        - Neural Architecture Search example");
            Console.WriteLine("  automl     - AutoML Pipeline example");
            Console.WriteLine("  deployment - Model Deployment example");
            Console.WriteLine("  federated  - Federated Learning example");
            Console.WriteLine("  multimodal - Multimodal AI example");
            Console.WriteLine("  help       - Show this help message");
            Console.WriteLine("\nExample: AiDotNet.Examples diffusion");
        }
    }
}