// Tweak.x — CallForward 1.0.1 (com.anhdang.callforward)
// Chay trong SpringBoard + InCallService (loc o CallForward.plist), KHONG chay trong MobilePhone (phan do o PhoneUI.x).
//
// Nhiem vu: khi co cuoc goi SIM den, doc so nguoi goi bang TelephonyUtilities (TUCallCenter/TUCall, goi qua runtime
// vi la API rieng), khop voi danh sach luat da gan:
//   - Khop luat -> tu cho cuoc goi "ban" ngay (disconnect) de nha mang kich hoat ma chuyen-khi-ban **67*:
//       chuyen duoc  -> cuoc goi qua so dich, may dich reo binh thuong, dich ban thi ben goi nghe ban cua dich.
//       chuyen hong  -> ben goi nghe ban ngay tai may nay (luat cung cua anh Quoc), may khong reo.
//   - Khong khop -> khong dung vao, cuoc goi reo binh thuong.
//
// Ban 1.0.1 la ban DO + THU: moi duong doc so / cat cuoc deu ghi log vao /var/mobile/Documents/CallForward.log
// de vong sau chot duong dung tren may that (iPhone 12 Pro, iOS 16.3.1).

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CallKit/CallKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "CFShared.h"

// ---------- Tien ich goi runtime (API rieng, khong import header rieng) ----------
static id CFMsgId0(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}
static void CFMsgVoid0(id obj, SEL sel) {
    if (!obj || ![obj respondsToSelector:sel]) return;
    ((void (*)(id, SEL))objc_msgSend)(obj, sel);
}
static void CFMsgVoid1Long(id obj, SEL sel, long a1) {
    if (!obj || ![obj respondsToSelector:sel]) return;
    ((void (*)(id, SEL, long))objc_msgSend)(obj, sel, a1);
}
static void CFMsgVoid1Id(id obj, SEL sel, id a1) {
    if (!obj || ![obj respondsToSelector:sel]) return;
    ((void (*)(id, SEL, id))objc_msgSend)(obj, sel, a1);
}
static id CFKVC(id obj, NSString *key) {
    if (!obj || key.length == 0) return nil;
    @try { return [obj valueForKey:key]; } @catch (NSException *e) { return nil; }
}

// Doc so nguoi goi tu 1 TUCall: thu lan luot cac duong da biet
static NSString *CFCallerFromTUCall(id call) {
    if (!call) return nil;
    NSArray *directKeys = @[@"destinationID", @"callerID", @"_destinationID", @"destinationId"];
    for (NSString *k in directKeys) {
        id v = CFKVC(call, k);
        if ([v isKindOfClass:[NSString class]] && [v length] > 0) return v;
        SEL sel = NSSelectorFromString(k);
        id v2 = CFMsgId0(call, sel);
        if ([v2 isKindOfClass:[NSString class]] && [v2 length] > 0) return v2;
    }
    // handle: TUHandle / CXHandle co "value" la so
    id handle = CFKVC(call, @"handle");
    if (!handle) handle = CFMsgId0(call, NSSelectorFromString(@"handle"));
    if (handle) {
        id val = CFKVC(handle, @"value");
        if ([val isKindOfClass:[NSString class]] && [val length] > 0) return val;
    }
    return nil;
}

// ---------- Lop theo doi cuoc goi ----------
@interface CFCallWatcher : NSObject <CXCallObserverDelegate>
@property (nonatomic, strong) CXCallObserver *observer;
@property (nonatomic, strong) NSMutableSet *handledUUIDs;
@property (nonatomic, assign) BOOL dumpedTUCallProps;
- (void)start;
- (void)checkIncomingTUCall;
- (void)attemptRejectTUCall:(id)call cxUUID:(NSUUID *)cxUUID caller:(NSString *)caller;
@end

@implementation CFCallWatcher

- (void)start {
    self.handledUUIDs = [NSMutableSet set];
    self.observer = [[CXCallObserver alloc] init];
    [self.observer setDelegate:self queue:dispatch_get_main_queue()];
    CFLog(@"watcher: CXCallObserver da chay trong %@", [[NSProcessInfo processInfo] processName]);
}

- (void)callObserver:(CXCallObserver *)callObserver callChanged:(CXCall *)call {
    CFLog(@"CX: call %@ outgoing=%d connected=%d ended=%d onHold=%d",
          call.UUID.UUIDString, call.isOutgoing, call.hasConnected, call.hasEnded, call.isOnHold);
    if (call.isOutgoing || call.hasConnected || call.hasEnded) return;
    if ([self.handledUUIDs containsObject:call.UUID]) return;
    // Cho TUCall kip xuat hien roi kiem tra 2 nhip
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkIncomingTUCall];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkIncomingTUCall];
    });
}

