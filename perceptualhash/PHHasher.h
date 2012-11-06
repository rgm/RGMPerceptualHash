//
//  PHHasher.h
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012/11/05.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define HASH_LENGTH 64

const char *ph_NSDataToHexString(NSData *hash);
NSData *ph_HexStringToNSData(const char *str);

@interface PHHasher : NSObject

- (NSData *)perceptualHashWithImage:(NSImage *)image;
- (NSImage *)normalizeImage:(NSImage *)image;

@end
