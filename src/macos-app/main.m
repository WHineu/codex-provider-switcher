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
@property(nonatomic, strong) NSBox *currentIndicator;
@property(nonatomic, strong) NSTextField *currentValue;
@property(nonatomic, strong) NSTextField *currentMetaValue;
@property(nonatomic, strong) NSPopUpButton *providerMenu;
@property(nonatomic, strong) NSTextField *detailValue;
@property(nonatomic, strong) NSButton *switchButton;
@property(nonatomic, strong) NSButton *refreshButton;
@property(nonatomic, strong) NSProgressIndicator *progress;
@property(nonatomic, copy) NSString *currentProviderID;
@property(nonatomic, strong) NSDictionary *currentProvider;
@property(nonatomic) BOOL busy;
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

- (NSTextField *)sectionLabel:(NSString *)text {
    NSTextField *field = [self label:text size:11 weight:NSFontWeightMedium];
    field.textColor = NSColor.secondaryLabelColor;
    return field;
}

- (NSBox *)separator {
    NSBox *box = [[NSBox alloc] init];
    box.boxType = NSBoxSeparator;
    return box;
}

- (NSBox *)currentRouteSurface {
    NSBox *box = [[NSBox alloc] init];
    box.boxType = NSBoxCustom;
    box.borderWidth = 1;
    box.cornerRadius = 8;
    box.borderColor = NSColor.separatorColor;
    box.fillColor = NSColor.controlBackgroundColor;
    return box;
}

