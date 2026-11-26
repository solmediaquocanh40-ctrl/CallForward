// CFShared.h — CallForward 1.0.0 (com.anhdang.callforward)
// Phan dung chung cho tweak (SpringBoard / InCallService / MobilePhone) va prefs.
// Kho cai dat: CFPreferences domain "com.anhdang.callforward" (doc/ghi xuyen tien trinh cung user mobile).
// Log: /var/mobile/Documents/CallForward.log

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#define CF_DOMAIN @"com.anhdang.callforward"
#define CF_LOG_PATH @"/var/mobile/Documents/CallForward.log"
#define CF_NOTIFY_PREFS CFSTR("com.anhdang.callforward/prefsChanged")

// Khoa cai dat
// enabled    (BOOL)   cong tac tong
// rules      (Array)  moi phan tu: { caller: NSString, dest: NSString, sim: NSNumber 0=SIM chinh, 1=SIM phu }
// destSIM1   (String) so dich dang set cho ma chuyen-khi-ban (**67*) cua SIM chinh
// destSIM2   (String) so dich dang set cho ma chuyen-khi-ban (**67*) cua SIM phu

static inline void CFLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"HH:mm:ss";
    NSString *proc = [[NSProcessInfo processInfo] processName];
    NSString *line = [NSString stringWithFormat:@"[%@][%@] %@\n", [df stringFromDate:[NSDate date]], proc, msg];
    NSLog(@"[CallForward] %@", msg);
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:CF_LOG_PATH];
    if (!fh) {
        [[NSFileManager defaultManager] createFileAtPath:CF_LOG_PATH contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:CF_LOG_PATH];
    }
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

// Chuan hoa so dien thoai VN: bo khoang trang/dau cham, +84 -> 0, 84xxxxxxxxx (11 so) -> 0xxxxxxxxx
static inline NSString *CFNormalizeNumber(NSString * _Nullable raw) {
    if (![raw isKindOfClass:[NSString class]] || raw.length == 0) return @"";
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar c = [raw characterAtIndex:i];
        if (c >= '0' && c <= '9') [digits appendFormat:@"%C", c];
        else if (c == '+' && digits.length == 0) [digits appendString:@"+"];
    }
    NSString *d = digits;
    if ([d hasPrefix:@"+84"] && d.length == 12) d = [@"0" stringByAppendingString:[d substringFromIndex:3]];
    else if ([d hasPrefix:@"84"] && d.length == 11) d = [@"0" stringByAppendingString:[d substringFromIndex:2]];
    else if ([d hasPrefix:@"+"]) d = [d substringFromIndex:1];
    return d;
}

// So sanh 2 so: bang nhau sau chuan hoa, hoac 9 so cuoi bang nhau (chong lech dinh dang)
static inline BOOL CFNumbersMatch(NSString * _Nullable a, NSString * _Nullable b) {
    NSString *na = CFNormalizeNumber(a);
    NSString *nb = CFNormalizeNumber(b);
    if (na.length == 0 || nb.length == 0) return NO;
    if ([na isEqualToString:nb]) return YES;
    if (na.length >= 9 && nb.length >= 9) {
        return [[na substringFromIndex:na.length - 9] isEqualToString:[nb substringFromIndex:nb.length - 9]];
    }
    return NO;
}

static inline _Nullable id CFPrefValue(NSString *key) {
    return (__bridge_transfer id)CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR("com.anhdang.callforward"));
}

static inline void CFSetPrefValue(NSString *key, _Nullable id value) {
    if (value) CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, CFSTR("com.anhdang.callforward"));
    else CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, CFSTR("com.anhdang.callforward"));
    CFPreferencesAppSynchronize(CFSTR("com.anhdang.callforward"));
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CF_NOTIFY_PREFS, NULL, NULL, true);
}

static inline BOOL CFEnabled(void) {
    id v = CFPrefValue(@"enabled");
    if ([v isKindOfClass:[NSNumber class]]) return [v boolValue];
    return YES; // mac dinh bat
}

static inline NSArray<NSDictionary *> *CFRules(void) {
    id v = CFPrefValue(@"rules");
    if ([v isKindOfClass:[NSArray class]]) return v;
    return @[];
}

static inline void CFSaveRules(NSArray<NSDictionary *> *rules) {
    CFSetPrefValue(@"rules", rules);
}

static inline NSDictionary * _Nullable CFRuleForCaller(NSString *caller) {
    for (NSDictionary *r in CFRules()) {
        if ([r isKindOfClass:[NSDictionary class]] && CFNumbersMatch(r[@"caller"], caller)) return r;
    }
    return nil;
}

// Them moi hoac cap nhat luat cho so goi (khop theo so da chuan hoa)
static inline void CFUpsertRule(NSString *caller, NSString *dest, NSInteger sim) {
    NSString *nc = CFNormalizeNumber(caller);
    NSString *nd = CFNormalizeNumber(dest);
    if (nc.length == 0 || nd.length == 0) return;
    NSMutableArray *rules = [CFRules() mutableCopy];
    BOOL found = NO;
    for (NSUInteger i = 0; i < rules.count; i++) {
        NSDictionary *r = rules[i];
        if ([r isKindOfClass:[NSDictionary class]] && CFNumbersMatch(r[@"caller"], nc)) {
            rules[i] = @{ @"caller": nc, @"dest": nd, @"sim": @(sim) };
            found = YES;
            break;
        }
    }
    if (!found) [rules addObject:@{ @"caller": nc, @"dest": nd, @"sim": @(sim) }];
    CFSaveRules(rules);
    CFLog(@"luat: da luu %@ -> %@ (SIM %ld), tong %lu luat", nc, nd, (long)sim, (unsigned long)rules.count);
}

static inline void CFDeleteRuleForCaller(NSString *caller) {
    NSMutableArray *rules = [CFRules() mutableCopy];
    NSUInteger before = rules.count;
    [rules filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *r, NSDictionary *bindings) {
        return ![r isKindOfClass:[NSDictionary class]] || !CFNumbersMatch(r[@"caller"], caller);
    }]];
    if (rules.count != before) {
        CFSaveRules(rules);
        CFLog(@"luat: da xoa luat cua %@, con %lu luat", CFNormalizeNumber(caller), (unsigned long)rules.count);
    }
}

static inline NSString *CFDestForSIM(NSInteger sim) {
    id v = CFPrefValue(sim == 1 ? @"destSIM2" : @"destSIM1");
    if ([v isKindOfClass:[NSString class]]) return CFNormalizeNumber(v);
    return @"";
}

// URL quay ma MMI: tel://**67*<dest>%23 (ban phim Dien thoai se mo san, nguoi dung chon line + bam Goi)
static inline NSString * _Nullable CFTelURLForMMI(NSString *mmiBody) {
    NSString *s = [[NSString stringWithFormat:@"tel://%@", mmiBody] stringByReplacingOccurrencesOfString:@"#" withString:@"%23"];
    return s;
}

NS_ASSUME_NONNULL_END
