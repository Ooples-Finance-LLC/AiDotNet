using System;
using System.Linq;
using AiDotNet.LinearAlgebra;
using AiDotNet.Helpers;

namespace AiDotNet.MultimodalAI.Encoders
{
    /// <summary>
    /// Audio-specific modality encoder for processing audio data
    /// </summary>
    public class AudioModalityEncoder : ModalityEncoderBase
    {
        private readonly int _sampleRate;
        private readonly int _frameSize;
        private readonly bool _useSpectralFeatures;
        
        /// <summary>
        /// Initializes a new instance of AudioModalityEncoder
        /// </summary>
        /// <param name="outputDimension">Output dimension of the encoder (default: 256)</param>
        /// <param name="sampleRate">Sample rate of audio data (default: 16000)</param>
        /// <param name="frameSize">Frame size for feature extraction (default: 512)</param>
        /// <param name="useSpectralFeatures">Whether to extract spectral features (default: true)</param>
        public AudioModalityEncoder(int outputDimension = 256, int sampleRate = 16000, 
            int frameSize = 512, bool useSpectralFeatures = true) 
            : base("Audio", outputDimension)
        {
            _sampleRate = sampleRate;
            _frameSize = frameSize;
            _useSpectralFeatures = useSpectralFeatures;
        }

        /// <summary>
        /// Encodes audio data into a vector representation
        /// </summary>
        /// <param name="input">Audio data as double[], float[], or Tensor<double></param>
        /// <returns>Encoded vector representation</returns>
        public override Vector<double> Encode(object input)
        {
            if (!ValidateInput(input))
            {
                throw new ArgumentException($"Invalid input type for audio encoding. Expected double[], float[], or Tensor<double>, got {input?.GetType()?.Name ?? "null"}");
            }

            // Preprocess the input
            var preprocessed = Preprocess(input);
            var audioData = preprocessed as double[] ?? throw new InvalidOperationException("Preprocessing failed");

            // Extract features
            var features = ExtractAudioFeatures(audioData);
            
            // Project to output dimension if needed
            if (features.Length != OutputDimension)
            {
                features = ProjectToOutputDimension(features);
            }

            // Normalize the output
            return Normalize(features);
        }

        /// <summary>
        /// Preprocesses raw audio input
        /// </summary>
        public override object Preprocess(object input)
        {
            double[] audioData;

            switch (input)
            {
                case double[] doubleArray:
                    audioData = doubleArray;
                    break;
                case float[] floatArray:
                    audioData = floatArray.Select(f => (double)f).ToArray();
                    break;
                case Tensor<double> tensor:
                    audioData = tensor.ToArray();
                    break;
                case Tensor<float> floatTensor:
                    audioData = floatTensor.ToArray().Select(f => (double)f).ToArray();
                    break;
                default:
                    throw new ArgumentException($"Unsupported input type: {input?.GetType()?.Name ?? "null"}");
            }

            // Apply preprocessing steps
            audioData = RemoveDCOffset(audioData);
            audioData = NormalizeAmplitude(audioData);
            
            if (_useSpectralFeatures)
            {
                audioData = ApplyPreEmphasis(audioData, 0.97);
            }

            return audioData;
        }

        /// <summary>
        /// Validates the input for audio encoding
        /// </summary>
        protected override bool ValidateInput(object input)
        {
            return input is double[] || input is float[] || 
                   input is Tensor<double> || input is Tensor<float>;
        }

        /// <summary>
        /// Extracts audio features from preprocessed data
        /// </summary>
        private Vector<double> ExtractAudioFeatures(double[] audioData)
        {
            var features = new System.Collections.Generic.List<double>();

            // Time domain features
            features.AddRange(ExtractTimeDomainFeatures(audioData));

            if (_useSpectralFeatures)
            {
                // Frequency domain features
                features.AddRange(ExtractSpectralFeatures(audioData));
            }

            // Statistical features
            features.AddRange(ExtractStatisticalFeatures(audioData));

            return new Vector<double>(features.ToArray());
        }

        /// <summary>
        /// Extracts time domain features
        /// </summary>
        private double[] ExtractTimeDomainFeatures(double[] audioData)
        {
            var features = new System.Collections.Generic.List<double>();

            // Zero Crossing Rate
            double zcr = CalculateZeroCrossingRate(audioData);
            features.Add(zcr);

            // Energy
            double energy = audioData.Sum(x => x * x) / audioData.Length;
            features.Add(energy);

            // Root Mean Square
            double rms = Math.Sqrt(energy);
            features.Add(rms);

            // Peak amplitude
            double peak = audioData.Max(Math.Abs);
            features.Add(peak);

            return features.ToArray();
        }

        /// <summary>
        /// Extracts spectral features using basic FFT
        /// </summary>
        private double[] ExtractSpectralFeatures(double[] audioData)
        {
            var features = new System.Collections.Generic.List<double>();

            // Simple spectral analysis (placeholder for full FFT)
            // In production, you would use a proper FFT library
            int numBins = Math.Min(32, audioData.Length / 2);
            var spectrum = ComputeSimpleSpectrum(audioData, numBins);

            // Spectral centroid
            double centroid = CalculateSpectralCentroid(spectrum);
            features.Add(centroid);

            // Spectral spread
            double spread = CalculateSpectralSpread(spectrum, centroid);
            features.Add(spread);

            // Spectral flux
            double flux = CalculateSpectralFlux(spectrum);
            features.Add(flux);

            // Add spectral bins (reduced set)
            features.AddRange(spectrum.Take(Math.Min(16, spectrum.Length)));

            return features.ToArray();
        }

