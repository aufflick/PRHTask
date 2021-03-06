//
//  PRHTask.m
//  Revision Switcher
//
//  Created by Peter Hosey on 2011-10-13.
//  Copyright 2011 Peter Hosey. All rights reserved.
//

#import "PRHTask.h"

#import <objc/runtime.h>

@interface PRHTask ()
@property(copy) id standardInput;

@property(nonatomic, readwrite, retain) NSError *standardOutputReadError, *standardErrorReadError;

@end

@implementation PRHTask
{
	pid_t pid;
	dispatch_source_t processExitSource, standardOutputReadSource, standardErrorReadSource;
	NSMutableData *accumulatedStandardOutputData, *accumulatedStandardErrorData;
}

@synthesize launchPath;
@synthesize arguments;
@synthesize currentDirectoryPath;

@synthesize processIdentifier;
@synthesize terminationStatus;

@synthesize standardInput;
@synthesize standardOutput;
@synthesize standardError;

@synthesize environment;

@synthesize trimWhitespaceFromAccumulatedOutputs;

@synthesize accumulatedStandardOutputData;
@synthesize accumulatedStandardErrorData;

@synthesize standardOutputReadError, standardErrorReadError;

@synthesize successfulTerminationBlock;
@synthesize abnormalTerminationBlock;

#pragma mark Implementation guts

- (void) startPipeOrNot:(BOOL)flag pipe:(id)pipe onQueue:(dispatch_queue_t)queue intoData:(NSMutableData *)destination observerSourcePropertyKey:(NSString *)sourcePropertyKey errorSourcePropertyKey:(NSString *)errorPropertyKey {
	if (flag) {
		NSFileHandle *fh = [pipe respondsToSelector:@selector(fileHandleForReading)]
			? [pipe fileHandleForReading]
			: pipe;

		dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)[fh fileDescriptor], /*mask*/ 0, queue);
		dispatch_source_set_event_handler(source, ^(void) {
			//Cast explanation: In our case, this is a FD, and dispatch_source_get_handle(3) says “The result of this function may be cast directly to the underlying type”.
			int fd = (int)dispatch_source_get_handle(source);

			unsigned long bytesWaiting = dispatch_source_get_data(source);
			NSMutableData *data = [NSMutableData dataWithLength:bytesWaiting];
			ssize_t amountRead = read(fd, [data mutableBytes], bytesWaiting);
			if (amountRead < 0) {
				NSNumber *errnoNum = [NSNumber numberWithInt:errno];
				NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:[errnoNum intValue] userInfo:nil];
				[self setValue:error forKey:errorPropertyKey];
			} else {
				//We can cast to unsigned here because the if establishes that amountRead is non-negative.
				[data setLength:(NSUInteger)amountRead];
				[destination appendData:data];
			}
		});

		object_setInstanceVariable(self, [sourcePropertyKey UTF8String], source);

		dispatch_resume(source);
	}
}

- (NSFileHandle *) fileHandleWithWantedSelector:(SEL)wantedSel closingFileHandleFromUnwantedSelector:(SEL)unwantedSel bothFromPipe:(id)possiblePipe {
	NSFileHandle *fh = nil;
	NSPipe *pipe = possiblePipe;

	if ([possiblePipe respondsToSelector:unwantedSel])
		[[pipe fileHandleForReading] closeFile];

	if ([possiblePipe respondsToSelector:wantedSel])
		fh = [pipe fileHandleForWriting];
	else
		fh = possiblePipe;

	return fh;
}
- (NSFileHandle *) readingFileHandleFromPipeClosingWriteEnd:(id)possiblePipe {
	return [self fileHandleWithWantedSelector:@selector(fileHandleForReading) closingFileHandleFromUnwantedSelector:@selector(fileHandleForWriting) bothFromPipe:possiblePipe];
}
- (NSFileHandle *) writingFileHandleFromPipeClosingReadEnd:(id)possiblePipe {
	return [self fileHandleWithWantedSelector:@selector(fileHandleForWriting) closingFileHandleFromUnwantedSelector:@selector(fileHandleForReading) bothFromPipe:possiblePipe];
}