- (void)buildWindow {
    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 620, 400)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = @"Codex Provider Switcher";
    self.window.releasedWhenClosed = NO;
    [self.window center];

    NSTextField *title = [self label:@"Codex Provider Switcher" size:19 weight:NSFontWeightSemibold];
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"Development";
    NSTextField *versionLabel = [self label:version size:11 weight:NSFontWeightMedium];
    versionLabel.textColor = NSColor.tertiaryLabelColor;
    NSView *headerSpacer = [[NSView alloc] init];
    [headerSpacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *header = [NSStackView stackViewWithViews:@[title, headerSpacer, versionLabel]];
    header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    header.alignment = NSLayoutAttributeCenterY;

    NSTextField *currentLabel = [self sectionLabel:@"CURRENT ROUTE"];
    [currentLabel.heightAnchor constraintGreaterThanOrEqualToConstant:14].active = YES;
    self.currentIndicator = [[NSBox alloc] init];
    self.currentIndicator.boxType = NSBoxCustom;
    self.currentIndicator.borderWidth = 0;
    self.currentIndicator.cornerRadius = 2;
    self.currentIndicator.fillColor = NSColor.systemGrayColor;
    [self.currentIndicator.widthAnchor constraintEqualToConstant:4].active = YES;
    [self.currentIndicator.heightAnchor constraintEqualToConstant:52].active = YES;
    [self.currentIndicator setAccessibilityLabel:@"Current provider status"];

    self.currentValue = [self label:@"Loading..." size:24 weight:NSFontWeightSemibold];
    self.currentValue.lineBreakMode = NSLineBreakByTruncatingTail;
    self.currentMetaValue = [NSTextField labelWithString:@"Reading configured providers..."];
    self.currentMetaValue.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.currentMetaValue.textColor = NSColor.secondaryLabelColor;
    self.currentMetaValue.lineBreakMode = NSLineBreakByTruncatingTail;
    NSStackView *currentText = [NSStackView stackViewWithViews:@[self.currentValue, self.currentMetaValue]];
    currentText.orientation = NSUserInterfaceLayoutOrientationVertical;
    currentText.alignment = NSLayoutAttributeLeading;
    currentText.spacing = 3;
    NSStackView *currentRow = [NSStackView stackViewWithViews:@[self.currentIndicator, currentText]];
    currentRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    currentRow.alignment = NSLayoutAttributeCenterY;
    currentRow.spacing = 14;
    NSStackView *currentContent = [NSStackView stackViewWithViews:@[currentLabel, currentRow]];
    currentContent.orientation = NSUserInterfaceLayoutOrientationVertical;
    currentContent.alignment = NSLayoutAttributeLeading;
    currentContent.spacing = 10;
    currentContent.translatesAutoresizingMaskIntoConstraints = NO;
    NSBox *currentSurface = [self currentRouteSurface];
    [currentSurface.contentView addSubview:currentContent];
    [NSLayoutConstraint activateConstraints:@[
        [currentContent.leadingAnchor constraintEqualToAnchor:currentSurface.contentView.leadingAnchor constant:18],
        [currentContent.trailingAnchor constraintEqualToAnchor:currentSurface.contentView.trailingAnchor constant:-18],
        [currentContent.topAnchor constraintEqualToAnchor:currentSurface.contentView.topAnchor constant:15],
        [currentContent.bottomAnchor constraintEqualToAnchor:currentSurface.contentView.bottomAnchor constant:-15]
    ]];

    NSTextField *targetLabel = [self sectionLabel:@"SELECT DESTINATION"];
    self.providerMenu = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.providerMenu.controlSize = NSControlSizeLarge;
    self.providerMenu.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    self.providerMenu.enabled = NO;
    self.providerMenu.target = self;
    self.providerMenu.action = @selector(providerChanged:);
    [self.providerMenu setAccessibilityLabel:@"Target provider"];

    self.switchButton = [NSButton buttonWithTitle:@"Switch Provider" target:self action:@selector(switchClicked:)];
    self.switchButton.controlSize = NSControlSizeLarge;
    self.switchButton.keyEquivalent = @"\r";
    self.switchButton.enabled = NO;
    [self.switchButton.widthAnchor constraintGreaterThanOrEqualToConstant:140].active = YES;
    [self.switchButton setAccessibilityLabel:@"Switch provider"];

    NSImage *refreshImage = [NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:@"Refresh providers"];
    self.refreshButton = [NSButton buttonWithImage:refreshImage target:self action:@selector(refreshClicked:)];
    self.refreshButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.refreshButton.controlSize = NSControlSizeLarge;
    self.refreshButton.toolTip = @"Refresh providers";
    [self.refreshButton.widthAnchor constraintEqualToConstant:34].active = YES;
    [self.refreshButton setAccessibilityLabel:@"Refresh providers"];

    self.progress = [[NSProgressIndicator alloc] init];
    self.progress.style = NSProgressIndicatorStyleSpinning;
    self.progress.controlSize = NSControlSizeSmall;
    self.progress.displayedWhenStopped = NO;
    [self.progress.widthAnchor constraintEqualToConstant:16].active = YES;

    self.detailValue = [NSTextField labelWithString:@"Reading configured providers..."];
    self.detailValue.textColor = NSColor.secondaryLabelColor;
    self.detailValue.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.detailValue setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.detailValue setAccessibilityLabel:@"Provider status"];
    NSView *actionSpacer = [[NSView alloc] init];
    [actionSpacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *actions = [NSStackView stackViewWithViews:@[
        self.detailValue, actionSpacer, self.progress, self.refreshButton, self.switchButton
    ]];
    actions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actions.spacing = 10;
    actions.alignment = NSLayoutAttributeCenterY;

    NSTextField *footnote = [NSTextField labelWithString:@"Stop active Codex tasks before switching. Quit and reopen Codex after the change."];
    footnote.textColor = NSColor.secondaryLabelColor;
    footnote.font = [NSFont systemFontOfSize:11];
    footnote.maximumNumberOfLines = 2;

    NSStackView *stack = [NSStackView stackViewWithViews:@[
        header, [self separator], currentSurface, targetLabel, self.providerMenu,
        [self separator], actions, footnote
    ]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 12;
    [stack setCustomSpacing:16 afterView:header];
    [stack setCustomSpacing:18 afterView:currentSurface];
    [stack setCustomSpacing:8 afterView:targetLabel];
    [stack setCustomSpacing:18 afterView:self.providerMenu];
    [stack setCustomSpacing:10 afterView:actions];
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *content = [[NSView alloc] init];
    [content addSubview:stack];
    self.window.contentView = content;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:30],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-30],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:24],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-22],
        [header.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [currentSurface.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [currentSurface.heightAnchor constraintEqualToConstant:118],
        [self.providerMenu.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [actions.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [footnote.widthAnchor constraintEqualToAnchor:stack.widthAnchor]
    ]];
}

- (NSDictionary *)payloadFromOutput:(NSString *)output error:(NSError **)error {
    if (!output.length) return nil;
    NSData *data = [output dataUsingEncoding:NSUTF8StringEncoding];
    id payload = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:error] : nil;
    return [payload isKindOfClass:NSDictionary.class] ? payload : nil;
}

- (NSString *)providerKindLabel:(NSDictionary *)provider {
    return [provider[@"kind"] isEqualToString:@"builtin"] ? @"Built-in provider" : @"Custom provider";
}

- (NSString *)providerMenuLabel:(NSDictionary *)provider {
    NSString *name = [provider[@"name"] isKindOfClass:NSString.class] ? provider[@"name"] : provider[@"id"];
    return [NSString stringWithFormat:@"%@  -  %@", name, [self providerKindLabel:provider]];
}

