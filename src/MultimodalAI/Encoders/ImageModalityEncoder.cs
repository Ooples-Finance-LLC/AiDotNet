using System;
using System.Linq;
using AiDotNet.LinearAlgebra;

namespace AiDotNet.MultimodalAI.Encoders
{
    /// <summary>
    /// Image-specific modality encoder for processing image data
    /// </summary>
    public class ImageModalityEncoder : ModalityEncoderBase
    {
        private readonly int _patchSize;
        private readonly bool _useColorHistogram;
        private readonly bool _useTextureFeatures;
        
        /// <summary>
        /// Initializes a new instance of ImageModalityEncoder
        /// </summary>
        /// <param name="outputDimension">Output dimension of the encoder (default: 512)</param>
        /// <param name="patchSize">Size of patches for feature extraction (default: 16)</param>
        /// <param name="useColorHistogram">Whether to extract color histogram features (default: true)</param>
        /// <param name="useTextureFeatures">Whether to extract texture features (default: true)</param>
        public ImageModalityEncoder(int outputDimension = 512, int patchSize = 16,
            bool useColorHistogram = true, bool useTextureFeatures = true) 
            : base("Image", outputDimension)
        {
            _patchSize = patchSize;
            _useColorHistogram = useColorHistogram;
            _useTextureFeatures = useTextureFeatures;
        }

        /// <summary>
        /// Encodes image data into a vector representation
        /// </summary>
        /// <param name="input">Image data as 2D/3D array or Tensor</param>
        /// <returns>Encoded vector representation</returns>
        public override Vector<double> Encode(object input)
        {
            if (!ValidateInput(input))
            {
                throw new ArgumentException($"Invalid input type for image encoding. Expected array or Tensor, got {input?.GetType()?.Name ?? "null"}");
            }

            // Preprocess the input
            var preprocessed = Preprocess(input);
            var imageData = preprocessed as ImageData ?? throw new InvalidOperationException("Preprocessing failed");

            // Extract features
            var features = ExtractImageFeatures(imageData);
            
            // Project to output dimension if needed
            if (features.Length != OutputDimension)
            {
                features = ProjectToOutputDimension(features);
            }

            // Normalize the output
            return Normalize(features);
        }

        /// <summary>
        /// Preprocesses raw image input
        /// </summary>
        public override object Preprocess(object input)
        {
            ImageData imageData;

            switch (input)
            {
                case double[,] gray2D:
                    imageData = new ImageData
                    {
                        Width = gray2D.GetLength(1),
                        Height = gray2D.GetLength(0),
                        Channels = 1,
                        Data = Flatten2DArray(gray2D)
                    };
                    break;
                    
                case float[,] grayFloat2D:
                    imageData = new ImageData
                    {
                        Width = grayFloat2D.GetLength(1),
                        Height = grayFloat2D.GetLength(0),
                        Channels = 1,
                        Data = Flatten2DArray(grayFloat2D).Select(f => (double)f).ToArray()
                    };
                    break;
                    
                case double[,,] rgb3D:
                    imageData = new ImageData
                    {
                        Width = rgb3D.GetLength(2),
                        Height = rgb3D.GetLength(1),
                        Channels = rgb3D.GetLength(0),
                        Data = Flatten3DArray(rgb3D)
                    };
                    break;
                    
                case float[,,] rgbFloat3D:
                    imageData = new ImageData
                    {
                        Width = rgbFloat3D.GetLength(2),
                        Height = rgbFloat3D.GetLength(1),
                        Channels = rgbFloat3D.GetLength(0),
                        Data = Flatten3DArray(rgbFloat3D).Select(f => (double)f).ToArray()
                    };
                    break;
                    
                case Tensor<double> tensor:
                    // Assume tensor shape is [C, H, W] or [H, W]
                    if (tensor.Rank == 2)
                    {
                        imageData = new ImageData
                        {
                            Width = tensor.Shape[1],
                            Height = tensor.Shape[0],
                            Channels = 1,
                            Data = tensor.ToArray()
                        };
                    }
                    else if (tensor.Rank == 3)
                    {
                        imageData = new ImageData
                        {
                            Width = tensor.Shape[2],
                            Height = tensor.Shape[1],
                            Channels = tensor.Shape[0],
                            Data = tensor.ToArray()
                        };
                    }
                    else
                    {
                        throw new ArgumentException($"Tensor must have rank 2 or 3, got rank {tensor.Rank}");
                    }
                    break;
                    
                default:
                    throw new ArgumentException($"Unsupported input type: {input?.GetType()?.Name ?? "null"}");
            }

            // Normalize pixel values to [0, 1]
            imageData.Data = NormalizePixelValues(imageData.Data);

            return imageData;
        }

