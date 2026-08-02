#import <Cocoa/Cocoa.h>

@interface CommandResult : NSObject
@property(nonatomic) int exitCode;
@property(nonatomic, copy) NSString *output;
@property(nonatomic, copy) NSString *error;
@end
@implementation CommandResult
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTextField *currentValue;
@property(nonatomic, strong) NSPopUpButton *providerMenu;
@property(nonatomic, strong) NSTextField *detailValue;
@property(nonatomic, strong) NSButton *switchButton;
@property(nonatomic, strong) NSButton *refreshButton;
@property(nonatomic, strong) NSProgressIndicator *progress;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [self buildWindow];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self refreshStatus];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (NSTextField *)label:(NSString *)text size:(CGFloat)size weight:(NSFontWeight)weight {
    NSTextField *field = [NSTextField labelWithString:text];
    field.font = [NSFont systemFontOfSize:size weight:weight];
    return field;
}

- (void)buildWindow {
    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 560, 280)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = @"Codex Provider Switcher";
    self.window.releasedWhenClosed = NO;
    [self.window center];

    NSTextField *title = [self label:@"Codex Provider Switcher" size:23 weight:NSFontWeightSemibold];
    NSTextField *subtitle = [NSTextField labelWithString:@"Switch between Codex built-in and configured providers."];
    subtitle.textColor = NSColor.secondaryLabelColor;

    NSTextField *currentLabel = [self label:@"Current provider" size:13 weight:NSFontWeightMedium];
    self.currentValue = [NSTextField labelWithString:@"Loading..."];
    self.currentValue.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightMedium];
    NSGridView *statusGrid = [NSGridView gridViewWithViews:@[@[currentLabel, self.currentValue]]];
    statusGrid.columnSpacing = 16;
    [statusGrid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;
    [statusGrid columnAtIndex:1].xPlacement = NSGridCellPlacementLeading;

    self.providerMenu = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.providerMenu.enabled = NO;
    self.switchButton = [NSButton buttonWithTitle:@"Switch" target:self action:@selector(switchClicked:)];
    self.refreshButton = [NSButton buttonWithTitle:@"Refresh" target:self action:@selector(refreshClicked:)];
    self.switchButton.enabled = NO;
    self.progress = [[NSProgressIndicator alloc] init];
    self.progress.style = NSProgressIndicatorStyleSpinning;
    self.progress.controlSize = NSControlSizeSmall;
    self.progress.displayedWhenStopped = NO;

    NSStackView *actions = [NSStackView stackViewWithViews:@[
        self.providerMenu, self.switchButton, self.refreshButton, self.progress
    ]];
    actions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actions.spacing = 10;
    actions.alignment = NSLayoutAttributeCenterY;

    self.detailValue = [NSTextField labelWithString:@"Stop active Codex tasks before switching. Reopen Codex after the change."];
    self.detailValue.textColor = NSColor.secondaryLabelColor;
    self.detailValue.maximumNumberOfLines = 2;

    NSStackView *stack = [NSStackView stackViewWithViews:@[
        title, subtitle, statusGrid, actions, self.detailValue
    ]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 18;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *content = [[NSView alloc] init];
    [content addSubview:stack];
    self.window.contentView = content;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:28],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-28],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:26],
        [self.providerMenu.widthAnchor constraintGreaterThanOrEqualToConstant:260],
        [self.detailValue.widthAnchor constraintEqualToAnchor:stack.widthAnchor]
    ]];
}

- (void)refreshClicked:(id)sender {
    [self refreshStatus];
}

- (void)switchClicked:(id)sender {
    NSMenuItem *item = self.providerMenu.selectedItem;
    NSString *providerID = item.representedObject;
    if (!providerID.length) return;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Switch to %@?", item.title];
    alert.informativeText = @"Confirm that all active Codex tasks are stopped. Reopen Codex after switching.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Switch"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;

    [self setBusy:YES message:@"Switching provider..."];
    [self runAsync:@[@"--json", @"switch", providerID, @"--confirm-no-active-tasks"] completion:^(CommandResult *result) {
        [self setBusy:NO message:result.exitCode == 0 ? @"Switch complete. Reopen Codex." : @"Switch failed."];
        [self showResult:result successTitle:@"Provider switched"];
        [self refreshStatus];
    }];
}

