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
	[task setLaunchPath:@"/usr/bin/true"];
	[task launch];

	[pool drain];
	return EXIT_SUCCESS;
}