- (void)showCurrentProvider:(NSDictionary *)provider {
    self.currentProvider = provider;
    NSString *providerID = provider[@"id"];
    NSString *name = [provider[@"name"] isKindOfClass:NSString.class] ? provider[@"name"] : providerID;
    self.currentValue.stringValue = name ?: @"Unavailable";

    NSMutableArray<NSString *> *details = [NSMutableArray array];
    if (providerID.length) [details addObject:providerID];
    [details addObject:[self providerKindLabel:provider]];
    BOOL hasAdapter = [provider[@"adapter"] isKindOfClass:NSString.class];
    BOOL healthy = [provider[@"adapter_healthy"] respondsToSelector:@selector(boolValue)] && [provider[@"adapter_healthy"] boolValue];
    if (hasAdapter) [details addObject:healthy ? @"Adapter ready" : @"Adapter stopped"];
    self.currentMetaValue.stringValue = [details componentsJoinedByString:@"  |  "];
    self.currentIndicator.fillColor = hasAdapter && !healthy ? NSColor.systemOrangeColor : NSColor.systemGreenColor;
    [self.currentIndicator setAccessibilityValue:hasAdapter && !healthy ? @"Adapter stopped" : @"Ready"];
}

- (void)clearProviderUI:(NSString *)message {
    self.currentProviderID = nil;
    self.currentProvider = nil;
    self.currentValue.stringValue = @"Unavailable";
    self.currentMetaValue.stringValue = message;
    self.currentIndicator.fillColor = NSColor.systemOrangeColor;
    [self.providerMenu removeAllItems];
    self.providerMenu.enabled = NO;
    self.switchButton.enabled = NO;
}

- (void)refreshClicked:(id)sender {
    [self refreshStatus];
}

- (void)providerChanged:(id)sender {
    [self updateSwitchButton];
}

- (void)updateSwitchButton {
    if (self.busy || self.providerMenu.numberOfItems == 0 || !self.currentProviderID.length) {
        self.switchButton.enabled = NO;
        return;
    }
    NSDictionary *provider = self.providerMenu.selectedItem.representedObject;
    NSString *providerID = [provider isKindOfClass:NSDictionary.class] ? provider[@"id"] : nil;
    if (!providerID.length) {
        self.switchButton.enabled = NO;
        return;
    }
    BOOL sameProvider = [providerID isEqualToString:self.currentProviderID];
    BOOL hasAdapter = [provider[@"adapter"] isKindOfClass:NSString.class];
    BOOL healthy = [provider[@"adapter_healthy"] respondsToSelector:@selector(boolValue)] && [provider[@"adapter_healthy"] boolValue];
    if (sameProvider && hasAdapter && !healthy) {
        self.switchButton.title = @"Start Adapter";
        self.switchButton.enabled = YES;
    } else if (sameProvider) {
        self.switchButton.title = @"Already Active";
        self.switchButton.enabled = NO;
    } else {
        self.switchButton.title = @"Switch Provider";
        self.switchButton.enabled = YES;
    }
}

- (void)switchClicked:(id)sender {
    NSDictionary *provider = self.providerMenu.selectedItem.representedObject;
    if (![provider isKindOfClass:NSDictionary.class]) return;
    NSString *providerID = provider[@"id"];
    NSString *name = [provider[@"name"] isKindOfClass:NSString.class] ? provider[@"name"] : providerID;
    if (!providerID.length) return;

    BOOL startingAdapter = [providerID isEqualToString:self.currentProviderID] &&
        [provider[@"adapter"] isKindOfClass:NSString.class] &&
        [provider[@"adapter_healthy"] respondsToSelector:@selector(boolValue)] &&
        ![provider[@"adapter_healthy"] boolValue];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = startingAdapter
        ? [NSString stringWithFormat:@"Start the adapter for %@?", name]
        : [NSString stringWithFormat:@"Switch to %@?", name];
    alert.informativeText = @"Confirm that all active Codex tasks are stopped. Quit and reopen Codex after switching.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:startingAdapter ? @"Start Adapter" : @"Switch Provider"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;

    [self setBusy:YES message:startingAdapter ? @"Starting local adapter..." : [NSString stringWithFormat:@"Switching to %@...", name]];
    [self runAsync:@[@"--json", @"switch", providerID, @"--confirm-no-active-tasks"] completion:^(CommandResult *result) {
        [self setBusy:NO message:result.exitCode == 0 ? @"Provider command complete." : @"Provider was not changed."];
        [self showSwitchResult:result];
        [self refreshStatus];
    }];
}

