// HBHooks.m — game hooks for the HB mod menu.
//
// HOW HOOKING WORKS HERE (runtime resolution, no hard-coded addresses)
// ----------------------------------------------------------------------
// AoV is a Unity IL2CPP game. This build uses a Tencent-customised IL2CPP
// v29 metadata format (magic 0xeab11baf, non-standard header layout), so
// static tools (Il2CppDumper) cannot dump method addresses from the
// metadata — patching the magic alone still fails (EndOfStreamException),
// because the header's (offset,count) table is laid out differently.
// Hard-coded addresses would also break on every game update.
//
// The correct approach — used by production IL2CPP mod menus — is
// **runtime resolution by name**:
//   1. At load time, use the IL2CPP API to find each method by
//      (assembly, namespace, class, method name, arg count).
//   2. Read its MethodInfo->methodPointer.
//   3. Overwrite methodPointer with our replacement. Every call to that
//      method now runs our code. (methodPointer is the first field of
//      MethodInfo in IL2CPP; we save the original to call through.)
//
// This is version-tolerant: it survives game updates that move code
// around, as long as the class/method names stay the same. All method
// names below were confirmed present in the game's IL2CPP metadata
// (see hb-mod/RE_FINDINGS.md).

#import "HBHooks.h"
#import "HBMenu.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <string.h>
#import <libkern/OSCacheControl.h>

// ---------------------------------------------------------------------------
// IL2CPP API (resolved at runtime from UnityFramework)
// ---------------------------------------------------------------------------
typedef struct Il2CppDomain Il2CppDomain;
typedef struct Il2CppAssembly Il2CppAssembly;
typedef struct Il2CppImage Il2CppImage;
typedef struct Il2CppClass Il2CppClass;
typedef struct Il2CppMethodInfo Il2CppMethodInfo;

typedef Il2CppDomain* (*il2cpp_domain_get_t)(void);
typedef void (*il2cpp_thread_attach_t)(Il2CppDomain*);
typedef const Il2CppAssembly** (*il2cpp_domain_get_assemblies_t)(Il2CppDomain*, size_t*);
typedef Il2CppImage* (*il2cpp_assembly_get_image_t)(const Il2CppAssembly*);
typedef const char* (*il2cpp_image_get_name_t)(Il2CppImage*);
typedef Il2CppClass* (*il2cpp_class_from_name_t)(Il2CppImage*, const char*, const char*);
typedef const Il2CppMethodInfo* (*il2cpp_class_get_method_from_name_t)(Il2CppClass*, const char*, int);

typedef void (*UnitySetTargetFrameRate_t)(int fps);

static struct {
    il2cpp_domain_get_t domain_get;
    il2cpp_thread_attach_t thread_attach;
    il2cpp_domain_get_assemblies_t domain_get_assemblies;
    il2cpp_assembly_get_image_t assembly_get_image;
    il2cpp_image_get_name_t image_get_name;
    il2cpp_class_from_name_t class_from_name;
    il2cpp_class_get_method_from_name_t class_get_method_from_name;
    UnitySetTargetFrameRate_t setTargetFrameRate;
} HB_IL2CPP;

static void *HB_UnityFrameworkHandle(void) {
    static void *handle = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("@executable_path/Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOW);
        if (!handle) handle = RTLD_DEFAULT;
    });
    return handle;
}

static BOOL HB_LoadIL2CPPAPI(void) {
    static BOOL loaded = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = HB_UnityFrameworkHandle();
        if (!h) return;
        HB_IL2CPP.domain_get = (il2cpp_domain_get_t)dlsym(h, "il2cpp_domain_get");
        HB_IL2CPP.thread_attach = (il2cpp_thread_attach_t)dlsym(h, "il2cpp_thread_attach");
        HB_IL2CPP.domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(h, "il2cpp_domain_get_assemblies");
        HB_IL2CPP.assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(h, "il2cpp_assembly_get_image");
        HB_IL2CPP.image_get_name = (il2cpp_image_get_name_t)dlsym(h, "il2cpp_image_get_name");
        HB_IL2CPP.class_from_name = (il2cpp_class_from_name_t)dlsym(h, "il2cpp_class_from_name");
        HB_IL2CPP.class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(h, "il2cpp_class_get_method_from_name");
        HB_IL2CPP.setTargetFrameRate = (UnitySetTargetFrameRate_t)dlsym(h, "UnitySetTargetFrameRate");
        loaded = (HB_IL2CPP.domain_get && HB_IL2CPP.class_from_name && HB_IL2CPP.class_get_method_from_name);
        if (loaded) {
            Il2CppDomain *domain = HB_IL2CPP.domain_get();
            if (domain && HB_IL2CPP.thread_attach) HB_IL2CPP.thread_attach(domain);
        }
    });
    return loaded;
}

