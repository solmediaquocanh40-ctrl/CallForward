#import <Preferences/PSListController.h>

@interface CFPrefsController : PSListController
- (void)armSIM1:(id)sender;
- (void)disarmSIM1:(id)sender;
- (void)statusSIM1:(id)sender;
- (void)armSIM2:(id)sender;
- (void)disarmSIM2:(id)sender;
- (void)statusSIM2:(id)sender;
- (void)addRuleSIM1:(id)sender;
- (void)addRuleSIM2:(id)sender;
- (void)showRules:(id)sender;
- (void)deleteRule:(id)sender;
@end
