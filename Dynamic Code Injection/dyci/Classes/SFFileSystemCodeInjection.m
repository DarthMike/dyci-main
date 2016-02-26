//
//  SFFileSystemCodeInjection.m
//  dyci
//
//  Created by Miguel on 26/02/2016.
//  Copyright © 2016 Stanfy. All rights reserved.
//

#import "SFFileSystemCodeInjection.h"
#import "SFFileWatcher.h"

#if TARGET_IPHONE_SIMULATOR

@interface SFFileSystemCodeInjection() <SFFileWatcherDelegate>

@property (nonatomic, copy) void(^watchHandler)(SFFileSystemCodeInjectionType, NSString *);
@property (nonatomic) SFFileWatcher *dciDirectoryFileWatcher;

@end

@implementation SFFileSystemCodeInjection


- (void)enableWithHandler:(void(^)(SFFileSystemCodeInjectionType, NSString *))handler {
    NSString * dciDirectoryPath = [self dciDirectoryPath];
    
    // Saving application bundle path, to have ability to inject
    // Resources, xibs, etc
    [self saveCurrentApplicationBundlePath:dciDirectoryPath];
    
    // Setting up watcher, to get in touch with director contents
    self.dciDirectoryFileWatcher = [SFFileWatcher fileWatcherWithPath:dciDirectoryPath
                              delegate:self];
    
    self.watchHandler = handler;
}

- (void)disable {
    
}

#pragma mark - SFLibWatcherDelegate

- (void)newFileWasFoundAtPath:(NSString *)filePath {
    
    NSLog(@"New file injection detected at path : %@", filePath);
    if ([[filePath lastPathComponent] isEqualToString:@"resource"]) {
        NSString * injectedResourcePath =
        [NSString stringWithContentsOfFile:filePath
                                  encoding:NSUTF8StringEncoding
                                     error:nil];
        
        self.watchHandler(SFFileSystemCodeInjectionTypeResource, injectedResourcePath);
        
    }
    
    // If its library
    // Sometimes... we got notification with temporary file
    // dci12123.dylib.ld_1237sj
    NSString * dciDynamicLibraryPath = filePath;
    if (![[dciDynamicLibraryPath pathExtension] isEqualToString:@"dylib"]) {
        dciDynamicLibraryPath = [dciDynamicLibraryPath stringByDeletingPathExtension];
    }
    if ([[dciDynamicLibraryPath pathExtension] isEqualToString:@"dylib"]) {
        self.watchHandler(SFFileSystemCodeInjectionTypeCode, dciDynamicLibraryPath);
    }
}

#pragma mark - Checking for Library

- (NSString *)dciDirectoryPath {
    
    char * userENV = getenv("USER");
    NSString * dciDirectoryPath = nil;
    if (userENV != NULL) {
        dciDirectoryPath = [NSString stringWithFormat:@"/Users/%s/.dyci/", userENV];
    } else {
        // Fallback to the path, since, we cannot get USER variable
        NSString *simUserDirectoryPath = [@"~" stringByExpandingTildeInPath];
        
        // Assume default installation, which will have /Users/{username}/ structure
        NSArray * simUserDirectoryPathComponents = [simUserDirectoryPath pathComponents];
        if (simUserDirectoryPathComponents.count > 3) {
            // Get first 3 components
            NSMutableArray * macUserDirectoryPathComponents = [[simUserDirectoryPathComponents subarrayWithRange:NSMakeRange(0, 3)] mutableCopy];
            [macUserDirectoryPathComponents addObject:@".dyci"];
            dciDirectoryPath = [NSString pathWithComponents:macUserDirectoryPathComponents];
        }
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:dciDirectoryPath]) {
            // Fallback for users who have changed default HOME directiory path
            // So Idea is that whe have USERHOME/Library/Developer.... etc
            // So we should put everything we can before Library developer
            //
            NSRange userHomeEndPosition = [simUserDirectoryPath rangeOfString:@"/Library/Developer"];
            NSString * macUserHomePath = [simUserDirectoryPath substringToIndex:userHomeEndPosition.location];
            dciDirectoryPath = [macUserHomePath stringByAppendingPathComponent:@".dyci"];
        }
        
    }
    
    NSLog(@"DYCI directory path is : %@", dciDirectoryPath);
    return dciDirectoryPath;
}



#pragma mark - Helpers

- (void)saveCurrentApplicationBundlePath:(NSString *)dyciPath {
    
    NSString * filePathWithBundleInformation = [dyciPath stringByAppendingPathComponent:@"bundle"];
    
    NSString * mainBundlePath = [[NSBundle mainBundle] resourcePath];
    [mainBundlePath writeToFile:filePathWithBundleInformation
                     atomically:NO
                       encoding:NSUTF8StringEncoding
                          error:nil];
}

@end

#endif