- (void)refreshStatus {
    [self setBusy:YES message:@"Reading configured providers..."];
    [self runAsync:@[@"--json", @"list"] completion:^(CommandResult *result) {
        [self setBusy:NO message:result.exitCode == 0 ? @"Select a provider." : @"Unable to read providers."];
        if (result.exitCode != 0) {
            self.currentValue.stringValue = @"Unavailable";
            [self showResult:result successTitle:@""];
            return;
        }
        NSData *data = [result.output dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *payload = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSArray *providers = [payload isKindOfClass:NSDictionary.class] ? payload[@"providers"] : nil;
        NSString *current = [payload isKindOfClass:NSDictionary.class] ? payload[@"current"] : nil;
        if (![providers isKindOfClass:NSArray.class] || ![current isKindOfClass:NSString.class]) {
            self.currentValue.stringValue = @"Invalid response";
            return;
        }
        [self.providerMenu removeAllItems];
        NSInteger selectedIndex = 0;
        NSInteger index = 0;
        for (NSDictionary *provider in providers) {
            NSString *providerID = provider[@"id"];
            NSString *name = provider[@"name"];
            if (![providerID isKindOfClass:NSString.class] || ![name isKindOfClass:NSString.class]) continue;
            NSString *label = [name isEqualToString:providerID] ? name : [NSString stringWithFormat:@"%@ (%@)", name, providerID];
            [self.providerMenu addItemWithTitle:label];
            self.providerMenu.lastItem.representedObject = providerID;
            if ([providerID isEqualToString:current]) selectedIndex = index;
            index++;
        }
        self.currentValue.stringValue = current;
        [self.providerMenu selectItemAtIndex:selectedIndex];
        self.providerMenu.enabled = self.providerMenu.numberOfItems > 0;
        self.switchButton.enabled = self.providerMenu.numberOfItems > 0;
    }];
}

- (void)setBusy:(BOOL)busy message:(NSString *)message {
    self.providerMenu.enabled = !busy && self.providerMenu.numberOfItems > 0;
    self.switchButton.enabled = !busy && self.providerMenu.numberOfItems > 0;
    self.refreshButton.enabled = !busy;
    self.detailValue.stringValue = message;
    busy ? [self.progress startAnimation:nil] : [self.progress stopAnimation:nil];
}

- (void)showResult:(CommandResult *)result successTitle:(NSString *)successTitle {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = result.exitCode == 0 ? successTitle : @"Command failed";
    NSString *detail = result.exitCode == 0 ? result.output : (result.error.length ? result.error : result.output);
    alert.informativeText = detail.length ? detail : @"No details were returned.";
    alert.alertStyle = result.exitCode == 0 ? NSAlertStyleInformational : NSAlertStyleCritical;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)runAsync:(NSArray<NSString *> *)arguments completion:(void (^)(CommandResult *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        CommandResult *result = [self run:arguments];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(result); });
    });
}

- (CommandResult *)run:(NSArray<NSString *> *)arguments {
    CommandResult *result = [[CommandResult alloc] init];
    NSURL *launcher = [NSBundle.mainBundle URLForResource:@"run-switcher" withExtension:@"zsh"];
    if (!launcher) {
        result.exitCode = 127;
        result.error = @"The app bundle is missing run-switcher.zsh.";
        return result;
    }
    NSTask *task = [[NSTask alloc] init];
    NSPipe *stdoutPipe = [NSPipe pipe];
    NSPipe *stderrPipe = [NSPipe pipe];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/zsh"];
    task.arguments = [@[launcher.path] arrayByAddingObjectsFromArray:arguments];
    task.standardOutput = stdoutPipe;
    task.standardError = stderrPipe;
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        result.exitCode = 126;
        result.error = error.localizedDescription;
        return result;
    }
    [task waitUntilExit];
    NSData *stdoutData = [stdoutPipe.fileHandleForReading readDataToEndOfFile];
    NSData *stderrData = [stderrPipe.fileHandleForReading readDataToEndOfFile];
    NSCharacterSet *trim = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    result.exitCode = task.terminationStatus;
    result.output = [[[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] ?: @"" stringByTrimmingCharactersInSet:trim];
    result.error = [[[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] ?: @"" stringByTrimmingCharactersInSet:trim];
    return result;
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
