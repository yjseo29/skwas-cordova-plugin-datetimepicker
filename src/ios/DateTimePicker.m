#import "DateTimePicker.h"
#import "Extensions.h"
#import "ModalPickerViewController.h"
#import "TransparentCoverVerticalAnimator.h"

@interface DateTimePicker() // (Private)

// Configures the UIDatePicker with the NSMutableDictionary options.
- (void)configureDatePicker:(NSMutableDictionary *)optionsOrNil datePicker:(UIDatePicker *)datePicker;

@end


@implementation DateTimePicker {
    BOOL _isVisible;
    NSString *_callbackId;
}

#pragma mark - Public Methods

- (void)pluginInitialize {
    [self initPickerView:self.webView.superview];
}

- (void)show:(CDVInvokedUrlCommand*)command {
    if (_isVisible) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ILLEGAL_ACCESS_EXCEPTION messageAsString:@"A date/time picker dialog is already showing."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    _callbackId = command.callbackId;

    NSMutableDictionary *optionsOrNil = [command.arguments objectAtIndex:command.arguments.count - 1];

    [self configureDatePicker:optionsOrNil datePicker:self.modalPicker.datePicker];

    // If the previous presentation is still animating out (e.g. hide()
    // immediately followed by show()), presenting right away fails silently
    // and leaves a blank screen; wait for the dismissal to finish first.
    if (self.modalPicker.isBeingDismissed && self.modalPicker.transitionCoordinator != nil) {
        __weak DateTimePicker *weakSelf = self;
        [self.modalPicker.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            DateTimePicker *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf.viewController presentViewController:strongSelf.modalPicker animated:YES completion:nil];
            }
        }];
    } else {
        [self.viewController presentViewController:self.modalPicker animated:YES completion:nil];
    }

    _isVisible = YES;
}

