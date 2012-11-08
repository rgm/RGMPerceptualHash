//
//  main.m
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012/11/05.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PHHasher.h"

int main(int argc, const char * argv[])
{

  if (argc != 2) {
    printf("Usage: %s [file]\n", argv[0]);
    exit(1);
  }

  @autoreleasepool {
    PHHasher *hasher = [PHHasher new];
    hasher.url       = [[NSURL alloc]
                        initFileURLWithPath:[NSString stringWithCString:argv[1]
                                                               encoding:NSUTF8StringEncoding]];
    hasher.debug     = YES;
    [hasher perceptualHash];
  }
  return 0;
}
