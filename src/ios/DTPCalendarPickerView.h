#import <UIKit/UIKit.h>

// A date (and time) picker built on UICalendarView, iOS 16+.
//
// UICalendarView is the same calendar grid the inline UIDatePicker draws, but
// it can decorate individual days (a dot, an image or a small custom view
// under the day number), which UIDatePicker cannot. Two things the inline
// picker does by itself have to be rebuilt here:
// - date + time: a "Time" row with a compact time picker under the calendar,
//   which is the same pill control the inline picker shows there;
// - the result: the selected day combined with the time of that row.
//
// Decorations are keyed by Gregorian "yyyy-MM-dd". Each value is a dictionary:
//   style: "dot" (default) | "bar" | "label" | "image"
//   color: "#rrggbb" (defaults to the tint color)
//   size:  "small" | "medium" | "large" (dot/image; default medium)
//   text:  the label text (style "label")
//   image: an SF Symbol name (style "image")
// UIKit clips decorations to the small area under the day number and makes
// them non-interactive; a bar spans that area's width, a label shrinks its
// font to fit it.
API_AVAILABLE(ios(16.0))
@interface DTPCalendarPickerView : UIView

- (instancetype)initWithLocale:(NSLocale *)locale showTime:(BOOL)showTime timeText:(NSString *)timeText;

@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *decorations;
@property (nonatomic, strong) NSDate *minimumDate;
@property (nonatomic, strong) NSDate *maximumDate;
@property (nonatomic, assign) NSInteger minuteInterval;

// The selected day at the time of the time row (midnight without the row).
// Setting it also scrolls the calendar to that month.
@property (nonatomic, strong) NSDate *date;

@end