- (void)checkIncomingTUCall {
    if (!CFEnabled()) return;
    Class tuCenterClass = NSClassFromString(@"TUCallCenter");
    if (!tuCenterClass) { CFLog(@"TU: khong thay TUCallCenter"); return; }
    id center = CFMsgId0(tuCenterClass, NSSelectorFromString(@"sharedInstance"));
    if (!center) { CFLog(@"TU: sharedInstance nil"); return; }

    NSMutableArray *calls = [NSMutableArray array];
    id incoming = CFMsgId0(center, NSSelectorFromString(@"incomingCall"));
    if (incoming) [calls addObject:incoming];
    NSArray *listKeys = @[@"currentCalls", @"allCalls", @"calls", @"_calls"];
    for (NSString *k in listKeys) {
        id list = CFKVC(center, k);
        if ([list isKindOfClass:[NSArray class]]) {
            for (id c in list) { if (c && ![calls containsObject:c]) [calls addObject:c]; }
        }
    }
    if (calls.count == 0) { CFLog(@"TU: chua thay cuoc goi nao trong TUCallCenter"); return; }

    for (id call in calls) {
        // Bo qua cuoc da ket noi / da ket thuc / cuoc goi di neu doc duoc cac co nay
        id statusVal = CFKVC(call, @"status");
        // status TUCall: 1=calling, 3=conversing... chi log, khong loc cung o ban do
        NSString *caller = CFCallerFromTUCall(call);
        CFLog(@"TU: call=%@ status=%@ caller=%@", call, statusVal, caller ?: @"(chua doc duoc)");

        if (!self.dumpedTUCallProps) {
            self.dumpedTUCallProps = YES;
            unsigned int count = 0;
            objc_property_t *props = class_copyPropertyList(object_getClass(call), &count);
            NSMutableString *names = [NSMutableString string];
            for (unsigned int i = 0; i < count; i++) [names appendFormat:@"%s ", property_getName(props[i])];
            if (props) free(props);
            CFLog(@"TU: properties cua %@: %@", NSStringFromClass(object_getClass(call)), names);
            id provider = CFKVC(call, @"provider");
            id localId = CFKVC(call, @"localSenderIdentity");
            if (!localId) localId = CFKVC(call, @"senderIdentity");
            CFLog(@"TU: provider=%@ localSenderIdentity=%@", provider, localId);
        }

        if (!caller) continue;
        NSDictionary *rule = CFRuleForCaller(caller);
        if (!rule) continue;

        id uuidObj = CFKVC(call, @"callUUID");
        if (!uuidObj) uuidObj = CFKVC(call, @"UUID");
        NSString *uuidKey = [uuidObj description] ?: caller;
        if ([self.handledUUIDs containsObject:uuidKey]) continue;
        [self.handledUUIDs addObject:uuidKey];

        CFLog(@"KHOP LUAT: %@ -> %@ (SIM %@) — tien hanh cho ban/chuyen", caller, rule[@"dest"], rule[@"sim"]);
        NSUUID *cxUUID = nil;
        for (CXCall *c in self.observer.calls) { if (!c.isOutgoing && !c.hasEnded) { cxUUID = c.UUID; break; } }
        [self attemptRejectTUCall:call cxUUID:cxUUID caller:caller];
    }
}

- (void)attemptRejectTUCall:(id)call cxUUID:(NSUUID *)cxUUID caller:(NSString *)caller {
    BOOL tried = NO;
    // Duong 1: TUCall -disconnect
    if ([call respondsToSelector:NSSelectorFromString(@"disconnect")]) {
        CFMsgVoid0(call, NSSelectorFromString(@"disconnect"));
        CFLog(@"cat cuoc: da goi TUCall.disconnect cho %@", caller);
        tried = YES;
    }
    // Duong 2: TUCall -disconnectWithReason:
    if (!tried && [call respondsToSelector:NSSelectorFromString(@"disconnectWithReason:")]) {
        CFMsgVoid1Long(call, NSSelectorFromString(@"disconnectWithReason:"), 1);
        CFLog(@"cat cuoc: da goi TUCall.disconnectWithReason:1 cho %@", caller);
        tried = YES;
    }
    // Duong 3: TUCallCenter -disconnectCall:
    if (!tried) {
        Class tuCenterClass = NSClassFromString(@"TUCallCenter");
        id center = CFMsgId0(tuCenterClass, NSSelectorFromString(@"sharedInstance"));
        if ([center respondsToSelector:NSSelectorFromString(@"disconnectCall:")]) {
            CFMsgVoid1Id(center, NSSelectorFromString(@"disconnectCall:"), call);
            CFLog(@"cat cuoc: da goi TUCallCenter.disconnectCall: cho %@", caller);
            tried = YES;
        }
    }
    // Duong 4 (du phong song song neu co UUID): CallKit CXCallController end call
    if (cxUUID) {
        CXCallController *controller = [[CXCallController alloc] init];
        CXEndCallAction *action = [[CXEndCallAction alloc] initWithCallUUID:cxUUID];
        CXTransaction *tx = [[CXTransaction alloc] initWithAction:action];
        [controller requestTransaction:tx completion:^(NSError *error) {
            CFLog(@"cat cuoc: CXCallController end %@ -> %@", cxUUID, error ? error.localizedDescription : @"OK");
        }];
        tried = YES;
    }
    if (!tried) CFLog(@"cat cuoc: THAT BAI — khong duong nao kha dung cho %@", caller);
}

@end

static CFCallWatcher *gWatcher = nil;

%ctor {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (![bundleID isEqualToString:@"com.apple.springboard"] && ![bundleID isEqualToString:@"com.apple.InCallService"]) return;
        CFLog(@"=== CallForward 1.0.1 nap vao %@ ===", bundleID);
        CFLog(@"luat hien co: %lu", (unsigned long)CFRules().count);
        gWatcher = [[CFCallWatcher alloc] init];
        [gWatcher start];
    }
}
