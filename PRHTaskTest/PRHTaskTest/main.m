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
	task.launchPath = @"/usr/bin/true";
	task.successfulTerminationBlock = ^(PRHTask *completedTask) {
		NSLog(@"Completed task: %@ with exit status: %i", completedTask, completedTask.terminationStatus);
	};
	[task launch];

	[pool drain];
	return EXIT_SUCCESS;
}

