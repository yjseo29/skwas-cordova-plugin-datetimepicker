#import "DTPCalendarPickerView.h"
#import "Extensions.h"

// Matches the row the inline UIDatePicker draws: aligned with the calendar's
// own horizontal padding, headline label, no separator.
static const CGFloat kTimeRowHeight = 44;
static const CGFloat kTimeRowInset = 10;
static const CGFloat kBarHeight = 3;
static const CGFloat kLabelFontSize = 9;

#pragma mark - Decoration views

// A bar under the day number. UIKit decides the decoration's frame (and clips
// to it); the bar fills that frame's width so adjacent days read as one line.
@interface DTPBarDecorationView : UIView
@end

@implementation DTPBarDecorationView {
    UIView *_bar;
}

- (instancetype)initWithColor:(UIColor *)color {
    if ((self = [super initWithFrame:CGRectZero])) {
        self.backgroundColor = [UIColor clearColor];
        _bar = [[UIView alloc] init];
        _bar.backgroundColor = color;
        _bar.layer.cornerRadius = kBarHeight / 2;
        [self addSubview:_bar];
    }
    return self;
}

// Ask for more width than a day has: UIKit clips the decoration to the area
// under the number, so the bar ends up as wide as that area.
- (CGSize)intrinsicContentSize {
    return CGSizeMake(200, kBarHeight);
}

- (CGSize)sizeThatFits:(CGSize)size {
    return CGSizeMake(size.width > 0 ? size.width : 200, kBarHeight);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _bar.frame = CGRectMake(0, (self.bounds.size.height - kBarHeight) / 2, self.bounds.size.width, kBarHeight);
}

@end

// A small text under the day number ("start", "end"). Words differ in length
// between languages, so the width is capped to the day's area and the font
// shrinks to fit instead of the text being clipped.
@interface DTPLabelDecorationView : UILabel
@end

@implementation DTPLabelDecorationView

