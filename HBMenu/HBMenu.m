// HBMenu.m — HB mod menu UI (custom design, NOT a TUMADAM clone)
//
// Design v2 (landscape, 2026-11-09):
//  - WIDE landscape card, two columns — no sidebar tabs, no tall vertical list.
//  - Dark navy card (#10111C), cyan accent (#00D4FF), rounded corners.
//  - Header: "HB" badge + "HB Cheat" + version, HIDE HACK pill, FPS pills
//    (30/60/90/120), close button.
//  - Left column: BẢN ĐỒ + NGẮM (AIMBOT). Right column: SKIN + TỰ ĐỘNG
//    + HIỆU NĂNG. Every row has an SF Symbol icon.
//  - Floating "HB" button (draggable circle) — tap to open menu.
//  - Two-finger tap anywhere on screen toggles the menu.
//
// The feature switches call into HBHooks to apply / remove each cheat.
// Hook bodies live in HBHooks.m; addresses that still need RE are marked
// HB_TODO and safely no-op until filled in.

#import "HBMenu.h"
#import "HBHooks.h"

static NSString *const kHBDefaultsPrefix = @"HB_";

// Colors
static UIColor *HBColorBackground(void) { return [UIColor colorWithRed:0x12/255.0 green:0x12/255.0 blue:0x1F/255.0 alpha:0.96]; }
static UIColor *HBColorCard(void)       { return [UIColor colorWithRed:0x1E/255.0 green:0x1E/255.0 blue:0x2E/255.0 alpha:1.0]; }
static UIColor *HBColorAccent(void)     { return [UIColor colorWithRed:0x00/255.0 green:0xD4/255.0 blue:0xFF/255.0 alpha:1.0]; }
static UIColor *HBColorText(void)       { return [UIColor whiteColor]; }
static UIColor *HBColorSubtext(void)    { return [UIColor colorWithWhite:0.65 alpha:1.0]; }

@interface HBMenu ()
@property (nonatomic, strong) UIWindow *menuWindow;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIButton *floatButton;
@property (nonatomic, strong) UIWindow *floatWindow;
@property (nonatomic, assign) BOOL menuVisible;
@end

@implementation HBMenu

+ (instancetype)shared {
    static HBMenu *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[HBMenu alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) { [self loadDefaults]; }
    return self;
}

#pragma mark - Defaults

- (void)loadDefaults {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    _hackMap        = [d boolForKey:@"HB_hackMap"];
    _showRecall     = [d boolForKey:@"HB_showRecall"];
    _cameraDistance = [d floatForKey:@"HB_cameraDistance"]; if (_cameraDistance == 0) _cameraDistance = 1.25f;
    _fakeName       = [d boolForKey:@"HB_fakeName"];
    _fakeNameText   = [d stringForKey:@"HB_fakeNameText"] ?: @"";
    _aimEnabled     = [d boolForKey:@"HB_aimEnabled"];
    _aimSkill1      = [d boolForKey:@"HB_aimSkill1"]; if (![d objectForKey:@"HB_aimSkill1"]) _aimSkill1 = YES;
    _aimSkill2      = [d boolForKey:@"HB_aimSkill2"]; if (![d objectForKey:@"HB_aimSkill2"]) _aimSkill2 = YES;
    _aimSkill3      = [d boolForKey:@"HB_aimSkill3"];
    _aimDistance    = [d floatForKey:@"HB_aimDistance"]; if (_aimDistance == 0) _aimDistance = 14.0f;
    _aimDeviation   = [d floatForKey:@"HB_aimDeviation"]; if (_aimDeviation == 0) _aimDeviation = 0.95f;
    _unlockSkin     = [d boolForKey:@"HB_unlockSkin"];
    _unlockSkin2    = [d boolForKey:@"HB_unlockSkin2"];
    _changeSkinInMatch = [d boolForKey:@"HB_changeSkinInMatch"];
    _autoSmite      = [d boolForKey:@"HB_autoSmite"]; if (![d objectForKey:@"HB_autoSmite"]) _autoSmite = YES;
    _autoSmiteBuff  = [d boolForKey:@"HB_autoSmiteBuff"]; if (![d objectForKey:@"HB_autoSmiteBuff"]) _autoSmiteBuff = YES;
    _autoSmiteDragon= [d boolForKey:@"HB_autoSmiteDragon"]; if (![d objectForKey:@"HB_autoSmiteDragon"]) _autoSmiteDragon = YES;
    _autoExecute    = [d boolForKey:@"HB_autoExecute"];
    _autoExecuteHP  = [d floatForKey:@"HB_autoExecuteHP"]; if (_autoExecuteHP == 0) _autoExecuteHP = 13.0f;
    _autoSwapItems  = [d boolForKey:@"HB_autoSwapItems"]; if (![d objectForKey:@"HB_autoSwapItems"]) _autoSwapItems = YES;
    _fpsLimit       = [d integerForKey:@"HB_fpsLimit"]; if (_fpsLimit == 0) _fpsLimit = 60;
}

