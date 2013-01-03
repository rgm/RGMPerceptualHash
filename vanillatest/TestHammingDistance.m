//
//  TestHammingDistance.m
//  perceptualhash
//
//  Created by Ryan McCuaig on 2013/01/03.
//  Copyright (c) 2013 Ryan McCuaig. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "PHHamming.h"

#define HASH_LENGTH 128

@interface TestHammingDistance : SenTestCase {
  void *zeroes, *ones, *halves;
}
@end

@implementation TestHammingDistance

- (void)setUp
{
  [super setUp];
  zeroes = malloc(HASH_LENGTH/8);
  ones   = malloc(HASH_LENGTH/8);
  halves = malloc(HASH_LENGTH/8);
  for (int i = 0; i < HASH_LENGTH/8; i++) {
    ((char *)zeroes)[i] = 0x00;
    ((char *)ones)[i]   = 0xFF;
    ((char *)halves)[i] = 0xF0;
  }
}

- (void)tearDown
{
  [super tearDown];
  free(zeroes);
  free(ones);
  free(halves);
}

- (void)testHammingOfPerfectlyDifferentBitArrays
{
  STAssertEquals(128, ph_hamming_count(zeroes, ones, HASH_LENGTH), @"hamming dist should be 128");
}

- (void)testHammingOfHalfDifferentBitArrays
{
  STAssertEquals(64, ph_hamming_count(zeroes, halves, HASH_LENGTH), @"hamming dist should be 128");
}

- (void)testHammingOfPerfectlyEqualBitArrays
{
  STAssertEquals(0, ph_hamming_count(zeroes, zeroes, HASH_LENGTH), @"hamming dist should be 0");
}

- (void)testHammingOfOffByOneBitArrays
{
  void *offByOne = malloc(HASH_LENGTH/8);
  for (int i = 0; i < HASH_LENGTH/8; i++) {
    ((char *)offByOne)[i] = 0x00;
  }
  ((char *)offByOne)[0] = 0x01;
  STAssertEquals(1, ph_hamming_count(zeroes, offByOne, HASH_LENGTH), @"hamming dist should be 1");
  free(offByOne);
}

@end