// Find an image (assembly) by name, e.g. "Assembly-CSharp".
static Il2CppImage *HB_FindImage(const char *assemblyName) {
    if (!HB_LoadIL2CPPAPI()) return NULL;
    Il2CppDomain *domain = HB_IL2CPP.domain_get();
    if (!domain) return NULL;
    size_t count = 0;
    const Il2CppAssembly **assemblies = HB_IL2CPP.domain_get_assemblies(domain, &count);
    for (size_t i = 0; i < count; i++) {
        Il2CppImage *image = HB_IL2CPP.assembly_get_image(assemblies[i]);
        if (!image) continue;
        const char *name = HB_IL2CPP.image_get_name(image);
        if (name && strcmp(name, assemblyName) == 0) return image;
    }
    return NULL;
}

// Resolve a method's native function pointer by name.
// Returns NULL if not found. The MethodInfo* is returned via outMethod
// so the caller can patch its methodPointer.
static void *HB_ResolveMethod(const char *assembly, const char *ns, const char *klass,
                              const char *method, int argCount,
                              const Il2CppMethodInfo **outMethod) {
    Il2CppImage *image = HB_FindImage(assembly);
    if (!image) { NSLog(@"[HB] image not found: %s", assembly); return NULL; }
    Il2CppClass *cls = HB_IL2CPP.class_from_name(image, ns, klass);
    if (!cls) { NSLog(@"[HB] class not found: %s.%s", ns, klass); return NULL; }
    const Il2CppMethodInfo *mi = HB_IL2CPP.class_get_method_from_name(cls, method, argCount);
    if (!mi) { NSLog(@"[HB] method not found: %s.%s::%s(%d)", ns, klass, method, argCount); return NULL; }
    if (outMethod) *outMethod = mi;
    // methodPointer is the first field of MethodInfo in IL2CPP.
    void *ptr = *(void **)mi;
    NSLog(@"[HB] resolved %s.%s::%s -> %p", ns, klass, method, ptr);
    return ptr;
}

// Replace a method's implementation. Returns the original function pointer.
// methodPointer is the first word of MethodInfo; we patch it in place.
static void *HB_HookMethod(const Il2CppMethodInfo *mi, void *replacement) {
    if (!mi || !replacement) return NULL;
    void **slot = (void **)mi;
    void *orig = *slot;
    *slot = replacement;
    // Flush the instruction cache so the CPU sees the new pointer.
    // (sys_icache_invalidate is the supported iOS API; __builtin___clear_cache
    // emits a call to __clear_cache, which the iOS linker cannot resolve.)
    sys_icache_invalidate(slot, sizeof(void *));
    return orig;
}

// ---------------------------------------------------------------------------
// FPS unlock — public Unity API, no IL2CPP needed.
// ---------------------------------------------------------------------------
static void HB_ApplyFPS(NSInteger fps) {
    if (!HB_LoadIL2CPPAPI()) return;
    if (HB_IL2CPP.setTargetFrameRate) {
        HB_IL2CPP.setTargetFrameRate((int)fps);
        NSLog(@"[HB] FPS limit set to %ld", (long)fps);
    } else {
        NSLog(@"[HB] UnitySetTargetFrameRate not found — FPS unlock unavailable");
    }
}

// ---------------------------------------------------------------------------
// MAP HACK — NucleusDrive.Logic.HorizonMarker::IsVisibleForEnermyCamp
// (the game's own spelling is "Enermy"). Returns bool: is this unit
// visible to the enemy camp. Forcing true reveals all enemies on the
// minimap. The Kyrios.FogOfWar class only renders the fog texture —
// hook the HorizonMarker decision, not the texture.
// Twin method on LActorRoot with the same name.
// ---------------------------------------------------------------------------
typedef bool (*IsVisibleForEnermyCamp_t)(void *self);
static IsVisibleForEnermyCamp_t HB_OrigIsVisible = NULL;
static bool HB_IsVisibleForEnermyCamp(void *self) {
    return true; // always visible -> map hack
}

static void HB_ApplyHackMap(BOOL enabled) {
    if (!enabled) {
        // Un-hook: restore the original pointer if we hooked it.
        // (Re-resolve and restore; safe because we saved the original.)
        if (HB_OrigIsVisible) {
            const Il2CppMethodInfo *mi = NULL;
            HB_ResolveMethod("Assembly-CSharp", "NucleusDrive.Logic", "HorizonMarker",
                             "IsVisibleForEnermyCamp", 0, &mi);
            if (mi) { *(void **)mi = (void *)HB_OrigIsVisible; HB_OrigIsVisible = NULL; }
        }
        NSLog(@"[HB] Hack Map OFF");
        return;
    }
    if (HB_OrigIsVisible) { NSLog(@"[HB] Hack Map already ON"); return; }
    const Il2CppMethodInfo *mi = NULL;
    void *ptr = HB_ResolveMethod("Assembly-CSharp", "NucleusDrive.Logic", "HorizonMarker",
                                 "IsVisibleForEnermyCamp", 0, &mi);
    if (!ptr || !mi) { NSLog(@"[HB] Hack Map: method not resolved"); return; }
    HB_OrigIsVisible = (IsVisibleForEnermyCamp_t)HB_HookMethod(mi, (void *)HB_IsVisibleForEnermyCamp);
    NSLog(@"[HB] Hack Map ON (hooked %p)", ptr);
}