- (void)saveDefaults {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:_hackMap forKey:@"HB_hackMap"];
    [d setBool:_showRecall forKey:@"HB_showRecall"];
    [d setFloat:_cameraDistance forKey:@"HB_cameraDistance"];
    [d setBool:_fakeName forKey:@"HB_fakeName"];
    [d setObject:_fakeNameText forKey:@"HB_fakeNameText"];
    [d setBool:_aimEnabled forKey:@"HB_aimEnabled"];
    [d setBool:_aimSkill1 forKey:@"HB_aimSkill1"];
    [d setBool:_aimSkill2 forKey:@"HB_aimSkill2"];
    [d setBool:_aimSkill3 forKey:@"HB_aimSkill3"];
    [d setFloat:_aimDistance forKey:@"HB_aimDistance"];
    [d setFloat:_aimDeviation forKey:@"HB_aimDeviation"];
    [d setBool:_unlockSkin forKey:@"HB_unlockSkin"];
    [d setBool:_unlockSkin2 forKey:@"HB_unlockSkin2"];
    [d setBool:_changeSkinInMatch forKey:@"HB_changeSkinInMatch"];
    [d setBool:_autoSmite forKey:@"HB_autoSmite"];
    [d setBool:_autoSmiteBuff forKey:@"HB_autoSmiteBuff"];
    [d setBool:_autoSmiteDragon forKey:@"HB_autoSmiteDragon"];
    [d setBool:_autoExecute forKey:@"HB_autoExecute"];
    [d setFloat:_autoExecuteHP forKey:@"HB_autoExecuteHP"];
    [d setBool:_autoSwapItems forKey:@"HB_autoSwapItems"];
    [d setInteger:_fpsLimit forKey:@"HB_fpsLimit"];
    [d synchronize];
}

#pragma mark - Install (called from constructor)

- (void)install {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupFloatButton];
        [self setupTwoFingerTap];
        [HBHooks applySavedState:self];
    });
}

// Two-finger tap anywhere toggles the menu.
- (void)setupTwoFingerTap {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleTwoFingerTap:)];
    tap.numberOfTouchesRequired = 2;
    tap.numberOfTapsRequired = 1;
    tap.cancelsTouchesInView = NO;
    [keyWindow addGestureRecognizer:tap];
}

- (void)handleTwoFingerTap:(UITapGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateRecognized) {
        [self toggleMenu];
    }
}

#pragma mark - Floating HB button

- (void)setupFloatButton {
    self.floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 120, 52, 52)];
    self.floatWindow.windowLevel = UIWindowLevelAlert + 1;
    self.floatWindow.backgroundColor = [UIColor clearColor];
    self.floatWindow.hidden = NO;

    self.floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatButton.frame = CGRectMake(0, 0, 52, 52);
    self.floatButton.layer.cornerRadius = 26;
    self.floatButton.backgroundColor = HBColorAccent();
    self.floatButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.floatButton.layer.borderWidth = 2;
    self.floatButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.floatButton.layer.shadowOpacity = 0.5;
    self.floatButton.layer.shadowRadius = 6;
    self.floatButton.layer.shadowOffset = CGSizeMake(0, 2);
    [self.floatButton setTitle:@"HB" forState:UIControlStateNormal];
    [self.floatButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.floatButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.floatButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

    // Drag to move
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleFloatDrag:)];
    [self.floatButton addGestureRecognizer:pan];

    [self.floatWindow addSubview:self.floatButton];
}

