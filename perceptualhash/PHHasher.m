//
//  PHHasher.m
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012/11/05.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import "PHHasher.h"
#import <QuartzCore/QuartzCore.h>

#define HASH_LENGTH          128   // bits
#define NORMALIZED_DIM       512   // px
#define GREY_LEVELS          255
#define INPUT_CUBE_DIMENSION 64
#define BLUR_RADIUS          20.0f

int compare_chars(const void *a, const void *b)
{
  // for qsort
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

- (id)init
{
  self = [super init];
  if (self) {
    _url   = nil;
    _debug = NO;
  }
  return self;
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

- (NSData *)perceptualHash
{
  NSImage *image = [[NSImage alloc] initWithContentsOfURL:self.url];
  NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData: [[self normalizeImage:image] TIFFRepresentation]];
  //if (self.debug) {
    //[self writeImageRepToDisk:rep withSuffix:@"blurred"];
  //}
  NSImage *normalizedImage = image;
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
  CIFilter *resize      = [CIFilter filterWithName:@"CILanczosScaleTransform"];

  CIImage *sourceImage = [CIImage imageWithData:[image TIFFRepresentation]];

  // make up off-screen context
  int bytesPerRow            = NORMALIZED_DIM * 4;
  void *buffer               = calloc(NORMALIZED_DIM, bytesPerRow);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  CGContextRef ctxRef = CGBitmapContextCreate(buffer,
                                              NORMALIZED_DIM,
                                              NORMALIZED_DIM,
                                              8,
                                              bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
  CIContext *context = [CIContext contextWithCGContext:ctxRef options:nil];
  CGColorSpaceRelease(colorSpace);
  CGContextRelease(ctxRef);

  // configure & chain CI filters
  [luminance setDefaults];
  [luminance setValue:sourceImage forKey:kCIInputImageKey];
  [luminance setValue:@INPUT_CUBE_DIMENSION forKey:@"inputCubeDimension"];
  [luminance setValue:[self perceptualColorCubeWithSize:INPUT_CUBE_DIMENSION]
               forKey:@"inputCubeData"];
  CIImage *luminanceResult = [luminance valueForKey:kCIOutputImageKey];

//  [affineClamp setDefaults]; // to remove white fringe on blur
//  [affineClamp setValue:luminanceResult forKey:kCIInputImageKey];
//  CIImage *affineResult = [affineClamp valueForKey:kCIOutputImageKey];

  [blur setDefaults];
  [blur setValue:luminanceResult forKey:kCIInputImageKey];
  [blur setValue:@BLUR_RADIUS forKey:@"inputRadius"];
  CIImage *blurResult = [blur valueForKey:kCIOutputImageKey];

  [resize setDefaults];
  [resize setValue:[self scaleFactor:image] forKey:@"inputScale"];
  [resize setValue:[self aspectRatio:image] forKey:@"inputAspectRatio"];
  [resize setValue:blurResult forKey:kCIInputImageKey];
  CIImage *resizeResult = [resize valueForKey:kCIOutputImageKey];

  CGRect cropRect = CGRectMake(0, 0, NORMALIZED_DIM, NORMALIZED_DIM);
  CIImage *result = [resizeResult imageByCroppingToRect: cropRect];

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

  if (self.debug) {
    [self writeImageRepToDisk:bitmapRep withSuffix:@"normalized"];
  }

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
  unsigned char hash[HASH_LENGTH+1];
  for (int i = 0; i < HASH_LENGTH; i++) {
    if (blockMeans[i] < median) {
      hash[i] = '0';
    } else {
      hash[i] = '1';
    }
  }
  hash[HASH_LENGTH] = '\0';
  printf("block hash bin:\t%s\n", hash);

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

- (NSData *)perceptualColorCubeWithSize:(const unsigned int)size
{

  // Y = 0.2126 R + 0.7152 G + 0.0722 B
  // per http://en.wikipedia.org/wiki/Luminance_(relative)

  int cubeDataSize = size * size * size * sizeof(float)*4;
  struct colorPoint { float r, g, b, a; };
  struct colorPoint cubeData[size][size][size];
  float rgb[3];
  const float redFactor   = 0.2126; // empirical
  const float greenFactor = 0.7152; // empirical
  const float blueFactor  = 0.0722; // empirical

  for (int blue = 0; blue < size; blue++) {
    rgb[2] = ((float) blue) / (size-1);
    for (int green = 0; green < size; green++) {
      rgb[1] = ((float) green / (size-1));
      for (int red = 0; red < size; red++) {
        rgb[0] = ((float) red / (size-1));
        float luminance = (rgb[0]*redFactor) + (rgb[1]*greenFactor) + (rgb[2]*blueFactor);
        cubeData[red][green][blue] = (struct colorPoint){luminance, luminance, luminance, 1.0};
      }
    }
  }

  NSData *data = [NSData dataWithBytes:cubeData length:cubeDataSize];
  return data;
}

@end
