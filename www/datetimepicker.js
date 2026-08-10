/*
The MIT License (MIT)

Copyright (c) 2015 skwas

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/
var utils = require("skwas-cordova-plugin-datetimepicker.utils");
var exec = require("cordova/exec");

/**
 * This represents the DateTimePicker, and provides methods to show the native DateTime picker.
 * @constructor
 */
function DateTimePicker () {
}

/**
 * Show the date time picker.
 *
 * @param {Function} successCallback The function to call when the datetime has changed.
 */
DateTimePicker.prototype.show = function (options, successCallback, errorCallback) {
    if (!utils.isObject(options)) {
        throw new Error("'options' is required.");
    }

    var settings = {
        mode: "date",
        date: new Date(),
        minDate: null,
        maxDate: null,
        allowOldDates: null,
        allowFutureDates: null,
        minuteInterval: 1,
        locale: null,
        okText: null,
        cancelText: null,
        clearText: null,
        titleText: null,
        android: {
            // If omitted/undefined, default theme will be used.
            theme: undefined,
            calendar: false
        },
        ios: {
            // The picker UI: "wheels" (default) or "calendar" (iOS 14+, date and
            // datetime modes only; time always uses wheels).
            pickerStyle: undefined,
            // How the picker is presented: "sheet" (default, bottom sheet),
            // "popup" (centered) or "popover" (anchored to anchorEl). For a
            // popover, iOS positions it automatically (below/above the
            // element, wherever there is room).
            presentation: undefined,
            // DOM element (or CSS selector) the popover is anchored to.
            // Required for presentation "popover".
            anchorEl: undefined,
            // Set to false to hide the title and the buttons: only the picker is
            // shown, and dismissing (tapping outside) confirms the selection.
            toolbar: undefined,
            // Width of the centered popup in points (default 360). Always capped
            // to the screen width; values below 280 are raised to 280.
            popupWidth: undefined,
            // Maximum width of the popover content in points. By default the
            // popover sizes itself to its content; values below 280 are raised to 280.
            popoverMaxWidth: undefined,
            // "light" or "dark" forces the picker's appearance regardless of the
            // system theme; omit to follow the system (default).
            theme: undefined
        },
        success: undefined,
        cancel: undefined,
        error: undefined
    };

    // Copy options into settings overwriting the defaults.
    for (var key in settings) {
        if (utils.isDefined(options[key])) {
            settings[key] = options[key];
        }
    }

    // Backward compat for callbacks.
    if (!utils.isFunction(settings.success)) {
        settings.success = successCallback;
    }
    if (!utils.isFunction(settings.error)) {
        settings.error = errorCallback;
    }

    var onPluginError = utils.getErrorHandler(settings.error).bind(this);
    var onPluginSuccess = function (result) {
        // The success handler expects the result to be:
        //
        // {
        //    "ticks": a 64-bit int (ticks),
        //    "cancelled": true|false
        // }
        console.debug("DateTimePickerPlugin: Exec 'show' returned:", result);
        if (utils.isDefined(result) && utils.isObject(result) && result !== null) {
            if (result.cancelled === true) {
                utils.isFunction(settings.cancel) && settings.cancel.apply(this);
            } else if (utils.isNumber(result.ticks)) {
                var resultDate = new Date(result.ticks);
                utils.isFunction(settings.success) && settings.success.apply(this, [resultDate]);
            } else {
                utils.isFunction(settings.success) && settings.success.apply(this, []);
            }
            return;
        }

        onPluginError("Unexpected result from plugin: " + JSON.stringify(arguments));
    }.bind(this);

    // Validate/sanitize options.
    try {
        if (utils.validate(utils.isValidMode, settings, "mode", "Expected a String: date, time, datetime.")) {
            settings.mode = settings.mode.toLowerCase();
        }

        // Validate if dates are valid, convert to ticks since epoch.
        if (utils.validate(utils.isDate, settings, "date", "Expected a Date.")) {
            settings.ticks = settings.date.valueOf();
        }
        if (!!settings.minDate && utils.validate(utils.isDate, settings, "minDate", "Expected a Date.")) {
            settings.minDateTicks = settings.minDate.valueOf();
        }
        if (!!settings.maxDate && utils.validate(utils.isDate, settings, "maxDate", "Expected a Date.")) {
            settings.maxDateTicks = settings.maxDate.valueOf();
        }

        if (!!settings.minuteInterval && utils.validate(utils.isMinuteInterval, settings, "minuteInterval", "Expected a Number which is a divisor of 60 (min 1, max 30).")) {
            settings.minuteInterval = parseInt(settings.minuteInterval);
        }
    } catch (e) {
        onPluginError(e.message);
        return;
    }

    // Resolve the iOS popover anchor element to its bounding rect, since DOM
    // elements cannot be passed over the bridge. Build a serializable copy so
    // the caller's options object is not mutated.
    if (settings.ios !== null && utils.isObject(settings.ios)) {
        var iosSettings = {
            pickerStyle: settings.ios.pickerStyle,
            presentation: settings.ios.presentation,
            toolbar: settings.ios.toolbar,
            popupWidth: settings.ios.popupWidth,
            popoverMaxWidth: settings.ios.popoverMaxWidth,
            theme: settings.ios.theme
        };
        var anchorEl = settings.ios.anchorEl;
        if (anchorEl) {
            if (typeof anchorEl === "string") {
                anchorEl = document.querySelector(anchorEl);
            }
            if (anchorEl && typeof anchorEl.getBoundingClientRect === "function") {
                var anchorRect = anchorEl.getBoundingClientRect();
                iosSettings.anchorRect = {
                    x: anchorRect.left,
                    y: anchorRect.top,
                    width: anchorRect.width,
                    height: anchorRect.height
                };
            }
        }
        settings.ios = iosSettings;
    }

    console.debug("DateTimePickerPlugin: Exec 'show' with:", settings);
    exec(onPluginSuccess, onPluginError, "DateTimePicker", "show", [settings]);
};

/**
 * Hide the date time picker.
 *
 * If the picker is currently being shown and a cancel-callback was provided
 * in the options, the callback will be called when the picker is hidden.
 */
DateTimePicker.prototype.hide = function () {
    console.debug("DateTimePickerPlugin: Exec 'hide'.");
    exec(null, utils.getErrorHandler().bind(this), "DateTimePicker", "hide");
};

module.exports = new DateTimePicker();
