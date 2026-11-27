/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/.
 */

#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <os/lock.h>
#include <dlfcn.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef NS_ENUM(NSInteger, ScaleMode) { ScaleFit, ScaleStretch };
typedef struct {
    CGRect imageRect;
    CGRect viewport;
    BOOL active;
    CGFloat screenTop;
} MouseGeometry;

static ScaleMode mode;
static IMP originalUpdateLayer;
static IMP originalMouseLocation;
static os_unfair_lock geometryLock = OS_UNFAIR_LOCK_INIT;
static MouseGeometry currentGeometry;
static CGFloat gameWidth = 1024;
static CGFloat gameHeight = 768;
static CGFloat minimumWidth = 1024;
static CGFloat minimumHeight = 768;
static char overlayAssociation;

static void readDimension(const char *name, CGFloat *dimension)
{
    const char *value = getenv(name);
    if (!value || !*value) return;
    char *end = NULL;
    double parsed = strtod(value, &end);
    if (end && !*end && parsed > 0 && isfinite(parsed)) *dimension = parsed;
}

static void readGameDimensions(void)
{
    readDimension("FNAF_DISPLAY_WIDTH", &gameWidth);
    readDimension("FNAF_DISPLAY_HEIGHT", &gameHeight);
    minimumWidth = gameWidth;
    minimumHeight = gameHeight;
    readDimension("FNAF_DISPLAY_MIN_WIDTH", &minimumWidth);
    readDimension("FNAF_DISPLAY_MIN_HEIGHT", &minimumHeight);
}

static BOOL stretchOnly(void)
{
    return getenv("FNAF_DISPLAY_STRETCH_ONLY") != NULL;
}

@interface ScaleOverlay : NSObject
@property (nonatomic, strong) CALayer *background;
@property (nonatomic, strong) CALayer *image;
@property (nonatomic) NSRect lastViewport;
@property (nonatomic) NSSize lastWindowSize;
@property (nonatomic) ScaleMode lastMode;
@end
@implementation ScaleOverlay
@end

static NSRect viewportForMode(NSRect window, ScaleMode selected)
{
    if (selected == ScaleStretch) return window;
    CGFloat scale = MIN(NSWidth(window) / gameWidth, NSHeight(window) / gameHeight);
    NSSize size = NSMakeSize(gameWidth * scale, gameHeight * scale);
    return NSMakeRect(NSMidX(window) - size.width / 2, NSMidY(window) - size.height / 2,
                      size.width, size.height);
}

static void saveMouseGeometry(MouseGeometry geometry)
{
    os_unfair_lock_lock(&geometryLock);
    currentGeometry = geometry;
    os_unfair_lock_unlock(&geometryLock);
}

static MouseGeometry mouseGeometry(void)
{
    os_unfair_lock_lock(&geometryLock);
    MouseGeometry geometry = currentGeometry;
    os_unfair_lock_unlock(&geometryLock);
    return geometry;
}

static CGPoint remap(CGPoint point, MouseGeometry geometry, BOOL quartzCoordinates)
{
    if (!geometry.active) return point;
    if (quartzCoordinates) point.y = geometry.screenTop - point.y;
    if (CGRectContainsPoint(geometry.viewport, point)) {
        CGFloat x = (point.x - CGRectGetMinX(geometry.viewport)) / CGRectGetWidth(geometry.viewport);
        CGFloat y = (point.y - CGRectGetMinY(geometry.viewport)) / CGRectGetHeight(geometry.viewport);
        point = CGPointMake(CGRectGetMinX(geometry.imageRect) + x * CGRectGetWidth(geometry.imageRect),
                            CGRectGetMinY(geometry.imageRect) + y * CGRectGetHeight(geometry.imageRect));
    }
    if (quartzCoordinates) point.y = geometry.screenTop - point.y;
    return point;
}

static BOOL cameFromWineMac(void *call)
{
    Dl_info info;
    return dladdr(call, &info) && info.dli_fname && strstr(info.dli_fname, "/winemac");
}

