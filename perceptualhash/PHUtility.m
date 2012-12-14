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

// gives a bitwise hamming distance as an absolute number
// divide by the bit_count for percentage

 int ph_hamming_count(void *bits1, void *bits2, size_t bit_count)
{
  // obviously this could be more efficient
  // mais je ne suis pas Brian Kernighan
  int count = 0;
  unsigned char *bits1AsChar = (unsigned char *)bits1;
  unsigned char *bits2AsChar = (unsigned char *)bits2;
  for (size_t i = 0; i < bit_count/8; i++) {
    unsigned char byte1 = bits1AsChar[i];
    unsigned char byte2 = bits2AsChar[i];
    for (int j = 0; j < 8; j++) {
      unsigned char bit1 = (byte1 >> j) | 0xFE; // right shift to lowest bit, then OR against 11111110
      unsigned char bit2 = (byte2 >> j) | 0xFE;
      if (bit1 != bit2) {
        count += 1;
      }
    }
  }
  return count;
}