        /// <summary>
        /// Validates the input for image encoding
        /// </summary>
        protected override bool ValidateInput(object input)
        {
            return input is double[,] || input is float[,] ||
                   input is double[,,] || input is float[,,] ||
                   input is Tensor<double> || input is Tensor<float>;
        }

        /// <summary>
        /// Extracts image features from preprocessed data
        /// </summary>
        private Vector<double> ExtractImageFeatures(ImageData imageData)
        {
            var features = new System.Collections.Generic.List<double>();

            // Global statistics
            features.AddRange(ExtractGlobalStatistics(imageData));

            if (_useColorHistogram && imageData.Channels >= 3)
            {
                // Color histogram features
                features.AddRange(ExtractColorHistogram(imageData));
            }

            if (_useTextureFeatures)
            {
                // Texture features
                features.AddRange(ExtractTextureFeatures(imageData));
            }

            // Spatial features
            features.AddRange(ExtractSpatialFeatures(imageData));

            return new Vector<double>(features.ToArray());
        }

        /// <summary>
        /// Extracts global image statistics
        /// </summary>
        private double[] ExtractGlobalStatistics(ImageData imageData)
        {
            var features = new System.Collections.Generic.List<double>();

            for (int c = 0; c < imageData.Channels; c++)
            {
                var channelData = GetChannelData(imageData, c);
                
                // Mean
                double mean = channelData.Average();
                features.Add(mean);

                // Standard deviation
                double stdDev = Math.Sqrt(channelData.Select(x => Math.Pow(x - mean, 2)).Average());
                features.Add(stdDev);

                // Min and Max
                features.Add(channelData.Min());
                features.Add(channelData.Max());
            }

            return features.ToArray();
        }

        /// <summary>
        /// Extracts color histogram features
        /// </summary>
        private double[] ExtractColorHistogram(ImageData imageData)
        {
            int numBins = 16; // Reduced for efficiency
            var histogram = new double[numBins * imageData.Channels];

            for (int c = 0; c < imageData.Channels; c++)
            {
                var channelData = GetChannelData(imageData, c);
                var channelHist = ComputeHistogram(channelData, numBins);
                
                for (int b = 0; b < numBins; b++)
                {
                    histogram[c * numBins + b] = channelHist[b];
                }
            }

            // Normalize histogram
            double sum = histogram.Sum();
            if (sum > 0)
            {
                for (int i = 0; i < histogram.Length; i++)
                {
                    histogram[i] /= sum;
                }
            }

            return histogram;
        }

        /// <summary>
        /// Extracts texture features using simple edge detection
        /// </summary>
        private double[] ExtractTextureFeatures(ImageData imageData)
        {
            var features = new System.Collections.Generic.List<double>();

            // Convert to grayscale if needed
            var grayData = imageData.Channels == 1 ? imageData.Data : ConvertToGrayscale(imageData);

            // Compute gradients
            var (gradX, gradY) = ComputeGradients(grayData, imageData.Width, imageData.Height);

            // Gradient magnitude statistics
            var magnitudes = new double[gradX.Length];
            for (int i = 0; i < gradX.Length; i++)
            {
                magnitudes[i] = Math.Sqrt(gradX[i] * gradX[i] + gradY[i] * gradY[i]);
            }

            features.Add(magnitudes.Average());
            features.Add(Math.Sqrt(magnitudes.Select(x => x * x).Average()));
            features.Add(magnitudes.Max());

            // Edge density
            double edgeThreshold = 0.1;
            double edgeDensity = magnitudes.Count(m => m > edgeThreshold) / (double)magnitudes.Length;
            features.Add(edgeDensity);

            return features.ToArray();
        }

        /// <summary>
        /// Extracts spatial features by dividing image into patches
        /// </summary>
        private double[] ExtractSpatialFeatures(ImageData imageData)
        {
            var features = new System.Collections.Generic.List<double>();

            int patchesX = Math.Max(1, imageData.Width / _patchSize);
            int patchesY = Math.Max(1, imageData.Height / _patchSize);

            for (int py = 0; py < patchesY; py++)
            {
                for (int px = 0; px < patchesX; px++)
                {
                    var patchFeatures = ExtractPatchFeatures(imageData, px, py, patchesX, patchesY);
                    features.AddRange(patchFeatures);
                }
            }

            return features.ToArray();
        }

