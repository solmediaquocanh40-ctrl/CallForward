// PhoneUI.x — CallForward 1.0.1 (com.anhdang.callforward)
// Chay trong app Dien thoai (com.apple.mobilephone): them muc "Chuyen huong cuoc goi" vao tab Gan day.
//   - Vuot sang phai tren 1 dong so -> hanh dong "Chuyen huong"
//   - Cham chu (i) cua so do -> sau khi trang chi tiet mo, bang gan so dich cung hien
// Bang gan: hien so goi, nhap so dich, chon SIM chinh/phu, Luu -> ghi luat vao kho chung.
// Sau khi luu, de nghi quay ma **67*<dich># bang dung line SIM do de nha mang kich hoat chuyen-khi-ban.
//
// Ban 1.0.1 la ban DO + THU: cac duong doc so tu dong Gan day deu ghi log; neu doc khong ra,
// bang gan van mo voi o so goi de trong de anh tu nhap tay — luat van luu duoc.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>
#include <stdlib.h>
#import "CFShared.h"

static id CFPUKVC(id obj, NSString *key) {
    if (!obj || key.length == 0) return nil;
    @try { return [obj valueForKey:key]; } @catch (NSException *e) { return nil; }
}
static id CFPUMsgId1(id obj, SEL sel, id a1) {
    if (!obj || ![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL, id))objc_msgSend)(obj, sel, a1);
}

// Trich so goi tu 1 doi tuong "cuoc goi gan day" (CHRecentCall / PHRecentCall tuy ban iOS)
static NSString *CFPUCallerFromCallObject(id callObj, BOOL dumpProps) {
    if (!callObj) return nil;
    if (dumpProps) {
        unsigned int count = 0;
        objc_property_t *props = class_copyPropertyList(object_getClass(callObj), &count);
        NSMutableString *names = [NSMutableString string];
        for (unsigned int i = 0; i < count; i++) [names appendFormat:@"%s ", property_getName(props[i])];
        if (props) free(props);
        CFLog(@"GanDay: properties cua %@: %@", NSStringFromClass(object_getClass(callObj)), names);
    }
    NSArray *keys = @[@"callerId", @"callerID", @"phoneNumber", @"destinationID", @"callerIdValue", @"_callerId"];
    for (NSString *k in keys) {
        id v = CFPUKVC(callObj, k);
        if ([v isKindOfClass:[NSString class]] && [v length] > 0) return v;
        if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    }
    id handle = CFPUKVC(callObj, @"handle");
    if (handle) {
        id val = CFPUKVC(handle, @"value");
        if ([val isKindOfClass:[NSString class]] && [val length] > 0) return val;
    }
    return nil;
}

// ---------- Trinh bang gan so dich ----------
@interface CFRuleSheet : NSObject
+ (void)presentForCaller:(NSString *)caller fromViewController:(UIViewController *)vc;
+ (UIViewController *)topViewControllerFrom:(UIViewController *)vc;
+ (void)saveRuleCaller:(NSString *)caller dest:(NSString *)dest sim:(NSInteger)sim fromViewController:(UIViewController *)vc;
@end

@implementation CFRuleSheet

+ (UIViewController *)topViewControllerFrom:(UIViewController *)vc {
    UIViewController *top = vc;
    while (top.presentedViewController) top = top.presentedViewController;
    if ([top isKindOfClass:[UINavigationController class]]) {
        UIViewController *vis = [(UINavigationController *)top visibleViewController];
        if (vis) top = vis;
    }
    return top;
}

+ (void)presentForCaller:(NSString *)caller fromViewController:(UIViewController *)vc {
    UIViewController *top = [self topViewControllerFrom:vc];
    if (!top) { CFLog(@"bang gan: khong tim thay view controller de hien"); return; }
    NSDictionary *existing = caller.length ? CFRuleForCaller(caller) : nil;
    NSString *msg = caller.length
        ? [NSString stringWithFormat:@"So goi: %@\nGan so dich — lan sau so nay goi vao, cuoc goi se chuyen qua so dich (chuyen hong thi may bao ban).", CFNormalizeNumber(caller)]
        : @"Em chua doc tu dong duoc so goi tu dong nay, anh nhap so goi va so dich thu cong giup em.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chuyen huong cuoc goi" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"So goi (neu chua co san)";
        tf.text = caller.length ? CFNormalizeNumber(caller) : @"";
        tf.keyboardType = UIKeyboardTypePhonePad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"So dich nhan thay";
        tf.text = existing ? existing[@"dest"] : @"";
        tf.keyboardType = UIKeyboardTypePhonePad;
    }];
    // 2 nut luu: SIM chinh / SIM phu
    UIAlertAction *saveMain = [UIAlertAction actionWithTitle:@"Luu — ap cho SIM chinh" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *c = alert.textFields[0].text;
        NSString *d = alert.textFields[1].text;
        [self saveRuleCaller:c dest:d sim:0 fromViewController:top];
    }];
    UIAlertAction *saveSub = [UIAlertAction actionWithTitle:@"Luu — ap cho SIM phu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *c = alert.textFields[0].text;
        NSString *d = alert.textFields[1].text;
        [self saveRuleCaller:c dest:d sim:1 fromViewController:top];
    }];
    [alert addAction:saveMain];
    [alert addAction:saveSub];
    if (existing) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Xoa luat cua so nay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            CFDeleteRuleForCaller(caller);
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Huy" style:UIAlertActionStyleCancel handler:nil]];
    [top presentViewController:alert animated:YES completion:nil];
    CFLog(@"bang gan: da mo cho so %@ (luat cu: %@)", caller ?: @"(trong)", existing ? @"co" : @"khong");
}

