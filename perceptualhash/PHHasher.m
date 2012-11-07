//
//  PHHasher.m
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012/11/05.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import "PHHasher.h"
#import <QuartzCore/QuartzCore.h>

#define NORMALIZED_DIM 512 //px
#define GREY_LEVELS 255

typedef enum {
  PH_BLOCK_MEAN_VALUE,
} PHAlgorithmType;

int compare_chars(const void *a, const void *b)
{
  const unsigned char *ia = (const unsigned char *)a;
  const unsigned char *ib = (const unsigned char *)b;
  return (*ia - *ib);
}

const char *ph_NSDataToHexString(NSData *hash)
{
  const unsigned char *dataBuffer = (const unsigned char *)[hash bytes];
  
  if (!dataBuffer) {
    return [[NSString string] cStringUsingEncoding:NSASCIIStringEncoding];
  }

  NSUInteger dataLength = [hash length];
  NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
  
  for (int i = 0; i < dataLength; ++i) {
    [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
  }
  return [hexString cStringUsingEncoding:NSASCIIStringEncoding];
}

NSData *ph_HexStringToNSData(const char *str)
{
  return nil;
}

@implementation PHHasher

- (NSData *)perceptualHashWithImage:(NSImage *)image
{
  NSImage *normalizedImage = image;
  NSData *buffer = [self hashImage: normalizedImage withAlgorithm:PH_BLOCK_MEAN_VALUE];
  return [buffer copy];
}

- (NSImage *)normalizeImage:(NSImage *)image
{
  // use core image false colour?
  // strip all but luminance channel
  // 1.0 isotropic blur
  // resize to 512 x 512, bicubic
  // equalize to 256 grey levels
  // Y = 0.2126 R + 0.7152 G + 0.0722 B per http://en.wikipedia.org/wiki/Luminance_(relative) ... colour cube?
  CIFilter *luminance = [CIFilter filterWithName:@"CIColorCube"];
  CIFilter *affineClamp = [CIFilter filterWithName:@"CIAffineClamp"];
  CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
  CIFilter *resize = [CIFilter filterWithName:@"CILanczosScaleTransform"];
  //  CIFilter *equalize;
  CIImage *sourceImage = [CIImage imageWithData:[image TIFFRepresentation]];
  int bytesPerRow = NORMALIZED_DIM * 4;
  void *buffer = calloc(NORMALIZED_DIM, bytesPerRow);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  CGContextRef ctxRef = CGBitmapContextCreate(buffer,
                                              NORMALIZED_DIM,
                                              NORMALIZED_DIM,
                                              8,
                                              bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
  CIContext *context = [CIContext contextWithCGContext:ctxRef options:nil];
  CGColorSpaceRelease(colorSpace);
  CGContextRelease(ctxRef);
  [luminance setDefaults];
  [luminance setValue:sourceImage forKey:kCIInputImageKey];
  [luminance setValue:@64.0 forKey:@"inputCubeDimension"];
  [luminance setValue:[self perceptualColorCubeWithSize:64] forKey:@"inputCubeData"];
  CIImage *luminanceResult = [luminance valueForKey:kCIOutputImageKey];
//  [affineClamp setDefaults]; // to remove white fringe on blur
//  [affineClamp setValue:luminanceResult forKey:kCIInputImageKey];
//  CIImage *affineResult = [affineClamp valueForKey:kCIOutputImageKey];
  [blur setDefaults];
  [blur setValue:luminanceResult forKey:kCIInputImageKey];
  [blur setValue:@20.0f forKey:@"inputRadius"];
  CIImage *blurResult = [blur valueForKey:kCIOutputImageKey];
  [resize setDefaults];
  [resize setValue:[self scaleFactor:image] forKey:@"inputScale"];
  [resize setValue:[self aspectRatio:image] forKey:@"inputAspectRatio"];
  [resize setValue:blurResult forKey:kCIInputImageKey];
  CIImage *resizeResult = [resize valueForKey:kCIOutputImageKey];
  CIImage *result = [resizeResult imageByCroppingToRect:CGRectMake(0.0, 0.0, NORMALIZED_DIM, NORMALIZED_DIM)];
  CGImageRef cgImage = [context createCGImage:result fromRect:[result extent]];
  [self histogramEqualize:cgImage];
  NSImage *normalizedImage = [[NSImage alloc] initWithCGImage:cgImage size:NSZeroSize];
  CFRelease(cgImage);
  free(buffer);

  return normalizedImage;
}

- (NSData *)hashImage:(NSImage *)image withAlgorithm:(PHAlgorithmType)algorithm
{
  NSData *buffer = nil;
  switch (algorithm) {
    case PH_BLOCK_MEAN_VALUE : {
      buffer = [image TIFFRepresentation];
    };
    default: {
    };
  }
  return buffer;
}

- (NSNumber *)scaleFactor:(NSImage *)image
{
  CGFloat scale = NORMALIZED_DIM / image.size.height;
  return [NSNumber numberWithFloat:scale];
}

- (NSNumber *)aspectRatio:(NSImage *)image
{
  CGFloat scale = [[self scaleFactor:image] floatValue];
  CGFloat scaledX = image.size.width * scale;
  CGFloat aspect = NORMALIZED_DIM / scaledX;
  return [NSNumber numberWithFloat:aspect];
}

- (void)histogramEqualize:(CGImageRef)cgImage;
// http://en.wikipedia.org/wiki/Histogram_equalization
{

  int bytesPerRow = NORMALIZED_DIM * 4;
  void *contextBuffer = calloc(NORMALIZED_DIM, bytesPerRow);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  CGContextRef ctxRef = CGBitmapContextCreate(contextBuffer,
                                              NORMALIZED_DIM,
                                              NORMALIZED_DIM,
                                              8,
                                              bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
  CGColorSpaceRelease(colorSpace);
  CGContextDrawImage(ctxRef, CGRectMake(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)), cgImage);
  CGContextRelease(ctxRef);

  unsigned char *originalPixelBuffer = (unsigned char *)contextBuffer;

  long histogram[GREY_LEVELS];
  long cumulativeHistogram[GREY_LEVELS];
  for (int j = 0; j < GREY_LEVELS; j++) {
    histogram[j] = 0;
    cumulativeHistogram[j] = 0;
  }
  for (int i = 0; i < bytesPerRow*NORMALIZED_DIM; i+=4) {
    int value = (int)originalPixelBuffer[i];
    histogram[value] += 1;
  }
  long cumulative = 0;
  for (int j = 0; j < GREY_LEVELS; j++) {
    cumulative += histogram[j];
    cumulativeHistogram[j] = cumulative;
  }

  // figure out normalized cdf
  int minGreyLevel = 0;
  int maxGreyLevel = GREY_LEVELS-1;
  while (true) {
    if (histogram[minGreyLevel] != 0 || minGreyLevel >= GREY_LEVELS-1) {
      break;
    } else {
      minGreyLevel++;
    }
  }
  while (true) {
    if (histogram[maxGreyLevel] != 0 || maxGreyLevel <= 0) {
      break;
    } else {
      maxGreyLevel--;
    }
  }
  int adjustedValues[GREY_LEVELS];
  for (int j = 1; j < GREY_LEVELS; j++) {
    float top = cumulativeHistogram[j] - cumulativeHistogram[minGreyLevel];
    float bottom = NORMALIZED_DIM*NORMALIZED_DIM-cumulativeHistogram[minGreyLevel];
    float divided = top/bottom;
    float mult = divided*(GREY_LEVELS-1);
    adjustedValues[j] = (int)roundl(mult);
  }

  NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                        pixelsWide:NORMALIZED_DIM
                                                                        pixelsHigh:NORMALIZED_DIM
                                                                     bitsPerSample:8
                                                                   samplesPerPixel:3
                                                                          hasAlpha:NO
                                                                          isPlanar:NO
                                                                    colorSpaceName:NSDeviceRGBColorSpace
                                                                      bitmapFormat:0
                                                                       bytesPerRow:NORMALIZED_DIM*3
                                                                      bitsPerPixel:24];
  
  NSImage *image = [NSImage new];
  [image addRepresentation:bitmapRep];

  unsigned char *newPixelBuffer = [bitmapRep bitmapData];

  for (int y = 0; y < NORMALIZED_DIM; y++) {
    for (int x = 0; x < NORMALIZED_DIM*3; x++) {
      unsigned char oldValue = originalPixelBuffer[(x+y*NORMALIZED_DIM)*4]; // original has alpha, hence 4
      unsigned char newValue = adjustedValues[oldValue];
      newPixelBuffer[(x+y*NORMALIZED_DIM)*3 + 0] = newValue;
      newPixelBuffer[(x+y*NORMALIZED_DIM)*3 + 1] = newValue;
      newPixelBuffer[(x+y*NORMALIZED_DIM)*3 + 2] = newValue;
    }
  }

  NSString *filename = @"/Users/rgm/Desktop/testimage2.jpg";
  NSDictionary *opts = @{NSImageCompressionFactor : @1.0};
  NSData *imageData = [bitmapRep representationUsingType:NSJPEGFileType properties:opts];
  [imageData writeToFile:filename atomically:NO];

  unsigned char blockMeans[HASH_LENGTH];
  int runLength = NORMALIZED_DIM*NORMALIZED_DIM/HASH_LENGTH;
  for (int i = 0; i < HASH_LENGTH; i++) {
    long accumulator = 0;
    for (int j = 0; j < runLength; j++) {
      long currentValue = (long)newPixelBuffer[j+(i*runLength)*3];
      accumulator += currentValue;
    }
    int mean = (int)roundtol((float)accumulator/runLength);
    printf("%2d => %7ld %7d %5d\n", i, accumulator, runLength, mean);
    blockMeans[i] = mean;
    // get the run
    // calculate the mean of the run
    // store it in the blockMeans
  }

  unsigned char sortedBlockMeans[HASH_LENGTH];
  memcpy(sortedBlockMeans, blockMeans, sizeof(blockMeans));
  qsort(sortedBlockMeans, HASH_LENGTH, sizeof(unsigned char), compare_chars);

  for (int i = 0; i < HASH_LENGTH; i++) {
    printf("%3d => %3d\t%3d\n", i, blockMeans[i], sortedBlockMeans[i]);
  }

  unsigned char median = sortedBlockMeans[(int)floor(HASH_LENGTH-1)/2];
  printf("median: %d\n", median);
  // figure out the median value of means
  // convert to a binary number as mean[i] < median => 0 else 1
  unsigned char hash[HASH_LENGTH+1];
  for (int i = 0; i < HASH_LENGTH; i++) {
    if (blockMeans[i] < median) {
      hash[i] = '0';
    } else {
      hash[i] = '1';
    }
  }
  hash[HASH_LENGTH] = '\0';
  printf("block hash binary: %s\n", hash); // 0111111110000000001101111111111111000111011111110000000000000000

  unsigned char bitHash[HASH_LENGTH/8];
  for (int i = 0; i < HASH_LENGTH/8; i++) {
    bitHash[i] = 0;
  }
  for (int i = 0; i < HASH_LENGTH; i++) {
    int charIndex = (i / 8);
    int bitIndex = 7-(i % 8);
    int blockMean = blockMeans[i];
    if (blockMean >= median) {
      bitHash[charIndex] |= (1 << bitIndex); // set the bit
    }
  }
  printf("block hash hex: "); // expect 7F8037FFC77F0000
  for (int i = 0; i < HASH_LENGTH/8; i++) {
    printf("%02X", bitHash[i]);
  }
  printf("\n");

  free(contextBuffer);
}

- (NSData *)perceptualColorCubeWithSize:(const unsigned int)size
{
  // Y = 0.2126 R + 0.7152 G + 0.0722 B per http://en.wikipedia.org/wiki/Luminance_(relative)
  int cubeDataSize = size * size * size * sizeof(float)*4;
  struct colorPoint { float r, g, b, a; };
  struct colorPoint cubeData[size][size][size];
  float rgb[3];
  float redFactor = 0.2126;
  float greenFactor = 0.7152;
  float blueFactor = 0.0722;

  for (int b = 0; b < size; b++) {
    rgb[2] = ((float) b) / (size-1); // blue
    for (int g = 0; g < size; g++) {
      rgb[1] = ((float) g / (size-1)); // green
      for (int r = 0; r < size; r++) {
        rgb[0] = ((float) r / (size-1)); // red
        float luminance = (rgb[0]*redFactor) + (rgb[1]*greenFactor) + (rgb[2]*blueFactor);
        cubeData[r][g][b] = (struct colorPoint){luminance, luminance, luminance, 1.0};
      }
    }
  }

  NSData *data = [NSData dataWithBytes:cubeData length:cubeDataSize];
  return data;
}

@end