- (void)hide:(CDVInvokedUrlCommand*)command {
    if (_isVisible) {
        // Hide the view with our custom transition.
        [self.modalPicker dismissViewControllerAnimated:true completion:nil];
        [self callbackCancelWithJavascript];
        _isVisible = NO;
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark UIViewControllerTransitioningDelegate methods

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
                                                                  presentingController:(UIViewController *)presenting
                                                                      sourceController:(UIViewController *)source {
    TransparentCoverVerticalAnimator *animator = [TransparentCoverVerticalAnimator new];
    animator.presenting = YES;
    return animator;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    TransparentCoverVerticalAnimator *animator = [TransparentCoverVerticalAnimator new];
    return animator;
}

#pragma mark UIPopoverPresentationControllerDelegate methods

// Keep the real popover look on iPhone instead of adapting to a sheet.
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection {
    return UIModalPresentationNone;
}

// Called when the user dismisses the popover by tapping outside of it.
// Without a toolbar there are no buttons, so dismissing confirms the
// selection; with a toolbar it cancels.
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    if (self.modalPicker.showToolbar) {
        if (self.modalPicker.cancelHandler != nil) self.modalPicker.cancelHandler();
    } else {
        if (self.modalPicker.doneHandler != nil) self.modalPicker.doneHandler(self.modalPicker);
    }
}
#pragma mark - Private Methods

- (void)initPickerView:(UIView*)theWebView {
    ModalPickerViewController *picker = [[ModalPickerViewController alloc] init];

    // Custom floating card with our own sheet-like spring transition.
    // (A native UISheetPresentationController was tried, but it cannot keep the
    // sheet fully fixed while dragging the picker wheels.)
    picker.modalPresentationStyle = UIModalPresentationCustom;
    picker.transitioningDelegate = self;

    if (@available(iOS 13.4, *)) {
        [picker.datePicker addTarget:self action:@selector(handleDatePickerTap:) forControlEvents:UIControlEventEditingDidBegin];
    }

    picker.doneHandler = ^(id sender) {
        ModalPickerViewController *modelPicker = (ModalPickerViewController *)sender;
        if (modelPicker == nil) {
            [self callbackSuccessWithJavascript:nil];
        } else {
            [self callbackSuccessWithJavascript:modelPicker.datePicker.date];
        }
        _isVisible = NO;
    };

    picker.cancelHandler = ^() {
        [self callbackCancelWithJavascript];
        _isVisible = NO;
    };

    self.modalPicker = picker;
}

- (void)configureDatePicker:(NSMutableDictionary *)optionsOrNil datePicker:(UIDatePicker *)datePicker {
    
    // iOS-specific options:
    // - pickerStyle: "wheels" (default) or "calendar" (iOS 14+, date/datetime only).
    // - presentation: "sheet" (default), "popup" (centered), or "popover"
    //   (anchored to the element rect in "anchorRect"; the system decides
    //   whether it fits below or above the element).
    // - toolbar: NO hides the title and buttons; dismissing then confirms.
    NSString *mode = [optionsOrNil objectForKey:@"mode"];
    NSDictionary *iosOptions = [optionsOrNil objectForKeyNotNull:@"ios"];
    NSString *pickerStyleRaw = [iosOptions isKindOfClass:NSDictionary.class] ? [iosOptions objectForKeyNotNull:@"pickerStyle"] : nil;
    NSString *presentationRaw = [iosOptions isKindOfClass:NSDictionary.class] ? [iosOptions objectForKeyNotNull:@"presentation"] : nil;
    NSDictionary *anchorRect = [iosOptions isKindOfClass:NSDictionary.class] ? [iosOptions objectForKeyNotNull:@"anchorRect"] : nil;
    NSNumber *toolbarValue = [iosOptions isKindOfClass:NSDictionary.class] ? [iosOptions objectForKeyNotNull:@"toolbar"] : nil;
    NSString *pickerStyle = [pickerStyleRaw isKindOfClass:NSString.class] ? [pickerStyleRaw lowercaseString] : @"";
    NSString *presentation = [presentationRaw isKindOfClass:NSString.class] ? [presentationRaw lowercaseString] : @"";

    // The picker UI: calendar falls back to wheels for the time mode and below iOS 14.
    BOOL useCalendar = NO;
    if (@available(iOS 14.0, *)) {
        useCalendar = [pickerStyle isEqualToString:@"calendar"] && ![mode isEqualToString:@"time"];
        UIDatePickerStyle newStyle = useCalendar ? UIDatePickerStyleInline : UIDatePickerStyleWheels;
        if (datePicker.preferredDatePickerStyle != newStyle) {
            // Changing the style while the picker is installed in a view
            // hierarchy (with the previous style's constraints) can leave its
            // internal layout broken. Detach it first; it is re-added when the
            // picker controls are rebuilt for the new style.
            [datePicker removeFromSuperview];
            datePicker.preferredDatePickerStyle = newStyle;
        }
    } else if (@available(iOS 13.4, *)) {
        datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    }

    // The presentation: popover falls back to the sheet when no anchor rect
    // was provided.
    BOOL usePopover = [presentation isEqualToString:@"popover"]
        && [anchorRect isKindOfClass:NSDictionary.class];
    BOOL usePopup = !usePopover && [presentation isEqualToString:@"popup"];

    self.modalPicker.inlinePicker = useCalendar;
    self.modalPicker.popupPresentation = usePopup;
    self.modalPicker.popoverPresentation = usePopover;
    self.modalPicker.showToolbar = toolbarValue != nil ? [toolbarValue boolValue] : YES;

    // Optional width overrides; clamped to a sane minimum so the picker
    // cannot be squeezed into an unusable layout.
    NSNumber *popupWidthValue = [iosOptions isKindOfClass:NSDictionary.class] ? [iosOptions objectForKeyNotNull:@"popupWidth"] : nil;
    NSNumber *popoverMaxWidthValue = [iosOptions isKindOfClass:NSDictionary.class] ? [iosOptions objectForKeyNotNull:@"popoverMaxWidth"] : nil;
    self.modalPicker.popupWidth = popupWidthValue != nil ? MAX(280, [popupWidthValue doubleValue]) : 0;
    self.modalPicker.popoverMaxWidth = popoverMaxWidthValue != nil ? MAX(280, [popoverMaxWidthValue doubleValue]) : 0;

    // Optional forced light/dark appearance; follows the system otherwise.
    // Affects the whole picker: our own styling and UIKit's dynamic colors.
    if (@available(iOS 13.0, *)) {
        NSString *themeRaw = [iosOptions isKindOfClass:NSDictionary.class] ? [iosOptions objectForKeyNotNull:@"theme"] : nil;
        NSString *theme = [themeRaw isKindOfClass:NSString.class] ? [themeRaw lowercaseString] : @"";
        if ([theme isEqualToString:@"light"]) {
            self.modalPicker.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
        } else if ([theme isEqualToString:@"dark"]) {
            self.modalPicker.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        } else {
            self.modalPicker.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
        }
    }

    // Presentation. The presentation controller is recreated per presentation,
    // so this is (re)configured on every show.
    if (usePopover) {
        self.modalPicker.modalPresentationStyle = UIModalPresentationPopover;
        self.modalPicker.transitioningDelegate = nil;

        UIPopoverPresentationController *popover = self.modalPicker.popoverPresentationController;
        popover.sourceView = self.webView;
        popover.sourceRect = CGRectMake(
            [[anchorRect objectForKeyNotNull:@"x"] doubleValue],
            [[anchorRect objectForKeyNotNull:@"y"] doubleValue],
            MAX(1, [[anchorRect objectForKeyNotNull:@"width"] doubleValue]),
            MAX(1, [[anchorRect objectForKeyNotNull:@"height"] doubleValue]));
        popover.permittedArrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;
        popover.delegate = self;
    } else {
        self.modalPicker.modalPresentationStyle = UIModalPresentationCustom;
        self.modalPicker.transitioningDelegate = self;
    }

    // Mode (must be set first, otherwise minuteInterval > 1 acts wonky).
    if ([mode isEqualToString:@"date"]) {
        datePicker.datePickerMode = UIDatePickerModeDate;
    } else if ([mode isEqualToString:@"time"]) {
        datePicker.datePickerMode = UIDatePickerModeTime;
    } else {
        datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    }
   
    // Locale.
    NSString *localeString = [optionsOrNil objectForKeyNotNull:@"locale"];
    datePicker.locale = localeString.length > 0 ? [[NSLocale alloc] initWithLocaleIdentifier:localeString] : [NSLocale currentLocale];
    
    // Texts.
    self.modalPicker.doneText = [optionsOrNil objectForKeyNotNull:@"okText"];
    self.modalPicker.cancelText = [optionsOrNil objectForKeyNotNull:@"cancelText"];
    self.modalPicker.clearText = [optionsOrNil objectForKeyNotNull:@"clearText"];
    self.modalPicker.titleText = [optionsOrNil objectForKeyNotNull:@"titleText"];

    // Minute interval.
    NSInteger minuteInterval = [[optionsOrNil objectForKeyNotNull:@"minuteInterval"] ?: [NSNumber numberWithInt:1] intValue];
    datePicker.minuteInterval = minuteInterval;
    
    // Allow old/future dates.
    BOOL allowOldDates = [[optionsOrNil objectForKeyNotNull:@"allowOldDates"] ?: [NSNumber numberWithInt:1] boolValue];
    BOOL allowFutureDates = [[optionsOrNil objectForKeyNotNull:@"allowFutureDates"] ?: [NSNumber numberWithInt:1] boolValue];
    
    // Min/max dates.
    NSDate *today = [NSDate today];
    long long todayTicks = ((long long)[today timeIntervalSince1970]) * DDBIntervalFactor;
    long long endOfTodayTicks = ((long long)[[[today addDay:1] addSecond:-1] timeIntervalSince1970]) * DDBIntervalFactor;
    NSNumber *minDateTicks = [optionsOrNil objectForKeyNotNull:@"minDateTicks"] ?: allowOldDates ? nil : [NSNumber numberWithLongLong:(todayTicks)];
    NSNumber *maxDateTicks = [optionsOrNil objectForKeyNotNull:@"maxDateTicks"] ?: allowFutureDates ? nil : [NSNumber numberWithLongLong:(endOfTodayTicks)];

    if (minDateTicks) {
        datePicker.minimumDate = [[NSDate dateWithTimeIntervalSince1970:([minDateTicks longLongValue] / DDBIntervalFactor)] roundDownToMinuteInterval:minuteInterval];
    } else {
        datePicker.minimumDate = nil;
    }
    if (maxDateTicks) {
        datePicker.maximumDate = [[NSDate dateWithTimeIntervalSince1970:([maxDateTicks longLongValue] / DDBIntervalFactor)] roundUpToMinuteInterval:minuteInterval];
    } else {
        datePicker.maximumDate = nil;
    }
    
    // Selected date.
    long long ticks = [[optionsOrNil objectForKey:@"ticks"] longLongValue];
    [datePicker setDate:[[NSDate dateWithTimeIntervalSince1970:(ticks / DDBIntervalFactor)] roundToMinuteInterval:minuteInterval] animated:FALSE];
}

// Sends the date to the plugin javascript handler.
- (void)callbackSuccessWithJavascript:(NSDate *)date {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    // When date is nil, user clicked 'clear' button so we dispatch success without ticks in that case.
    if (date != nil) {
        long long ticks = ((long long)[date timeIntervalSince1970]) * DDBIntervalFactor;
        [result setObject:[NSNumber numberWithLongLong:ticks] forKey:@"ticks"];
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_callbackId];
}

// Sends a cancellation notification to the plugin javascript handler.
- (void)callbackCancelWithJavascript {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    [result setObject:[NSNumber numberWithBool:YES] forKey:@"cancelled"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_callbackId];
}

- (void)handleDatePickerTap:(id)sender{
  [sender resignFirstResponder];
}

@end
