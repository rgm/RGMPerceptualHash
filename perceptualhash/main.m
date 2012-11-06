//
//  main.m
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012/11/05.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PHHasher.h"

void save(NSImage *image)
{
  NSString *filename = @"/Users/rgm/Desktop/testimage.jpg";
  NSData *imageData = [image TIFFRepresentation];
  NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
  NSDictionary *opts = @{NSImageCompressionFactor : @1.0};
  imageData = [imageRep representationUsingType:NSJPEGFileType properties:opts];
  [imageData writeToFile:filename atomically:NO];

}

int main(int argc, const char * argv[])
{

  if (argc != 2) {
    printf("Usage: %s [file]\n", argv[0]);
    exit(1);
  }

  @autoreleasepool {
    NSURL *url = [[NSURL alloc] initFileURLWithPath:[NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding]];
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:url];
    PHHasher *hasher = [PHHasher new];
    NSData *hash = [hasher perceptualHashWithImage:image];
//    printf("%s\n", ph_NSDataToHexString(hash));
    save([hasher normalizeImage:image]);
  }
  return 0;
}