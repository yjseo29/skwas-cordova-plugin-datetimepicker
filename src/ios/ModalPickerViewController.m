#import "ModalPickerViewController.h"
#import "Extensions.h"

static const float kHeaderBarHeight = 44;
static const float kHeaderBarHeightSmall = 32;
static const float kDatePickerHeight = 200;
static const float kSheetMargin = 10;
static const float kSheetCornerRadius = 22;
// Extra space above the header (between the sheet's top edge and the buttons).
static const float kHeaderTopPadding = 12;
// Centered popup and popover.
static const float kPopupWidth = 360;
static const float kPopupContentPadding = 10;
static const float kPopupTitleHeight = 44;
static const float kPopupFooterHeight = 48;
static const float kHeaderButtonInset = 16;
static const float kHeaderButtonGap = 8;
static const float kCapsuleButtonCornerRadius = 16;

@interface ModalPickerViewController()

@end

@implementation ModalPickerViewController {
    UIView *_internalView;

    UIView *_headerView;
    UILabel *_titleLabel;

    // Popup/popover presentations only: buttons live in a footer under a hairline.
    UIView *_footerView;
    UIView *_footerSeparator;

    UIButton *_doneBtn;
    UIButton *_clearBtn;
    UIButton *_cancelBtn;

    NSLayoutConstraint *_headerHeight;
    NSLayoutConstraint *_popupWidthConstraint;
    // Fixed height for the wheels sheet; deactivated elsewhere, where the
    // picker sizes itself. Attached to the long-lived date picker, created once.
    NSLayoutConstraint *_datePickerHeight;
    // Configuration the controls were last built for; controls are rebuilt
    // when the requested configuration changes between presentations.
    BOOL _builtAsPopup;
    BOOL _builtAsPopover;
    BOOL _builtAsInline;
    BOOL _builtWithToolbar;

    UIColor *lightBackgroundColor;
    UIColor *lightCapsuleFillColor;
    UIColor *darkBackgroundColor;
    UIColor *darkCapsuleFillColor;
}

- (id)init {
    if ((self = [super init])) {
        _datePicker = [[UIDatePicker alloc] init];
        _showToolbar = YES;
    }

    return self;
}

- (UIView *)contentView {
    return _internalView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor clearColor];
    self.view.opaque = NO;

    // Tapping outside the sheet/popup dismisses it, like the native sheet's
    // dimmed area. (In popover presentation the view only covers the content,
    // so this never fires; the popover itself handles outside taps.)
    UITapGestureRecognizer *backgroundTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
    backgroundTap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:backgroundTap];

    [self createSwatches];
    [self createControls];
}

- (void)didReceiveMemoryWarning {
    if (!(self.isViewLoaded && self.view.window)) {
        [self teardownControls];

        lightBackgroundColor = nil;
        darkBackgroundColor = nil;
        lightCapsuleFillColor = nil;
        darkCapsuleFillColor = nil;
    }

    [super didReceiveMemoryWarning];
}

