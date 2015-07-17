#import <libactivator/libactivator.h>
#include <dispatch/dispatch.h>
#import <notify.h>
#import "dispatch_cancelable_block/dispatch_cancelable_block.h"

#define LASendEventWithName(eventName) \
	[LASharedActivator sendEventToListener:[LAEvent eventWithName:eventName mode:[LASharedActivator currentEventMode]]]

#define kPreferencesDomain "org.thebigboss.gviridis.afterlock"
#define kDefaultSecondsAfterLock 300.0    // Should be same as default value in Preferences.plist

static NSString *afterlock_eventName = @"org.thebigboss.gviridis.afterlock";

static dispatch_cancelable_block_t cancelable_block = nil;
static double secondsAfterLock = kDefaultSecondsAfterLock;

@interface AfterLockDataSource : NSObject <LAEventDataSource> {}

+ (id)sharedInstance;

@end

@implementation AfterLockDataSource

+ (id)sharedInstance {
	static id sharedInstance = nil;
	static dispatch_once_t token = 0;
	dispatch_once(&token, ^{
		sharedInstance = [self new];
	});
	return sharedInstance;
}

+ (void)load {
	[self sharedInstance];
}

- (id)init {
	if ((self = [super init])) {
		// Register our event
		if (LASharedActivator.isRunningInsideSpringBoard) {
			[LASharedActivator registerEventDataSource:self forEventName:afterlock_eventName];
		}
	}
	return self;
}

- (void)dealloc {
	if (LASharedActivator.isRunningInsideSpringBoard) {
		[LASharedActivator unregisterEventDataSourceWithEventName:afterlock_eventName];
	}
	[super dealloc];
}

- (NSString *)localizedTitleForEventName:(NSString *)eventName {
	return [NSString stringWithFormat: @"%d seconds after lock", (int)secondsAfterLock];
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName {
	return @"After Lock";
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName {
	return @"Configure in Settings -> After Lock";
}
/*
- (BOOL)eventWithNameIsHidden:(NSString *)eventName {
	return NO;
}
*/
/*
- (BOOL)eventWithNameRequiresAssignment:(NSString *)eventName {
	return NO;
}
*/
- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode {
	return YES;
}
/*
- (BOOL)eventWithNameSupportsUnlockingDeviceToSend:(NSString *)eventName {
	return NO;
}
*/

@end

////////////////////////////////////////////////////////////////

// Event dispatch

%hook SBLockScreenManager

- (void)_setUILocked:(_Bool)arg1 {
	if (arg1) {    // lock
		dispatch_block_t block = ^{
		    LASendEventWithName(afterlock_eventName);
		};
		if (cancelable_block) {
			cancel_block(cancelable_block);
		}
		cancelable_block = dispatch_after_delay(secondsAfterLock, block);
	} else {    // unlock
		if (cancelable_block) {
			cancel_block(cancelable_block);
		}
	}
	%orig;
}

%end



void updatePreferences(CFNotificationCenterRef center,void *observer,CFStringRef name,const void *object,CFDictionaryRef userInfo) {
    NSDictionary *prefDict = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@kPreferencesDomain];
	NSString *prefObject = [prefDict objectForKey:@"kSecondsAfterLock"];
    secondsAfterLock = fabs((nil == prefObject) ? kDefaultSecondsAfterLock : prefObject.doubleValue);
}

%ctor {
	%init;
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,&updatePreferences,CFSTR("org.thebigboss.gviridis.afterlock/UpdatePreferences"),NULL,0);
    notify_post("org.thebigboss.gviridis.afterlock/UpdatePreferences");
	[AfterLockDataSource sharedInstance];
}
