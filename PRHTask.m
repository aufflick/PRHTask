//
//  PRHTask.m
//  Revision Switcher
//
//  Created by Peter Hosey on 2011-10-13.
//  Copyright 2011 Peter Hosey. All rights reserved.
//

#import "PRHTask.h"

@interface PRHTask ()
@property(nonatomic, readwrite, retain) NSError *standardOutputReadError, *standardErrorReadError;
@property(nonatomic, retain) id standardOutputObserverToken, standardErrorObserverToken, taskDidTerminateObserverToken;
@end

@implementation PRHTask
{
	NSMutableData *accumulatedStandardOutputData, *accumulatedStandardErrorData;
}

@synthesize trimWhitespaceFromAccumulatedOutputs;

@synthesize accumulatedStandardOutputData;
@synthesize accumulatedStandardErrorData;

@synthesize standardOutputReadError, standardErrorReadError;

@synthesize standardOutputObserverToken, standardErrorObserverToken, taskDidTerminateObserverToken;

- (NSString *) outputStringFromStandardOutputUTF8 {
	NSString *str = [[[NSString alloc] initWithData:[self accumulatedStandardOutputData] encoding:NSUTF8StringEncoding] autorelease];

	if (self.trimWhitespaceFromAccumulatedOutputs)
		str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	return str;
}
- (NSString *) errorOutputStringFromStandardErrorUTF8 {
	NSString *str = [[[NSString alloc] initWithData:[self accumulatedStandardErrorData] encoding:NSUTF8StringEncoding] autorelease];

	if (self.trimWhitespaceFromAccumulatedOutputs)
		str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	return str;
}

- (BOOL) accumulatesStandardOutput {
	return (accumulatedStandardOutputData != nil);
}
- (void) setAccumulatesStandardOutput:(BOOL)flag {
	if (flag && !accumulatedStandardOutputData) {
		accumulatedStandardOutputData = [[NSMutableData alloc] init];
		[self setStandardOutput:[NSPipe pipe]];
	} else if (accumulatedStandardOutputData && !flag) {
		[accumulatedStandardOutputData release];
		accumulatedStandardOutputData = nil;
		[self setStandardOutput:nil];
	}
}
- (BOOL) accumulatesStandardError {
	return (accumulatedStandardErrorData != nil);
}
- (void) setAccumulatesStandardError:(BOOL)flag {
	if (flag && !accumulatedStandardErrorData) {
		accumulatedStandardErrorData = [[NSMutableData alloc] init];
		[self setStandardError:[NSPipe pipe]];
	} else if (accumulatedStandardErrorData && !flag) {
		[accumulatedStandardErrorData release];
		accumulatedStandardErrorData = nil;
		[self setStandardError:nil];
	}
}

@synthesize successfulTerminationBlock;
@synthesize abnormalTerminationBlock;

- (NSFileHandle *)devNullFileHandle {
	static NSFileHandle *devNullFileHandle;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		devNullFileHandle = [[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"] retain];
	});
	return devNullFileHandle;
}
- (void) nullifyStandardOutput {
	[self setStandardOutput:[self devNullFileHandle]];
}
- (void) nullifyStandardError {
	[self setStandardError:[self devNullFileHandle]];
}

#pragma mark Inherited methods

- (id) init {
	if ((self = [super init])) {
		trimWhitespaceFromAccumulatedOutputs = YES;
	}
	return self;
}

- (void) launch {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	taskDidTerminateObserverToken = [nc addObserverForName:NSTaskDidTerminateNotification
		object:self
		queue:nil
		usingBlock:^(NSNotification *notification) {
			PRHTask *task = [notification object];
			PRHTerminationBlock block = ([task terminationStatus] == 0)
				? [task successfulTerminationBlock]
				: [task abnormalTerminationBlock];
			block(task);
		}];

	void (^startPipe)(BOOL, id, NSMutableData *, NSString *, NSString *) = ^void(BOOL flag, id pipe, NSMutableData *destination, NSString *tokenPropertyKey, NSString *errorPropertyKey){
		if (flag) {
			id token = [nc addObserverForName:NSFileHandleReadCompletionNotification
				object:pipe
				queue:nil
				usingBlock:^(NSNotification *notification) {
					NSFileHandle *fh = [notification object];
					NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
					if (data) {
						if ([data length] > 0) {
							[destination appendData:data];
							[fh readInBackgroundAndNotify];
						} else {
							//End of file.
						}
					} else {
						NSNumber *errnoNum = [[notification userInfo] objectForKey:@"NSFileHandleError"];
						NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:[errnoNum intValue] userInfo:nil];
						[self setValue:error forKey:tokenPropertyKey];
					}
				}];
			[self setValue:token forKey:tokenPropertyKey];

			if ([pipe respondsToSelector:@selector(fileHandleForReading)]) {
				NSFileHandle *fh = [pipe fileHandleForReading];
				[fh readInBackgroundAndNotify];
			}
		}
	};

	startPipe([self accumulatesStandardOutput], [self standardOutput], accumulatedStandardOutputData, @"standardOutputObserverToken", @"standardOutputReadError");
	startPipe([self accumulatesStandardError], [self standardError], accumulatedStandardErrorData, @"standardErrorObserverToken", @"standardErrorReadError");

	[super launch];
}

- (void) dealloc {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	if (taskDidTerminateObserverToken) {
		[nc removeObserver:taskDidTerminateObserverToken];
		[taskDidTerminateObserverToken release];
	}
	if (standardOutputObserverToken) {
		[nc removeObserver:standardOutputObserverToken];
		[standardOutputObserverToken release];
	}
	if (standardErrorObserverToken) {
		[nc removeObserver:standardErrorObserverToken];
		[standardErrorObserverToken release];
	}

	[accumulatedStandardOutputData release];
	[accumulatedStandardErrorData release];
	[standardOutputReadError release];
	[standardErrorReadError release];

	[successfulTerminationBlock release];
	[abnormalTerminationBlock release];

	[super dealloc];
}

@end
