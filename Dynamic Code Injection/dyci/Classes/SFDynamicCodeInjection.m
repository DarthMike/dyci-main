//
//  SFDynamicCodeInjection
//  Dynamic Code Injection
//
//  Created by Paul Taykalo on 10/7/12.
//  Copyright (c) 2012 Stanfy LLC. All rights reserved.
//
#import <objc/runtime.h>
#import "SFDynamicCodeInjection.h"
#include <dlfcn.h>
#import "NSSet+ClassesList.h"
#import "NSObject+DyCInjection.h"
#import "SFInjectionsNotificationsCenter.h"
#import "SFFileSystemCodeInjection.h"

@interface SFDynamicCodeInjection()

@end

@implementation SFDynamicCodeInjection {

   BOOL _enabled;
#if TARGET_IPHONE_SIMULATOR
    SFFileSystemCodeInjection *_fileSystemCodeInjection;
#else
#endif
   
}

+ (void)load {
   [self enable];

   NSLog(@"============================================");
   NSLog(@"DYCI : Dynamic Code Injection was started...");
   NSLog(@"To disable it, paste next line in your application:didFinishLaunching: method : \n\n"
         "[NSClassFromString(@\"SFDynamicCodeInjection\") performSelector:@selector(disable)];\n\n");
   NSLog(@"     or");
   NSLog(@"Simply remove dyci from dependencies");
   NSLog(@"============================================");
   

}

+ (SFDynamicCodeInjection *)sharedInstance {
   static SFDynamicCodeInjection * _instance = nil;

   @synchronized (self) {
      if (_instance == nil) {
         _instance = [[self alloc] init];
      }
   }

   return _instance;
}

+ (void)enable {
    
    
    SFDynamicCodeInjection *instance = [self sharedInstance];
   if (!instance->_enabled) {
      
      instance->_enabled = YES;

      // Swizzling init and dealloc methods
      [NSObject allowInjectionSubscriptionOnInitMethod];

#if TARGET_IPHONE_SIMULATOR
       instance->_fileSystemCodeInjection = [[SFFileSystemCodeInjection alloc] init];
      [instance->_fileSystemCodeInjection enableWithHandler:^(SFFileSystemCodeInjectionType type, NSString *injectedResourcePath) {
          switch (type) {
              case SFFileSystemCodeInjectionTypeCode: {
                  [instance injectWithLibraryAtPath:injectedResourcePath];
                  break;
              }
              case SFFileSystemCodeInjectionTypeResource: {
                  [instance injectResourcesAtPath:injectedResourcePath];
                  break;
              }
          }
      }];
#else
       
#endif
   }

}


+ (void)disable {
   if ([self sharedInstance]->_enabled) {
      [self sharedInstance]->_enabled = NO;
      
      // Re-swizzling init and dealloc methods
      [NSObject allowInjectionSubscriptionOnInitMethod];
       
#if TARGET_IPHONE_SIMULATOR
       [[self sharedInstance]->_fileSystemCodeInjection disable];
#else
       
#endif
      NSLog(@"============================================");
      NSLog(@"DYCI : Dynamic Code Injection was stopped   ");
      NSLog(@"============================================");

   }
}

#pragma mark - Injection entry points

- (void)injectResourcesAtPath:(NSString *)path {
    NSLog(@" ");
    NSLog(@" ================================================= ");
    NSLog(@"New resource was injected");
    NSLog(@"All classes will be notified with");
    NSLog(@" - (void)updateOnResourceInjection:(NSString *)path ");
    NSLog(@" ");
    
    // Flushing UIImage cache
    [self flushUIImageCache];
    
    if ([[path pathExtension] isEqualToString:@"strings"]) {
        [self flushBundleCache:[NSBundle mainBundle]];
    }
    
    [[SFInjectionsNotificationsCenter sharedInstance] notifyOnResourceInjection:path];
}

- (void)injectWithLibraryAtPath:(NSString *)path {
    NSLog(@" ");
    NSLog(@" ================================================= ");
    NSLog(@"Found new DCI ... Loading");
    
    NSMutableSet * classesSet = [NSMutableSet currentClassesSet];
    
    void * libHandle = dlopen([path cStringUsingEncoding:NSUTF8StringEncoding],
                              RTLD_NOW | RTLD_GLOBAL);
    char * err = dlerror();
    
    if (libHandle) {
        
        NSLog(@"DYCI was successfully loaded");
        NSLog(@"Searching classes to inject");
        
        // Retrieving difference between old classes list and
        // current classes list
        NSMutableSet * currentClassesSet = [NSMutableSet currentClassesSet];
        [currentClassesSet minusSet:classesSet];
        
        [self performInjectionWithClassesInSet:currentClassesSet];
        
    } else {
        
        NSLog(@"Couldn't load file Error : %s", err);
        
    }
    
    NSLog(@" ");
    
    dlclose(libHandle);
}

