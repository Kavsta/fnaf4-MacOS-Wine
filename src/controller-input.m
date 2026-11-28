/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * you can obtain one at https://mozilla.org/MPL/2.0/.
 */

#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <GameController/GameController.h>
#include <math.h>
#include <stdlib.h>

typedef NS_ENUM(NSInteger, FNAFControllerMode) {
    FNAFControllerModeOff = 0,
    FNAFControllerModeStickA,
    FNAFControllerModeStickRepeat,
    FNAFControllerModeDPad,
};

typedef NS_ENUM(NSInteger, FNAFDirection) {
    FNAFDirectionNone = 0,
    FNAFDirectionLeft = -1,
    FNAFDirectionRight = 1,
    FNAFDirectionUp = 2,
    FNAFDirectionDown = -2,
};

static BOOL isFNAF4Window(NSWindow *window)
{
    return [window.title hasPrefix:@"Five Nights at Freddy"];
}

static NSWindow *activeFNAF4Window(void)
{
    NSWindow *window = NSApp.keyWindow;
    return isFNAF4Window(window) ? window : nil;
}

static NSRect gameContentRectOnScreen(NSWindow *window)
{
    NSView *contentView = window.contentView;
    if (!contentView) return NSZeroRect;
    NSRect contentRect = [contentView convertRect:contentView.bounds toView:nil];
    return [window convertRectToScreen:contentRect];
}

static NSScreen *primaryScreen(void)
{
    return NSScreen.screens.firstObject;
}

static CGPoint quartzPointFromCocoa(NSPoint point)
{
    NSScreen *screen = primaryScreen();
    CGFloat top = screen ? NSMaxY(screen.frame) : 0;
    return CGPointMake(point.x, top - point.y);
}

static void postMouseEvent(CGEventType type, NSPoint point)
{
    CGEventRef event = CGEventCreateMouseEvent(NULL, type, quartzPointFromCocoa(point), kCGMouseButtonLeft);
    if (!event) return;
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
}

static NSPoint clampedPointerPoint(NSWindow *window, NSPoint point)
{
    NSRect bounds = NSInsetRect(gameContentRectOnScreen(window), 1, 1);
    if (NSIsEmptyRect(bounds)) return point;
    if (!NSPointInRect(point, bounds)) point = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
    point.x = fmax(NSMinX(bounds), fmin(NSMaxX(bounds), point.x));
    point.y = fmax(NSMinY(bounds), fmin(NSMaxY(bounds), point.y));
    return point;
}

static void movePointerBy(NSWindow *window, CGFloat dx, CGFloat dy)
{
    NSPoint point = clampedPointerPoint(window, NSEvent.mouseLocation);
    NSRect bounds = NSInsetRect(gameContentRectOnScreen(window), 1, 1);
    if (NSIsEmptyRect(bounds)) return;
    point.x = fmax(NSMinX(bounds), fmin(NSMaxX(bounds), point.x + dx));
    point.y = fmax(NSMinY(bounds), fmin(NSMaxY(bounds), point.y + dy));
    postMouseEvent(kCGEventMouseMoved, point);
}

static NSPoint pointForDirection(NSWindow *window, FNAFDirection direction)
{
    NSRect bounds = gameContentRectOnScreen(window);
    switch (direction) {
        case FNAFDirectionLeft:  return NSMakePoint(NSMinX(bounds) + NSWidth(bounds) * 0.08, NSMidY(bounds));
        case FNAFDirectionRight: return NSMakePoint(NSMinX(bounds) + NSWidth(bounds) * 0.92, NSMidY(bounds));
        case FNAFDirectionUp:    return NSMakePoint(NSMidX(bounds), NSMinY(bounds) + NSHeight(bounds) * 0.58);
        case FNAFDirectionDown:  return NSMakePoint(NSMidX(bounds), NSMinY(bounds) + NSHeight(bounds) * 0.08);
        default:                 return NSMakePoint(NSMidX(bounds), NSMidY(bounds));
    }
}

static void postClickAtPointer(NSWindow *window)
{
    NSPoint point = clampedPointerPoint(window, NSEvent.mouseLocation);
    postMouseEvent(kCGEventLeftMouseDown, point);
    postMouseEvent(kCGEventLeftMouseUp, point);
}

static FNAFDirection directionForAxes(float x, float y, float deadZone)
{
    if (fabsf(x) < deadZone && fabsf(y) < deadZone) return FNAFDirectionNone;
    if (fabsf(x) >= fabsf(y)) return x < 0 ? FNAFDirectionLeft : FNAFDirectionRight;
    return y > 0 ? FNAFDirectionUp : FNAFDirectionDown;
}

static NSString *controllerPreferencePath(void)
{
    const char *configuredPath = getenv("FNAF4_CONTROLLER_PREFS");
    if (configuredPath && *configuredPath) return @(configuredPath);
    return [NSHomeDirectory() stringByAppendingPathComponent:
            @"Library/Application Support/FNAF4-Wine/controller-mode"];
}

