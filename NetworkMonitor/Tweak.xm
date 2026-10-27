
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <sys/socket.h>
#import <stdint.h>

static NSString * const NMStatePath =
    @"/var/mobile/Library/Preferences/com.networkmonitor.tweak.plist";

static NSMutableDictionary *NMState;
static dispatch_queue_t NMQueue;
static dispatch_source_t NMTimer;

static NSString *NMMonthKey(void) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    f.dateFormat = @"yyyy-MM";
    return [f stringFromDate:[NSDate date]];
}

static uint64_t NMValue(NSDictionary *d, NSString *key) {
    id value = d[key];
    return [value respondsToSelector:@selector(unsignedLongLongValue)]
        ? [value unsignedLongLongValue] : 0;
}

static uint64_t NMInterfaceBytes(NSString *wanted) {
    struct ifaddrs *list = NULL;
    uint64_t total = 0;

    if (getifaddrs(&list) != 0) return 0;

    for (struct ifaddrs *ifa = list; ifa; ifa = ifa->ifa_next) {
        if (!ifa->ifa_name || !ifa->ifa_data || !ifa->ifa_addr) continue;
        if (ifa->ifa_addr->sa_family != AF_LINK) continue;

        NSString *name = [NSString stringWithUTF8String:ifa->ifa_name];
        if (![wanted isEqualToString:name]) continue;

        struct if_data *data = (struct if_data *)ifa->ifa_data;
        total = (uint64_t)data->ifi_ibytes +
                (uint64_t)data->ifi_obytes;
        break;
    }

    freeifaddrs(list);
    return total;
}

static void NMSave(void) {
    [NMState writeToFile:NMStatePath atomically:YES];
}

static void NMCollect(void) {
    if (!NMQueue) {
        NMQueue = dispatch_queue_create(
            "com.networkmonitor.counter", DISPATCH_QUEUE_SERIAL);
    }

    dispatch_async(NMQueue, ^{
        if (!NMState) {
            NMState = [NSMutableDictionary dictionaryWithContentsOfFile:NMStatePath];
            if (!NMState) NMState = [NSMutableDictionary dictionary];
        }

        uint64_t wifi = NMInterfaceBytes(@"en0");
        uint64_t cell = NMInterfaceBytes(@"pdp_ip0");
        NSString *month = NMMonthKey();

        if (![NMState[@"month"] isEqualToString:month]) {
            NMState[@"month"] = month;
            NMState[@"monthlyWifi"] = @0;
            NMState[@"monthlyCell"] = @0;
        }

        uint64_t oldWifi = NMValue(NMState, @"lastWifi");
        uint64_t oldCell = NMValue(NMState, @"lastCell");

        // Lần đọc đầu tiên chỉ thiết lập mốc.
        if (![NMState[@"initialized"] boolValue]) {
            NMState[@"initialized"] = @YES;
        } else {
            if (wifi >= oldWifi) {
                uint64_t delta = wifi - oldWifi;
                NMState[@"lifetimeWifi"] =
                    @(NMValue(NMState, @"lifetimeWifi") + delta);
                NMState[@"monthlyWifi"] =
                    @(NMValue(NMState, @"monthlyWifi") + delta);
            }

            if (cell >= oldCell) {
                uint64_t delta = cell - oldCell;
                NMState[@"lifetimeCell"] =
                    @(NMValue(NMState, @"lifetimeCell") + delta);
                NMState[@"monthlyCell"] =
                    @(NMValue(NMState, @"monthlyCell") + delta);
            }
        }

        NMState[@"lastWifi"] = @(wifi);
        NMState[@"lastCell"] = @(cell);
        NMState[@"updatedAt"] = @([[NSDate date] timeIntervalSince1970]);

        NMSave();
    });
}

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier
                isEqualToString:@"com.apple.Preferences"]) {
            return;
        }

        NMCollect();

        dispatch_async(dispatch_get_main_queue(), ^{
            if (NMTimer) return;

            NMTimer = dispatch_source_create(
                DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                dispatch_get_main_queue());

            dispatch_source_set_timer(
                NMTimer,
                dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC),
                30 * NSEC_PER_SEC,
                2 * NSEC_PER_SEC);

            dispatch_source_set_event_handler(NMTimer, ^{
                NMCollect();
            });

            dispatch_resume(NMTimer);
        });
    }
}