- (void)refreshStatus {
    [self setBusy:YES message:@"Reading configured providers..."];
    [self runAsync:@[@"--json", @"list"] completion:^(CommandResult *result) {
        if (result.exitCode != 0) {
            [self clearProviderUI:@"Could not read configured providers."];
            [self setBusy:NO message:@"Unable to read providers."];
            [self showCommandFailure:result title:@"Unable to read providers"];
            return;
        }

        NSError *jsonError = nil;
        NSDictionary *payload = [self payloadFromOutput:result.output error:&jsonError];
        NSArray *providers = [payload[@"providers"] isKindOfClass:NSArray.class] ? payload[@"providers"] : nil;
        NSString *current = [payload[@"current"] isKindOfClass:NSString.class] ? payload[@"current"] : nil;
        if (!providers || !current.length) {
            [self clearProviderUI:@"The provider list response was invalid."];
            [self setBusy:NO message:@"Unable to read providers."];
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Invalid provider response";
            alert.informativeText = @"The switcher returned data that the app could not understand. No provider was changed.";
            alert.alertStyle = NSAlertStyleCritical;
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            return;
        }

        [self.providerMenu removeAllItems];
        self.currentProviderID = current;
        NSDictionary *currentProvider = nil;
        NSInteger selectedIndex = 0;
        NSInteger addedIndex = 0;
        for (id value in providers) {
            if (![value isKindOfClass:NSDictionary.class]) continue;
            NSDictionary *provider = value;
            NSString *providerID = provider[@"id"];
            if (![providerID isKindOfClass:NSString.class] || !providerID.length) continue;
            [self.providerMenu addItemWithTitle:[self providerMenuLabel:provider]];
            self.providerMenu.lastItem.representedObject = provider;
            if ([providerID isEqualToString:current]) {
                selectedIndex = addedIndex;
                currentProvider = provider;
            }
            addedIndex++;
        }
        if (!currentProvider || self.providerMenu.numberOfItems == 0) {
            [self clearProviderUI:@"The active provider was not in the provider list."];
            [self setBusy:NO message:@"Unable to read providers."];
            return;
        }
        [self showCurrentProvider:currentProvider];
        [self.providerMenu selectItemAtIndex:selectedIndex];
        [self setBusy:NO message:@"Select a provider to continue."];
    }];
}

- (void)setBusy:(BOOL)busy message:(NSString *)message {
    self.busy = busy;
    self.providerMenu.enabled = !busy && self.providerMenu.numberOfItems > 0;
    self.refreshButton.enabled = !busy;
    self.detailValue.stringValue = message;
    busy ? [self.progress startAnimation:nil] : [self.progress stopAnimation:nil];
    [self updateSwitchButton];
}

- (void)showSwitchResult:(CommandResult *)result {
    if (result.exitCode != 0) {
        [self showCommandFailure:result title:@"Provider was not changed"];
        return;
    }
    NSError *jsonError = nil;
    NSDictionary *payload = [self payloadFromOutput:result.output error:&jsonError];
    if (!payload) {
        [self showCommandFailure:result title:@"Provider command completed"];
        return;
    }

    BOOL changed = [payload[@"changed"] respondsToSelector:@selector(boolValue)] && [payload[@"changed"] boolValue];
    NSString *previous = [payload[@"previous"] isKindOfClass:NSString.class] ? payload[@"previous"] : nil;
    NSString *current = [payload[@"current"] isKindOfClass:NSString.class] ? payload[@"current"] : self.currentProviderID;
    NSString *adapter = [payload[@"adapter"] isKindOfClass:NSString.class] ? payload[@"adapter"] : nil;
    NSString *warning = [payload[@"warning"] isKindOfClass:NSString.class] ? payload[@"warning"] : nil;

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (changed && previous.length && current.length) {
        [lines addObject:[NSString stringWithFormat:@"%@ -> %@", previous, current]];
    } else if (current.length) {
        [lines addObject:[NSString stringWithFormat:@"%@ is already active.", current]];
    }
    if ([adapter isEqualToString:@"started"]) [lines addObject:@"The local adapter started successfully."];
    if ([adapter isEqualToString:@"already running"]) [lines addObject:@"The local adapter is already running."];
    if (changed) [lines addObject:@"Quit and reopen Codex to apply the change."];
    if (warning.length) [lines addObject:[NSString stringWithFormat:@"Warning: %@", warning]];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = changed ? @"Provider switched" : @"Provider already active";
    alert.informativeText = [lines componentsJoinedByString:@"\n\n"];
    alert.alertStyle = warning.length ? NSAlertStyleWarning : NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)showCommandFailure:(CommandResult *)result title:(NSString *)title {
    NSError *jsonError = nil;
    NSDictionary *payload = [self payloadFromOutput:result.output error:&jsonError];
    NSString *jsonMessage = [payload[@"error"] isKindOfClass:NSString.class] ? payload[@"error"] : nil;
    NSString *detail = jsonMessage.length ? jsonMessage : (result.error.length ? result.error : result.output);
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = detail.length ? detail : @"No details were returned.";
    alert.alertStyle = NSAlertStyleCritical;
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
