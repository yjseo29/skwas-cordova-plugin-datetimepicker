#import <UIKit/UIKit.h>

@interface ModalPickerViewController : UIViewController {
}

- (id)init;

// The sheet (card) view; used by the transition animator to slide only the sheet.
@property (nonatomic, readonly) UIView *contentView;

// When YES, the picker is shown as a centered popup instead of a bottom
// sheet. The transition animator fades and scales the popup rather than
// sliding it up.
@property (nonatomic, assign) BOOL popupPresentation;

// When YES, the picker is presented inside a UIPopoverPresentationController
// anchored to an element: the content fills the popover and the system
// handles positioning, the arrow, and the dismissal animation.
@property (nonatomic, assign) BOOL popoverPresentation;

// When YES, the date picker uses the inline (calendar) style, which sizes
// itself; when NO, the wheels style is used.
@property (nonatomic, assign) BOOL inlinePicker;

// When NO, the title and buttons are hidden: only the picker is shown, and
// dismissing (tapping outside) confirms the selection. Defaults to YES.
@property (nonatomic, assign) BOOL showToolbar;

// Width of the centered popup in points; 0 uses the default (360). Always
// capped to the screen width by a required layout constraint.
@property (nonatomic, assign) CGFloat popupWidth;

// Maximum width of the popover content in points; 0 sizes the popover to its
// content.
@property (nonatomic, assign) CGFloat popoverMaxWidth;

@property (strong) NSString *titleText;
@property (strong) NSString *doneText;
@property (strong) NSString *cancelText;
@property (strong) NSString *clearText;
@property (strong) UIDatePicker *datePicker;
@property (nonatomic, strong) void (^doneHandler)(id sender);
@property (nonatomic, strong) void (^cancelHandler)();

@end
