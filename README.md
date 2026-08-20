[![npm version](https://badge.fury.io/js/skwas-cordova-plugin-datetimepicker.svg)](https://badge.fury.io/js/skwas-cordova-plugin-datetimepicker)
[![Node CI](https://github.com/skwasjer/skwas-cordova-plugin-datetimepicker/actions/workflows/ci.yml/badge.svg)](https://github.com/skwasjer/skwas-cordova-plugin-datetimepicker/actions/workflows/ci.yml)

# skwas-cordova-plugin-datetimepicker

Cordova Plugin for showing a native date, time or datetime picker.

## Installation

`cordova plugin add skwas-cordova-plugin-datetimepicker`

or for latest

`cordova plugin add https://github.com/skwasjer/skwas-cordova-plugin-datetimepicker.git`

## Supported platforms

- Android 6.0 (API 23) and higher
- iOS 9 and higher

## Methods

### show

`show(options)`  
Show the plugin with specified options.

`show(options, successCallback, errorCallback)`  
Show the plugin with specified options and callbacks.

This was the original way to call the plugin, and is kept for compatibility.
> Note: The `successCallback` and `errorCallback` respectively will be ignored if the `success` or `error` callback is provided on the `options` argument.

#### Options

| Name                | Type                | Default        | Android                    | iOS                        | |
|---------------------|---------------------|----------------|:--------------------------:|:--------------------------:|--------------------------|
| mode                | String              | `date`         | `date`, `time`, `datetime` | `date`, `time`, `datetime` | The display mode |
| date                | Date                |                | required                   | required                   | The initial date to display |
| allowOldDates       | boolean             | true           | ![Supported][supported]    | ![Supported][supported]    | Allow older dates to be selected |
| allowFutureDates    | boolean             | true           | ![Supported][supported]    | ![Supported][supported]    | Allow future dates to be selected |
| minDate             | Date                |                | ![Supported][supported]    | ![Supported][supported]    | Set the minimum date that can be selected |
| maxDate             | Date                |                | ![Supported][supported]    | ![Supported][supported]    | Set the maximum date that can be selected |
| minuteInterval      | int                 | 1              | >= Honeycomb               | ![Supported][supported]    | For minute spinner the number of minutes per step |
| locale              | String              | (user default) | -                          | ![Supported][supported]    | The locale to use for text and date/time |
| okText              | String              | (os default)   | ![Supported][supported]    | ![Supported][supported]    | The text to use for the ok button |
| cancelText          | String              | (os default)   | ![Supported][supported]    | ![Supported][supported]    | The text to use for the cancel button |
| clearText           | String              |                | ![Supported][supported]    | ![Supported][supported]    | The text to use for the clear button |
| titleText           | String              |                | Depends&#160;on&#160;theme | ![Supported][supported]    | The text to use for the dialog title |
| success             | Function(date)      | -              | ![Supported][supported]    | ![Supported][supported]    | The success callback |
| cancel              | Function()          | -              | ![Supported][supported]    | ![Supported][supported]    | The cancel callback |
| error               | Function(err)       | -              | ![Supported][supported]    | ![Supported][supported]    | The error callback |
| pickerStyle         | String              | `wheels`       | ![Supported][supported]    | ![Supported][supported]    | The picker UI: `wheels` shows spinner wheels, `calendar` shows the calendar date picker. On Android the calendar style also uses the clock face time picker (all modes); on iOS the `time` mode always uses wheels. |
| presentation        | String              | `sheet`        | ![Supported][supported]    | ![Supported][supported]    | How the picker is presented: `sheet` (bottom sheet), `popup` (centered) or `popover` (iOS only, anchored to `ios.anchorEl`; falls back to `popup` on Android). |
| toolbar             | boolean             | `true`         | ![Supported][supported]    | ![Supported][supported]    | Set to `false` to hide the title and the buttons: only the picker is shown, and dismissing confirms the selection. |
| popupWidth          | number              | `360`          | ![Supported][supported]    | ![Supported][supported]    | Width of the centered popup in points/dp. Always capped to the screen width. |
| theme               | String              | (system)       | ![Supported][supported]    | ![Supported][supported]    | `light` or `dark` forces the picker's appearance regardless of the system theme; omit to follow the system. |
| is24HourView        | boolean             | (device&#160;setting) | ![Supported][supported] | uses&#160;`locale`         | Use a 24 hour clock; when omitted the device's 24-hour setting is followed. On iOS the 12/24 hour clock follows the `locale` option/device locale instead. |
| android             | Object              | {}             | optional                   | ignored                    | Android specific options; can also override the shared options above per platform |
| ios                 | Object              | {}             | ignored                    | optional                   | iOS specific options; can also override the shared options above per platform |

> When providing the `clearText` property, an extra button is shown with intent to clear the current date. When the user taps this button, the `success` callback will be called with an `undefined` date. From a UI perspective, this button should be hidden by application code when no date is currently set by omitting the property, but this is up to you.

#### Android options

The shared options above (`pickerStyle`, `presentation`, `toolbar`, `popupWidth`, `theme`) can be overridden here. Android-only options:

| Name                | Type                | Default     | Description               |
|---------------------|---------------------|-------------|---------------------------|
| theme               | int                 | (system)    | Besides `light`/`dark`, legacy [android.R.style](https://developer.android.com/reference/android/R.style.html) integers are still accepted and mapped to light/dark by their resource name. |
| calendar            | boolean             | `false`     | Deprecated: use `pickerStyle: "calendar"` instead. |

> The Android picker is drawn in a Material 3 styled container (using the `com.google.android.material` library), so it looks the same on every device instead of following the manufacturer theme. `minuteInterval` is supported by the `wheels` time picker only.

##### Custom colors (Android)

The plugin ships a default color theme (One UI flavored: blue accent, white/dark gray surfaces) in [`src/android/res/values/dtp_theme.xml`](src/android/res/values/dtp_theme.xml) and [`values-night/dtp_theme.xml`](src/android/res/values-night/dtp_theme.xml) (dark mode), applied automatically.

The theme is resolved in this order:

1. A style named `DateTimePickerTheme` defined in the **app's** Android resources - a per-app override.
2. The plugin's bundled `DateTimePickerDefaultTheme` (`dtp_theme.xml`) - edit these files to change the colors globally, or delete them to fall through.
3. The plain Material 3 day/night defaults.

All styles must have a `Theme.Material3` parent. The relevant attributes:

```xml
<style name="DateTimePickerTheme" parent="Theme.Material3.DayNight.NoActionBar">
    <!-- Accent: buttons, selected day circle, clock hand. All three items
         are needed: the framework picker widgets read the android: ones. -->
    <item name="colorPrimary">#0381FE</item>
    <item name="android:colorAccent">#0381FE</item>
    <item name="android:colorControlActivated">#0381FE</item>
    <!-- Popup background. -->
    <item name="colorSurfaceContainerHigh">#FFFFFF</item>
    <!-- Bottom sheet background. -->
    <item name="colorSurfaceContainerLow">#FFFFFF</item>
    <!-- Text. -->
    <item name="colorOnSurface">#252525</item>
    <item name="colorOnSurfaceVariant">#8C8C8C</item>
</style>
```

Some text sizes can be tuned with optional dimens (defined in the same `dtp_theme.xml`; remove them to keep the stock sizes):

```xml
<!-- Calendar header labels (year on top, selected date below). -->
<dimen name="dtp_header_year_text_size">16sp</dimen>
<dimen name="dtp_header_date_text_size">28sp</dimen>
<!-- Footer buttons (Cancel/Clear/OK). -->
<dimen name="dtp_button_text_size">15sp</dimen>
<!-- Wheel (spinner) picker text and selection divider thickness. -->
<dimen name="dtp_wheel_text_size">18sp</dimen>
<dimen name="dtp_wheel_divider_height">2dp</dimen>
```

Some text colors can likewise be overridden with optional color resources (remove them to follow the theme colors; also define them in `values-night/` for dark mode):

```xml
<!-- Calendar header labels (fall back to colorOnSurfaceVariant/colorOnSurface). -->
<color name="dtp_header_year_text_color">#8C8C8C</color>
<color name="dtp_header_date_text_color">#252525</color>
<!-- Footer buttons (fall back to colorPrimary). -->
<color name="dtp_button_text_color">#0381FE</color>
<!-- Wheel (spinner) picker text and selection divider color. The divider
     color is applied through the DtpWheelThemeOverlay style in dtp_theme.xml. -->
<color name="dtp_wheel_text_color">#252525</color>
<color name="dtp_wheel_divider_color">#338C8C8C</color>
```

> The wheel text color/size need Android 10+; on older versions the text color is applied on a best-effort basis and the size keeps the stock value.

For a per-app override, ship the style with the app, e.g. in `config.xml`:

```xml
<platform name="android">
    <resource-file src="res/android/values/app_dtp_theme.xml" target="app/src/main/res/values/app_dtp_theme.xml" />
    <resource-file src="res/android/values-night/app_dtp_theme.xml" target="app/src/main/res/values-night/app_dtp_theme.xml" />
</platform>
```

#### iOS options

The shared options above (`pickerStyle`, `presentation`, `toolbar`, `popupWidth`, `theme`) can be overridden here. The `calendar` picker style needs iOS 14+ and falls back to wheels below. iOS-only options:

| Name                | Type                | Default     | Description               |
|---------------------|---------------------|-------------|---------------------------|
| anchorEl            | Element or String   |             | The DOM element (or CSS selector) the popover is anchored to. Required for `presentation: "popover"`; without it the picker falls back to the sheet. iOS automatically positions the popover below or above the element, wherever there is room. |
| popoverMaxWidth     | number              |             | Maximum width of the popover content in points. By default the popover sizes itself to its content; values below 280 are raised to 280. |

#### Example

```js
document.addEventListener("deviceready", onDeviceReady, false);
function onDeviceReady() {

    var myDate = new Date(); // From model.

    cordova.plugins.DateTimePicker.show({
        mode: "date",
        date: myDate,
        success: function(newDate) {
            // Handle new date.
            console.info(newDate);
            myDate = newDate;
        }
    });
}
```

### hide

`hide()`  
Hide the date time picker.

If the picker is currently being shown and a cancel-callback was provided in the options, the callback will be called when the picker is hidden.

#### Example

```js
cordova.plugins.DateTimePicker.hide();
```

## Changelog

For a list of all changes  [see here](./CHANGELOG.md).

## Build requirements

- Cordova 8 or higher
- Android:
  - Android SDK (SDK Platform 35 and Build Tools 35.0.0 or higher)
  - `cordova-android@14.0.0` or higher (the `com.google.android.material` library requires compile SDK 35)
  - `android-minSdkVersion` 23 or higher (the `cordova-android@14` default is 24)
- Xcode 11 or higher (iOS)
  - &gt;= `cordova-ios@5.1.1`
- Node 10.x or higher

### Contributors

- [skwasjer](https://github.com/skwasjer)
- [turshija](https://github.com/turshija)
- [emanfu](https://github.com/emanfu)
- [masimplo](https://github.com/masimplo)


[supported]: ./docs/res/check.svg "Supported"
[not-supported]: ./doc/res/close.svg "Not supported"
