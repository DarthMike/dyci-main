//
//  SFFileSystemCodeInjection.h
//  dyci
//
//  Created by Miguel on 26/02/2016.
//  Copyright © 2016 Stanfy. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_IPHONE_SIMULATOR

typedef NS_ENUM(NSInteger, SFFileSystemCodeInjectionType) {
    SFFileSystemCodeInjectionTypeCode,
    SFFileSystemCodeInjectionTypeResource
};

@interface SFFileSystemCodeInjection : NSObject

/*
 Enables file watching for code injections
 */
- (void)enableWithHandler:(void(^)(SFFileSystemCodeInjectionType, NSString*))handler;

/*
 Disables file watching for code injections
 */
- (void)disable;


@end

#endif