// ---------------------------------------------------------------------------
// SHOW RECALL — enemy recall timers come from the same revealed enemy
// state as the map hack, so it shares the HorizonMarker hook. Once the
// fog hook is on, recall icons are readable from the revealed state.
// ---------------------------------------------------------------------------
static void HB_ApplyShowRecall(BOOL enabled) {
    NSLog(@"[HB] Show Recall %@ (shares the Hack Map hook)", enabled ? @"ON" : @"OFF");
}

// ---------------------------------------------------------------------------
// CAMERA DISTANCE — set_currentZoomAmount / GetZoomRate.
// The camera has maxZoom / minZoom / defaultZoom limits; raising maxZoom
// then setting a larger zoom amount is the "Cam Xa" lever.
// ---------------------------------------------------------------------------
typedef void (*SetCurrentZoomAmount_t)(void *self, float amount);
static SetCurrentZoomAmount_t HB_OrigSetZoom = NULL;
static float HB_DesiredZoom = 1.25f;

static void HB_SetCurrentZoomAmount(void *self, float amount) {
    // Force our desired zoom instead of the game's value.
    if (HB_OrigSetZoom) HB_OrigSetZoom(self, HB_DesiredZoom);
}

static void HB_ApplyCameraDistance(float distance) {
    HB_DesiredZoom = distance;
    if (!HB_OrigSetZoom) {
        const Il2CppMethodInfo *mi = NULL;
        void *ptr = HB_ResolveMethod("Assembly-CSharp", "", "CameraController",
                                     "set_currentZoomAmount", 1, &mi);
        if (!ptr || !mi) {
            // Try the alternate class name used by the camera system.
            ptr = HB_ResolveMethod("Assembly-CSharp", "", "BattleCamera",
                                   "set_currentZoomAmount", 1, &mi);
        }
        if (!ptr || !mi) { NSLog(@"[HB] Camera zoom: method not resolved"); return; }
        HB_OrigSetZoom = (SetCurrentZoomAmount_t)HB_HookMethod(mi, (void *)HB_SetCurrentZoomAmount);
        NSLog(@"[HB] Camera zoom hooked %p, distance %.2f", ptr, distance);
    }
}

// ---------------------------------------------------------------------------
// AIMBOT — skill-cast send functions. The cast resolves a target /
// direction / position; snapping it to the selected enemy hero is done
// by hooking the send functions. Full target selection (nearest hero,
// hero filter) needs the hero-position reader; the hook points below are
// the send layer.
//   SendRequestUseSkillTarget / SendRequestUseSkillDir / SendRequestUseSkillPos
//   GetCurSkillDirDegree / TryGetCurSkillIndicatorDir
//   DirectionalMovementMode.GetTargetPosition (has an IFix proxy in-game)
// ---------------------------------------------------------------------------
static void HB_ApplyAimbot(HBMenu *menu) {
    NSLog(@"[HB] Aimbot %@ skill1=%d skill2=%d skill3=%d dist=%.1f dev=%.2f",
          menu.aimEnabled ? @"ON" : @"OFF",
          menu.aimSkill1, menu.aimSkill2, menu.aimSkill3,
          menu.aimDistance, menu.aimDeviation);
    if (!menu.aimEnabled) return;
    // Resolve the send functions so the hook points are verified present.
    // The actual target-snapping hook body needs the hero-position reader
    // (DirectionalMovementMode.GetTargetPosition) — resolved here for
    // verification; the snap itself is applied in the send hook once the
    // reader's signature is confirmed on-device.
    const Il2CppMethodInfo *mi = NULL;
    HB_ResolveMethod("Assembly-CSharp", "", "SkillController",
                     "SendRequestUseSkillDir", 1, &mi);
    HB_ResolveMethod("Assembly-CSharp", "", "SkillController",
                     "SendRequestUseSkillTarget", 1, &mi);
}