static CGPoint wineEventLocation(CGEventRef event)
{
    CGPoint position = CGEventGetLocation(event);
    MouseGeometry geometry = mouseGeometry();
    if (geometry.active && cameFromWineMac(__builtin_return_address(0))) {
        return remap(position, geometry, YES);
    }
    return position;
}

static NSPoint wineMouseLocation(id cls, SEL selector)
{
    NSPoint position = ((NSPoint (*)(id, SEL))originalMouseLocation)(cls, selector);
    MouseGeometry geometry = mouseGeometry();
    if (geometry.active && cameFromWineMac(__builtin_return_address(0))) {
        return NSPointFromCGPoint(remap(NSPointToCGPoint(position), geometry, NO));
    }
    return position;
}

__attribute__((used, section("__DATA,__interpose")))
static const struct {
    typeof(&CGEventGetLocation) replacement;
    typeof(&CGEventGetLocation) original;
} wineEventLocationHook = { wineEventLocation, CGEventGetLocation };

static BOOL isGameWindow(NSWindow *window)
{
    return [window.title hasPrefix:@"Five Nights at Freddy"] ||
           [window.title hasPrefix:@"Ultimate Custom Night"];
}

static NSView *findFrameView(NSView *view)
{
    for (NSView *child in view.subviews) {
        NSView *found = findFrameView(child);
        if (found) return found;
        NSSize size = child.bounds.size;
        if (fabs(size.width - gameWidth) < 0.5 && fabs(size.height - gameHeight) < 0.5) return child;
    }
    return nil;
}

static NSRect screenRect(NSWindow *window, NSView *view, NSRect rect)
{
    return [window convertRectToScreen:[view convertRect:rect toView:nil]];
}

static void syncMouse(NSWindow *window, NSView *root, NSRect source, NSRect destination)
{
    if (!window.keyWindow) return;
    MouseGeometry geometry = {
        .imageRect = NSRectToCGRect(screenRect(window, root, source)),
        .viewport = NSRectToCGRect(screenRect(window, root, destination)),
        .active = NSApp.active && window.visible,
        .screenTop = NSMaxY(NSScreen.screens.firstObject.frame),
    };
    saveMouseGeometry(geometry);
}

