//
//  PRHTask.h
//  Revision Switcher
//
//  Created by Peter Hosey on 2011-10-13.
//  Copyright 2011 Peter Hosey. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^PRHTerminationBlock)(NSTask *task);

@interface PRHTask : NSTask

//For directing output to /dev/null.
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

#pragma mark -

@property(copy) PRHTerminationBlock successfulTerminationBlock;
@property(copy) PRHTerminationBlock abnormalTerminationBlock;

@end
