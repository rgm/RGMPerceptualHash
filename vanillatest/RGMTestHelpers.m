#import "RGMTestHelpers.h"

@implementation NSImage (RGMTestHelpers)

- (BOOL)rgm_isPixelIdenticalToImage:(NSImage *)image
{
  NSData *selfData = [self TIFFRepresentation];
  NSData *otherData = [image TIFFRepresentation];
  BOOL result = [selfData isEqualToData:otherData];
  return result;
}

@end