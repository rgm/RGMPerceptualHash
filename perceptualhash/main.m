//
//  main.m
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012/11/05.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PHHasher.h"
#import "PHUtility.h"

#import "Lagrangian/Lagrangian.h"

int main(int argc, const char * argv[])
{

#if L3_TESTS
  @autoreleasepool {
    L3TestRunner *runner = [L3TestRunner new];
    L3TestSuite *suite = [[L3TestSuite alloc] init];
//    L3TestSuite *suite = [L3TestSuite testSuiteWithName:@"main"];
    [runner performSelector:@selector(runTest:) withObject:nil];
    exit(EXIT_FAILURE);
  }
#endif

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
    const char *hash = ph_NSDataToHexString([hasher perceptualHash]);
    printf("%s\n", hash);
  }
  return 0;
}

@l3_suite("main");
@l3_test("test failure") {
  l3_assert(YES, l3_equals(NO));
}
