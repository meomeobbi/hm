// HBMenu.h — HB mod menu for Arena of Valor (com.tumadam.aovz)
// Brand: HB. Custom UI designed from scratch (no TUMADAM layout).
// Toggle: two-finger tap anywhere on screen, or tap the floating HB button.

#import <UIKit/UIKit.h>

@interface HBMenu : NSObject

// Shared instance
+ (instancetype)shared;

// Show / hide the menu
- (void)showMenu;
- (void)hideMenu;
- (void)toggleMenu;

// Feature states (persisted in NSUserDefaults)
@property (nonatomic, assign) BOOL hackMap;
@property (nonatomic, assign) BOOL showRecall;
@property (nonatomic, assign) float cameraDistance;   // 1.0 - 2.0
@property (nonatomic, assign) BOOL fakeName;
@property (nonatomic, copy)   NSString *fakeNameText;

@property (nonatomic, assign) BOOL aimEnabled;
@property (nonatomic, assign) BOOL aimSkill1;
@property (nonatomic, assign) BOOL aimSkill2;
@property (nonatomic, assign) BOOL aimSkill3;
@property (nonatomic, assign) float aimDistance;      // 5 - 20
@property (nonatomic, assign) float aimDeviation;     // 0 - 1

@property (nonatomic, assign) BOOL unlockSkin;
@property (nonatomic, assign) BOOL unlockSkin2;
@property (nonatomic, assign) BOOL changeSkinInMatch;

@property (nonatomic, assign) BOOL autoSmite;
@property (nonatomic, assign) BOOL autoSmiteBuff;
@property (nonatomic, assign) BOOL autoSmiteDragon;
@property (nonatomic, assign) BOOL autoExecute;
@property (nonatomic, assign) float autoExecuteHP;    // 5 - 30 (%)
@property (nonatomic, assign) BOOL autoSwapItems;

@property (nonatomic, assign) NSInteger fpsLimit;     // 30 / 60 / 90 / 120

@end
