//
//  vanillatest.m
//  vanillatest
//
//  Created by Ryan McCuaig on 2012/12/14.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import "vanillatest.h"

@implementation vanillatest

- (void)setUp
{
  [super setUp];
}

- (void)tearDown
{
  [super tearDown];
}

- (void)testHasherShouldRaiseWithNilURL
{
  PHHasher *hasher = [PHHasher new];
  STAssertThrows([hasher perceptualHash], @"nil-url hasher should throw a parameter assert");
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

