@interface NSImage (RGMTestHelpers)

- (BOOL)rgm_isPixelIdenticalToImage:(NSImage *)image;
- (BOOL)rgm_isPixelSimilarToImage:(NSImage *)image epsilon:(float)epsilon;

@end

#define RGMAssertEqualImages(a1, a2, description, ...) \
do { \
  NSImage *a1Value = (a1); \
  NSImage *a2Value = (a2); \
  if (![a1Value rgm_isPixelIdenticalToImage: a2Value]) { \
    [self failWithException: \
      ([NSException failureInEqualityBetweenObject:a1Value \
                                         andObject:a2Value \
                                            inFile:[NSString stringWithUTF8String:__FILE__] \
                                            atLine:__LINE__ \
                                   withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
  } \
} while(0) 
