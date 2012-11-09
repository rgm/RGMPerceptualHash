//
//  PHHasher.h
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012/11/05.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PHHasher : NSObject

@property NSURL *url;
@property BOOL debug;

- (NSData *)perceptualHash;

@end