#pragma mark Inherited and NSTask methods

- (id) init {
	if ((self = [super init])) {
		trimWhitespaceFromAccumulatedOutputs = YES;
	}
	return self;
}



- (void) launch {
	//It may be better to have a property for the queue.
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, /*flags*/ 0);

	[self startPipeOrNot:[self accumulatesStandardOutput] 
					pipe:[self standardOutput]
				 onQueue:queue
				intoData:accumulatedStandardOutputData 
		observerSourcePropertyKey:@"standardOutputObserverToken" 
		errorSourcePropertyKey:@"standardOutputReadError"];
	[self startPipeOrNot:[self accumulatesStandardError] 
					pipe:[self standardError] 
				 onQueue:queue
				intoData:accumulatedStandardErrorData 
		observerSourcePropertyKey:@"standardErrorObserverToken" 
		errorSourcePropertyKey:@"standardErrorReadError"];
    
    // Preparing for child
    // We can't do this stuff in a convenience method etc. because some of the required Cocoa/Core Foundation
    // is not save after fork.
    // See http://opensource.apple.com/source/CF/CF-550/CFRuntime.c
    
    NSArray *args = [[NSArray arrayWithObject:self.launchPath] arrayByAddingObjectsFromArray:self.arguments];
    
	for (NSString *key in self.environment) {
		NSString *value = [self.environment objectForKey:key];
		setenv([key UTF8String], [value UTF8String], /*overwrite*/ 1);
	}
    
	NSString *desiredCWD = self.currentDirectoryPath;
	if (desiredCWD) {
		int changed = chdir([desiredCWD fileSystemRepresentation]);
		NSAssert(changed == 0, @"Could not change CWD to %@", desiredCWD);
	}
    
	char **argv = malloc(sizeof(char *) * ([args count] + 1));
	char **argvp = argv;
    
	for (NSString *arg in args) {
		NSMutableData *argData = [[[arg dataUsingEncoding:NSUTF8StringEncoding] mutableCopy] autorelease];
		//Null-terminate
		[argData setLength:[argData length] + 1];
        
		*(argvp++) = [argData mutableBytes];
	}
	*argvp = NULL;

    const char * path = [self.launchPath fileSystemRepresentation];
    
    int childStdInReadFileDes, childStdInWriteFileDes;
    int childStdOutReadFileDes, childStdOutWriteFileDes;
    int childStdErrReadFileDes, childStdErrWriteFileDes;
    
    if (!self.standardInput)
    {
        childStdInReadFileDes = -1;
        childStdInWriteFileDes = -1;
    }
    else if ([self.standardInput isKindOfClass:[NSPipe class]])
    {
        childStdInReadFileDes = [[(NSPipe *)self.standardInput fileHandleForReading] fileDescriptor];
        childStdInWriteFileDes = [[(NSPipe *)self.standardInput fileHandleForWriting] fileDescriptor];
    }
    else
    {
        childStdInReadFileDes = [(NSFileHandle *)self.standardInput fileDescriptor];
        childStdInWriteFileDes = -1;
    }
    
    if (!self.standardOutput)
    {
        childStdOutReadFileDes = -1;
        childStdOutWriteFileDes = -1;
    }
    else if ([self.standardOutput isKindOfClass:[NSPipe class]])
    {
        childStdOutReadFileDes = [[(NSPipe *)self.standardOutput fileHandleForReading] fileDescriptor];
        childStdOutWriteFileDes = [[(NSPipe *)self.standardOutput fileHandleForWriting] fileDescriptor];
    }
    else
    {
        childStdOutReadFileDes = -1;
        childStdOutWriteFileDes = [(NSFileHandle *)self.standardOutput fileDescriptor];
    }

    if (!self.standardError)
    {
        childStdErrReadFileDes = -1;
        childStdErrWriteFileDes = -1;
    }
    else if ([self.standardError isKindOfClass:[NSPipe class]])
    {
        childStdErrReadFileDes = [[(NSPipe *)self.standardError fileHandleForReading] fileDescriptor];
        childStdErrWriteFileDes = [[(NSPipe *)self.standardError fileHandleForWriting] fileDescriptor];
    }
    else
    {
        childStdErrReadFileDes = -1;
        childStdErrWriteFileDes = [(NSFileHandle *)self.standardError fileDescriptor];
    }
    
	pid = fork();
	if (pid == 0) {
		//Child process
        
        if (childStdInReadFileDes >= 0)
        {
            dup2(childStdInReadFileDes, STDIN_FILENO);
            close(childStdInReadFileDes);
        }
        if (childStdInWriteFileDes >= 0)
            close(childStdInWriteFileDes);
        if (childStdOutWriteFileDes >= 0)
        {
            dup2(childStdOutWriteFileDes, STDOUT_FILENO);
            close(childStdOutWriteFileDes);
        }
        if (childStdOutReadFileDes >= 0)
            close(childStdOutReadFileDes);
        if (childStdErrWriteFileDes >= 0)
        {
            dup2(childStdErrWriteFileDes, STDERR_FILENO);
            close(childStdErrWriteFileDes);
        }
        if (childStdErrReadFileDes >= 0)
            close(childStdErrReadFileDes);
        
        execv(path, argv);
        __builtin_unreachable();
	} else {
		NSAssert(pid > 0, @"Couldn't fork: %s", strerror(errno));
	}
    
    free(argv);
    
    processIdentifier = pid;
    
    // should we be closing one end of the pipes here?
    // doing what I thought was right resulted in occasional sigpipes (err 141) at the child end

	__block PRHTask *bself = self;
	pid_t launchedPID = pid; //Avert the retain cycle we'd have if the block accessed the ivar.

	processExitSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, (uintptr_t)pid, DISPATCH_PROC_EXIT, queue);
	dispatch_source_set_event_handler(processExitSource, ^(void) {
		int status = -1;
		waitpid(launchedPID, &status, /*options*/ 0);
        terminationStatus = WEXITSTATUS(status);
		PRHTerminationBlock block = (terminationStatus == 0)
			? [bself successfulTerminationBlock]
			: [bself abnormalTerminationBlock];
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			block(bself);
		});
	});
	dispatch_resume(processExitSource);
}

