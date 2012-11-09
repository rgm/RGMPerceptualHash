//
//  PHHasher.m
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012/11/05.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "PHHasher.h"
#import "PHUtility.h"

#define HASH_LENGTH          128   // bits
#define NORMALIZED_DIM       512   // px
#define GREY_LEVELS          255
#define INPUT_CUBE_DIMENSION 64
#define BLUR_RADIUS          20.0f // px

@implementation PHHasher

- (id)init
{
  self = [super init];
  if (self) {
    _url   = nil;
    _debug = NO;
  }
  return self;
}

- (NSData *)perceptualHash
{
  NSImage *image = [[NSImage alloc] initWithContentsOfURL:self.url];
  NSImage *normalizedImage = [self normalizeImage:image];
  NSData *buffer = [self hashImage: normalizedImage];
  return [buffer copy];
}

- (NSImage *)normalizeImage:(NSImage *)image
{

  //
  // perceptual luminance only -> blur -> resize to 512x512 -> histogram
  // equalize over GREY_LEVELS
  //

  CIFilter *luminance   = [CIFilter filterWithName:@"CIColorCube"];
  CIFilter *affineClamp = [CIFilter filterWithName:@"CIAffineClamp"];
  CIFilter *blur        = [CIFilter filterWithName:@"CIGaussianBlur"];
  CIFilter *crop        = [CIFilter filterWithName:@"CICrop"];
  CIFilter *resize      = [CIFilter filterWithName:@"CILanczosScaleTransform"];

  CIImage *sourceImage = [CIImage imageWithData:[image TIFFRepresentation]];
  CGRect initialExtent = [sourceImage extent];

  // make up off-screen context
  int bytesPerRow            = initialExtent.size.width * 4;
  void *buffer               = calloc(initialExtent.size.height, bytesPerRow);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  CGContextRef ctxRef        = CGBitmapContextCreate(buffer,
                                                     initialExtent.size.width,
                                                     initialExtent.size.height,
                                                     8,
                                                     bytesPerRow,
                                                     colorSpace,
                                                     kCGImageAlphaPremultipliedLast);
  CIContext *context         = [CIContext contextWithCGContext:ctxRef
                                                       options:nil];
  CGColorSpaceRelease(colorSpace);
  CGContextRelease(ctxRef);

  // configure & chain CI filters
  [luminance setDefaults];
  [luminance setValue:sourceImage forKey:kCIInputImageKey];
  [luminance setValue:@INPUT_CUBE_DIMENSION forKey:@"inputCubeDimension"];
  [luminance setValue:[self luminanceCubeWithSteps:INPUT_CUBE_DIMENSION]
               forKey:@"inputCubeData"];
  CIImage *luminanceResult = [luminance valueForKey:kCIOutputImageKey];
//  if (self.debug) { [self writeCIImageToDisk:luminanceResult WithSuffix:@"luminance"]; }

  // affine clamp to avoid the white edge fringing
  [affineClamp setDefaults];
  [affineClamp setValue:luminanceResult forKey:kCIInputImageKey];
  NSAffineTransform *identityTransform = [NSAffineTransform transform];
  [affineClamp setValue:identityTransform forKey:@"inputTransform"];
  CIImage *affineResult = [affineClamp valueForKey:kCIOutputImageKey];

  [blur setDefaults];
  [blur setValue:affineResult forKey:kCIInputImageKey];
  [blur setValue:@BLUR_RADIUS forKey:@"inputRadius"];
  CIImage *blurResult = [blur valueForKey:kCIOutputImageKey];

  // need a crop to pull the affine clamped image back
  // from infinite extents
  [crop setDefaults];
  [crop setValue:blurResult forKey:kCIInputImageKey];
  CIVector *originalCropRect = [CIVector vectorWithX:initialExtent.origin.x
                                                   Y:initialExtent.origin.y
                                                   Z:initialExtent.size.width
                                                   W:initialExtent.size.height];
  [crop setValue:originalCropRect forKey:@"inputRectangle"];
  CIImage *cropResult = [crop valueForKey:kCIOutputImageKey];
//  if (self.debug) { [self writeCIImageToDisk:cropResult WithSuffix:@"blur"]; }

  [resize setDefaults];
  [resize setValue:[self scaleFactor:initialExtent] forKey:@"inputScale"];
  [resize setValue:[self aspectRatio:initialExtent] forKey:@"inputAspectRatio"];
  [resize setValue:cropResult forKey:kCIInputImageKey];
  CIImage *resizeResult = [resize valueForKey:kCIOutputImageKey];
//  if (self.debug) { [self writeCIImageToDisk:resizeResult WithSuffix:@"resize"]; }

  CGRect smallCropRect = CGRectMake(0, 0, NORMALIZED_DIM, NORMALIZED_DIM);
  CIImage *result = [resizeResult imageByCroppingToRect: smallCropRect];

  CGImageRef cgImage = [context createCGImage:result fromRect:[result extent]];
  [self histogramEqualize:cgImage];
  NSImage *normalizedImage = [[NSImage alloc] initWithCGImage:cgImage size:NSZeroSize];

  CGContextRelease(ctxRef);
  CFRelease(cgImage);
  free(buffer);

  return normalizedImage;
}

- (NSData *)hashImage:(NSImage *)image
{
  NSData *buffer = nil;
  buffer = [image TIFFRepresentation];
  return buffer;
}

