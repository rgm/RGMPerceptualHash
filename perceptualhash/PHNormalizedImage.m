//
//  PHNormalizedImage.m
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012-12-15.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import "PHNormalizedImage.h"

@implementation PHNormalizedImage

- (id)initWithSourceImage:(NSImage *)image
{
  NSParameterAssert(image != nil);
  if (self = [super init]) {
    _sourceImage = image;
  }
  return self;
}

@end