- (void)handleFloatDrag:(UIPanGestureRecognizer *)pan {
    CGPoint t = [pan translationInView:self.floatWindow];
    CGPoint c = self.floatWindow.center;
    c.x += t.x; c.y += t.y;
    CGSize s = [UIScreen mainScreen].bounds.size;
    c.x = MAX(26, MIN(s.width - 26, c.x));
    c.y = MAX(26, MIN(s.height - 26, c.y));
    self.floatWindow.center = c;
    [pan setTranslation:CGPointZero inView:self.floatWindow];
}

#pragma mark - Menu window

- (void)toggleMenu {
    self.menuVisible ? [self hideMenu] : [self showMenu];
}

- (void)showMenu {
    if (self.menuVisible) return;
    self.menuVisible = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self buildMenuWindow];
        self.menuWindow.hidden = NO;
    });
}

- (void)hideMenu {
    if (!self.menuVisible) return;
    self.menuVisible = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.menuWindow.hidden = YES;
        self.menuWindow = nil;
    });
}

- (void)buildMenuWindow {
    CGSize screen = [UIScreen mainScreen].bounds.size;
    // Wide landscape card (game is played in landscape)
    CGFloat w = MIN(screen.width * 0.88, 1150);
    CGFloat h = MIN(screen.height * 0.90, 720);
    CGFloat x = (screen.width - w) / 2;
    CGFloat y = (screen.height - h) / 2;

    self.menuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.menuWindow.windowLevel = UIWindowLevelAlert + 2;
    self.menuWindow.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];

    // Tap outside the card closes the menu
    UITapGestureRecognizer *outside = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleOutsideTap:)];
    [self.menuWindow addGestureRecognizer:outside];

    // Card
    self.cardView = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, h)];
    self.cardView.backgroundColor = HBColorBackground();
    self.cardView.layer.cornerRadius = 22;
    self.cardView.layer.borderColor = HBColorAccent().CGColor;
    self.cardView.layer.borderWidth = 1.5;
    self.cardView.clipsToBounds = YES;
    [self.menuWindow addSubview:self.cardView];

    // Header
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 72)];
    header.backgroundColor = HBColorCard();
    [self.cardView addSubview:header];

    UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(18, 14, 44, 44)];
    badge.backgroundColor = HBColorAccent();
    badge.textColor = [UIColor blackColor];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.font = [UIFont boldSystemFontOfSize:17];
    badge.text = @"HB";
    badge.layer.cornerRadius = 22;
    badge.clipsToBounds = YES;
    [header addSubview:badge];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(72, 10, 300, 28)];
    title.text = @"HB Cheat";
    title.textColor = HBColorText();
    title.font = [UIFont boldSystemFontOfSize:23];
    [header addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(72, 40, 300, 18)];
    sub.text = @"Arena of Valor  •  v1.0";
    sub.textColor = HBColorSubtext();
    sub.font = [UIFont systemFontOfSize:13];
    [header addSubview:sub];

    // HIDE HACK pill
    UIView *hidePill = [[UIView alloc] initWithFrame:CGRectMake(w - 500, 20, 168, 32)];
    hidePill.backgroundColor = [UIColor colorWithRed:0x26/255.0 green:0x28/255.0 blue:0x3E/255.0 alpha:1.0];
    hidePill.layer.cornerRadius = 16;
    [header addSubview:hidePill];
    UILabel *hideLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, 110, 32)];
    hideLabel.text = @"HIDE HACK:";
    hideLabel.textColor = HBColorText();
    hideLabel.font = [UIFont boldSystemFontOfSize:14];
    [hidePill addSubview:hideLabel];
    UILabel *hideState = [[UILabel alloc] initWithFrame:CGRectMake(122, 0, 40, 32)];
    hideState.text = @"OFF";
    hideState.textColor = HBColorAccent();
    hideState.font = [UIFont boldSystemFontOfSize:14];
    [hidePill addSubview:hideState];

    // FPS pills in header
    UILabel *fpsLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 316, 20, 40, 32)];
    fpsLabel.text = @"FPS";
    fpsLabel.textColor = HBColorSubtext();
    fpsLabel.font = [UIFont boldSystemFontOfSize:14];
    [header addSubview:fpsLabel];
    NSArray *fpsOptions = @[@30, @60, @90, @120];
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(w - 272 + i * 52, 20, 46, 32);
        [b setTitle:[NSString stringWithFormat:@"%@", fpsOptions[i]] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        b.layer.cornerRadius = 16;
        b.tag = [fpsOptions[i] integerValue];
        BOOL selected = (self.fpsLimit == [fpsOptions[i] integerValue]);
        b.backgroundColor = selected ? HBColorAccent() : [UIColor clearColor];
        [b setTitleColor:selected ? [UIColor blackColor] : HBColorText() forState:UIControlStateNormal];
        [b addTarget:self action:@selector(fpsTapped:) forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:b];
    }

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(w - 52, 18, 36, 36);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [closeBtn setTitleColor:HBColorText() forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    // Divider under header
    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(20, 72, w - 40, 1)];
    divider.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    [self.cardView addSubview:divider];

    // Two-column content
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 73, w, h - 73 - 36)];
    [self.cardView addSubview:self.scrollView];

    CGFloat colW = (w - 60 - 24) / 2;
    CGFloat lx = 30;
    CGFloat rx = 30 + colW + 24;

    // LEFT column: BẢN ĐỒ + NGẮM
    CGFloat ly = 12;
    ly = [self addSection:@"BẢN ĐỒ" icon:@"map" toView:self.scrollView atX:lx atY:ly width:colW];
    ly = [self addSwitchRow:@"Hack Map" detail:@"Hiện toàn bộ địch trên bản đồ" icon:@"map" key:@"hackMap" value:self.hackMap toView:self.scrollView atX:lx atY:ly width:colW];
    ly = [self addSwitchRow:@"Hiện Hồi Chiêu" detail:@"Hiện thời gian hồi chiêu của địch" icon:@"eye" key:@"showRecall" value:self.showRecall toView:self.scrollView atX:lx atY:ly width:colW];
    ly = [self addSliderRow:@"Cam Xa" key:@"cameraDistance" value:self.cameraDistance min:1.0 max:2.0 icon:@"camera" toView:self.scrollView atX:lx atY:ly width:colW];
    ly = [self addSwitchRow:@"Fake Name" detail:@"Đổi tên hiển thị trong trận" icon:@"person" key:@"fakeName" value:self.fakeName toView:self.scrollView atX:lx atY:ly width:colW];

    ly = [self addSection:@"NGẮM (AIMBOT)" icon:@"crosshair" toView:self.scrollView atX:lx atY:ly + 6 width:colW];
    ly = [self addSwitchRow:@"Bật AIM" detail:@"Tự ngắm skill vào tướng địch" icon:@"crosshair" key:@"aimEnabled" value:self.aimEnabled toView:self.scrollView atX:lx atY:ly width:colW];
    ly = [self addSwitchRow:@"Aim Skill 1" detail:@"" icon:@"crosshair" key:@"aimSkill1" value:self.aimSkill1 toView:self.scrollView atX:lx atY:ly width:colW];
    ly = [self addSwitchRow:@"Aim Skill 2" detail:@"" icon:@"crosshair" key:@"aimSkill2" value:self.aimSkill2 toView:self.scrollView atX:lx atY:ly width:colW];
    ly = [self addSwitchRow:@"Aim Skill 3" detail:@"" icon:@"crosshair" key:@"aimSkill3" value:self.aimSkill3 toView:self.scrollView atX:lx atY:ly width:colW];
    ly = [self addSliderRow:@"Khoảng cách AIM" key:@"aimDistance" value:self.aimDistance min:5 max:20 icon:@"crosshair" toView:self.scrollView atX:lx atY:ly width:colW];
    ly = [self addSliderRow:@"Độ lệch" key:@"aimDeviation" value:self.aimDeviation min:0 max:1 icon:@"crosshair" toView:self.scrollView atX:lx atY:ly width:colW];

    // RIGHT column: SKIN + TỰ ĐỘNG + HIỆU NĂNG
    CGFloat ry = 12;
    ry = [self addSection:@"SKIN" icon:@"sparkles" toView:self.scrollView atX:rx atY:ry width:colW];
    ry = [self addSwitchRow:@"Unlock Skin" detail:@"Mở toàn bộ skin (bản 1)" icon:@"sparkles" key:@"unlockSkin" value:self.unlockSkin toView:self.scrollView atX:rx atY:ry width:colW];
    ry = [self addSwitchRow:@"Unlock Skin 2" detail:@"Mở full skin, không trận ảo" icon:@"sparkles" key:@"unlockSkin2" value:self.unlockSkin2 toView:self.scrollView atX:rx atY:ry width:colW];
    ry = [self addSwitchRow:@"Đổi skin trong trận" detail:@"Đổi skin ngay khi đang đánh" icon:@"sparkles" key:@"changeSkinInMatch" value:self.changeSkinInMatch toView:self.scrollView atX:rx atY:ry width:colW];

    ry = [self addSection:@"TỰ ĐỘNG" icon:@"arrow.clockwise" toView:self.scrollView atX:rx atY:ry + 6 width:colW];
    ry = [self addSwitchRow:@"Auto Trừng Trị" detail:@"Tự dùng Trừng Trị  •  Bùa  •  Rồng / Tà Thần" icon:@"arrow.clockwise" key:@"autoSmite" value:self.autoSmite toView:self.scrollView atX:rx atY:ry width:colW];
    ry = [self addSwitchRow:@"Auto Bộc Phá" detail:@"Tự dùng khi máu địch thấp" icon:@"bolt" key:@"autoExecute" value:self.autoExecute toView:self.scrollView atX:rx atY:ry width:colW];
    ry = [self addSliderRow:@"Máu địch để Bộc Phá" key:@"autoExecuteHP" value:self.autoExecuteHP min:5 max:30 icon:@"bolt" toView:self.scrollView atX:rx atY:ry width:colW];
    ry = [self addSwitchRow:@"Auto đổi đồ" detail:@"Tự đổi trang bị theo tình huống" icon:@"arrow.clockwise" key:@"autoSwapItems" value:self.autoSwapItems toView:self.scrollView atX:rx atY:ry width:colW];

    ry = [self addSection:@"HIỆU NĂNG" icon:@"bolt" toView:self.scrollView atX:rx atY:ry + 6 width:colW];
    ry = [self addFPSRowToView:self.scrollView atX:rx atY:ry width:colW];

    CGFloat contentH = MAX(ly, ry) + 16;
    self.scrollView.contentSize = CGSizeMake(w, contentH);

    // Footer hint
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(0, h - 34, w, 20)];
    hint.text = @"Gõ 2 ngón tay để ẩn / hiện menu   •   Bấm nút HB để mở menu";
    hint.textColor = HBColorSubtext();
    hint.font = [UIFont systemFontOfSize:13];
    hint.textAlignment = NSTextAlignmentCenter;
    [self.cardView addSubview:hint];
}

