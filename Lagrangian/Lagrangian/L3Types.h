//  L3Types.h
//  Created by Rob Rix on 2012-11-08.
//  Copyright (c) 2012 Rob Rix. All rights reserved.

#import <Foundation/Foundation.h>

@class L3TestCase, L3TestState, L3TestStep;

#pragma mark -
#pragma mark Test functions

typedef void(*L3TestCaseFunction)(L3TestState *, L3TestCase *);
typedef void(*L3TestStepFunction)(L3TestState *, L3TestCase *, L3TestStep *);


#pragma mark -
#pragma mark Assert patterns

typedef bool(^L3Pattern)(id);


#pragma mark -
#pragma mark Object conversion

#import "L3PreprocessorUtilities.h"

// start off by assuming all conversions to be unavailable (is this necessary?)
static inline id l3_to_object(...) __attribute__((overloadable, unavailable));

#define l3_define_to_object_by_boxing_with_type(type) \
	__attribute__((overloadable)) static inline id l3_to_object(type x) { return @(x); };

// box these types automatically
l3_fold(l3_define_to_object_by_boxing_with_type,
		uint64_t, uint32_t, uint16_t, uint8_t,
		int64_t, int32_t, int16_t, int8_t,
		unsigned long, signed long,
		double, float,
		bool,
		char *)
__attribute__((overloadable)) static inline id l3_to_object(id x) { return x; }
__attribute__((overloadable)) static inline id l3_to_object(void *x) { return [NSValue valueWithPointer:0]; }


#pragma mark -
#pragma mark Pattern conversion

#define l3_to_pattern(x) \
	(^L3Pattern{ __typeof__(x) y = x; return l3_to_pattern_f(y); }())


static inline L3Pattern l3_to_pattern_f(...) __attribute__((overloadable, unavailable));

#define l3_define_to_pattern_by_equality_with_type(type) \
	__attribute__((overloadable)) static inline L3Pattern l3_to_pattern_f(type x) { \
		return ^bool(id y){ return [y isEqual:l3_to_object(x)]; }; \
	}

l3_fold(l3_define_to_pattern_by_equality_with_type,
		uint64_t, uint32_t, uint16_t, uint8_t,
		int64_t, int32_t, int16_t, int8_t,
		unsigned long, signed long,
		double, float,
		bool,
		char *,
		id)

__attribute__((overloadable)) static inline L3Pattern l3_to_pattern_f(L3Pattern x) { return x; }

// nil comparisons
__attribute__((overloadable)) static inline L3Pattern l3_to_pattern_f(void *x) { return ^bool(id y){ return (__bridge void *)y == x; }; }

// floating point comparisons with epsilon
__attribute__((overloadable)) static inline L3Pattern l3_to_pattern_f(double x, double epsilon) { return ^bool(id y){ return [y isKindOfClass:[NSNumber class]] && fabs(x - [y doubleValue]) < epsilon; }; }
__attribute__((overloadable)) static inline L3Pattern l3_to_pattern_f(float x, float epsilon) { return ^bool(id y){ return [y isKindOfClass:[NSNumber class]] && fabsf(x - [y doubleValue]) < epsilon; }; }
