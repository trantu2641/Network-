
#import <Preferences/Preferences.h>
#import <Foundation/Foundation.h>

static NSString * const NMStatePath =
    @"/var/mobile/Library/Preferences/com.networkmonitor.tweak.plist";

static uint64_t NMRead(NSDictionary *d, NSString *key) {
    id value = d[key];
    return [value respondsToSelector:@selector(unsignedLongLongValue)]
        ? [value unsignedLongLongValue] : 0;
}

static NSString *NMPretty(uint64_t bytes) {
    NSByteCountFormatter *f = [[NSByteCountFormatter alloc] init];
    f.countStyle = NSByteCountFormatterCountStyleBinary;
    f.includesUnit = YES;
    return [f stringFromByteCount:(long long)bytes];
}

@interface NMRootListController : PSListController
@end

@implementation NMRootListController

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *items = [NSMutableArray array];

    [items addObject:[PSSpecifier
        preferenceSpecifierNamed:@"NetworkMonitor"
        target:nil set:nil get:nil detail:nil
        cell:PSGroupCell edit:nil]];

    NSArray *rows = @[
        @[@"Wi-Fi · Tháng này", @"monthlyWifi"],
        @[@"4G/5G · Tháng này", @"monthlyCell"],
        @[@"Tổng · Tháng này", @"monthlyTotal"],
        @[@"Wi-Fi · Tích lũy", @"lifetimeWifi"],
        @[@"4G/5G · Tích lũy", @"lifetimeCell"],
        @[@"Tổng · Tích lũy", @"lifetimeTotal"]
    ];

    for (NSArray *row in rows) {
        PSSpecifier *s = [PSSpecifier
            preferenceSpecifierNamed:row[0]
            target:self set:nil
            get:@selector(valueForSpecifier:)
            detail:nil cell:PSStaticTextCell edit:nil];

        [s setProperty:row[1] forKey:@"NMKey"];
        [items addObject:s];
    }

    [items addObject:[PSSpecifier
        preferenceSpecifierNamed:
            @"Số liệu được cập nhật khi Cài đặt đang mở."
        target:nil set:nil get:nil detail:nil
        cell:PSGroupCell edit:nil]];

    PSSpecifier *reset = [PSSpecifier
        preferenceSpecifierNamed:@"Đặt lại thống kê tháng"
        target:self set:nil get:nil detail:nil
        cell:PSButtonCell edit:nil];

    [reset setButtonAction:@selector(resetMonthly)];
    [items addObject:reset];

    _specifiers = [items copy];
    return _specifiers;
}

- (id)valueForSpecifier:(PSSpecifier *)specifier {
    NSDictionary *state =
        [NSDictionary dictionaryWithContentsOfFile:NMStatePath] ?: @{};

    NSString *key = [specifier propertyForKey:@"NMKey"];

    if ([key isEqualToString:@"monthlyTotal"]) {
        return NMPretty(
            NMRead(state, @"monthlyWifi") +
            NMRead(state, @"monthlyCell"));
    }

    if ([key isEqualToString:@"lifetimeTotal"]) {
        return NMPretty(
            NMRead(state, @"lifetimeWifi") +
            NMRead(state, @"lifetimeCell"));
    }

    return NMPretty(NMRead(state, key));
}

- (void)resetMonthly {
    NSMutableDictionary *state =
        [NSMutableDictionary dictionaryWithContentsOfFile:NMStatePath];

    if (!state) state = [NSMutableDictionary dictionary];

    state[@"monthlyWifi"] = @0;
    state[@"monthlyCell"] = @0;
    state[@"month"] = NMMonthKey();

    [state writeToFile:NMStatePath atomically:YES];
    [self reloadSpecifiers];
}

@end