#pragma mark - Injections

/*
 Injecting in all classes, that were found in specified set
 */
- (void)performInjectionWithClassesInSet:(NSMutableSet *)classesSet {

   for (NSValue * classWrapper in classesSet) {
      Class clz;
      [classWrapper getValue:&clz];
      NSString * className = NSStringFromClass(clz);

      if ([className hasPrefix:@"__"] && [className hasSuffix:@"__"]) {
         // Skip some O_o classes

      } else {

         [self performInjectionWithClass:clz];
         NSLog(@"Class was successfully injected");

      }
   }
}



- (void)performInjectionWithClass:(Class)injectedClass {
   // Parsing it's method

   // This is really fun
   // Even if we load two instances of classes with the same name :)
   // NSClassFromString Will return FIRST(Original) Instance. And this is cool!
   NSString * className = [NSString stringWithFormat:@"%s", class_getName(injectedClass)];
   Class originalClass = NSClassFromString(className);

   // Replacing instance methods
   [self replaceMethodsOfClass:originalClass withMethodsOfClass:injectedClass];

   // Additionally we need to update Class methods (not instance methods) implementations
   [self replaceMethodsOfClass:object_getClass(originalClass) withMethodsOfClass:object_getClass(injectedClass)];

   // Notifying about new classes logic
    NSLog(@"Class (%@) and their subclasses instances would be notified with", NSStringFromClass(originalClass));
    NSLog(@" - (void)updateOnClassInjection ");

    [[SFInjectionsNotificationsCenter sharedInstance] notifyOnClassInjection:originalClass];

}


- (void)replaceMethodsOfClass:(Class)originalClass withMethodsOfClass:(Class)injectedClass {
   if (originalClass != injectedClass) {

      NSLog(@"Injecting %@ class : %@", class_isMetaClass(injectedClass) ? @"meta" : @"", NSStringFromClass(injectedClass));

      // Original class methods

      int i = 0;
      unsigned int mc = 0;

      Method * injectedMethodsList = class_copyMethodList(injectedClass, &mc);
      for (i = 0; i < mc; i++) {

         Method m = injectedMethodsList[i];
         SEL selector = method_getName(m);
         const char * types = method_getTypeEncoding(m);
         IMP injectedImplementation = method_getImplementation(m);

         //  Replacing old implementation with new one
         class_replaceMethod(originalClass, selector, injectedImplementation, types);

      }

   }
}




#pragma mark - Privat API's

/*
 This one was found by searching on Github private headers
 */
- (void)flushUIImageCache {
#warning Fix this
   [NSClassFromString(@"UIImage") performSelector:@selector(_flushSharedImageCache)];

}

/*
 And this one was found Here
 http://michelf.ca/blog/2010/killer-private-eraser/
 Thanks to Michel
 */
extern void _CFBundleFlushBundleCaches(CFBundleRef bundle) __attribute__((weak_import));

- (void)flushBundleCache:(NSBundle *)bundle {
   
   // Check if we still have this function
   if (_CFBundleFlushBundleCaches != NULL) {
         CFURLRef bundleURL;
         CFBundleRef myBundle;
         
         // Make a CFURLRef from the CFString representation of the
         // bundle’s path.
         bundleURL = CFURLCreateWithFileSystemPath(
                                                   kCFAllocatorDefault,
                                                   (CFStringRef)[bundle bundlePath],
                                                   kCFURLPOSIXPathStyle,
                                                   true );
         
         // Make a bundle instance using the URLRef.
         myBundle = CFBundleCreate( kCFAllocatorDefault, bundleURL );
         
         _CFBundleFlushBundleCaches(myBundle);
         
         CFRelease(myBundle);
         CFRelease(bundleURL);
   }
}

#pragma mark - Settings

+ (void)notifyAllClassesOnInjection {
    [SFInjectionsNotificationsCenter sharedInstance].notificationStategy = SFInjectionNotificationStrategyAllClasses;
}

+ (void)notifyInjectedClassAndSubclassesOnInjection {
    [SFInjectionsNotificationsCenter sharedInstance].notificationStategy = SFInjectionNotificationStrategyInjectedClassOnly;
}

@end


