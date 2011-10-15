//
//  PRHTask.h
//  Revision Switcher
//
//  Created by Peter Hosey on 2011-10-13.
//  Copyright 2011 Peter Hosey. All rights reserved.
//

#import <Foundation/Foundation.h>

/*This is a replacement for NSTask that improves upon it in a couple of ways.
 *First, rather than having to set your own pipe for standard output and error, you can tell the task to accumulate the output for you, and retrieve it when the task completes.
 *Second, when the process exits, rather than posting an NSNotification, a PRHTask will call either of two blocks that you provide. You can set them both to the same block if you want.
 *
 *It also uses formal properties wherever appropriate and (currently) uses GCD internally.
 *
 *Currently, this does not provide any way to hook standard input up to anything. You can either let it be inherited (default, as in NSTask) or nullify it (connect it to /dev/null).
 *Also, this does not yet have a formal version of NSTask's environment property. Until then, setting the process's environment is unsupported.
 */

@class PRHTask;

typedef void (^PRHTerminationBlock)(PRHTask *task);

@interface PRHTask : NSObject

//taskWithProgramNameAndArguments: passes the array to argumentsIncludingProgramName (see below).
+ (id) taskWithProgramNameAndArguments:(NSArray *)arguments;
//Wraps taskWithProgramNameAndArguments:, enabling you to pass the name and arguments individually without rolling them into an array yourself first.
+ (id) taskWithProgramName:(NSString *)name arguments:(id)arg1, ... NS_REQUIRES_NIL_TERMINATION;

//init works, too.

#pragma mark Properties

//Everything in this section is just like NSTask's counterpart unless otherwise noted.

@property(copy) NSString *launchPath;
@property(copy) NSArray *arguments;
//Shorthand for both of the above.
//When setting: If the first argument is an absolute path, this will set that as the launch path; otherwise, this will set /usr/bin/env as the launch path.
//When getting: Prepends the launch path unless it ends with “env” as a path component.
@property(nonatomic, copy) NSArray *argumentsIncludingProgramName;

@property(copy) NSString *currentDirectoryPath;
//Convenience alternative if you have, say, a URL from an open panel to use. Must be a file URL or an exception ensues.
@property(nonatomic, copy) NSURL *currentDirectoryURL;

//Just like in NSTask, each of these can be either an NSPipe or an NSFileHandle. You should not touch these if you use the accumulation feature (see below).
//TODO: standardInput
@property(copy) id standardOutput;
@property(copy) id standardError;

#pragma mark -

@property(readonly) pid_t processIdentifier;
@property(readonly) int terminationStatus;

- (void) launch;
- (void) terminate;

#pragma mark Easy output accumulation

//For directing output to (or input from) /dev/null.
- (void) nullifyStandardInput;
- (void) nullifyStandardOutput;
- (void) nullifyStandardError;

//Don't attempt to interact with NSTask's standard{Output,Error} properties if you touch these standard-{output,error} properties.

//Set either or both of these before launch to have normal or error output accumulate in the appropriate data object.
@property(nonatomic) BOOL accumulatesStandardOutput, accumulatesStandardError;

//“Whitespace” here includes line breaks (whitespaceAndNewlineCharacterSet). Applies to both output and error output. Only affects the string properties; the data properties always contain the full output unmolested. Defaults to YES.
@property(nonatomic) BOOL trimWhitespaceFromAccumulatedOutputs;

//You probably should only use these after the task exits.
//You can expect the string properties to return nil if the output data is not valid UTF-8.
@property(nonatomic, readonly) NSData *accumulatedStandardOutputData;
@property(nonatomic, readonly) NSString *outputStringFromStandardOutputUTF8;
@property(nonatomic, readonly) NSData *accumulatedStandardErrorData;
@property(nonatomic, readonly) NSString *errorOutputStringFromStandardErrorUTF8;

@property(nonatomic, readonly, retain) NSError *standardOutputReadError, *standardErrorReadError;

#pragma mark Post process

//These blocks are called on the main thread (main queue).
@property(copy) PRHTerminationBlock successfulTerminationBlock;
@property(copy) PRHTerminationBlock abnormalTerminationBlock;

@end
