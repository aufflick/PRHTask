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

	PRHTask *task = [[[PRHTask alloc] init] autorelease];
	task.launchPath = @"/bin/echo";
	task.arguments = [NSArray arrayWithObject:@"I am the very model of a modern Major-General"];
	task.successfulTerminationBlock = ^(PRHTask *completedTask) {
		NSLog(@"Completed task: %@ with exit status: %i", completedTask, completedTask.terminationStatus);
	};
	task.abnormalTerminationBlock = ^(PRHTask *completedTask) {
		NSLog(@"Task exited abnormally: %@ with exit status: %i", completedTask, completedTask.terminationStatus);
	};
	[task launch];

	dispatch_main();

	[pool drain];
	return EXIT_SUCCESS;
}

