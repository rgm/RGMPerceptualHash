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

typedef enum {
  PH_BLOCK_MEAN_VALUE,
} PHAlgorithmType;

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
  [self printHistogram:cgImage];
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

- (void)printHistogram:(CGImageRef)cgImage;
// http://en.wikipedia.org/wiki/Histogram_equalization
{
  int histogram[255];
  long cumulativeHistogram[255];
  for (int j = 0; j < 255; j++) {
    histogram[j] = 0;
    cumulativeHistogram[j] = 0;
  }
  int bytesPerRow = NORMALIZED_DIM * 4;
  void *buffer = calloc(NORMALIZED_DIM, bytesPerRow);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  CGContextRef ctxRef = CGBitmapContextCreate(buffer,
                                              NORMALIZED_DIM,
                                              NORMALIZED_DIM,
                                              8,
                                              bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
  CGColorSpaceRelease(colorSpace);
  CGContextDrawImage(ctxRef, CGRectMake(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)), cgImage);
  CGContextRelease(ctxRef);

  unsigned char *rawPixelData = (unsigned char *)buffer;
  for (int i = 0; i < bytesPerRow*NORMALIZED_DIM; i+=4) {
    int value = (int)rawPixelData[i];
    histogram[value] += 1;
//    printf("%02X %02X %02X %02X :: ", rawPixelData[i], rawPixelData[i+1], rawPixelData[i+2], rawPixelData[i+3]);
  }
  long cumulative = 0;
  for (int j = 0; j < 255; j++) {
    cumulative += histogram[j];
    cumulativeHistogram[j] = cumulative;
    printf("%3d -> %5d\t(%6ld)\t", j, histogram[j], cumulativeHistogram[j]);
    for (int k = 0; k < histogram[j] / 100; k++) {
      printf("*");
    }
    printf("\n");
  }

  // figure out normalized cdf
  int minValue = 0;
  int maxValue = 254;
  while (true) {
    if (histogram[minValue] != 0 || minValue >= 254) {
      break;
    } else {
      minValue++;
    }
  }
  while (true) {
    if (histogram[maxValue] != 0 || maxValue <= 0) {
      break;
    } else {
      maxValue--;
    }
  }
  printf("min: %d\nmax: %d\n", minValue, maxValue);
  int adjustedValues[255];
  for (int j = 1; j < 255; j++) {
    float top = cumulativeHistogram[j] - cumulativeHistogram[minValue];
    float bottom = NORMALIZED_DIM*NORMALIZED_DIM-cumulativeHistogram[minValue];
    float divided = top/bottom;
    float mult = divided*254;
    adjustedValues[j] = (int)roundl(mult);
    printf("%3d >> %6d\n", j, adjustedValues[j]);
  }

  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
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
  [image addRepresentation:bitmap];

  unsigned char *newPixelBuffer = [bitmap bitmapData];

  for (int y = 0; y < NORMALIZED_DIM; y++) {
    for (int x = 0; x < NORMALIZED_DIM*3; x++) {
      unsigned char oldValue = rawPixelData[(x+y*NORMALIZED_DIM)*4];
      unsigned char newValue = adjustedValues[oldValue];
      newPixelBuffer[(x+y*NORMALIZED_DIM)*3 + 0] = newValue;
      newPixelBuffer[(x+y*NORMALIZED_DIM)*3 + 1] = newValue;
      newPixelBuffer[(x+y*NORMALIZED_DIM)*3 + 2] = newValue;
    }
  }

  NSString *filename = @"/Users/rgm/Desktop/testimage2.jpg";
  NSDictionary *opts = @{NSImageCompressionFactor : @1.0};
  NSData *imageData = [bitmap representationUsingType:NSJPEGFileType properties:opts];
  [imageData writeToFile:filename atomically:NO];

  free(buffer);
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
