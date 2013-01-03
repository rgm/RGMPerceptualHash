//
//  vanillatest.m
//  vanillatest
//
//  Created by Ryan McCuaig on 2012/12/14.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "PHHasher.h"
#import "PHUtility.h"

@interface vanillatest : SenTestCase

@end

@implementation vanillatest

- (void)testHasherShouldRaiseWithNoImage
{
  PHHasher *hasher = [PHHasher new];
  STAssertThrows([hasher perceptualHash], @"hasher with no source image should throw a parameter assert");
}

- (void)testBlackWeightedImage
{
  // a 512x512 image with a 128 bit hash will have one block == four lines
  // so 3 black lines and one white line will median out to 0
  // therefore the hash will be 0x0000000000000000

  PHHasher *hasher = [PHHasher new];
  NSString *path = [[NSBundle bundleForClass:[vanillatest class]] pathForImageResource:@"3K1W"];
  hasher.url = [NSURL fileURLWithPath:path];
//  hasher.image = image;
//  const char *hash = ph_NSDataToHexString([hasher perceptualHash]);
//  STAssertEquals("0000000000000000", hash, @"block hash should be zero for 3K1W image");
}

@end

