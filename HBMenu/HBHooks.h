// HBHooks.h — game hooks for the HB mod menu.
//
// Status of each hook (honest assessment, 2026-11-09):
//  - FPS unlock: IMPLEMENTED — sets Unity Application.targetFrameRate.
//  - Map hack / aimbot / skin unlock / auto actions: STRUCTURE READY.
//    The exact UnityFramework function addresses still need to be found by
//    reverse engineering (the game is IL2CPP + obfuscated). Each hook is a
//    clearly marked HB_TODO with the intended mechanism written out, so it
//    can be filled in as soon as the address is known. Until then the
//    toggle is a safe no-op (menu works, game is untouched).

#import <Foundation/Foundation.h>
@class HBMenu;

@interface HBHooks : NSObject

// Called once at install: re-apply every saved toggle.
+ (void)applySavedState:(HBMenu *)menu;

// Called when a menu toggle/slider changes.
+ (void)applyFeature:(NSString *)key enabled:(BOOL)enabled menu:(HBMenu *)menu;

@end