- (void)handleOutsideTap:(UITapGestureRecognizer *)g {
    CGPoint p = [g locationInView:self.menuWindow];
    if (!CGRectContainsPoint(self.cardView.frame, p)) {
        [self hideMenu];
    }
}

#pragma mark - Row builders

// SF Symbol icon in a small rounded chip.
- (UIImageView *)iconView:(NSString *)symbolName frame:(CGRect)frame {
    UIImage *img = [UIImage systemImageNamed:symbolName];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:frame];
    iv.image = img;
    iv.tintColor = HBColorAccent();
    iv.contentMode = UIViewContentModeScaleAspectFit;
    return iv;
}

- (CGFloat)addSection:(NSString *)title icon:(NSString *)icon toView:(UIView *)parent atX:(CGFloat)x atY:(CGFloat)y width:(CGFloat)w {
    UIView *chip = [[UIView alloc] initWithFrame:CGRectMake(x, y + 2, 30, 30)];
    chip.backgroundColor = [UIColor colorWithRed:0x26/255.0 green:0x28/255.0 blue:0x3E/255.0 alpha:1.0];
    chip.layer.cornerRadius = 9;
    [parent addSubview:chip];
    [chip addSubview:[self iconView:icon frame:CGRectMake(4, 4, 22, 22)]];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(x + 40, y + 4, w - 40, 22)];
    label.text = title;
    label.textColor = HBColorAccent();
    label.font = [UIFont boldSystemFontOfSize:16];
    [parent addSubview:label];

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(x, y + 42, w, 1)];
    line.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    [parent addSubview:line];
    return y + 54;
}

