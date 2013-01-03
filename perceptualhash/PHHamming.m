//
//  PHHamming.m
//  perceptualhash
//
//  Created by Ryan McCuaig on 2013/01/03.
//  Copyright (c) 2013 Ryan McCuaig. All rights reserved.
//

#import "PHHamming.h"

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
