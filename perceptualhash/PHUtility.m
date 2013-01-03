//
//  PHUtility.m
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012/11/09.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import "PHUtility.h"

int compare_chars(const void *a, const void *b)
{
  // for qsort
  const unsigned char *ia = (const unsigned char *)a;
  const unsigned char *ib = (const unsigned char *)b;
  return (*ia - *ib);
}

const char *ph_NSDataToHexString(NSData *hash)
{
  const unsigned char *dataBuffer = (const unsigned char *)[hash bytes];

  if (!dataBuffer) {
    return [[NSString string] cStringUsingEncoding:NSASCIIStringEncoding];
  }

  NSUInteger dataLength = [hash length];
  NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];

  for (int i = 0; i < dataLength; ++i) {
    [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
  }
  return [hexString cStringUsingEncoding:NSASCIIStringEncoding];
}

NSData *ph_HexStringToNSData(const char *str)
{
  return nil;
}