static FNAFControllerMode readControllerMode(void)
{
    NSString *path = controllerPreferencePath();
    NSString *value = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    if ([value isEqualToString:@"off"]) return FNAFControllerModeOff;
    if ([value isEqualToString:@"stick-repeat"]) return FNAFControllerModeStickRepeat;
    if ([value isEqualToString:@"dpad"]) return FNAFControllerModeDPad;
    return FNAFControllerModeStickA;
}

static void writeControllerMode(FNAFControllerMode mode)
{
    NSString *value = @"stick-a";
    switch (mode) {
        case FNAFControllerModeOff: value = @"off"; break;
        case FNAFControllerModeStickRepeat: value = @"stick-repeat"; break;
        case FNAFControllerModeDPad: value = @"dpad"; break;
        case FNAFControllerModeStickA: break;
    }
    NSString *path = controllerPreferencePath();
    NSString *directory = path.stringByDeletingLastPathComponent;
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    [value writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

@interface FNAFControllerSupport : NSObject <NSMenuDelegate>
@property (nonatomic) FNAFControllerMode mode;
@property (nonatomic, weak) GCController *connectedController;
@property (nonatomic, strong) NSMenuItem *topLevelMenu;
@property (nonatomic, strong) NSArray<NSMenuItem *> *modeItems;
@property (nonatomic) BOOL stickActive;
@property (nonatomic) BOOL consumeStickPush;
@property (nonatomic) FNAFDirection pendingStickDirection;
@property (nonatomic) BOOL dpadActive;
@property (nonatomic) FNAFDirection pendingDpadDirection;
@property (nonatomic) BOOL buttonAWasPressed;
@property (nonatomic) BOOL flashlightDown;
@property (nonatomic) BOOL doorDown;
@property (nonatomic) CFAbsoluteTime lastUpdate;
- (void)update;
- (void)selectMode:(NSMenuItem *)sender;
- (void)syncMenu;
- (void)setVirtualKey:(CGKeyCode)key down:(BOOL)down held:(BOOL *)held;
- (void)releaseHeldInputs;
- (void)installMenuIfNeeded;
@end

@implementation FNAFControllerSupport
- (void)setMode:(FNAFControllerMode)mode
{
    if (_mode == mode) return;
    _mode = mode;
    self.stickActive = NO;
    self.consumeStickPush = NO;
    self.pendingStickDirection = FNAFDirectionNone;
    self.dpadActive = NO;
    self.pendingDpadDirection = FNAFDirectionNone;
    [self setVirtualKey:0x3B down:NO held:&_flashlightDown];
    [self setVirtualKey:0x38 down:NO held:&_doorDown];
    [self syncMenu];
}

- (void)setVirtualKey:(CGKeyCode)key down:(BOOL)down held:(BOOL *)held
{
    if (*held == down) return;
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, key, down);
    if (event) {
        CGEventPost(kCGHIDEventTap, event);
        CFRelease(event);
    }
    *held = down;
}

- (void)releaseHeldInputs
{
    [self setVirtualKey:0x3B down:NO held:&_flashlightDown];
    [self setVirtualKey:0x38 down:NO held:&_doorDown];
    self.buttonAWasPressed = NO;
    self.stickActive = NO;
    self.consumeStickPush = NO;
    self.pendingStickDirection = FNAFDirectionNone;
    self.dpadActive = NO;
    self.pendingDpadDirection = FNAFDirectionNone;
}

- (void)syncMenu
{
    for (NSMenuItem *item in self.modeItems) {
        item.state = item.tag == self.mode ? NSControlStateValueOn : NSControlStateValueOff;
    }
}

- (void)installMenuIfNeeded
{
    if (!NSApp.mainMenu) return;
    if (!self.topLevelMenu) {
        self.topLevelMenu = [[NSMenuItem alloc] initWithTitle:@"Controller" action:NULL keyEquivalent:@""];
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Controller"];
        menu.delegate = self;
        NSArray<NSString *> *titles = @[
            @"Off",
            @"Left Stick: Pan, A / Cross to Enter",
            @"Left Stick: Push Again to Enter",
            @"D-Pad: Tap to Aim, Tap Again to Enter",
        ];
        NSMutableArray<NSMenuItem *> *items = [NSMutableArray arrayWithCapacity:titles.count];
        for (NSUInteger index = 0; index < titles.count; index++) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:titles[index]
                                                         action:@selector(selectMode:)
                                                  keyEquivalent:@""];
            item.target = self;
            item.tag = (NSInteger)index;
            [menu addItem:item];
            [items addObject:item];
        }
        [menu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *note = [[NSMenuItem alloc]
            initWithTitle:@"A/Cross: click  •  B/Circle: flashlight  •  X/Square: door"
            action:NULL keyEquivalent:@""];
        note.enabled = NO;
        [menu addItem:note];
        self.modeItems = items;
        self.topLevelMenu.submenu = menu;
        [self syncMenu];
    }
    if ([NSApp.mainMenu indexOfItem:self.topLevelMenu] < 0) [NSApp.mainMenu addItem:self.topLevelMenu];
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    if (menu == self.topLevelMenu.submenu) [self syncMenu];
}

