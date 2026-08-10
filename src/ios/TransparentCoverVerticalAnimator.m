#import "TransparentCoverVerticalAnimator.h"
#import "ModalPickerViewController.h"

// Spring-based slide-up for the sheet, fade/scale for the calendar popup,
// matching the feel of the standard iOS presentations.
static const NSTimeInterval kPresentDuration = 0.45;
static const NSTimeInterval kDismissDuration = 0.3;
static const NSTimeInterval kPopupPresentDuration = 0.3;
static const NSTimeInterval kPopupDismissDuration = 0.2;
static const CGFloat kDimAlpha = 0.25;
static const CGFloat kPopupInitialScale = 1.1;

@implementation TransparentCoverVerticalAnimator

static BOOL isCalendarPopup(UIViewController *viewController) {
    return [viewController isKindOfClass:ModalPickerViewController.class]
        && ((ModalPickerViewController *)viewController).popupPresentation;
}

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *presented = [transitionContext viewControllerForKey:
        self.presenting ? UITransitionContextToViewControllerKey : UITransitionContextFromViewControllerKey];
    if (isCalendarPopup(presented)) {
        return self.presenting ? kPopupPresentDuration : kPopupDismissDuration;
    }
    return self.presenting ? kPresentDuration : kDismissDuration;
}

// The sheet (card) inside the presented view controller's full-screen view.
static UIView *sheetViewForController(UIViewController *viewController) {
    if ([viewController isKindOfClass:ModalPickerViewController.class]) {
        UIView *contentView = ((ModalPickerViewController *)viewController).contentView;
        if (contentView) return contentView;
    }
    return viewController.view.subviews.firstObject;
}

// Distance the sheet has to travel to be fully offscreen (its height + gap to the bottom edge).
static CGFloat offscreenOffsetForSheet(UIView *sheet, UIView *containerView) {
    if (!sheet) return containerView.bounds.size.height;
    CGRect sheetFrame = [sheet convertRect:sheet.bounds toView:containerView];
    return containerView.bounds.size.height - CGRectGetMinY(sheetFrame);
}

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext {
    // Grab the from and to view controllers from the context
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];

    if (self.presenting) {
        fromViewController.view.userInteractionEnabled = NO;

        UIView *toView = toViewController.view;
        toView.frame = [transitionContext finalFrameForViewController:toViewController];
        [transitionContext.containerView addSubview:toView];
        [toView layoutIfNeeded];

        UIView *sheet = sheetViewForController(toViewController);
        toView.backgroundColor = [UIColor clearColor];

        if (isCalendarPopup(toViewController)) {
            // Popup: fade in while scaling down into place.
            sheet.alpha = 0;
            sheet.transform = CGAffineTransformMakeScale(kPopupInitialScale, kPopupInitialScale);

            [UIView animateWithDuration:kPopupPresentDuration
                                  delay:0
                 usingSpringWithDamping:1.0
                  initialSpringVelocity:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                sheet.alpha = 1;
                sheet.transform = CGAffineTransformIdentity;
                toView.backgroundColor = [UIColor colorWithWhite:0 alpha:kDimAlpha];
            } completion:^(BOOL finished) {
                [transitionContext completeTransition:YES];
            }];
        } else {
            // Sheet: slide up from the bottom edge.
            CGFloat offset = offscreenOffsetForSheet(sheet, transitionContext.containerView);
            sheet.transform = CGAffineTransformMakeTranslation(0, offset);

            [UIView animateWithDuration:kPresentDuration
                                  delay:0
                 usingSpringWithDamping:1.0
                  initialSpringVelocity:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                sheet.transform = CGAffineTransformIdentity;
                toView.backgroundColor = [UIColor colorWithWhite:0 alpha:kDimAlpha];
            } completion:^(BOOL finished) {
                [transitionContext completeTransition:YES];
            }];
        }
    }
    else {
        toViewController.view.userInteractionEnabled = YES;

        UIView *fromView = fromViewController.view;
        UIView *sheet = sheetViewForController(fromViewController);

        if (isCalendarPopup(fromViewController)) {
            // Popup: quick fade out.
            [UIView animateWithDuration:kPopupDismissDuration
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                sheet.alpha = 0;
                fromView.backgroundColor = [UIColor clearColor];
            } completion:^(BOOL finished) {
                sheet.alpha = 1;
                [transitionContext completeTransition:YES];
            }];
        } else {
            // Sheet: slide down below the bottom edge.
            CGFloat offset = offscreenOffsetForSheet(sheet, transitionContext.containerView);

            [UIView animateWithDuration:kDismissDuration
                                  delay:0
                 usingSpringWithDamping:1.0
                  initialSpringVelocity:0
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                sheet.transform = CGAffineTransformMakeTranslation(0, offset);
                fromView.backgroundColor = [UIColor clearColor];
            } completion:^(BOOL finished) {
                sheet.transform = CGAffineTransformIdentity;
                [transitionContext completeTransition:YES];
            }];
        }
    }
}

@end
