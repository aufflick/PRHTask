//
//  main.m
//  PRHTaskTest
//
//  Created by Peter Hosey on 2011-10-13.
//  Copyright 2011 Peter Hosey. All rights reserved.
//

#import "PRHTask.h"

int main (int argc, char **argv) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	//When using the varargs method, strings and arrays of strings can be mixed in the arguments parameter list.
	PRHTask *task = [PRHTask taskWithProgramName:@"echo" arguments:@"I am the very model of a", [NSArray arrayWithObjects:@"modern", @"Major-General", nil], nil];
	task.accumulatesStandardOutput = YES;

	task.successfulTerminationBlock = ^(PRHTask *completedTask) {
		NSLog(@"Completed task: %@ with exit status: %i", completedTask, completedTask.terminationStatus);
		NSLog(@"Accumulated output: %@", [task outputStringFromStandardOutputUTF8]);

		exit(EXIT_SUCCESS);
	};
	task.abnormalTerminationBlock = ^(PRHTask *completedTask) {
		NSLog(@"Task exited abnormally: %@ with exit status: %i", completedTask, completedTask.terminationStatus);
		exit(EXIT_FAILURE);
	};

	[task launch];

	dispatch_main();

	[pool drain];
	return EXIT_SUCCESS;
}

