/**
 * Interface for cordova.plugins adding DateTimePicker
 *
 * @interface Plugins
 */
interface Plugins {
  DateTimePicker: DateTimePicker;
}

interface IDatePickerOptions {
  mode: 'date' | 'time' | 'datetime';
  date: Date;
  minDate?: Date;
  maxDate?: Date;
  allowOldDates?: boolean;
  allowFutureDates?: boolean;
  minuteInterval?: number;
  locale?: string;
  okText?: string;
  cancelText?: string;
  clearText?: string;
  titleText?: string;
  android?: {
    theme?: number; // Theme_DeviceDefault_Dialog
    calendar?: boolean;
    is24HourView?: boolean;
  };
  ios?: {
    /**
     * The picker UI. "wheels" (default) shows spinner wheels. "calendar"
     * (iOS 14+) shows an inline calendar; applies to the date and datetime
     * modes only (time mode always uses wheels).
     */
    pickerStyle?: 'wheels' | 'calendar';
    /**
     * How the picker is presented. "sheet" (default) is a bottom sheet,
     * "popup" is centered on screen, and "popover" is anchored to anchorEl.
     * iOS positions the popover automatically (below/above the element,
     * wherever there is room).
     */
    presentation?: 'sheet' | 'popup' | 'popover';
    /**
     * The element (or CSS selector) the popover is anchored to.
     * Required for presentation "popover"; without it the picker falls back
     * to the sheet presentation.
     */
    anchorEl?: HTMLElement | string;
    /**
     * Set to false to hide the title and the buttons: only the picker is
     * shown, and dismissing (tapping outside) confirms the selection.
     * Defaults to true.
     */
    toolbar?: boolean;
    /**
     * Width of the centered popup in points (default 360). Always capped to
     * the screen width; values below 280 are raised to 280.
     */
    popupWidth?: number;
    /**
     * Maximum width of the popover content in points. By default the popover
     * sizes itself to its content; values below 280 are raised to 280.
     */
    popoverMaxWidth?: number;
    /**
     * "light" or "dark" forces the picker's appearance regardless of the
     * system theme; omit to follow the system (default).
     */
    theme?: 'light' | 'dark';
  };
  success: (newDate?: Date) => void;
  cancel?: () => void;
  error: (err: Error) => void;
}

interface DateTimePicker {

  /**
   * Show the date/time picker with specified options.
   *
   * @param {IDatePickerOptions} options
   * @memberof DateTimePicker
   */
  show(options: IDatePickerOptions): void;

  /**
   * Show the date/time picker with specified options and callbacks.
   * Legacy way to call the show method, kept for backward compatibility.
   * NOTE: The successCallback and errorCallback respectively will be ignored if the success or error callback is provided on the options argument.
   *
   * @param {IDatePickerOptions} options
   * @param {(newDate?: Date) => void} successCb
   * @param {(err: Error) => void} errorCb
   * @memberof DateTimePicker
   */
  show(options: IDatePickerOptions, successCb: (newDate?: Date) => void, errorCb: (err: Error) => void): void;

  /**
   * Hide the date/time picker.
   *
   * If the picker is currently being shown and a cancel-callback was provided
   * in the options, the callback will be called when the picker is hidden.
   *
   * @memberof DateTimePicker
   */
  hide(): void;
}