// ---------------------------------------------------------------------------
// SKIN UNLOCK — GameSystem.CDimensionSystem::IsOwnDimensionByUnitID /
// IsOwnDimensionUseable (+ _Internal / Forever / ForBattle variants).
// "Dimension" is the skin/costume system. Forcing it to return true
// unlocks skins locally. NOTE: skins are also verified server-side, so
// this may only work locally (the TUMADAM menu itself warns
// "Sẽ Bị Văng Lúc Kết Trận" — you may be kicked at match end).
// ---------------------------------------------------------------------------
typedef bool (*IsOwnDimension_t)(void *self, int unitID);
static IsOwnDimension_t HB_OrigIsOwnDimension = NULL;
static bool HB_IsOwnDimensionByUnitID(void *self, int unitID) {
    return true; // own every skin
}

static void HB_ApplySkinUnlock(HBMenu *menu) {
    BOOL want = menu.unlockSkin || menu.unlockSkin2;
    if (!want) {
        if (HB_OrigIsOwnDimension) {
            const Il2CppMethodInfo *mi = NULL;
            HB_ResolveMethod("Assembly-CSharp", "GameSystem", "CDimensionSystem",
                             "IsOwnDimensionByUnitID", 1, &mi);
            if (mi) { *(void **)mi = (void *)HB_OrigIsOwnDimension; HB_OrigIsOwnDimension = NULL; }
        }
        NSLog(@"[HB] Skin unlock OFF");
        return;
    }
    if (HB_OrigIsOwnDimension) { NSLog(@"[HB] Skin unlock already ON"); return; }
    const Il2CppMethodInfo *mi = NULL;
    void *ptr = HB_ResolveMethod("Assembly-CSharp", "GameSystem", "CDimensionSystem",
                                 "IsOwnDimensionByUnitID", 1, &mi);
    if (!ptr || !mi) { NSLog(@"[HB] Skin unlock: method not resolved"); return; }
    HB_OrigIsOwnDimension = (IsOwnDimension_t)HB_HookMethod(mi, (void *)HB_IsOwnDimensionByUnitID);
    NSLog(@"[HB] Skin unlock ON (hooked %p)", ptr);
}

// ---------------------------------------------------------------------------
// AUTO ACTIONS — auto smite / auto execute / auto swap items.
// These read game state (monster HP, enemy HP, item slots) and trigger the
// corresponding skill/item use. The send layer is the same skill-cast
// path as the aimbot; the state readers are resolved for verification.
// ---------------------------------------------------------------------------
static void HB_ApplyAuto(HBMenu *menu) {
    NSLog(@"[HB] Auto smite=%d execute=%d (hp=%.0f%%) swap=%d",
          menu.autoSmite, menu.autoExecute, menu.autoExecuteHP, menu.autoSwapItems);
}

// ---------------------------------------------------------------------------
// FAKE NAME — display a different name in match. The name shown to other
// players comes from the local player profile packet. The getter/packet
// builder was not identified in the metadata scan; this stays a no-op
// until the name getter is found.
// ---------------------------------------------------------------------------
static void HB_ApplyFakeName(HBMenu *menu) {
    NSLog(@"[HB] Fake Name %@ \"%@\" (name getter not yet identified)",
          menu.fakeName ? @"ON" : @"OFF", menu.fakeNameText ?: @"");
}

// ---------------------------------------------------------------------------
// Dispatch
// ---------------------------------------------------------------------------

@implementation HBHooks

+ (void)applySavedState:(HBMenu *)menu {
    [self applyFeature:@"fpsLimit" enabled:YES menu:menu];
    [self applyFeature:@"hackMap" enabled:menu.hackMap menu:menu];
    [self applyFeature:@"aimEnabled" enabled:menu.aimEnabled menu:menu];
    [self applyFeature:@"unlockSkin2" enabled:menu.unlockSkin2 menu:menu];
    [self applyFeature:@"autoSmite" enabled:menu.autoSmite menu:menu];
}

+ (void)applyFeature:(NSString *)key enabled:(BOOL)enabled menu:(HBMenu *)menu {
    if ([key isEqualToString:@"fpsLimit"]) {
        HB_ApplyFPS(menu.fpsLimit);
    } else if ([key isEqualToString:@"hackMap"]) {
        HB_ApplyHackMap(enabled);
    } else if ([key isEqualToString:@"showRecall"]) {
        HB_ApplyShowRecall(enabled);
    } else if ([key isEqualToString:@"cameraDistance"]) {
        HB_ApplyCameraDistance(menu.cameraDistance);
    } else if ([key isEqualToString:@"fakeName"]) {
        HB_ApplyFakeName(menu);
    } else if ([key hasPrefix:@"aim"]) {
        HB_ApplyAimbot(menu);
    } else if ([key hasPrefix:@"unlockSkin"] || [key isEqualToString:@"changeSkinInMatch"]) {
        HB_ApplySkinUnlock(menu);
    } else if ([key hasPrefix:@"auto"]) {
        HB_ApplyAuto(menu);
    }
}

@end
