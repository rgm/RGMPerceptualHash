//
//  PHHasher.h
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012/11/05.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define HASH_LENGTH          128   // bits = 16 chars for the hash
#define NORMALIZED_DIM       512   // pixels square for normalized image
#define GREY_LEVELS          255   // normalize greys over 8 bits
#define INPUT_CUBE_DIMENSION 64    // granularity of the greyscale transform
#define BLUR_RADIUS          20.0f // pixels

@interface PHHasher : NSObject

@property NSURL *url;
@property BOOL debug;

- (NSData *)perceptualHash;

@end