- (instancetype)initWithText:(NSString *)text color:(UIColor *)color {
    if ((self = [super initWithFrame:CGRectZero])) {
        self.text = text;
        self.textColor = color;
        self.font = [UIFont systemFontOfSize:kLabelFontSize weight:UIFontWeightSemibold];
        self.textAlignment = NSTextAlignmentCenter;
        self.adjustsFontSizeToFitWidth = YES;
        self.minimumScaleFactor = 0.6;
        self.lineBreakMode = NSLineBreakByClipping;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize natural = [super sizeThatFits:size];
    if (size.width > 0 && natural.width > size.width) natural.width = size.width;
    return natural;
}

@end

#pragma mark - Helpers

static UIColor *DTPColorFromHex(id value) {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *hex = [(NSString *)value stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (hex.length != 6 && hex.length != 8) return nil;

    unsigned int rgb = 0;
    if (![[NSScanner scannerWithString:hex] scanHexInt:&rgb]) return nil;

    if (hex.length == 8) {
        return [UIColor colorWithRed:((rgb >> 24) & 0xFF) / 255.0 green:((rgb >> 16) & 0xFF) / 255.0 blue:((rgb >> 8) & 0xFF) / 255.0 alpha:(rgb & 0xFF) / 255.0];
    }
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0 green:((rgb >> 8) & 0xFF) / 255.0 blue:(rgb & 0xFF) / 255.0 alpha:1];
}

static UICalendarViewDecorationSize DTPDecorationSize(id value) API_AVAILABLE(ios(16.0)) {
    NSString *size = [value isKindOfClass:NSString.class] ? [(NSString *)value lowercaseString] : @"";
    if ([size isEqualToString:@"small"]) return UICalendarViewDecorationSizeSmall;
    if ([size isEqualToString:@"large"]) return UICalendarViewDecorationSizeLarge;
    return UICalendarViewDecorationSizeMedium;
}

#pragma mark - DTPCalendarPickerView

@interface DTPCalendarPickerView () <UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate>
@end

@implementation DTPCalendarPickerView {
    UICalendarView *_calendarView;
    UICalendarSelectionSingleDate *_selection;
    NSCalendar *_gregorian;
    NSDateComponents *_selectedDay;

    UIView *_timeRow;
    UILabel *_timeLabel;
    UIDatePicker *_timePicker;
}

@dynamic date;

- (instancetype)initWithLocale:(NSLocale *)locale showTime:(BOOL)showTime timeText:(NSString *)timeText {
    if ((self = [super initWithFrame:CGRectZero])) {
        _gregorian = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        _minuteInterval = 1;

        // Same defaults as UIDatePicker: the user's calendar, the given locale.
        _calendarView = [[UICalendarView alloc] init];
        _calendarView.calendar = [NSCalendar currentCalendar];
        _calendarView.locale = locale;
        _calendarView.delegate = self;
        _calendarView.wantsDateDecorations = YES;
        _calendarView.backgroundColor = [UIColor clearColor];
        _calendarView.translatesAutoresizingMaskIntoConstraints = NO;

        _selection = [[UICalendarSelectionSingleDate alloc] initWithDelegate:self];
        _calendarView.selectionBehavior = _selection;

        [self addSubview:_calendarView];
        [NSLayoutConstraint activateConstraints:@[
            [_calendarView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_calendarView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_calendarView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        ]];

        if (showTime) {
            [self createTimeRowWithLocale:locale text:timeText];
            [NSLayoutConstraint activateConstraints:@[
                [_timeRow.topAnchor constraintEqualToAnchor:_calendarView.bottomAnchor],
                [_timeRow.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [_timeRow.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
                [_timeRow.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            ]];
        } else {
            [[_calendarView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor] setActive:YES];
        }
    }
    return self;
}

// The "Time" row the inline UIDatePicker shows under its calendar: a label and
// the compact time picker (the pill that pops up the time wheels).
- (void)createTimeRowWithLocale:(NSLocale *)locale text:(NSString *)text {
    _timeRow = [[UIView alloc] init];
    _timeRow.translatesAutoresizingMaskIntoConstraints = NO;

    _timeLabel = [[UILabel alloc] init];
    _timeLabel.text = text.length > 0 ? text : ([[NSBundle bundleForClass:UIApplication.class] localizedStringForKey:@"Time" value:@"Time" table:nil]);
    _timeLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    _timeLabel.textColor = [UIColor labelColor];
    _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _timePicker = [[UIDatePicker alloc] init];
    _timePicker.datePickerMode = UIDatePickerModeTime;
    _timePicker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    _timePicker.locale = locale;
    _timePicker.translatesAutoresizingMaskIntoConstraints = NO;

    [_timeRow addSubview:_timeLabel];
    [_timeRow addSubview:_timePicker];
    [self addSubview:_timeRow];

    [NSLayoutConstraint activateConstraints:@[
        [_timeRow.heightAnchor constraintEqualToConstant:kTimeRowHeight],

        [_timeLabel.leadingAnchor constraintEqualToAnchor:_timeRow.leadingAnchor constant:kTimeRowInset],
        [_timeLabel.centerYAnchor constraintEqualToAnchor:_timeRow.centerYAnchor],

        [_timePicker.trailingAnchor constraintEqualToAnchor:_timeRow.trailingAnchor constant:-kTimeRowInset],
        [_timePicker.centerYAnchor constraintEqualToAnchor:_timeRow.centerYAnchor],
        [_timePicker.leadingAnchor constraintGreaterThanOrEqualToAnchor:_timeLabel.trailingAnchor constant:8],
    ]];
}

#pragma mark - Properties

- (void)setMinimumDate:(NSDate *)minimumDate {
    _minimumDate = minimumDate;
    [self updateAvailableDateRange];
}

- (void)setMaximumDate:(NSDate *)maximumDate {
    _maximumDate = maximumDate;
    [self updateAvailableDateRange];
}

- (void)updateAvailableDateRange {
    NSDate *start = _minimumDate ?: [NSDate distantPast];
    NSDate *end = _maximumDate ?: [NSDate distantFuture];
    if ([end compare:start] == NSOrderedAscending) end = start;
    _calendarView.availableDateRange = [[NSDateInterval alloc] initWithStartDate:start endDate:end];
}

- (void)setMinuteInterval:(NSInteger)minuteInterval {
    _minuteInterval = minuteInterval;
    _timePicker.minuteInterval = minuteInterval;
}

- (NSDate *)date {
    NSCalendar *calendar = _calendarView.calendar;
    NSDateComponents *day = _selectedDay ?: _selection.selectedDate;
    NSDate *dayDate = day ? [calendar dateFromComponents:[self dayComponents:day]] : [calendar startOfDayForDate:[NSDate date]];
    if (!_timePicker) return dayDate;

    NSDateComponents *time = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:_timePicker.date];
    return [calendar dateBySettingHour:time.hour minute:time.minute second:0 ofDate:dayDate options:0] ?: dayDate;
}

- (void)setDate:(NSDate *)date {
    NSCalendar *calendar = _calendarView.calendar;
    NSDateComponents *day = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    _selectedDay = day;
    [_selection setSelectedDate:day animated:NO];
    _calendarView.visibleDateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth fromDate:date];
    if (_timePicker) [_timePicker setDate:date animated:NO];
}

// Only year/month/day, whatever else the selection components carry.
- (NSDateComponents *)dayComponents:(NSDateComponents *)components {
    NSDateComponents *day = [[NSDateComponents alloc] init];
    day.year = components.year;
    day.month = components.month;
    day.day = components.day;
    return day;
}

#pragma mark - UICalendarViewDelegate

- (UICalendarViewDecoration *)calendarView:(UICalendarView *)calendarView decorationForDateComponents:(NSDateComponents *)dateComponents {
    if (_decorations.count == 0) return nil;

    // Decorations are keyed by Gregorian day, whatever calendar the view uses.
    NSDate *date = [calendarView.calendar dateFromComponents:[self dayComponents:dateComponents]];
    if (!date) return nil;
    NSDateComponents *gregorian = [_gregorian components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    NSDictionary *decoration = _decorations[[NSString stringWithFormat:@"%04ld-%02ld-%02ld", (long)gregorian.year, (long)gregorian.month, (long)gregorian.day]];
    if (![decoration isKindOfClass:NSDictionary.class]) return nil;

    NSString *style = [decoration[@"style"] isKindOfClass:NSString.class] ? [decoration[@"style"] lowercaseString] : @"dot";
    UIColor *color = DTPColorFromHex(decoration[@"color"]) ?: self.tintColor;

    if ([style isEqualToString:@"bar"]) {
        return [UICalendarViewDecoration decorationWithCustomViewProvider:^UIView *{
            return [[DTPBarDecorationView alloc] initWithColor:color];
        }];
    }
    if ([style isEqualToString:@"label"]) {
        NSString *text = [decoration[@"text"] isKindOfClass:NSString.class] ? decoration[@"text"] : @"";
        return [UICalendarViewDecoration decorationWithCustomViewProvider:^UIView *{
            return [[DTPLabelDecorationView alloc] initWithText:text color:color];
        }];
    }
    if ([style isEqualToString:@"image"]) {
        NSString *name = [decoration[@"image"] isKindOfClass:NSString.class] ? decoration[@"image"] : @"";
        UIImage *image = [UIImage systemImageNamed:name];
        if (image) return [UICalendarViewDecoration decorationWithImage:image color:color size:DTPDecorationSize(decoration[@"size"])];
    }
    return [UICalendarViewDecoration decorationWithColor:color size:DTPDecorationSize(decoration[@"size"])];
}

#pragma mark - UICalendarSelectionSingleDateDelegate

- (void)dateSelection:(UICalendarSelectionSingleDate *)selection didSelectDate:(NSDateComponents *)dateComponents {
    if (dateComponents == nil) {
        // Tapping the selected day again deselects it; a picker always has a value.
        if (_selectedDay) [selection setSelectedDate:_selectedDay animated:NO];
        return;
    }
    _selectedDay = dateComponents;
}

- (BOOL)dateSelection:(UICalendarSelectionSingleDate *)selection canSelectDate:(NSDateComponents *)dateComponents {
    return YES;
}

@end