- (void)histogramEqualize:(CGImageRef)cgImage;
// http://en.wikipedia.org/wiki/Histogram_equalization
{

  // draw into a context buffer to get the raw pixels
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

//  if (self.debug) {
//    [self writeImageRepToDisk:bitmapRep withSuffix:@"normalized"];
//  }

  // assemble block means
  unsigned char blockMeans[HASH_LENGTH];
  int blockLength = NORMALIZED_DIM*NORMALIZED_DIM/HASH_LENGTH;
  for (int i = 0; i < HASH_LENGTH; i++) {
    long accumulator = 0;
    for (int j = 0; j < blockLength; j++) {
      // accumulate over the block
      long currentValue = (long)newPixelBuffer[j+(i*blockLength)*3];
      accumulator += currentValue;
    }
    int mean = (int)roundtol((float)accumulator/blockLength);
    blockMeans[i] = mean;
  }

  // find the median value
  unsigned char sortedBlockMeans[HASH_LENGTH];
  memcpy(sortedBlockMeans, blockMeans, sizeof(blockMeans));
  qsort(sortedBlockMeans, HASH_LENGTH, sizeof(unsigned char), compare_chars);
  unsigned char median = sortedBlockMeans[(int)floor(HASH_LENGTH-1)/2];

  // figure out hash as a binary string
  // convert to a binary number as mean[i] < median => 0 else 1
//  unsigned char hash[HASH_LENGTH+1];
//  for (int i = 0; i < HASH_LENGTH; i++) {
//    if (blockMeans[i] < median) {
//      hash[i] = '0';
//    } else {
//      hash[i] = '1';
//    }
//  }
//  hash[HASH_LENGTH] = '\0';
//  printf("block hash bin:\t%s\n", hash);

  // figure out hash as HASH_LENGTH/8 hex bytes
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
  printf("block hash hex:\t");
  for (int i = 0; i < HASH_LENGTH/8; i++) {
    printf("%02X", bitHash[i]);
  }
  printf("\n");

  free(contextBuffer);
}

# pragma mark calculating the hash

# pragma mark CoreImage helpers

- (NSData *)luminanceCubeWithSteps:(const unsigned int)steps
{

  // Y = 0.2126 R + 0.7152 G + 0.0722 B
  // per http://en.wikipedia.org/wiki/Luminance_(relative)

  int cubeDataSize = steps * steps * steps * sizeof(float)*4;
  struct colorPoint { float r, g, b, a; };
  struct colorPoint cubeData[steps][steps][steps];
  float rgb[3];
  const float redFactor   = 0.2126; // empirical
  const float greenFactor = 0.7152; // empirical
  const float blueFactor  = 0.0722; // empirical

  for (int blue = 0; blue < steps; blue++) {
    rgb[2] = ((float) blue) / (steps-1);
    for (int green = 0; green < steps; green++) {
      rgb[1] = ((float) green / (steps-1));
      for (int red = 0; red < steps; red++) {
        rgb[0] = ((float) red / (steps-1));
        float luminance = (rgb[0]*redFactor) + (rgb[1]*greenFactor) + (rgb[2]*blueFactor);
        cubeData[red][green][blue] = (struct colorPoint){luminance, luminance, luminance, 1.0};
      }
    }
  }

  NSData *data = [NSData dataWithBytes:cubeData length:cubeDataSize];
  return data;
}


- (NSNumber *)scaleFactor:(CGRect)originalRect
{
  CGFloat scale = NORMALIZED_DIM / originalRect.size.height;
  return [NSNumber numberWithFloat:scale];
}

- (NSNumber *)aspectRatio:(CGRect)originalRect
{
  CGFloat scale = [[self scaleFactor:originalRect] floatValue];
  CGFloat scaledX = originalRect.size.width * scale;
  CGFloat aspect = NORMALIZED_DIM / scaledX;
  return [NSNumber numberWithFloat:aspect];
}

# pragma mark debugging crap

- (void)writeCIImageToDisk:(CIImage *)ciImage WithSuffix:(NSString *)ext
{
  NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCIImage:ciImage];
  [self writeImageRepToDisk:rep withSuffix:ext];
}

- (void)writeCGImageToDisk:(CGImageRef)cgImage WithSuffix:(NSString *)ext
{
  NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
  [self writeImageRepToDisk:rep withSuffix:ext];
}

- (void)writeNSImageToDisk:(NSImage *)image withSuffix:(NSString *)ext
{
  NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
  [self writeImageRepToDisk:rep withSuffix:ext];
}

- (void)writeImageRepToDisk:(NSBitmapImageRep *)rep withSuffix:(NSString *)ext
{
  NSDictionary *opts = @{NSImageCompressionFactor : @1.0};
  NSURL *desktop = [[NSURL alloc] initFileURLWithPath:@"/Users/rgm/Desktop/"];
  NSString *filename = [self.url lastPathComponent];
  NSString *extension = [filename pathExtension];
  NSString *shortFilename = [filename stringByDeletingPathExtension];
  NSString *newFilename = [[NSString stringWithFormat:@"%@-%@", shortFilename, ext]
                        stringByAppendingPathExtension:extension];
  NSURL *fullPath = [desktop URLByAppendingPathComponent:newFilename];

  NSData *imageData = [rep representationUsingType:NSJPEGFileType properties:opts];
  [imageData writeToFile:[fullPath path] atomically:NO];
}


@end