- (void) terminate {
	kill(pid, SIGTERM);
}

- (void) dealloc {
	void (^PRHDispatchRelease)(void *) = ^void(void *object) {
		if (object != NULL)
			dispatch_release(object);
	};

	PRHDispatchRelease(standardOutputReadSource);
	PRHDispatchRelease(standardErrorReadSource);

	PRHDispatchRelease(processExitSource);

	[accumulatedStandardOutputData release];
	[accumulatedStandardErrorData release];
	[standardOutputReadError release];
	[standardErrorReadError release];

	[successfulTerminationBlock release];
	[abnormalTerminationBlock release];

	[launchPath release];
	[arguments release];
	[currentDirectoryPath release];
	[standardOutput release];
	[standardError release];
	[environment release];

	[super dealloc];
}

- (NSString *) description {
	NSMutableArray *descriptionChunks = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %p", [self class], self]];
	[descriptionChunks addObject:[NSString stringWithFormat:@"%@", self.launchPath ?: @"(no launch path set)"]];
	[descriptionChunks addObject:[NSString stringWithFormat:@"%@", self.arguments ?: @"(no arguments set)"]];
	[descriptionChunks addObject:@"in CWD"];
	if (!(self.currentDirectoryPath))
		[descriptionChunks addObject:@"(inherited)"];
	NSFileManager *mgr = [[[NSFileManager alloc] init] autorelease];
	[descriptionChunks addObject:self.currentDirectoryPath ?: [mgr currentDirectoryPath]];
	return [NSString stringWithFormat:@"<%@>", [descriptionChunks componentsJoinedByString:@" "]];
}

#pragma mark Conveniences

