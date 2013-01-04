//
//  PHNormalizedImage.h
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012-12-15.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PHNormalizedImage : NSObject

@property (readonly) NSImage *sourceImage;
@property (readonly) NSImage *image;
@property (assign) NSSize size;

- (id)initWithSourceImage:(NSImage *)image;

@end
