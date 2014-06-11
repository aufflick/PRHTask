PRHTask
=======

This is a fork of Peter Hosey's Mercurial repo, with a fix for [this bug](https://bitbucket.org/boredzo/prhtask/issue/1/use-of-objective-c-among-other-things).

## What it is

A replacement for NSTask. Should be drop-in for most (eventually all) purposes.

If there's anything in NSTask that this doesn't implement that you need, please file a request in the issue tracker. If you implement it yourself, please send in a patch.

### Features

* Output accumulation: The task can (optionally) read data from stdout and stderr for you. You collect it as either raw data or a string (decoded from UTF-8) when the process is done.
* Completion blocks: You can set a block to be called when the task successfully terminates or when it abnormally terminates. You can set a different block on each or the same block on both.
* Whitespace chomping: When using output accumulation, if you ask for the output as a string, it will, by default, come with any whitespace trimmed off the start and end. (You can turn this off.)
* Easily set stdin, stdout, or stderr to /dev/null.
* Formal properties for all properties.
* Conveniences such as currentDirectoryURL, argumentsIncludingProgramName, and taskWithProgramName:arguments:.

### Example

From the test program:

```objective-c
	PRHTask *task = [PRHTask taskWithProgramName:@"echo" arguments:@"I am the very model of a modern Major-General", nil];
        task.accumulatesStandardOutput = YES;

        task.successfulTerminationBlock = ^(PRHTask *completedTask) {
                NSLog(@"Completed task: %@ with exit status: %i", completedTask, completedTask.terminationStatus);
                NSLog(@"Accumulated output: %@", [task outputStringFromStandardOutputUTF8]);
        };
        task.abnormalTerminationBlock = ^(PRHTask *completedTask) {
                NSLog(@"Task exited abnormally: %@ with exit status: %i", completedTask, completedTask.terminationStatus);
        };

        [task launch];
```

### Missing features

Some of NSTask's features aren't implemented yet. (You can help!) These include:

* standardInput: You can nullify it, but can't hook it up to a pipe or FD yet.
* launchedTaskWithLaunchPath:arguments:: It's just not very useful, so I didn't bother.
* suspend and resume
* terminationReason (the “did it exit or get killed?” method, not to be confused with terminationStatus, which is supported)

### Features that will never be implemented include:

* NSTaskDidTerminateNotification (blocks are better)
* waitUntilExit (always makes a program worse; the termination blocks are a better solution)
