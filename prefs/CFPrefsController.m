// CFPrefsController.m — CallForward 1.0.1
// Trang Cai dat: cong tac tong, so dich + ma chuyen-khi-ban (**67*) cho tung SIM,
// them/xem/xoa luat thu cong (duong du phong khi chua gan duoc tu tab Gan day).

#import "CFPrefsController.h"
#import "../CFShared.h"
#import <Preferences/PSSpecifier.h>

@interface CFPrefsController ()
- (NSString *)fieldValueForID:(NSString *)specID;
- (void)showAlertTitle:(NSString *)title message:(NSString *)message;
- (void)dialMMI:(NSString *)mmiBody simLabel:(NSString *)simLabel;
- (void)addRuleWithSim:(NSInteger)sim;
@end

@implementation CFPrefsController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id value = CFPrefValue(key);
    if (!value) value = [specifier propertyForKey:@"default"];
    return value;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    CFSetPrefValue(key, value);
}

- (NSString *)fieldValueForID:(NSString *)specID {
    PSSpecifier *spec = [self specifierForID:specID];
    if (!spec) return @"";
    id v = [self readPreferenceValue:spec];
    if ([v isKindOfClass:[NSString class]]) return v;
    return @"";
}

- (void)showAlertTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dialMMI:(NSString *)mmiBody simLabel:(NSString *)simLabel {
    NSString *urlStr = CFTelURLForMMI(mmiBody);
    NSURL *url = urlStr ? [NSURL URLWithString:urlStr] : nil;
    if (!url) { [self showAlertTitle:@"Loi" message:@"Khong tao duoc ma quay."]; return; }
    [self showAlertTitle:@"Sap mo ban phim"
                 message:[NSString stringWithFormat:@"Anh chon dung line %@ o tren ban phim, kiem tra ma %@ roi bam Goi.", simLabel, mmiBody]];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    CFLog(@"prefs: mo quay ma %@ cho %@", mmiBody, simLabel);
}

// ----- SIM chinh (sim = 0) -----
- (void)armSIM1:(id)sender {
    NSString *dest = CFNormalizeNumber([self fieldValueForID:@"destSIM1"]);
    if (dest.length == 0) { [self showAlertTitle:@"Chua co so dich" message:@"Anh nhap So dich SIM chinh truoc giup em."]; return; }
    [self dialMMI:[NSString stringWithFormat:@"**67*%@#", dest] simLabel:@"SIM chinh"];
}
- (void)disarmSIM1:(id)sender { [self dialMMI:@"##67#" simLabel:@"SIM chinh"]; }
- (void)statusSIM1:(id)sender { [self dialMMI:@"*#67#" simLabel:@"SIM chinh"]; }

// ----- SIM phu (sim = 1) -----
- (void)armSIM2:(id)sender {
    NSString *dest = CFNormalizeNumber([self fieldValueForID:@"destSIM2"]);
    if (dest.length == 0) { [self showAlertTitle:@"Chua co so dich" message:@"Anh nhap So dich SIM phu truoc giup em."]; return; }
    [self dialMMI:[NSString stringWithFormat:@"**67*%@#", dest] simLabel:@"SIM phu"];
}
- (void)disarmSIM2:(id)sender { [self dialMMI:@"##67#" simLabel:@"SIM phu"]; }
- (void)statusSIM2:(id)sender { [self dialMMI:@"*#67#" simLabel:@"SIM phu"]; }

// ----- Luat thu cong -----
- (void)addRuleWithSim:(NSInteger)sim {
    NSString *caller = [self fieldValueForID:@"newRuleCaller"];
    NSString *dest = [self fieldValueForID:@"newRuleDest"];
    if (CFNormalizeNumber(caller).length == 0 || CFNormalizeNumber(dest).length == 0) {
        [self showAlertTitle:@"Thieu so" message:@"Anh nhap du So goi va So dich o muc Them luat thu cong giup em."];
        return;
    }
    CFUpsertRule(caller, dest, sim);
    [self showAlertTitle:@"Da luu luat"
                 message:[NSString stringWithFormat:@"%@ -> %@ (SIM %@). Nho set ma **67* cho SIM do neu chua set.", CFNormalizeNumber(caller), CFNormalizeNumber(dest), sim == 1 ? @"phu" : @"chinh"]];
}
- (void)addRuleSIM1:(id)sender { [self addRuleWithSim:0]; }
- (void)addRuleSIM2:(id)sender { [self addRuleWithSim:1]; }

- (void)showRules:(id)sender {
    NSArray *rules = CFRules();
    if (rules.count == 0) {
        [self showAlertTitle:@"Danh sach luat" message:@"Chua co luat nao. Anh gan tu tab Gan day trong app Dien thoai, hoac them thu cong o muc tren."];
        return;
    }
    NSMutableString *s = [NSMutableString string];
    for (NSDictionary *r in rules) {
        if ([r isKindOfClass:[NSDictionary class]]) {
            [s appendFormat:@"%@ -> %@ (SIM %@)\n", r[@"caller"], r[@"dest"], [r[@"sim"] integerValue] == 1 ? @"phu" : @"chinh"];
        }
    }
    [self showAlertTitle:[NSString stringWithFormat:@"%lu luat dang co", (unsigned long)rules.count] message:s];
}

- (void)deleteRule:(id)sender {
    NSString *caller = [self fieldValueForID:@"delRuleCaller"];
    if (CFNormalizeNumber(caller).length == 0) {
        [self showAlertTitle:@"Chua nhap so" message:@"Anh nhap so goi can xoa luat giup em."];
        return;
    }
    CFDeleteRuleForCaller(caller);
    [self showAlertTitle:@"Da xoa" message:[NSString stringWithFormat:@"Da xoa luat cua so %@ (neu co).", CFNormalizeNumber(caller)]];
}

@end