        /// <summary>
        /// Extracts statistical features
        /// </summary>
        private double[] ExtractStatisticalFeatures(double[] audioData)
        {
            var features = new System.Collections.Generic.List<double>();

            // Mean
            double mean = audioData.Average();
            features.Add(mean);

            // Standard deviation
            double stdDev = Math.Sqrt(audioData.Select(x => Math.Pow(x - mean, 2)).Average());
            features.Add(stdDev);

            // Skewness
            double skewness = audioData.Select(x => Math.Pow((x - mean) / stdDev, 3)).Average();
            features.Add(skewness);

            // Kurtosis
            double kurtosis = audioData.Select(x => Math.Pow((x - mean) / stdDev, 4)).Average() - 3;
            features.Add(kurtosis);

            return features.ToArray();
        }

        /// <summary>
        /// Projects features to the desired output dimension
        /// </summary>
        private Vector<double> ProjectToOutputDimension(Vector<double> features)
        {
            if (features.Length == OutputDimension)
                return features;

            var result = new double[OutputDimension];

            if (features.Length > OutputDimension)
            {
                // Downsample by averaging groups
                int groupSize = features.Length / OutputDimension;
                for (int i = 0; i < OutputDimension; i++)
                {
                    int start = i * groupSize;
                    int end = Math.Min(start + groupSize, features.Length);
                    double sum = 0;
                    for (int j = start; j < end; j++)
                    {
                        sum += features[j];
                    }
                    result[i] = sum / (end - start);
                }
            }
            else
            {
                // Upsample by interpolation
                double scale = (double)(features.Length - 1) / (OutputDimension - 1);
                for (int i = 0; i < OutputDimension; i++)
                {
                    double pos = i * scale;
                    int lower = (int)pos;
                    int upper = Math.Min(lower + 1, features.Length - 1);
                    double frac = pos - lower;
                    result[i] = features[lower] * (1 - frac) + features[upper] * frac;
                }
            }

            return new Vector<double>(result);
        }

        /// <summary>
        /// Removes DC offset from audio signal
        /// </summary>
        private double[] RemoveDCOffset(double[] audio)
        {
            double mean = audio.Average();
            return audio.Select(x => x - mean).ToArray();
        }

        /// <summary>
        /// Normalizes audio amplitude to [-1, 1] range
        /// </summary>
        private double[] NormalizeAmplitude(double[] audio)
        {
            double maxAbs = audio.Max(Math.Abs);
            if (maxAbs > 0)
            {
                return audio.Select(x => x / maxAbs).ToArray();
            }
            return audio;
        }

        /// <summary>
        /// Applies pre-emphasis filter
        /// </summary>
        private double[] ApplyPreEmphasis(double[] audio, double coefficient)
        {
            var result = new double[audio.Length];
            result[0] = audio[0];
            for (int i = 1; i < audio.Length; i++)
            {
                result[i] = audio[i] - coefficient * audio[i - 1];
            }
            return result;
        }

        /// <summary>
        /// Calculates zero crossing rate
        /// </summary>
        private double CalculateZeroCrossingRate(double[] audio)
        {
            int crossings = 0;
            for (int i = 1; i < audio.Length; i++)
            {
                if (Math.Sign(audio[i]) != Math.Sign(audio[i - 1]))
                {
                    crossings++;
                }
            }
            return (double)crossings / (audio.Length - 1);
        }

        /// <summary>
        /// Computes a simple spectrum (placeholder for FFT)
        /// </summary>
        private double[] ComputeSimpleSpectrum(double[] audio, int numBins)
        {
            var spectrum = new double[numBins];
            int windowSize = audio.Length / numBins;

            for (int i = 0; i < numBins; i++)
            {
                int start = i * windowSize;
                int end = Math.Min(start + windowSize, audio.Length);
                double energy = 0;
                for (int j = start; j < end; j++)
                {
                    energy += audio[j] * audio[j];
                }
                spectrum[i] = Math.Sqrt(energy / (end - start));
            }

            return spectrum;
        }

        /// <summary>
        /// Calculates spectral centroid
        /// </summary>
        private double CalculateSpectralCentroid(double[] spectrum)
        {
            double weightedSum = 0;
            double magnitudeSum = 0;

            for (int i = 0; i < spectrum.Length; i++)
            {
                weightedSum += i * spectrum[i];
                magnitudeSum += spectrum[i];
            }

            return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0;
        }

        /// <summary>
        /// Calculates spectral spread
        /// </summary>
        private double CalculateSpectralSpread(double[] spectrum, double centroid)
        {
            double weightedVariance = 0;
            double magnitudeSum = 0;

            for (int i = 0; i < spectrum.Length; i++)
            {
                double deviation = i - centroid;
                weightedVariance += deviation * deviation * spectrum[i];
                magnitudeSum += spectrum[i];
            }

            return magnitudeSum > 0 ? Math.Sqrt(weightedVariance / magnitudeSum) : 0;
        }

        /// <summary>
        /// Calculates spectral flux
        /// </summary>
        private double CalculateSpectralFlux(double[] spectrum)
        {
            // For a single frame, return the sum of squared magnitudes
            return spectrum.Sum(x => x * x);
        }
    }
}