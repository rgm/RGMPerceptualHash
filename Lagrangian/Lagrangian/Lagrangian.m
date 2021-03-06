//  Lagrangian.m
//  Created by Rob Rix on 2012-11-05.
//  Copyright (c) 2012 Rob Rix. All rights reserved.

#import "Lagrangian.h"

@l3_suite("Lagrangian");

static void l3_dummy_test_case_function(L3TestState *test, L3TestCase *_case);


@l3_test("suites record the file and line number where they were defined") {
	l3_assert(test.suite.file.lastPathComponent, l3_equals(@"Lagrangian.m"));
	l3_assert(test.suite.line, l3_equals(7));
}


@l3_test("set up functions are used to define state to be available during each test") {
	l3_assert(test[@"case"], l3_equalTo(_case));
}

@l3_set_up {
	test[@"case"] = _case;
}


@l3_test("test cases take a reference to their test case") {
	l3_assert(_case, l3_not(nil));
}

@l3_test("test cases take a reference to their test state") {
	l3_assert(test, l3_not(nil));
}


@l3_test("tests have a reference to their suite via their state") {
	l3_assert(test.suite, l3_not(nil));
	l3_assert(test.suite, l3_isKindOfClass([L3TestSuite class]));
	l3_assert(test.suite.name, l3_equals(@"Lagrangian"));
}


@l3_step("Create a step") {
	test[@"step"] = step;
}

@l3_test("steps are not run automatically") {
	l3_assert(test[@"step"], l3_equals(nil));
}

@l3_test("steps are reified and collected in the suite") {
	l3_assert(test.suite.steps[@"Create a step"], l3_not(nil));
}

@l3_test("steps can be performed individually") {
	[_case performStep:test.suite.steps[@"Create a step"] withState:test];
	l3_assert([test[@"step"] name], l3_equals(@"Create a step"));
}


@l3_step("Create a step indirectly") {
	[_case performStep:test.suite.steps[@"Create a step"] withState:test];
}

@l3_test("steps can perform other steps") {
	[_case performStep:test.suite.steps[@"Create a step indirectly"] withState:test];
	l3_assert([test[@"step"] name], @"Create a step");
}


@l3_step("Passing assertions") {
	l3_assert(YES, YES);
}

@l3_step("Failing assertions") {
	l3_assert(NO, YES);
}


@l3_test("steps return the success/failure of their assertions (if any) when they are run") {
	l3_assert(l3_perform_step("Passing assertions"), YES);
	
	L3TestCase *testCase = [L3TestCase testCaseWithName:@"failures" file:@"" __FILE__ line:__LINE__ function:l3_dummy_test_case_function];
	l3_assert([testCase performStep:test.suite.steps[@"Failing assertions"] withState:test], l3_equals(NO));
}

//@l3_tear_down {
//	
//}


//@l3_precondition {
//	
//}

//@l3_postcondition {
//	
//}

//@l3_invariant {
//	
//}

//@l3_benchmark {
//	
//}

static void l3_dummy_test_case_function(L3TestState *test, L3TestCase *_case) {}