+ (void)saveRuleCaller:(NSString *)caller dest:(NSString *)dest sim:(NSInteger)sim fromViewController:(UIViewController *)vc {
    if (CFNormalizeNumber(caller).length == 0 || CFNormalizeNumber(dest).length == 0) {
        UIAlertController *err = [UIAlertController alertControllerWithTitle:@"Thieu so" message:@"Anh nhap du so goi va so dich giup em." preferredStyle:UIAlertControllerStyleAlert];
        [err addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [vc presentViewController:err animated:YES completion:nil];
        return;
    }
    CFUpsertRule(caller, dest, sim);
    NSString *nd = CFNormalizeNumber(dest);
    NSString *armedDest = CFDestForSIM(sim);
    BOOL mismatch = armedDest.length > 0 && !CFNumbersMatch(armedDest, nd);
    NSString *mmi = [NSString stringWithFormat:@"**67*%@#", nd];
    NSString *note = mismatch
        ? [NSString stringWithFormat:@"Luu y: SIM nay dang set ma 67 cho so %@ (khac so dich vua gan). De chuyen dung so dich moi, anh quay lai ma: %@ bang dung line SIM %ld roi bam Goi.", armedDest, mmi, (long)(sim + 1)]
        : [NSString stringWithFormat:@"De nha mang kich hoat chuyen: mo ban phim, chon dung line SIM %ld, quay %@ roi bam Goi (lam 1 lan).", (long)(sim + 1), mmi];
    UIAlertController *done = [UIAlertController alertControllerWithTitle:@"Da luu luat" message:note preferredStyle:UIAlertControllerStyleAlert];
    [done addAction:[UIAlertAction actionWithTitle:@"Quay ma ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *urlStr = CFTelURLForMMI(mmi);
        NSURL *url = urlStr ? [NSURL URLWithString:urlStr] : nil;
        if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }]];
    [done addAction:[UIAlertAction actionWithTitle:@"De sau" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:done animated:YES completion:nil];
}

@end

// ---------- Moc vao man hinh Gan day ----------
// PHAI khai bao @interface day du cho PHRecentsController (class rieng cua app Dien thoai, SDK khong co header):
// Logos chi tao @class forward declaration, gui message cho self / truyen self lam UIViewController* se chet
// -Werror "receiver type is a forward declaration". Khai bao thua ke UITableViewController + method %new o day.
@interface PHRecentsController : UITableViewController
- (NSString *)cf_callerForRowAtIndexPath:(NSIndexPath *)indexPath;
@end

%group CFRecentsGroup

%hook PHRecentsController

%new
- (NSString *)cf_callerForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Duong 1: cac selector truc tiep tren controller
    NSArray *selNames = @[@"recentCallForIndexPath:", @"_recentCallForIndexPath:", @"callForIndexPath:", @"recentForIndexPath:"];
    for (NSString *sn in selNames) {
        id callObj = CFPUMsgId1(self, NSSelectorFromString(sn), indexPath);
        NSString *num = CFPUCallerFromCallObject(callObj, YES);
        if (num) { CFLog(@"GanDay: doc so qua %@ -> %@", sn, num); return num; }
    }
    // Duong 2: mang du lieu cua controller
    NSArray *arrKeys = @[@"recents", @"_recents", @"recentCalls", @"_recentCalls"];
    for (NSString *k in arrKeys) {
        id arr = CFPUKVC(self, k);
        if ([arr isKindOfClass:[NSArray class]] && indexPath.row < (NSInteger)[arr count]) {
            NSString *num = CFPUCallerFromCallObject(arr[indexPath.row], YES);
            if (num) { CFLog(@"GanDay: doc so qua mang %@ -> %@", k, num); return num; }
        }
    }
    // Duong 3: qua cell
    UITableView *tv = CFPUKVC(self, @"tableView");
    if (!tv) tv = [self isKindOfClass:[UITableViewController class]] ? [(UITableViewController *)self tableView] : nil;
    UITableViewCell *cell = tv ? [tv cellForRowAtIndexPath:indexPath] : nil;
    if (cell) {
        NSArray *cellKeys = @[@"call", @"_call", @"recentCall", @"callObject", @"_recentCall"];
        for (NSString *k in cellKeys) {
            NSString *num = CFPUCallerFromCallObject(CFPUKVC(cell, k), YES);
            if (num) { CFLog(@"GanDay: doc so qua cell.%@ -> %@", k, num); return num; }
        }
        CFLog(@"GanDay: cell class=%@, chua doc duoc so tu cell", NSStringFromClass(object_getClass(cell)));
    }
    CFLog(@"GanDay: KHONG doc duoc so o dong %ld — mo bang trong de nhap tay", (long)indexPath.row);
    return nil;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Khong goi orig: PHRecentsController khong cai san leading swipe, goi orig se trung vao IMP rong.
    // Mac dinh iOS cho phep vuot phai trong khi khong co hanh dong nao — tra ve cau hinh chi gom hanh dong cua minh.
    UIContextualAction *fwd = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                       title:@"Chuyen huong"
                                                                     handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        NSString *caller = [self cf_callerForRowAtIndexPath:indexPath];
        [CFRuleSheet presentForCaller:caller fromViewController:self];
        completionHandler(YES);
    }];
    fwd.backgroundColor = [UIColor systemBlueColor];
    return [UISwipeActionsConfiguration configurationWithActions:@[fwd]];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    @try { %orig; } @catch (NSException *e) { CFLog(@"GanDay: orig accessory loi: %@", e); }
    NSString *caller = [self cf_callerForRowAtIndexPath:indexPath];
    // Cho trang chi tiet mo xong roi hien bang (0.45s)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [CFRuleSheet presentForCaller:caller fromViewController:self];
    });
}