- (CGFloat)addSwitchRow:(NSString *)title detail:(NSString *)detail icon:(NSString *)icon key:(NSString *)key value:(BOOL)value toView:(UIView *)parent atX:(CGFloat)x atY:(CGFloat)y width:(CGFloat)w {
    CGFloat rowH = detail.length ? 66 : 54;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, rowH)];
    row.backgroundColor = HBColorCard();
    row.layer.cornerRadius = 14;
    [parent addSubview:row];

    UIView *chip = [[UIView alloc] initWithFrame:CGRectMake(12, (rowH - 40) / 2, 40, 40)];
    chip.backgroundColor = [UIColor colorWithRed:0x26/255.0 green:0x28/255.0 blue:0x3E/255.0 alpha:1.0];
    chip.layer.cornerRadius = 11;
    [row addSubview:chip];
    [chip addSubview:[self iconView:icon frame:CGRectMake(6, 6, 28, 28)]];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(64, 9, w - 64 - 80, 22)];
    label.text = title;
    label.textColor = HBColorText();
    label.font = [UIFont systemFontOfSize:18];
    [row addSubview:label];

    if (detail.length) {
        UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(64, 35, w - 64 - 80, 18)];
        sub.text = detail;
        sub.textColor = HBColorSubtext();
        sub.font = [UIFont systemFontOfSize:13];
        [row addSubview:sub];
    }

    UISwitch *sw = [[UISwitch alloc] init];
    sw.frame = CGRectMake(w - 64 - 14, (rowH - 31) / 2, 51, 31);
    sw.on = value;
    sw.onTintColor = HBColorAccent();
    sw.accessibilityIdentifier = key;
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];

    return y + rowH + 10;
}