- (void)selectMode:(NSMenuItem *)sender
{
    self.mode = (FNAFControllerMode)sender.tag;
    writeControllerMode(self.mode);
}

- (void)clickAtCurrentPointerInWindow:(NSWindow *)window
{
    postClickAtPointer(window);
}

- (void)processStickX:(float)x y:(float)y delta:(CFTimeInterval)delta window:(NSWindow *)window
{
    FNAFDirection direction = directionForAxes(x, y, 0.22f);
    if (direction == FNAFDirectionNone) {
        self.stickActive = NO;
        self.consumeStickPush = NO;
        return;
    }

    if (!self.stickActive) {
        if (self.mode == FNAFControllerModeStickRepeat && self.pendingStickDirection == direction) {
            [self clickAtCurrentPointerInWindow:window];
            self.pendingStickDirection = FNAFDirectionNone;
            self.consumeStickPush = YES;
        } else {
            self.pendingStickDirection = direction;
            self.consumeStickPush = NO;
        }
    }
    self.stickActive = YES;
    if (!self.consumeStickPush) {
        const CGFloat speed = 900.0;
        movePointerBy(window, x * speed * delta, y * speed * delta);
    }
}

- (void)processDPadX:(float)x y:(float)y window:(NSWindow *)window
{
    FNAFDirection direction = directionForAxes(x, y, 0.50f);
    if (direction == FNAFDirectionNone) {
        self.dpadActive = NO;
        return;
    }
    if (self.dpadActive) return;

    if (self.pendingDpadDirection == direction) {
        [self clickAtCurrentPointerInWindow:window];
        self.pendingDpadDirection = FNAFDirectionNone;
    } else {
        postMouseEvent(kCGEventMouseMoved, clampedPointerPoint(window, pointForDirection(window, direction)));
        self.pendingDpadDirection = direction;
    }
    self.dpadActive = YES;
}

- (void)update
{
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFTimeInterval delta = self.lastUpdate > 0 ? MIN(now - self.lastUpdate, 0.05) : (1.0 / 60.0);
    self.lastUpdate = now;

    NSWindow *window = activeFNAF4Window();
    if (!NSApp.active || !window || self.mode == FNAFControllerModeOff) {
        [self releaseHeldInputs];
        return;
    }

    GCController *controller = GCController.controllers.firstObject;
    if (controller != self.connectedController) {
        [self releaseHeldInputs];
        self.connectedController = controller;
    }
    if (!controller) return;

    GCExtendedGamepad *extended = controller.extendedGamepad;
    GCMicroGamepad *micro = controller.microGamepad;
    GCControllerDirectionPad *dpad = extended ? extended.dpad : micro.dpad;
    GCControllerButtonInput *buttonA = extended ? extended.buttonA : micro.buttonA;
    GCControllerButtonInput *buttonB = extended ? extended.buttonB : nil;
    GCControllerButtonInput *buttonX = extended ? extended.buttonX : micro.buttonX;
    if (!dpad || !buttonA) return;
    float stickX = extended ? extended.leftThumbstick.xAxis.value : 0;
    float stickY = extended ? extended.leftThumbstick.yAxis.value : 0;
    float dpadX = dpad.xAxis.value;
    float dpadY = dpad.yAxis.value;

    if (self.mode == FNAFControllerModeStickA || self.mode == FNAFControllerModeStickRepeat) {
        [self processStickX:stickX y:stickY delta:delta window:window];
        self.dpadActive = NO;
    } else if (self.mode == FNAFControllerModeDPad) {
        [self processDPadX:dpadX y:dpadY window:window];
        self.stickActive = NO;
    }

    BOOL buttonAPressed = buttonA.isPressed;
    if (buttonAPressed && !self.buttonAWasPressed) [self clickAtCurrentPointerInWindow:window];
    self.buttonAWasPressed = buttonAPressed;
    [self setVirtualKey:0x3B down:buttonB.isPressed held:&_flashlightDown];
    [self setVirtualKey:0x38 down:buttonX.isPressed held:&_doorDown];
}
@end

__attribute__((constructor)) static void enableFNAF4ControllerSupport(void)
{
    if (!getenv("FNAF4_ENABLE_CONTROLLER")) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        static FNAFControllerSupport *support;
        static dispatch_source_t timer;
        if (support) return;
        support = [FNAFControllerSupport new];
        support.mode = readControllerMode();
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, NSEC_PER_SEC / 60, NSEC_PER_MSEC * 2);
        dispatch_source_set_event_handler(timer, ^{
            if (!NSApp || !NSClassFromString(@"WineContentView")) return;
            [support installMenuIfNeeded];
            [support update];
        });
        dispatch_resume(timer);
    });
}