%end

%end // CFRecentsGroup

// ---------- Khoi dong moc Gan day (thu lai nhieu nhip neu class nap cham) ----------
static BOOL gCFRecentsHooked = NO;

static void CFPUTryHookRecents(NSString *when) {
    if (gCFRecentsHooked) return;
    if (NSClassFromString(@"PHRecentsController")) {
        %init(CFRecentsGroup);
        gCFRecentsHooked = YES;
        CFLog(@"GanDay: da moc PHRecentsController (%@) — vuot phai + nut i", when);
    }
}

// Liet ke moi class co chu "Recent" tren ban iOS nay — neu PHRecentsController khong ton tai,
// dong log nay chi thang ten class dung de vong sau doi moc.
static void CFPUDumpRecentCandidates(void) {
    @try {
        unsigned int count = 0;
        count = objc_getClassList(NULL, 0);
        if (count == 0) return;
        Class *list = (Class *)malloc(sizeof(Class) * count);
        if (!list) return;
        objc_getClassList(list, count);
        NSMutableString *found = [NSMutableString string];
        for (unsigned int i = 0; i < count; i++) {
            const char *n = class_getName(list[i]);
            if (n && strstr(n, "Recent")) [found appendFormat:@"%s ", n];
        }
        free(list);
        CFLog(@"GanDay: cac class chua 'Recent' tren may: %@", found.length ? found : @"(khong co class nao)");
    } @catch (NSException *e) {
        CFLog(@"GanDay: dump class Recent loi: %@", e);
    }
}

%ctor {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (![bundleID isEqualToString:@"com.apple.mobilephone"]) return;
        CFLog(@"=== CallForward 1.0.1 nap vao Dien thoai ===");
        CFPUTryHookRecents(@"luc nap");
        if (!gCFRecentsHooked) {
            CFLog(@"GanDay: PHRecentsController chua xuat hien luc nap — se thu lai cac nhip sau");
            CFPUDumpRecentCandidates();
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                CFPUTryHookRecents(@"app chay xong");
            }];
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                CFPUTryHookRecents(@"app active");
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                CFPUTryHookRecents(@"sau 2s");
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                CFPUTryHookRecents(@"sau 5s");
                if (!gCFRecentsHooked) CFLog(@"GanDay: VAN khong thay PHRecentsController sau 5s — xem dong dump class o tren");
            });
        }
    }
}
