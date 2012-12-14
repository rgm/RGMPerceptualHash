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

#import "Lagrangian/Lagrangian.h"

@implementation PHHasher {
  unsigned char *_hashBytes;
  void *_bigPixelBuffer;
  void *_littlePixelBuffer;
}

- (id)init
{
  self = [super init];
  if (self) {
    _url   = nil;
    _debug = NO;
    _hashBytes = calloc((size_t)[self hashByteLength], sizeof(unsigned char));
    _bigPixelBuffer = NULL;
    _littlePixelBuffer = NULL;
  }
  return self;
}

- (void)dealloc
{
  free(_hashBytes);
  if (_bigPixelBuffer != NULL) {
    free(_bigPixelBuffer);
  }
  if (_littlePixelBuffer != NULL) {
    free(_littlePixelBuffer);
  }
}

- (NSData *)perceptualHash
{
  NSParameterAssert(self.url != nil);
  [self calculateHash];
  NSData *data = [NSData dataWithBytes:[self hashBytes]
                                length:[self hashByteLength]];
  return data;
}

- (unsigned char *)hashBytes {
  return _hashBytes;
}

- (NSUInteger)hashByteLength {
  return HASH_LENGTH/8;
}

#pragma mark hash calculation

- (void)calculateHash
{
  NSImage *sourceImage = [[NSImage alloc] initWithContentsOfURL:self.url];
  NSImage *thumbnail = [self normalizedImageFromImage:sourceImage];
  [self calculateBlockMeansForImage: thumbnail intoHashBuffer:_hashBytes];
}

