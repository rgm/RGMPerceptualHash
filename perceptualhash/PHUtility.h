//
//  PHUtility.h
//  perceptualhash
//
//  Created by Ryan McCuaig on 2012/11/09.
//  Copyright (c) 2012 Ryan McCuaig. All rights reserved.
//

#import <Foundation/Foundation.h>

int compare_chars(const void *a, const void *b);
NSData *ph_HexStringToNSData(const char *str);
const char *ph_NSDataToHexString(NSData *hash);