- (CGFloat)addSliderRow:(NSString *)title key:(NSString *)key value:(float)value min:(float)min max:(float)max icon:(NSString *)icon toView:(UIView *)parent atX:(CGFloat)x atY:(CGFloat)y width:(CGFloat)w {
    CGFloat rowH = 76;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, rowH)];
    row.backgroundColor = HBColorCard();
    row.layer.cornerRadius = 14;
    [parent addSubview:row];

    UIView *chip = [[UIView alloc] initWithFrame:CGRectMake(12, 12, 40, 40)];
    chip.backgroundColor = [UIColor colorWithRed:0x26/255.0 green:0x28/255.0 blue:0x3E/255.0 alpha:1.0];
    chip.layer.cornerRadius = 11;
    [row addSubview:chip];
    [chip addSubview:[self iconView:icon frame:CGRectMake(6, 6, 28, 28)]];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(64, 10, w - 64 - 90, 22)];
    label.text = title;
    label.textColor = HBColorText();
    label.font = [UIFont systemFontOfSize:18];
    [row addSubview:label];

    UILabel *val = [[UILabel alloc] initWithFrame:CGRectMake(w - 90, 10, 74, 22)];
    val.textAlignment = NSTextAlignmentRight;
    val.textColor = HBColorAccent();
    val.font = [UIFont boldSystemFontOfSize:17];
    val.text = [NSString stringWithFormat:@"%.2f", value];
    val.tag = 1001;
    [row addSubview:val];

    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(64, 42, w - 64 - 16, 24)];
    sl.minimumValue = min;
    sl.maximumValue = max;
    sl.value = value;
    sl.minimumTrackTintColor = HBColorAccent();
    sl.accessibilityIdentifier = key;
    [sl addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:sl];

    return y + rowH + 10;
}