- (void)teardownControls {
    [_internalView removeFromSuperview];
    [_datePicker removeFromSuperview];
    // Do NOT reset datepicker ref (nor its reusable height constraint).
    _headerView = nil;
    _titleLabel = nil;
    _footerView = nil;
    _footerSeparator = nil;
    _internalView = nil;

    _doneBtn = nil;
    _clearBtn = nil;
    _cancelBtn = nil;

    _headerHeight = nil;
    _popupWidthConstraint = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (!_internalView) {
        [self createSwatches];
        [self createControls];
    } else if (_builtAsPopup != self.popupPresentation
               || _builtAsPopover != self.popoverPresentation
               || _builtAsInline != self.inlinePicker
               || _builtWithToolbar != self.showToolbar
               // The date picker is detached when its style is reset (see
               // configureDatePicker); rebuild to re-add it.
               || _datePicker.superview == nil) {
        // The requested configuration changed since the last presentation; rebuild.
        [self teardownControls];
        [self createControls];
    }

    // Update texts.
    _titleLabel.text = _titleText != (id)[NSNull null] && _titleText.length > 0 ? _titleText : nil;

    NSString *doneTitle = _doneText != (id)[NSNull null] && _doneText.length > 0 ? _doneText : UIKitLocalizedString(@"Done");
    NSString *cancelTitle = _cancelText != (id)[NSNull null] && _cancelText.length > 0 ? _cancelText : UIKitLocalizedString(@"Cancel");
    [_doneBtn setTitle:doneTitle forState:UIControlStateNormal];
    [_cancelBtn setTitle:cancelTitle forState:UIControlStateNormal];

    // Show clear button when clear text is set
    if (_clearText != (id)[NSNull null] && _clearText.length > 0) {
        [_clearBtn setTitle:_clearText forState:UIControlStateNormal];
        _clearBtn.hidden = NO;
    } else {
        [_clearBtn setTitle:nil forState:UIControlStateNormal];
        _clearBtn.hidden = YES;
    }

    // The popup width may change between presentations.
    if (_popupWidthConstraint) {
        _popupWidthConstraint.constant = self.popupWidth > 0 ? self.popupWidth : kPopupWidth;
    }

    // The popover is sized to fit its content, optionally capped in width
    // (in which case the height is re-measured for the capped width).
    if (self.popoverPresentation) {
        [self updateStyles];
        CGSize size = [_internalView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        if (self.popoverMaxWidth > 0 && size.width > self.popoverMaxWidth) {
            size = [_internalView systemLayoutSizeFittingSize:CGSizeMake(self.popoverMaxWidth, UILayoutFittingCompressedSize.height)
                                withHorizontalFittingPriority:UILayoutPriorityRequired
                                      verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
            size.width = self.popoverMaxWidth;
        }
        self.preferredContentSize = size;
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillLayoutSubviews {
    [self updateStyles];
    [super viewWillLayoutSubviews];
}

- (void)traitCollectionDidChange: (UITraitCollection *) previousTraitCollection {
    [self updateStyles];
    [super traitCollectionDidChange: previousTraitCollection];
}

#pragma mark - Controls/styling

- (void)createControls {
    _builtAsPopup = self.popupPresentation;
    _builtAsPopover = self.popoverPresentation;
    _builtAsInline = self.inlinePicker;
    _builtWithToolbar = self.showToolbar;
    BOOL popupLike = self.popupPresentation || self.popoverPresentation;
    // The calendar always gets the footer layout (title on top, buttons below a
    // hairline), even in the sheet; wheels in the sheet keep the header buttons.
    BOOL footerLayout = popupLike || self.inlinePicker;

    // Create a view that will host our controls: a floating card above the
    // bottom safe area (sheet), a centered popup, or the content of a popover
    // (which draws its own rounded container).
    _internalView = [[UIView alloc] init];
    _internalView.opaque = FALSE;
    _internalView.layer.cornerRadius = self.popoverPresentation ? 0 : kSheetCornerRadius;
    if (@available(iOS 13, *)) {
        // Apple's continuous ("squircle") corner curve, like the native sheet.
        _internalView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    _internalView.layer.masksToBounds = TRUE;

    [_internalView addSubview:_datePicker];

    if (self.showToolbar) {
        // Header: title only (popup/popover), or title and buttons (sheet).
        _headerView = [[UIView alloc] init];
        _headerView.backgroundColor = [UIColor clearColor];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textAlignment = NSTextAlignmentCenter;

        _doneBtn = [self createButtonWithAction:@selector(doneButtonTapped:)];
        _clearBtn = [self createButtonWithAction:@selector(clearButtonTapped:)];
        _cancelBtn = [self createButtonWithAction:@selector(cancelButtonTapped:)];

        [_headerView addSubview:_titleLabel];
        [_internalView addSubview:_headerView];
        if (footerLayout) {
            // Buttons go into a footer, below a thin separator line.
            _footerView = [[UIView alloc] init];
            _footerView.backgroundColor = [UIColor clearColor];
            _footerSeparator = [[UIView alloc] init];
            [_footerView addSubview:_footerSeparator];
            [_footerView addSubview:_cancelBtn];
            [_footerView addSubview:_clearBtn];
            [_footerView addSubview:_doneBtn];
            [_internalView addSubview:_footerView];
        } else {
            [_headerView addSubview:_cancelBtn];
            [_headerView addSubview:_clearBtn];
            [_headerView addSubview:_doneBtn];
        }
    }
    [self.view addSubview:_internalView];

    // Set constraints.
    _internalView.translatesAutoresizingMaskIntoConstraints = FALSE;
    _datePicker.translatesAutoresizingMaskIntoConstraints = FALSE;
    _headerView.translatesAutoresizingMaskIntoConstraints = FALSE;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = FALSE;
    _footerView.translatesAutoresizingMaskIntoConstraints = FALSE;
    _footerSeparator.translatesAutoresizingMaskIntoConstraints = FALSE;
    _doneBtn.translatesAutoresizingMaskIntoConstraints = FALSE;
    _clearBtn.translatesAutoresizingMaskIntoConstraints = FALSE;
    _cancelBtn.translatesAutoresizingMaskIntoConstraints = FALSE;

    // Fixed picker height for the wheels sheet; the inline calendar and the
    // popup/popover presentations let the picker size itself.
    if (!_datePickerHeight) {
        _datePickerHeight = [_datePicker.heightAnchor constraintEqualToConstant:kDatePickerHeight];
    }
    _datePickerHeight.active = !popupLike && !self.inlinePicker;

    // Container placement.
    if (self.popoverPresentation) {
        // The view is the popover's content; fill it edge to edge.
        [NSLayoutConstraint activateConstraints:@[
            [_internalView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [_internalView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [_internalView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [_internalView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        ]];
    } else if (self.popupPresentation) {
        // Centered popup; width capped, height follows the content's own size.
        _popupWidthConstraint = [_internalView.widthAnchor constraintEqualToConstant:self.popupWidth > 0 ? self.popupWidth : kPopupWidth];
        _popupWidthConstraint.priority = UILayoutPriorityDefaultHigh;

        [NSLayoutConstraint activateConstraints:@[
            [_internalView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [_internalView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
            [_internalView.widthAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-2 * kSheetMargin],
            _popupWidthConstraint,
        ]];
    } else {
        // Floating card with side margins, anchored to the bottom safe area
        // (which already leaves a comfortable gap to the screen edge).
        [NSLayoutConstraint activateConstraints:@[
            [_internalView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:kSheetMargin],
            [_internalView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-kSheetMargin],
            [_internalView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        ]];
    }

    // Content layout.
    if (!self.showToolbar) {
        // Just the picker; dismissing confirms the selection.
        CGFloat padding = popupLike ? kPopupContentPadding : 0;
        CGFloat topPadding = popupLike ? kPopupContentPadding : kHeaderTopPadding;
        [NSLayoutConstraint activateConstraints:@[
            [_datePicker.topAnchor constraintEqualToAnchor:_internalView.topAnchor constant:topPadding],
            [_datePicker.leadingAnchor constraintEqualToAnchor:_internalView.leadingAnchor constant:padding],
            [_datePicker.trailingAnchor constraintEqualToAnchor:_internalView.trailingAnchor constant:-padding],
            [_datePicker.bottomAnchor constraintEqualToAnchor:_internalView.bottomAnchor constant:-padding],
        ]];
        return;
    }

    _headerHeight = [_headerView.heightAnchor constraintEqualToConstant:kHeaderBarHeight];

    if (footerLayout) {
        // Title on top (collapsed when empty), buttons in a footer at the bottom.
        CGFloat hairline = 1.0 / UIScreen.mainScreen.scale;

        [NSLayoutConstraint activateConstraints:@[
            [_headerView.topAnchor constraintEqualToAnchor:_internalView.topAnchor],
            [_headerView.leadingAnchor constraintEqualToAnchor:_internalView.leadingAnchor],
            [_headerView.trailingAnchor constraintEqualToAnchor:_internalView.trailingAnchor],
            _headerHeight,

            [_titleLabel.centerXAnchor constraintEqualToAnchor:_headerView.centerXAnchor],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],
            [_titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:_headerView.leadingAnchor constant:kHeaderButtonInset],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_headerView.trailingAnchor constant:-kHeaderButtonInset],

            [_datePicker.topAnchor constraintEqualToAnchor:_headerView.bottomAnchor],
            [_datePicker.leadingAnchor constraintEqualToAnchor:_internalView.leadingAnchor constant:kPopupContentPadding],
            [_datePicker.trailingAnchor constraintEqualToAnchor:_internalView.trailingAnchor constant:-kPopupContentPadding],
            [_datePicker.bottomAnchor constraintEqualToAnchor:_footerView.topAnchor],

            [_footerView.leadingAnchor constraintEqualToAnchor:_internalView.leadingAnchor],
            [_footerView.trailingAnchor constraintEqualToAnchor:_internalView.trailingAnchor],
            [_footerView.bottomAnchor constraintEqualToAnchor:_internalView.bottomAnchor],
            [_footerView.heightAnchor constraintEqualToConstant:kPopupFooterHeight],

            [_footerSeparator.topAnchor constraintEqualToAnchor:_footerView.topAnchor],
            [_footerSeparator.leadingAnchor constraintEqualToAnchor:_footerView.leadingAnchor],
            [_footerSeparator.trailingAnchor constraintEqualToAnchor:_footerView.trailingAnchor],
            [_footerSeparator.heightAnchor constraintEqualToConstant:hairline],

            [_cancelBtn.leadingAnchor constraintEqualToAnchor:_footerView.leadingAnchor constant:kHeaderButtonInset],
            [_cancelBtn.centerYAnchor constraintEqualToAnchor:_footerView.centerYAnchor],

            [_doneBtn.trailingAnchor constraintEqualToAnchor:_footerView.trailingAnchor constant:-kHeaderButtonInset],
            [_doneBtn.centerYAnchor constraintEqualToAnchor:_footerView.centerYAnchor],

            [_clearBtn.trailingAnchor constraintEqualToAnchor:_doneBtn.leadingAnchor constant:-kHeaderButtonInset],
            [_clearBtn.centerYAnchor constraintEqualToAnchor:_footerView.centerYAnchor],
        ]];
    } else {
        // Keep the title centered, but never let it overlap the buttons.
        NSLayoutConstraint *titleCenterX = [_titleLabel.centerXAnchor constraintEqualToAnchor:_headerView.centerXAnchor];
        titleCenterX.priority = UILayoutPriorityDefaultHigh;

        [NSLayoutConstraint activateConstraints:@[
            [_headerView.topAnchor constraintEqualToAnchor:_internalView.topAnchor constant:kHeaderTopPadding],
            [_headerView.leadingAnchor constraintEqualToAnchor:_internalView.leadingAnchor],
            [_headerView.trailingAnchor constraintEqualToAnchor:_internalView.trailingAnchor],
            _headerHeight,

            [_cancelBtn.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:kHeaderButtonInset],
            [_cancelBtn.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],

            [_doneBtn.trailingAnchor constraintEqualToAnchor:_headerView.trailingAnchor constant:-kHeaderButtonInset],
            [_doneBtn.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],

            [_clearBtn.trailingAnchor constraintEqualToAnchor:_doneBtn.leadingAnchor constant:-kHeaderButtonGap],
            [_clearBtn.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],

            titleCenterX,
            [_titleLabel.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],
            [_titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:_cancelBtn.trailingAnchor constant:kHeaderButtonGap],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_clearBtn.leadingAnchor constant:-kHeaderButtonGap],

            [_datePicker.topAnchor constraintEqualToAnchor:_headerView.bottomAnchor],
            [_datePicker.leadingAnchor constraintEqualToAnchor:_internalView.leadingAnchor],
            [_datePicker.trailingAnchor constraintEqualToAnchor:_internalView.trailingAnchor],
            [_datePicker.bottomAnchor constraintEqualToAnchor:_internalView.bottomAnchor],
        ]];
    }
}

- (UIButton *)createButtonWithAction:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.contentEdgeInsets = UIEdgeInsetsMake(7, 14, 7, 14);
    button.layer.cornerRadius = kCapsuleButtonCornerRadius;
    button.layer.masksToBounds = TRUE;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)createSwatches {
    lightBackgroundColor = [UIColor colorWithR:242 G:242 B:247 A:1];
    darkBackgroundColor = [UIColor colorWithR:44 G:44 B:46 A:1];
    lightCapsuleFillColor = [UIColor colorWithR:120 G:120 B:128 A:0.16];
    darkCapsuleFillColor = [UIColor colorWithR:120 G:120 B:128 A:0.32];
}

- (void)updateStyles {
    if (!_internalView) return;

    BOOL footerLayout = _builtAsPopup || _builtAsPopover || _builtAsInline;

    // System font may have changed.
    CGFloat buttonFontSize = [UIFont systemFontSize] * 1.05;
    _doneBtn.titleLabel.font = [UIFont boldSystemFontOfSize:buttonFontSize];
    _clearBtn.titleLabel.font = [UIFont systemFontOfSize:buttonFontSize];
    _cancelBtn.titleLabel.font = [UIFont systemFontOfSize:buttonFontSize];
    _titleLabel.font = [UIFont systemFontOfSize:buttonFontSize weight:UIFontWeightSemibold];

    if (_headerHeight) {
        if (footerLayout) {
            // Title area is only shown when there is a title.
            _headerHeight.constant = _titleLabel.text.length > 0 ? kPopupTitleHeight : 0;
        } else {
            // Switch between large/small header height depending on orientation.
            BOOL compactHeight = self.view.bounds.size.width >= self.view.bounds.size.height;
            _headerHeight.constant = compactHeight ? kHeaderBarHeightSmall : kHeaderBarHeight;
        }
    }

    // Switching light/dark mode.
    UIColor *backgroundColor = lightBackgroundColor;
    UIColor *capsuleFillColor = lightCapsuleFillColor;
    UIColor *labelColor = [UIColor blackColor];
    UIColor *separatorColor = [UIColor colorWithWhite:0.5 alpha:0.3];
    if (@available(iOS 13, *)) {
        labelColor = [UIColor labelColor];
        separatorColor = [UIColor separatorColor];
    }

    if (@available(iOS 12, *)) {
        BOOL isDarkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        if (isDarkMode) {
            backgroundColor = darkBackgroundColor;
            capsuleFillColor = darkCapsuleFillColor;
        }
    }

    // One unified background color for the whole sheet (header + picker).
    _internalView.backgroundColor = backgroundColor;
    _datePicker.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = labelColor;
    _footerSeparator.backgroundColor = separatorColor;

    if (_builtAsPopover) {
        // Color the whole view and the popover container (incl. the arrow).
        self.view.backgroundColor = backgroundColor;
        self.popoverPresentationController.backgroundColor = backgroundColor;
    }

    if (!_doneBtn || !_cancelBtn || !_clearBtn) return;

    UIColor *tintColor = self.view.tintColor ?: [UIColor systemBlueColor];
    if (footerLayout) {
        // Footer: plain text buttons, tinted like alert actions.
        for (UIButton *button in @[_doneBtn, _cancelBtn, _clearBtn]) {
            button.backgroundColor = [UIColor clearColor];
            [button setTitleColor:tintColor forState:UIControlStateNormal];
            button.tintColor = tintColor;
        }
    } else {
        // Done: filled with the tint color. Cancel/clear: subtle gray capsule.
        _doneBtn.backgroundColor = tintColor;
        [_doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _doneBtn.tintColor = [UIColor whiteColor];

        for (UIButton *button in @[_cancelBtn, _clearBtn]) {
            button.backgroundColor = capsuleFillColor;
            [button setTitleColor:labelColor forState:UIControlStateNormal];
            button.tintColor = labelColor;
        }
    }
}

#pragma mark - Utils

NSString *UIKitLocalizedString(NSString *key) {
    return [[NSBundle bundleForClass:UIApplication.class] localizedStringForKey:key value:nil table:nil];
}

#pragma mark - Button handlers

- (void)backgroundTapped:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) return;

    // Only dismiss for taps outside the sheet.
    CGPoint location = [recognizer locationInView:self.view];
    if (_internalView && !CGRectContainsPoint(_internalView.frame, location)) {
        [self dismissViewControllerAnimated:true completion:^(void) {
            // Without a toolbar there are no buttons, so dismissing confirms
            // the selection; with a toolbar it cancels.
            if (self.showToolbar) {
                if (self.cancelHandler != nil) [self cancelHandler]();
            } else {
                if (self.doneHandler != nil) [self doneHandler](self);
            }
        }];
    }
}

- (void)doneButtonTapped:(UIButton*)sender {
    [self dismissViewControllerAnimated:true completion:^(void) {
        // Call the callback.
        if (self.doneHandler != nil) [self doneHandler](self);
    }];
}

- (void)cancelButtonTapped:(UIButton*)sender {
    [self dismissViewControllerAnimated:true completion:^(void) {
        // Call the callback.
        if (self.cancelHandler != nil) [self cancelHandler]();
    }];
}

- (void)clearButtonTapped:(UIButton*)sender {
    [self dismissViewControllerAnimated:true completion:^(void) {
        // Call the callback.
        if (self.doneHandler != nil) [self doneHandler](nil);
    }];
}
@end
