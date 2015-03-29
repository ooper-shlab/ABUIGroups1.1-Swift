//
//  ABUIGroupsAppDelegate.swift
//  ABUIGroups
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/3/29.
//
//
/*
     File: ABUIGroupsAppDelegate.h
     File: ABUIGroupsAppDelegate.m
 Abstract: Application delegate that sets up the application.
  Version: 1.1

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2013 Apple Inc. All Rights Reserved.

*/
import UIKit

@UIApplicationMain
@objc(ABUIGroupsAppDelegate)
class ABUIGroupsAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    
    //MARK: -
    //MARK: Application lifecycle
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        return true
    }
    
    
    func applicationWillResignActive(application: UIApplication) {
        /*
        Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        */
    }
    
    
    func applicationDidEnterBackground(application: UIApplication) {
        /*
        Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
        */
    }
    
    
    func applicationWillEnterForeground(application: UIApplication) {
        /*
        Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
        */
    }
    
    
    func applicationDidBecomeActive(application: UIApplication) {
        /*
        Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        */
    }
    
    
    func applicationWillTerminate(application: UIApplication) {
        /*
        Called when the application is about to terminate.
        See also applicationDidEnterBackground:.
        */
    }
    
    
    //MARK: -
    //MARK: Memory management
    
    func applicationDidReceiveMemoryWarning(application: UIApplication) {
        /*
        Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
        */
    }
    
}