+ (id) taskWithProgramNameAndArguments:(NSArray *)arguments {
	PRHTask *task = [[[PRHTask alloc] init] autorelease];
	task.argumentsIncludingProgramName = arguments;
	return task;
}
+ (id) taskWithProgramName:(NSString *)name arguments:(id)arg1 , ... {
	va_list argl;
	va_start(argl, arg1);

	NSMutableArray *array = [NSMutableArray arrayWithObject:name];
	if (arg1) {
		void (^addToArray)(NSMutableArray *, id) = ^void(NSMutableArray *theArray, id argToAdd) {
			if ([argToAdd isKindOfClass:[NSString class]]) {
				[theArray addObject:argToAdd];
			} else if ([argToAdd isKindOfClass:[NSArray class]]) {
				for (id subarg in argToAdd) {
					NSAssert([subarg isKindOfClass:[NSString class]], @"Array of args %@ passed that contains a non-string (%@)", argToAdd, subarg);
				}

				[theArray addObjectsFromArray:argToAdd];
			} else {
				NSAssert([argToAdd isKindOfClass:[NSString class]] || [argToAdd isKindOfClass:[NSArray class]], @"Only strings and arrays of strings are valid arguments");
			}
		};

		addToArray(array, arg1);

		id arg = nil;
		while ((arg = va_arg(argl, id))) {
			addToArray(array, arg);
		}
	}

	va_end(argl);
	return [self taskWithProgramNameAndArguments:array];
}

- (NSArray *) argumentsIncludingProgramName {
	NSArray *allArgs = nil;

	if ([[self.launchPath lastPathComponent] isEqualToString:@"env"])
		allArgs = self.arguments;
	else
		allArgs = [[NSArray arrayWithObject:self.launchPath] arrayByAddingObjectsFromArray:self.arguments];

	return allArgs;
}
- (void) setArgumentsIncludingProgramName:(NSArray *)argumentsIncludingProgramName {
	NSString *firstArg = [argumentsIncludingProgramName objectAtIndex:0UL];
	if ([firstArg isAbsolutePath]) {
		self.launchPath = firstArg;
		self.arguments = [argumentsIncludingProgramName subarrayWithRange:(NSRange){ 1UL, [argumentsIncludingProgramName count] - 1UL }];
	} else {
		self.launchPath = @"/usr/bin/env";
		self.arguments = argumentsIncludingProgramName;
	}
}

- (NSURL *) currentDirectoryURL {
	return [NSURL fileURLWithPath:self.currentDirectoryPath];
}
- (void) setCurrentDirectoryURL:(NSURL *)URL {
	NSParameterAssert([URL isFileURL]);
	self.currentDirectoryPath = [URL path];
}

#pragma mark Easy output accumulation

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
		self.standardOutput = [NSPipe pipe];
	} else if (accumulatedStandardOutputData && !flag) {
		[accumulatedStandardOutputData release];
		accumulatedStandardOutputData = nil;
		self.standardOutput = nil;
	}
}
- (BOOL) accumulatesStandardError {
	return (accumulatedStandardErrorData != nil);
}
- (void) setAccumulatesStandardError:(BOOL)flag {
	if (flag && !accumulatedStandardErrorData) {
		accumulatedStandardErrorData = [[NSMutableData alloc] init];
		self.standardError = [NSPipe pipe];
	} else if (accumulatedStandardErrorData && !flag) {
		[accumulatedStandardErrorData release];
		accumulatedStandardErrorData = nil;
		self.standardError = nil;
	}
}

- (NSFileHandle *)devNullFileHandle {
	static NSFileHandle *devNullFileHandle;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		devNullFileHandle = [[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"] retain];
	});
	return devNullFileHandle;
}
- (void) nullifyStandardInput {
	[self setStandardInput:[self devNullFileHandle]];
}
- (void) nullifyStandardOutput {
	[self setStandardOutput:[self devNullFileHandle]];
}
- (void) nullifyStandardError {
	[self setStandardError:[self devNullFileHandle]];
}

@end
