//
//  TestNormalizedImage.m
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012-12-15.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "RGMTestHelpers.h"

#import "PHNormalizedImage.h"

@interface TestNormalizedImage : SenTestCase

@end

@implementation TestNormalizedImage

-(void)testCanAllocate
{
  PHNormalizedImage *ni = [[PHNormalizedImage alloc] init];
  STAssertNotNil(ni, @"should be able to create");
}

-(void)testCanBeInitedWithImage
{
  NSImage *source = [self imageFromTestBundleNamed:@"3K1W"];
  PHNormalizedImage *normalized = [[PHNormalizedImage alloc] initWithSourceImage: source];
  STAssertEqualObjects(source, normalized.sourceImage, @"normalized should store and retrieve same .image property");
}

- (void)testInitWithNilImageRaisesException
{
  id (^nilInit)(void) = ^{ return [[PHNormalizedImage alloc] initWithSourceImage:nil]; };
  STAssertThrows(nilInit(), @"nil image should throw exception");
}

- (void)testCanSetImageSize
{
  PHNormalizedImage *norm = [[PHNormalizedImage alloc] initWithSourceImage:[self imageFromTestBundleNamed:@"white"]];
  NSSize size = NSMakeSize(512.0, 512.0);
  norm.size = size;
  STAssertEquals(size, norm.size, @"normalized should store and retrieve same .size property");
}

- (void)testHasReadonlyImageProperty
{
  PHNormalizedImage *norm = [self normalizedImageFromCorpusNamed:@"original"];
  STAssertTrue([norm respondsToSelector:NSSelectorFromString(@"image")], @"normalized image should have an image property");
}

- (void)testNormalizesImage
{
  NSImage *expected = [self imageFromTestBundleNamed:@"normalized"];
  PHNormalizedImage *observed = [[PHNormalizedImage alloc] initWithSourceImage:[self imageFromTestBundleNamed:@"original"]];
  RGMAssertEqualImages(expected, observed.sourceImage, @"images are not equal");
}


#pragma mark Helpers

- (NSImage *)imageFromTestBundleNamed:(NSString *)name
{
  // test class isn't pulling from main bundle
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:name];
  NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
  return image;
}

- (PHNormalizedImage *)normalizedImageFromCorpusNamed:(NSString *)name
{
  PHNormalizedImage *norm = [[PHNormalizedImage alloc] initWithSourceImage:[self imageFromTestBundleNamed:name]];
  return norm;
}

@end
