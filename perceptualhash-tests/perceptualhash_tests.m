//
//  perceptualhash_tests.m
//  perceptualhash-tests
//
//  Created by Ryan McCuaig on 2012/11/05.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import "perceptualhash_tests.h"

NSString *hexStringFromData(NSData *data)
{
  return nil;
}

NSData *dataFromHexString(NSString *str)
{
  return [NSData data];
}

@implementation perceptualhash_tests {
  NSImage *_image;
  NSData *_hash;
}

- (void)setUp
{
  [super setUp];
  
  NSURL *url = [NSURL URLWithString:@"file:///Users/rgm/Dropbox/projects/moresby/perceptualhash/test/fixtures/original.jpg"];
  _image = [[NSImage alloc] initWithContentsOfURL:url];
  _hash = dataFromHexString(@"ab2351fcab2351fcab2351fcab2351fcab2351fcab2351fcab2351fcab2351fcab2351fc");
}

- (void)tearDown
{
  // Tear-down code here.
  [super tearDown];
}

- (void)testEverything
{
  PHHasher *hasher = [PHHasher new];
  NSData *hash = [hasher perceptualHashWithImage:_image];

  STFail(@"fixme");
  STAssertTrue([_hash isEqualToData:hash], @"should be equal");
}

@end
