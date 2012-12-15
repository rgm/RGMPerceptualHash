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

- (void)setUp
{
  [super setUp];
}

- (void)tearDown
{
  [super tearDown];
}

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

- (void)testHammingOfPerfectlyDifferentBitArrays
{
  void *zeroes = malloc(HASH_LENGTH/8);
  void *ones = malloc(HASH_LENGTH/8);
  for (int i = 0; i < HASH_LENGTH/8; i++) {
    ((char *)zeroes)[i] = 0x00;
    ((char *)ones)[i] = 0xFF;
  }
  STAssertEquals(128, ph_hamming_count(zeroes, ones, HASH_LENGTH), @"hamming dist should be 128");
  free(zeroes);
  free(ones);
}

- (void)testHammingOfHalfDifferentBitArrays
{
  void *zeroes = malloc(HASH_LENGTH/8);
  void *ones = malloc(HASH_LENGTH/8);
  for (int i = 0; i < HASH_LENGTH/8; i++) {
    ((char *)zeroes)[i] = 0x00;
    ((char *)ones)[i] = 0xF0;
  }
  STAssertEquals(64, ph_hamming_count(zeroes, ones, HASH_LENGTH), @"hamming dist should be 128");
  free(zeroes);
  free(ones);
}

- (void)testHammingOfPerfectlyEqualBitArrays
{
  void *zeroes = malloc(HASH_LENGTH/8);
  for (int i = 0; i < HASH_LENGTH/8; i++) {
    ((char *)zeroes)[i] = 0x00;
  }
  STAssertEquals(0, ph_hamming_count(zeroes, zeroes, HASH_LENGTH), @"hamming dist should be 0");
  free(zeroes);
}

- (void)testHammingOfOffByOneBitArrays
{
  void *zeroes = malloc(HASH_LENGTH/8);
  void *ones = malloc(HASH_LENGTH/8);
  for (int i = 0; i < HASH_LENGTH/8; i++) {
    ((char *)zeroes)[i] = 0x00;
    ((char *)ones)[i] = 0x00;
  }
  ((char *)ones)[0] = 0x01;
  STAssertEquals(1, ph_hamming_count(zeroes, ones, HASH_LENGTH), @"hamming dist should be 1");
  free(zeroes);
  free(ones);
}

@end

