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
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testExample
{
  STAssertFalse(NO, @"whatever");
}

@end