- (CGFloat)addFPSRowToView:(UIView *)parent atX:(CGFloat)x atY:(CGFloat)y width:(CGFloat)w {
    CGFloat rowH = 62;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, rowH)];
    row.backgroundColor = HBColorCard();
    row.layer.cornerRadius = 14;
    [parent addSubview:row];

    UIView *chip = [[UIView alloc] initWithFrame:CGRectMake(12, 11, 40, 40)];
    chip.backgroundColor = [UIColor colorWithRed:0x26/255.0 green:0x28/255.0 blue:0x3E/255.0 alpha:1.0];
    chip.layer.cornerRadius = 11;
    [row addSubview:chip];
    [chip addSubview:[self iconView:@"bolt" frame:CGRectMake(6, 6, 28, 28)]];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(64, 19, 60, 22)];
    label.text = @"FPS";
    label.textColor = HBColorText();
    label.font = [UIFont systemFontOfSize:18];
    [row addSubview:label];

    NSArray *options = @[@30, @60, @90, @120];
    CGFloat bw = 74, gap = 10;
    CGFloat sx = x + w - 14 - 4 * bw - 3 * gap;
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(sx + i * (bw + gap), y + 13, bw, 36);
        [b setTitle:[NSString stringWithFormat:@"%@", options[i]] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        b.layer.cornerRadius = 10;
        b.tag = [options[i] integerValue];
        BOOL selected = (self.fpsLimit == [options[i] integerValue]);
        b.backgroundColor = selected ? HBColorAccent() : [UIColor clearColor];
        [b setTitleColor:selected ? [UIColor blackColor] : HBColorText() forState:UIControlStateNormal];
        [b addTarget:self action:@selector(fpsTapped:) forControlEvents:UIControlEventTouchUpInside];
        [parent addSubview:b];
    }
    return y + rowH + 10;
}

#pragma mark - Events

- (void)switchChanged:(UISwitch *)sw {
    NSString *key = sw.accessibilityIdentifier;
    BOOL on = sw.isOn;
    [self setValue:@(on) forKey:key];
    [self saveDefaults];
    [HBHooks applyFeature:key enabled:on menu:self];
}

- (void)sliderChanged:(UISlider *)sl {
    NSString *key = sl.accessibilityIdentifier;
    float v = sl.value;
    [self setValue:@(v) forKey:key];
    UIView *row = sl.superview;
    UILabel *val = (UILabel *)[row viewWithTag:1001];
    if (val) val.text = [NSString stringWithFormat:@"%.2f", v];
    [self saveDefaults];
    [HBHooks applyFeature:key enabled:YES menu:self];
}

- (void)fpsTapped:(UIButton *)b {
    self.fpsLimit = b.tag;
    [self saveDefaults];
    [HBHooks applyFeature:@"fpsLimit" enabled:YES menu:self];
    // Refresh the menu to update button colors
    [self hideMenu];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self showMenu];
    });
}

@end

// Constructor — runs when the dylib is loaded.
__attribute__((constructor))
static void HBMenuInit(void) {
    // Wait for the app to finish launching before touching UIKit.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[HBMenu shared] install];
    });
}
