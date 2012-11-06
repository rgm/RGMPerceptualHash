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
  CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
  CIFilter *resize = [CIFilter filterWithName:@"CILanczosScaleTransform"];
//  CIFilter *equalize;
  CIImage *sourceImage = [CIImage imageWithData:[image TIFFRepresentation]];
  int bytesPerRow = image.size.width * 4;
  void *buffer = calloc(image.size.height, bytesPerRow);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  CGContextRef ctxRef = CGBitmapContextCreate(buffer,
                                              image.size.width,
                                              image.size.height,
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
  [blur setDefaults];
  [blur setValue:luminanceResult forKey:kCIInputImageKey];
  [blur setValue:@0.0f forKey:@"inputRadius"];
  CIImage *blurResult = [blur valueForKey:kCIOutputImageKey];
  [resize setDefaults];
  [resize setValue:[self scaleFactor:image] forKey:@"inputScale"];
  [resize setValue:[self aspectRatio:image] forKey:@"inputAspectRatio"];
  [resize setValue:blurResult forKey:kCIInputImageKey];
  CIImage *resizeResult = [resize valueForKey:kCIOutputImageKey];
  CIImage *result = resizeResult;
  CGImageRef cgImage = [context createCGImage:result fromRect:[result extent]];
  NSImage *normalizedImage = [[NSImage alloc] initWithCGImage:cgImage size:NSMakeSize(NORMALIZED_DIM, NORMALIZED_DIM)];
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