        /// <summary>
        /// Extracts features from a single patch
        /// </summary>
        private double[] ExtractPatchFeatures(ImageData imageData, int patchX, int patchY, int patchesX, int patchesY)
        {
            var features = new System.Collections.Generic.List<double>();

            int startX = patchX * imageData.Width / patchesX;
            int endX = (patchX + 1) * imageData.Width / patchesX;
            int startY = patchY * imageData.Height / patchesY;
            int endY = (patchY + 1) * imageData.Height / patchesY;

            for (int c = 0; c < imageData.Channels; c++)
            {
                double sum = 0;
                int count = 0;

                for (int y = startY; y < endY; y++)
                {
                    for (int x = startX; x < endX; x++)
                    {
                        int idx = (c * imageData.Height + y) * imageData.Width + x;
                        sum += imageData.Data[idx];
                        count++;
                    }
                }

                features.Add(sum / count);
            }

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
                // Use PCA-like approach (simplified)
                int step = features.Length / OutputDimension;
                for (int i = 0; i < OutputDimension; i++)
                {
                    int idx = Math.Min(i * step, features.Length - 1);
                    result[i] = features[idx];
                }
            }
            else
            {
                // Pad with zeros
                for (int i = 0; i < features.Length; i++)
                {
                    result[i] = features[i];
                }
            }

            return new Vector<double>(result);
        }

        /// <summary>
        /// Helper methods
        /// </summary>
        private double[] Flatten2DArray<T>(T[,] array) where T : IConvertible
        {
            int height = array.GetLength(0);
            int width = array.GetLength(1);
            var result = new double[height * width];
            
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    result[y * width + x] = Convert.ToDouble(array[y, x]);
                }
            }
            
            return result;
        }

        private double[] Flatten3DArray<T>(T[,,] array) where T : IConvertible
        {
            int channels = array.GetLength(0);
            int height = array.GetLength(1);
            int width = array.GetLength(2);
            var result = new double[channels * height * width];
            
            for (int c = 0; c < channels; c++)
            {
                for (int y = 0; y < height; y++)
                {
                    for (int x = 0; x < width; x++)
                    {
                        result[(c * height + y) * width + x] = Convert.ToDouble(array[c, y, x]);
                    }
                }
            }
            
            return result;
        }

        private double[] NormalizePixelValues(double[] pixels)
        {
            double min = pixels.Min();
            double max = pixels.Max();
            double range = max - min;

            if (range > 0)
            {
                return pixels.Select(p => (p - min) / range).ToArray();
            }
            return pixels;
        }

        private double[] GetChannelData(ImageData imageData, int channel)
        {
            int pixelsPerChannel = imageData.Width * imageData.Height;
            var channelData = new double[pixelsPerChannel];
            
            int offset = channel * pixelsPerChannel;
            Array.Copy(imageData.Data, offset, channelData, 0, pixelsPerChannel);
            
            return channelData;
        }

        private double[] ConvertToGrayscale(ImageData imageData)
        {
            int numPixels = imageData.Width * imageData.Height;
            var grayscale = new double[numPixels];

            for (int i = 0; i < numPixels; i++)
            {
                double gray = 0;
                for (int c = 0; c < imageData.Channels; c++)
                {
                    gray += imageData.Data[c * numPixels + i];
                }
                grayscale[i] = gray / imageData.Channels;
            }

            return grayscale;
        }

        private double[] ComputeHistogram(double[] data, int numBins)
        {
            var histogram = new double[numBins];
            
            foreach (var value in data)
            {
                int bin = Math.Min((int)(value * numBins), numBins - 1);
                histogram[bin]++;
            }

            return histogram;
        }

        private (double[], double[]) ComputeGradients(double[] data, int width, int height)
        {
            var gradX = new double[data.Length];
            var gradY = new double[data.Length];

            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    int idx = y * width + x;
                    
                    // Compute X gradient (Sobel-like)
                    if (x > 0 && x < width - 1)
                    {
                        gradX[idx] = data[y * width + (x + 1)] - data[y * width + (x - 1)];
                    }

                    // Compute Y gradient
                    if (y > 0 && y < height - 1)
                    {
                        gradY[idx] = data[(y + 1) * width + x] - data[(y - 1) * width + x];
                    }
                }
            }

            return (gradX, gradY);
        }

        /// <summary>
        /// Internal class for storing image data
        /// </summary>
        private class ImageData
        {
            public int Width { get; set; }
            public int Height { get; set; }
            public int Channels { get; set; }
            public double[] Data { get; set; } = Array.Empty<double>();
        }
    }
}