static void updateScaledLayer(NSView *root, SEL selector)
{
    ((void (*)(id, SEL))originalUpdateLayer)(root, selector);
    NSWindow *window = root.window;
    if (window.contentView != root || !isGameWindow(window)) return;

    ScaleOverlay *state = objc_getAssociatedObject(root, &overlayAssociation);
    if (!state) {
        state = [ScaleOverlay new];
        state.background = [CALayer layer];
        state.background.zPosition = 10000;
        state.background.backgroundColor = NSColor.blackColor.CGColor;
        state.background.masksToBounds = YES;
        state.image = [CALayer layer];
        state.image.contentsGravity = kCAGravityResize;
        state.image.minificationFilter = kCAFilterLinear;
        state.image.magnificationFilter = kCAFilterLinear;
        [state.background addSublayer:state.image];
        [root.layer addSublayer:state.background];
        objc_setAssociatedObject(root, &overlayAssociation, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    id contents = root.layer.contents;
    NSView *gameFrame = findFrameView(root);
    NSRect windowRect = root.bounds;
    if (!contents || CFGetTypeID((__bridge CFTypeRef)contents) != CGImageGetTypeID() ||
        !gameFrame || NSWidth(windowRect) < gameWidth || NSHeight(windowRect) < gameHeight) {
        state.background.hidden = YES;
        if (window.keyWindow) saveMouseGeometry((MouseGeometry){0});
        return;
    }

    NSRect source = [root convertRect:gameFrame.bounds fromView:gameFrame];
    if (!NSContainsRect(NSInsetRect(windowRect, -0.5, -0.5), source)) {
        state.background.hidden = YES;
        if (window.keyWindow) saveMouseGeometry((MouseGeometry){0});
        return;
    }
    NSRect destination = viewportForMode(windowRect, mode);
    BOOL sourceFillsWindow = fabs(NSMinX(source) - NSMinX(windowRect)) < 0.5 &&
                             fabs(NSMinY(source) - NSMinY(windowRect)) < 0.5 &&
                             fabs(NSWidth(source) - NSWidth(windowRect)) < 0.5 &&
                             fabs(NSHeight(source) - NSHeight(windowRect)) < 0.5;
    BOOL destinationFillsWindow = fabs(NSMinX(destination) - NSMinX(windowRect)) < 0.5 &&
                                  fabs(NSMinY(destination) - NSMinY(windowRect)) < 0.5 &&
                                  fabs(NSWidth(destination) - NSWidth(windowRect)) < 0.5 &&
                                  fabs(NSHeight(destination) - NSHeight(windowRect)) < 0.5;
    if (sourceFillsWindow && destinationFillsWindow) {
        state.background.hidden = YES;
        if (window.keyWindow) saveMouseGeometry((MouseGeometry){0});
        BOOL changed = !NSEqualSizes(windowRect.size, state.lastWindowSize) ||
                       !NSEqualRects(destination, state.lastViewport) || state.lastMode != mode;
        if (changed) {
            fprintf(stderr, "FNAF display: native %.0fx%.0f frame; bypassing image copy\n",
                    NSWidth(source), NSHeight(source));
            state.lastWindowSize = windowRect.size;
            state.lastViewport = destination;
            state.lastMode = mode;
        }
        return;
    }

    CGImageRef frame = (__bridge CGImageRef)contents;
    const CGFloat sx = (CGFloat)CGImageGetWidth(frame) / NSWidth(windowRect);
    const CGFloat sy = (CGFloat)CGImageGetHeight(frame) / NSHeight(windowRect);
    CGRect crop = CGRectIntegral(CGRectMake((NSMinX(source) - NSMinX(windowRect)) * sx,
                                            (NSMinY(source) - NSMinY(windowRect)) * sy,
                                            NSWidth(source) * sx, NSHeight(source) * sy));
    CGImageRef image = CGImageCreateWithImageInRect(frame, crop);
    if (!image) {
        state.background.hidden = YES;
        if (window.keyWindow) saveMouseGeometry((MouseGeometry){0});
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    state.background.hidden = NO;
    state.background.frame = NSRectToCGRect(windowRect);
    NSRect relative = NSOffsetRect(destination, -NSMinX(windowRect), -NSMinY(windowRect));
    state.image.frame = NSRectToCGRect(relative);
    state.image.contents = (__bridge id)image;
    [CATransaction commit];
    syncMouse(window, root, source, destination);

    BOOL changed = !NSEqualSizes(windowRect.size, state.lastWindowSize) ||
                   !NSEqualRects(destination, state.lastViewport) || state.lastMode != mode;
    if (changed) {
        fprintf(stderr, "FNAF display: %s %.0fx%.0f -> %.0fx%.0f (window %.0fx%.0f, fullscreen=%d)\n",
                mode == ScaleStretch ? "Stretch" : "Zoom to fit",
                NSWidth(source), NSHeight(source), NSWidth(destination), NSHeight(destination),
                NSWidth(windowRect), NSHeight(windowRect),
                (window.styleMask & NSWindowStyleMaskFullScreen) != 0);
        state.lastWindowSize = windowRect.size;
        state.lastViewport = destination;
        state.lastMode = mode;
    }
    CGImageRelease(image);
}

@interface ScaleMenu : NSObject
@property (nonatomic, strong) NSMenuItem *fit;
@property (nonatomic, strong) NSMenuItem *stretch;
@property (nonatomic, strong) NSMenuItem *display;
- (void)selectMode:(NSMenuItem *)sender;
@end

@implementation ScaleMenu
- (void)sync
{
    if (self.fit) self.fit.state = mode == ScaleFit ? NSControlStateValueOn : NSControlStateValueOff;
    self.stretch.state = mode == ScaleStretch ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)selectMode:(NSMenuItem *)sender
{
    mode = !stretchOnly() && sender == self.fit ? ScaleFit : ScaleStretch;
    [self sync];
    const char *setting = getenv("FNAF4_DISPLAY_PREFS");
    if (setting) {
        NSString *value = mode == ScaleFit ? @"fit" : @"stretch";
        [value writeToFile:@(setting) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    for (NSWindow *window in NSApp.windows) {
        if (isGameWindow(window)) window.contentView.needsDisplay = YES;
    }
}
@end

static void refreshMenu(ScaleMenu *controller)
{
    if (!NSApp.mainMenu || [NSApp.mainMenu indexOfItem:controller.display] >= 0) return;
    [NSApp.mainMenu addItem:controller.display];
}

__attribute__((constructor)) static void enableDisplayScaler(void)
{
    if (!getenv("FNAF4_DISPLAY_SCALER")) return;
    readGameDimensions();
    dispatch_async(dispatch_get_main_queue(), ^{
        static ScaleMenu *controller;
        static dispatch_source_t timer;
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC, 30 * NSEC_PER_MSEC);
        dispatch_source_set_event_handler(timer, ^{
            if (!NSApp || !NSClassFromString(@"WineContentView")) return;
            if (!controller) {
                const char *setting = getenv("FNAF4_DISPLAY_PREFS");
                NSString *preference = setting ? [NSString stringWithContentsOfFile:@(setting)
                                                              encoding:NSUTF8StringEncoding error:NULL] : nil;
                mode = !stretchOnly() && [preference isEqualToString:@"fit"] ? ScaleFit : ScaleStretch;
                Method update = class_getInstanceMethod(NSClassFromString(@"WineContentView"), @selector(updateLayer));
                if (!update) return;
                originalUpdateLayer = method_setImplementation(update, (IMP)updateScaledLayer);
                Method mouse = class_getClassMethod(NSEvent.class, @selector(mouseLocation));
                originalMouseLocation = method_setImplementation(mouse, (IMP)wineMouseLocation);
                controller = [ScaleMenu new];
                controller.display = [[NSMenuItem alloc] initWithTitle:@"Display" action:NULL keyEquivalent:@""];
                NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Display"];
                if (!stretchOnly()) {
                    NSString *ratio = @"";
                    CGFloat aspect = gameWidth / gameHeight;
                    if (fabs(aspect - 4.0 / 3.0) < 0.01) ratio = @" (4:3)";
                    else if (fabs(aspect - 16.0 / 9.0) < 0.01) ratio = @" (16:9)";
                    controller.fit = [[NSMenuItem alloc] initWithTitle:[@"Zoom to Fit" stringByAppendingString:ratio]
                                                    action:@selector(selectMode:) keyEquivalent:@"1"];
                    controller.fit.target = controller;
                    controller.fit.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
                    [menu addItem:controller.fit];
                }
                controller.stretch = [[NSMenuItem alloc] initWithTitle:@"Stretch to Fill"
                                                    action:@selector(selectMode:) keyEquivalent:@"2"];
                controller.stretch.target = controller;
                controller.stretch.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
                [menu addItem:controller.stretch];
                controller.display.submenu = menu;
                [controller sync];
            }

            NSWindow *key = NSApp.keyWindow;
            if (!NSApp.active || !isGameWindow(key)) saveMouseGeometry((MouseGeometry){0});
            for (NSWindow *window in NSApp.windows) {
                if (!isGameWindow(window)) continue;
                refreshMenu(controller);
                if (!NSEqualSizes(window.contentMinSize, NSMakeSize(minimumWidth, minimumHeight))) {
                    window.contentMinSize = NSMakeSize(minimumWidth, minimumHeight);
                }
            }
        });
        dispatch_resume(timer);
    });
}