- (void)calculateBlockMeansForImage:(NSImage *)sourceImage
                     intoHashBuffer:(unsigned char *)hashBuffer
{
  int blockLength = NORMALIZED_DIM*NORMALIZED_DIM/HASH_LENGTH;
  int bytesPerPixel = 4;
  unsigned char blockMeans[HASH_LENGTH];
//  [self drawImage:sourceImage toBuffer:&_littlePixelBuffer]; // FIXME - CFZombie fail if uncommented
  unsigned char *pixelBuffer = _littlePixelBuffer; // needs to already have the normalized image
  for (int i = 0; i < HASH_LENGTH; i++) {
    long accumulator = 0;
    for (int j = 0; j < blockLength; j++) {
      long currentValue = (long)pixelBuffer[j+(i*blockLength)*bytesPerPixel];
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

  // unset all bits
  for (int i = 0; i < [self hashByteLength]; i++) {
    hashBuffer[i] = (unsigned char)0;
  }
  // figure out the hash (bitwise)
  for (int i = 0; i < HASH_LENGTH; i++) {
    int charIndex = (i / 8);
    int bitIndex = 7 - (i % 8);
    int blockMean = blockMeans[i];
    if (blockMean > median) {
      // set the bit, otherwise cleared above
      hashBuffer[charIndex] |= (1 << bitIndex);
    }
  }
}

#pragma mark image processing

- (NSImage *)normalizedImageFromImage:(NSImage *)sourceImage
{
  NSGraphicsContext *context = [self contextForImage:sourceImage
                                          usingBuffer:&_bigPixelBuffer];

  NSImage *normalizedImage = [self processWithFilterChain:sourceImage usingContext:context];
  NSImage *equalizedImage = [self equalizeImage:normalizedImage];

  if (self.debug) {
    [self writeNSImageToDisk:normalizedImage withSuffix:@"normalized"];
    [self writeNSImageToDisk:equalizedImage withSuffix:@"equalized"];
  }

  return normalizedImage;
}

- (NSGraphicsContext *)contextForImage:(NSImage *)sourceImage
                            usingBuffer:(void **)buffer;
{
  long bytesPerRow = sourceImage.size.width * 4;
  long numRows = sourceImage.size.height;
  *buffer = calloc(bytesPerRow, numRows);
  size_t bitsPerComponent = 8;
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef cgContext = CGBitmapContextCreate(*buffer,
                                                 sourceImage.size.width,
                                                 sourceImage.size.height,
                                                 bitsPerComponent,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaNoneSkipLast);
  NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:cgContext
                                                                          flipped:NO];
  CGContextRelease(cgContext);
  CGColorSpaceRelease(colorSpace);
  return nsContext;
}

- (NSImage *)processWithFilterChain:(NSImage *)image
                       usingContext:(NSGraphicsContext *)context
{
  //
  // perceptual luminance only -> blur -> resize to 512x512 -> histogram
  // equalize over GREY_LEVELS
  //
  CIImage *initialImage = [self CIImageFromNSImage:image usingContext:context];
  CGRect initialExtent = [initialImage extent];

  CIFilter *luminance   = [CIFilter filterWithName:@"CIColorCube"];
  CIFilter *affineClamp = [CIFilter filterWithName:@"CIAffineClamp"];
  CIFilter *blur        = [CIFilter filterWithName:@"CIGaussianBlur"];
  CIFilter *crop        = [CIFilter filterWithName:@"CICrop"];
  CIFilter *resize      = [CIFilter filterWithName:@"CILanczosScaleTransform"];

  [luminance setDefaults];
  [luminance setValue:initialImage forKey:kCIInputImageKey];
  [luminance setValue:@INPUT_CUBE_DIMENSION forKey:@"inputCubeDimension"];
  [luminance setValue:[self luminanceCubeWithSteps:INPUT_CUBE_DIMENSION]
               forKey:@"inputCubeData"];
  CIImage *luminanceResult = [luminance valueForKey:kCIOutputImageKey];

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

  [resize setDefaults];
  [resize setValue:[self scaleFactor:initialExtent] forKey:@"inputScale"];
  [resize setValue:[self aspectRatio:initialExtent] forKey:@"inputAspectRatio"];
  [resize setValue:cropResult forKey:kCIInputImageKey];
  CIImage *resizeResult = [resize valueForKey:kCIOutputImageKey];

  NSImage *result = [self NSImageFromCIImage:resizeResult usingContext:context];

  return result;
}

- (NSImage *)equalizeImage:(NSImage *)image
{
  [self drawImage:image toBuffer:&_littlePixelBuffer];
  unsigned char *pixelBuffer = (unsigned char *)_littlePixelBuffer;

  long histogram[GREY_LEVELS];
  long cumulativeHistogram[GREY_LEVELS];
  int adjustedValues[GREY_LEVELS];

  [self calculateHistogram:histogram fromBuffer:pixelBuffer];
  [self calculateCumulativeHistogram:cumulativeHistogram fromHistogram:histogram];
  [self calculateNormalizedCumulativeDistribution:adjustedValues
                                    fromHistogram:histogram
                           andCumulativeHistogram:cumulativeHistogram];
  [self adjustPixelBuffer:&pixelBuffer usingAdjustedValues:adjustedValues];

  NSImage *normalizedImage = [self imageFromPixelBuffer:&pixelBuffer
                                                  width:NORMALIZED_DIM
                                                 height:NORMALIZED_DIM];
  return normalizedImage;
}

- (void)calculateHistogram:(long *)histogram
                fromBuffer:(unsigned char *)pixelBuffer
{
  for (int i = 0; i < GREY_LEVELS; i++) {
    histogram[i] = 0;
  }
  int bytesPerRow = NORMALIZED_DIM * 4;
  for (int i = 0; i < bytesPerRow*NORMALIZED_DIM; i += 4) {
    int value = (int)pixelBuffer[i];
    histogram[value] += 1;
  }
  if (self.debug) {
    printf("histogram\n");
    for (int i = 0; i < GREY_LEVELS; i++) {
      printf("%3d\t%7d\n", i, (int)histogram[i]);
    }
  }
}

- (void)calculateCumulativeHistogram:(long *)cumulativeHistogram
                       fromHistogram:(long *)histogram
{
  long cumulative = 0;
  for (int i = 0; i < GREY_LEVELS; i++) {
    cumulativeHistogram[i] = 0;
  }
  for (int i = 0; i < GREY_LEVELS; i++) {
    cumulative += histogram[i];
    cumulativeHistogram[i] = cumulative;
  }
  if (self.debug) {
    printf("cumulative histogram\n");
    for (int i = 0; i < GREY_LEVELS; i++) {
      printf("%3d\t%7d\n", i, (int)cumulativeHistogram[i]);
    }
  }
}

- (void)calculateNormalizedCumulativeDistribution:(int *)adjustedValues
                                    fromHistogram:(long *)histogram
                           andCumulativeHistogram:(long *)cumulativeHistogram
{
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
  for (int j = 1; j < GREY_LEVELS; j++) {
    float top = cumulativeHistogram[j] - cumulativeHistogram[minGreyLevel];
    float bottom = NORMALIZED_DIM*NORMALIZED_DIM-cumulativeHistogram[minGreyLevel];
    float divided = top/bottom;
    float mult = divided*(GREY_LEVELS-1);
    adjustedValues[j] = (int)roundl(mult);
  }
}

- (void)adjustPixelBuffer:(unsigned char **)buffer
      usingAdjustedValues:(int *)adjustedValues
{
  // adjustedValues is an array with
  // indices are original grey level
  // values are the grey value to substitute
  unsigned char *theBuffer = *buffer;
  int bytesPerPixel = 4;
  int bytesPerRow = NORMALIZED_DIM * bytesPerPixel;
  for (int i = 0; i < NORMALIZED_DIM*bytesPerRow; i += bytesPerPixel) {
    int oldValue = theBuffer[i];
    int newValue = adjustedValues[oldValue];
    theBuffer[i + 0] = newValue; // red
    theBuffer[i + 1] = newValue; // green
    theBuffer[i + 2] = newValue; // blue
    theBuffer[i + 3] = 0xff;     // alpha
  }
}

- (NSImage *)imageFromPixelBuffer:(unsigned char **)buffer
                            width:(int)width
                           height:(int)height
{
  //  http://www.cocoabuilder.com/archive/cocoa/191884-create-nsimage-from-array-of-integers.html
  unsigned char *planes[1];
  planes[0] = *buffer;
  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
                                                                     pixelsWide:width
                                                                     pixelsHigh:height
                                                                  bitsPerSample:8
                                                                samplesPerPixel:4
                                                                       hasAlpha:YES
                                                                       isPlanar:NO
                                                                 colorSpaceName:NSDeviceRGBColorSpace
                                                                   bitmapFormat:0
                                                                    bytesPerRow:width*4
                                                                   bitsPerPixel:32];
  NSImage *image = [[NSImage alloc] initWithSize:[bitmap size]];
  [image addRepresentation:bitmap];
  return image;
}

- (void)drawImage:(NSImage *)image toBuffer:(void **)buffer
{
  NSGraphicsContext *context = [self contextForImage:image usingBuffer:buffer];
  CGImageRef ref = [image CGImageForProposedRect:NULL context:context hints:nil];
  CGRect extents = CGRectMake(0, 0, CGImageGetWidth(ref), CGImageGetHeight(ref));
  CGContextDrawImage([context graphicsPort], extents, ref);
  CGImageRelease(ref);
}

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

- (CIImage *)CIImageFromNSImage:(NSImage *)image
                   usingContext:(NSGraphicsContext *)context;
{
  // no apparent need to CGImageRelease on cgImage; instruments
  // says it's autoreleased when it gets used in creating the ciimage ??
  CGImageRef cgImage = [image CGImageForProposedRect:NULL context:context hints:nil];
  CIImage *ciImage = [CIImage imageWithCGImage:cgImage];
  return ciImage;
}

- (NSImage *)NSImageFromCIImage:(CIImage *)image
                   usingContext:(NSGraphicsContext *)context
{
  // no apparent need to CGImageRelease on cgImage; instruments
  // says it's autoreleased when it gets used in creating the nsimage ??
  CIContext *ciContext = [context CIContext];
  CGImageRef cgImage = [ciContext createCGImage:image fromRect:[image extent]];
  NSImage *nsImage = [[NSImage alloc] initWithCGImage:cgImage size:NSZeroSize];

  return nsImage;
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
