package com.skwas.cordova.datetimepicker;

import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.Paint;
import android.os.Build;
import android.text.TextUtils;
import android.util.Log;
import android.util.TypedValue;
import android.view.ContextThemeWrapper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.DatePicker;
import android.widget.EditText;
import android.widget.NumberPicker;
import android.widget.TextView;
import android.widget.TimePicker;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;
import java.util.List;
import java.util.Locale;

public class DateTimePicker extends CordovaPlugin {
	/**
	 * Options for date picker.
	 * Note that not all options are supported, they are here to match the options across all platforms.
	 */
	private class DateTimePickerOptions {
		public String mode = MODE_DATE;
		public Date date;
		public Date minDate = _minSupportedDate;
		public Date maxDate = _maxSupportedDate;
		public boolean allowOldDates = true;
		public boolean allowFutureDates = true;
		public int minuteInterval = 1;
		public String titleText = null;
		public String okText = null;
		public String cancelText = null;
		public String clearText = null;

		// Android specific
		public String pickerStyle = "wheels";     // "wheels" | "calendar"
		public String presentation = "sheet";     // "sheet" | "popup" ("popover" falls back to "popup")
		public boolean toolbar = true;
		public int popupWidth = 0;                 // dp, 0 = default
		public Boolean forceDarkTheme = null;      // null = follow system
		// Defaults to the device's "use 24-hour format" setting (like iOS,
		// which always follows the locale/device setting).
		public boolean is24HourView = android.text.format.DateFormat.is24HourFormat(_activity);

		public DateTimePickerOptions() {
		}

		public DateTimePickerOptions(JSONObject obj) throws JSONException {
			this();

			Date now = new Date();

			mode = obj.optString("mode", mode);

			date = new Date(obj.getLong("ticks"));

			allowOldDates = obj.optBoolean("allowOldDates", allowOldDates);
			allowFutureDates = obj.optBoolean("allowFutureDates", allowFutureDates);

			minDate = obj.has("minDateTicks")
					? new Date(obj.getLong("minDateTicks"))
					: (minDate = allowOldDates ? _minSupportedDate : now);
			maxDate = obj.has("maxDateTicks")
					? new Date(obj.getLong("maxDateTicks"))
					: (maxDate = allowFutureDates ? _maxSupportedDate : now);

			minuteInterval = obj.optInt("minuteInterval", minuteInterval);

			if (!obj.isNull("titleText")) {
				titleText = obj.optString("titleText");
			}

			if (!obj.isNull("okText")) {
				okText = obj.optString("okText");
			}
			okText = TextUtils.isEmpty(okText) ? _activity.getString(android.R.string.ok) : okText;

			if (!obj.isNull("cancelText")) {
				cancelText = obj.optString("cancelText");
			}
			cancelText = TextUtils.isEmpty(cancelText) ? _activity.getString(android.R.string.cancel) : cancelText;

			if (!obj.isNull("clearText")) {
				clearText = obj.optString("clearText");
			}

			JSONObject androidOptions = obj.optJSONObject("android");
			if (androidOptions != null) {
				// Legacy option: calendar=true selected the calendar date picker.
				boolean legacyCalendar = androidOptions.optBoolean("calendar", false);
				pickerStyle = androidOptions.optString("pickerStyle", legacyCalendar ? "calendar" : "wheels")
						.toLowerCase(Locale.US);

				presentation = androidOptions.optString("presentation", presentation).toLowerCase(Locale.US);
				if ("popover".equals(presentation)) {
					// Popovers are not an Android convention; use a popup instead.
					presentation = "popup";
				}

				toolbar = androidOptions.optBoolean("toolbar", toolbar);
				popupWidth = androidOptions.optInt("popupWidth", popupWidth);
				is24HourView = androidOptions.optBoolean("is24HourView", is24HourView);

				// theme: "light"/"dark" forces the appearance. Legacy android.R.style
				// ints are mapped to light/dark by their resource name.
				Object theme = androidOptions.opt("theme");
				if (theme instanceof String) {
					String themeName = ((String) theme).toLowerCase(Locale.US);
					if ("dark".equals(themeName)) forceDarkTheme = Boolean.TRUE;
					else if ("light".equals(themeName)) forceDarkTheme = Boolean.FALSE;
				} else if (theme instanceof Number) {
					forceDarkTheme = isLegacyDarkTheme(((Number) theme).intValue());
				}
			}
		}

		/**
		 * The "calendar" picker style: the calendar date picker, and the
		 * clock face for the time picker (also in the time-only mode).
		 */
		public boolean useCalendarStyle() {
			return "calendar".equals(pickerStyle);
		}
	}

	private static final String MODE_DATE = "date";
	private static final String MODE_TIME = "time";
	private static final String MODE_DATETIME = "datetime";
	private static final String TAG = "DateTimePicker";

	private Date _minSupportedDate;
	private Date _maxSupportedDate;

	private Activity _activity;
	private volatile Runnable _runnable;
	private volatile Dialog _dialog;
	private volatile CallbackContext _showCallbackContext;

	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		super.initialize(cordova, webView);

		_activity = cordova.getActivity();

		DatePicker dp = new DatePicker(_activity);
		// Min/max dates can be different depending on Android version.
		_minSupportedDate = new Date(dp.getMinDate());
		_maxSupportedDate = new Date(dp.getMaxDate());
	}

	@Override
	public synchronized boolean execute(String action, JSONArray args, final CallbackContext callbackContext) {
		Log.d(TAG, "DateTimePicker called with options: " + args);

		if (action.equals("show")) {
			show(args, callbackContext);
			return true;
		}

		if (action.equals("hide")) {
			hide(args, callbackContext);
			return true;
		}

		return false;
	}

	/**
	 * Plugin 'show' method.
	 *
	 * @param data            The JSON arguments passed to the method.
	 * @param callbackContext The callback context.
	 * @return true when the dialog is shown
	 */
	public synchronized boolean show(final JSONArray data, final CallbackContext callbackContext) {
		if (_runnable != null) {
			callbackContext.sendPluginResult(
					new PluginResult(
							PluginResult.Status.ILLEGAL_ACCESS_EXCEPTION,
							"A date/time picker dialog is already showing."
					)
			);
			return false;
		}

		final DateTimePickerOptions options;

		// Parse options from data parameter.
		if (data.length() == 1) {
			try {
				options = new DateTimePickerOptions(data.getJSONObject(0));
			} catch (JSONException ex) {
				callbackContext.error("Failed to load JSON options. " + ex.getMessage());
				return false;
			}
		} else {
			// Defaults.
			options = new DateTimePickerOptions();
		}

		// Set calendar.
		final Calendar calendar = GregorianCalendar.getInstance();
		calendar.setTimeInMillis(options.date.getTime());

		if (MODE_TIME.equalsIgnoreCase(options.mode)) {
			_runnable = showPicker(true, callbackContext, options, calendar);
		} else if (MODE_DATE.equalsIgnoreCase(options.mode) || MODE_DATETIME.equalsIgnoreCase(options.mode)) {
			_runnable = showPicker(false, callbackContext, options, calendar);
		} else {
			callbackContext.error("Unknown mode. Only 'date', 'time' and 'datetime' are valid modes.");
			return false;
		}

		_showCallbackContext = callbackContext;
		_activity.runOnUiThread(_runnable);
		return true;
	}

	/**
	 * Plugin 'hide' method.
	 *
	 * @param data            The JSON arguments passed to the method.
	 * @param callbackContext The callback context.
	 * @return always returns true.
	 */
	public synchronized boolean hide(final JSONArray data, final CallbackContext callbackContext) {
		if (_runnable != null && _dialog != null) {
			// Dismiss without triggering the dialog's cancel/confirm routing,
			// and always report a cancellation, also when there is no toolbar.
			final Dialog dialog = _dialog;
			_activity.runOnUiThread(new Runnable() {
				@Override
				public void run() {
					dialog.dismiss();
				}
			});
			sendCancelled(_showCallbackContext);
			cleanup();
		}

		callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.NO_RESULT));
		return true;
	}

	/**
	 * Builds the runnable showing the date or the time phase of the picker.
	 *
	 * @param timePhase false shows the date picker, true shows the time picker.
	 */
	private Runnable showPicker(final boolean timePhase, final CallbackContext callbackContext, final DateTimePickerOptions options, final Calendar calendar) {
		return new Runnable() {
			@Override
			public void run() {
				final Context themedContext = createThemedContext(options);
				final boolean calendarStyle = options.useCalendarStyle();

				final View pickerView;
				final boolean[] minuteIntervalApplied = new boolean[] { false };
				if (timePhase) {
					TimePicker timePicker = (TimePicker) inflatePicker(themedContext, calendarStyle ? "dtp_time_clock" : "dtp_time_wheels");
					configureTimePicker(timePicker, options, calendar, !calendarStyle, minuteIntervalApplied);
					pickerView = timePicker;
				} else {
					DatePicker datePicker = (DatePicker) inflatePicker(themedContext, calendarStyle ? "dtp_date_calendar" : "dtp_date_wheels");
					configureDatePicker(datePicker, options, calendar);
					pickerView = datePicker;
				}
				applyWheelStyles(pickerView, themedContext);

				Dialog dialog = PickerDialog.create(
						themedContext,
						"sheet".equals(options.presentation),
						pickerView,
						options.titleText,
						options.okText,
						options.cancelText,
						options.clearText,
						options.toolbar,
						options.popupWidth,
						// The calendar has a fixed framework width; hug it so the
						// popup has no artificial side margins (unless the app
						// explicitly asked for a popup width). Only the date
						// phase shows the calendar - the clock stretches, so
						// hugging it would fill the whole screen.
						calendarStyle && !timePhase && options.popupWidth == 0,
						// Trim the calendar widget's generous built-in side padding.
						calendarStyle && !timePhase,
						new PickerDialog.Listener() {
							@Override
							public void onDone() {
								if (timePhase) {
									readTime((TimePicker) pickerView, calendar, options, minuteIntervalApplied[0]);
									onCalendarSet(calendar, callbackContext);
								} else {
									readDate((DatePicker) pickerView, calendar);
									if (MODE_DATETIME.equalsIgnoreCase(options.mode)) {
										// Continue with the time phase.
										synchronized (DateTimePicker.this) {
											_runnable = showPicker(true, callbackContext, options, calendar);
											_activity.runOnUiThread(_runnable);
										}
									} else {
										onCalendarSet(calendar, callbackContext);
									}
								}
							}

							@Override
							public void onClear() {
								// Send empty object.
								callbackContext.success(new JSONObject());
								cleanup();
							}

							@Override
							public void onCancel() {
								sendCancelled(callbackContext);
								cleanup();
							}
						});

				_dialog = dialog;
				dialog.show();
			}
		};
	}

	/**
	 * A context with the Material 3 day/night theme, optionally forced into
	 * light or dark mode regardless of the system setting.
	 *
	 * The activity must stay the base context (its window token is needed to
	 * show dialogs), so the forced mode is applied as an override
	 * configuration on the theme wrapper rather than with
	 * createConfigurationContext().
	 */
	private Context createThemedContext(DateTimePickerOptions options) {
		// Theme lookup order:
		// 1. "DateTimePickerTheme" - app-defined override (per-app colors).
		// 2. "DateTimePickerDefaultTheme" - the plugin's bundled default
		//    (res/values/dtp_theme.xml; delete it to fall through).
		// 3. Material 3 day/night defaults.
		// Styles must have a Theme.Material3 parent.
		int themeId = _activity.getResources().getIdentifier("DateTimePickerTheme", "style", _activity.getPackageName());
		if (themeId == 0) {
			themeId = _activity.getResources().getIdentifier("DateTimePickerDefaultTheme", "style", _activity.getPackageName());
		}
		if (themeId == 0) {
			themeId = _activity.getResources().getIdentifier("Theme.Material3.DayNight.NoActionBar", "style", _activity.getPackageName());
		}
		if (themeId == 0) {
			// The material library should always be present (plugin dependency);
			// fall back to the device default just in case.
			themeId = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
					? android.R.style.Theme_DeviceDefault_DayNight
					: android.R.style.Theme_DeviceDefault;
		}

		ContextThemeWrapper wrapper = new ContextThemeWrapper(_activity, themeId);
		if (options.forceDarkTheme != null) {
			// Only the night bits are set; everything else inherits.
			Configuration override = new Configuration();
			override.uiMode = options.forceDarkTheme ? Configuration.UI_MODE_NIGHT_YES : Configuration.UI_MODE_NIGHT_NO;
			wrapper.applyOverrideConfiguration(override);
		}
		return wrapper;
	}

	/** Best-effort light/dark mapping for legacy android.R.style theme ints. */
	private Boolean isLegacyDarkTheme(int themeResId) {
		try {
			String name = _activity.getResources().getResourceEntryName(themeResId);
			return !name.contains("Light");
		} catch (Exception ex) {
			return null;
		}
	}

	private View inflatePicker(Context context, String layoutName) {
		int layoutId = _activity.getResources().getIdentifier(layoutName, "layout", _activity.getPackageName());
		return LayoutInflater.from(context).inflate(layoutId, null, false);
	}

	private void configureDatePicker(DatePicker datePicker, DateTimePickerOptions options, Calendar calendar) {
		datePicker.init(
				calendar.get(Calendar.YEAR),
				calendar.get(Calendar.MONTH),
				calendar.get(Calendar.DAY_OF_MONTH),
				null);
		datePicker.setMinDate(options.minDate.getTime());
		datePicker.setMaxDate(options.maxDate.getTime());

		// Restyle the calendar picker's built-in header: drop its colored
		// background and use surface text colors instead, keeping it M3-like.
		// The header must stay visible because tapping its year label is how
		// the framework picker switches to the quick year selection list.
		int headerId = Resources.getSystem().getIdentifier("date_picker_header", "id", "android");
		View header = headerId == 0 ? null : datePicker.findViewById(headerId);
		if (header != null) {
			header.setBackgroundColor(Color.TRANSPARENT);

			Context context = datePicker.getContext();
			boolean night = PickerDialog.isNight(context);
			int onSurface = PickerDialog.resolveColor(context, PickerDialog.materialAttr(context, "colorOnSurface"), night ? 0xFFE6E0E9 : 0xFF1D1B20);
			int onSurfaceVariant = PickerDialog.resolveColor(context, PickerDialog.materialAttr(context, "colorOnSurfaceVariant"), night ? 0xFFCAC4D0 : 0xFF49454F);

			int yearId = Resources.getSystem().getIdentifier("date_picker_header_year", "id", "android");
			View yearLabel = yearId == 0 ? null : header.findViewById(yearId);
			if (yearLabel instanceof TextView) {
				((TextView) yearLabel).setTextColor(resolveColorResource(context, "dtp_header_year_text_color", onSurfaceVariant));
				applyTextSizeDimen((TextView) yearLabel, "dtp_header_year_text_size");
			}

			int dateId = Resources.getSystem().getIdentifier("date_picker_header_date", "id", "android");
			View dateLabel = dateId == 0 ? null : header.findViewById(dateId);
			if (dateLabel instanceof TextView) {
				((TextView) dateLabel).setTextColor(resolveColorResource(context, "dtp_header_date_text_color", onSurface));
				applyTextSizeDimen((TextView) dateLabel, "dtp_header_date_text_size");
			}
		}
	}

	/**
	 * Restyles the clock time picker's built-in colored header (the selected
	 * time and AM/PM labels): transparent background and surface text colors,
	 * matching the restyled calendar header. The activated state (the field
	 * currently being edited) is emphasized with the stronger color.
	 */
	private void styleClockHeader(TimePicker timePicker, Context context) {
		int headerId = Resources.getSystem().getIdentifier("time_header", "id", "android");
		View header = headerId == 0 ? null : timePicker.findViewById(headerId);
		if (header == null) return;

		header.setBackgroundColor(Color.TRANSPARENT);

		boolean night = PickerDialog.isNight(context);
		int onSurface = PickerDialog.resolveColor(context, PickerDialog.materialAttr(context, "colorOnSurface"), night ? 0xFFE6E0E9 : 0xFF1D1B20);
		int onSurfaceVariant = PickerDialog.resolveColor(context, PickerDialog.materialAttr(context, "colorOnSurfaceVariant"), night ? 0xFFCAC4D0 : 0xFF49454F);

		ColorStateList labelColors = new ColorStateList(
				new int[][] { new int[] { android.R.attr.state_activated }, new int[0] },
				new int[] { onSurface, onSurfaceVariant });

		String[] labelNames = { "hours", "separator", "minutes", "am_label", "pm_label" };
		for (String labelName : labelNames) {
			int labelId = Resources.getSystem().getIdentifier(labelName, "id", "android");
			View label = labelId == 0 ? null : header.findViewById(labelId);
			if (label instanceof TextView) {
				((TextView) label).setTextColor(labelColors);
			}
		}

		// The text input mode (keyboard toggle) swaps the time display for a
		// "Set time" label with its own colored background; restyle it too.
		int inputHeaderId = Resources.getSystem().getIdentifier("input_header", "id", "android");
		View inputHeader = inputHeaderId == 0 ? null : timePicker.findViewById(inputHeaderId);
		if (inputHeader != null) {
			inputHeader.setBackgroundColor(Color.TRANSPARENT);
			if (inputHeader instanceof TextView) {
				((TextView) inputHeader).setTextColor(onSurface);
			}
		}
	}

	/**
	 * Applies the optional wheel styles from dtp_theme.xml (text color/size,
	 * divider color/height) to every NumberPicker inside the picker view.
	 */
	private void applyWheelStyles(View view, Context context) {
		if (view instanceof NumberPicker) {
			applyWheelStyle((NumberPicker) view, context);
		} else if (view instanceof ViewGroup) {
			ViewGroup group = (ViewGroup) view;
			for (int i = 0; i < group.getChildCount(); i++) {
				applyWheelStyles(group.getChildAt(i), context);
			}
		}
	}

	@SuppressWarnings("deprecation")
	private void applyWheelStyle(NumberPicker picker, Context context) {
		Resources resources = context.getResources();
		String packageName = context.getPackageName();

		int textColorId = resources.getIdentifier("dtp_wheel_text_color", "color", packageName);
		int textSizeId = resources.getIdentifier("dtp_wheel_text_size", "dimen", packageName);
		int dividerHeightId = resources.getIdentifier("dtp_wheel_divider_height", "dimen", packageName);

		// Text color/size: public API on Android 10+, best effort below.
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			if (textColorId != 0) picker.setTextColor(resources.getColor(textColorId));
			if (textSizeId != 0) picker.setTextSize(resources.getDimension(textSizeId));
		} else if (textColorId != 0) {
			try {
				int color = resources.getColor(textColorId);
				java.lang.reflect.Field paintField = NumberPicker.class.getDeclaredField("mSelectorWheelPaint");
				paintField.setAccessible(true);
				((Paint) paintField.get(picker)).setColor(color);
				for (int i = 0; i < picker.getChildCount(); i++) {
					View child = picker.getChildAt(i);
					if (child instanceof EditText) ((EditText) child).setTextColor(color);
				}
			} catch (Exception ignored) {
				// Keep the stock text style.
			}
		}

		// Divider height: public API on Android 10+, best effort below.
		// (The divider color is set through DtpWheelThemeOverlay at inflation.)
		if (dividerHeightId != 0) {
			int dividerHeight = Math.max(1, Math.round(resources.getDimension(dividerHeightId)));
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				picker.setSelectionDividerHeight(dividerHeight);
			} else {
				try {
					java.lang.reflect.Field heightField = NumberPicker.class.getDeclaredField("mSelectionDividerHeight");
					heightField.setAccessible(true);
					heightField.setInt(picker, dividerHeight);
				} catch (Exception ignored) {
					// Keep the stock divider height.
				}
			}
		}

		picker.invalidate();
	}

	/**
	 * Resolves a color resource by name (from the plugin's dtp_theme.xml, or
	 * overridden by the app); the fallback is used when it is not defined.
	 * Resolved against the themed context so a forced light/dark theme picks
	 * the right values/values-night variant.
	 */
	@SuppressWarnings("deprecation")
	private static int resolveColorResource(Context context, String colorName, int fallback) {
		int colorId = context.getResources().getIdentifier(colorName, "color", context.getPackageName());
		if (colorId == 0) return fallback;
		return context.getResources().getColor(colorId);
	}

	/**
	 * Applies a text size defined as a dimen resource (in the plugin's
	 * dtp_theme.xml, or overridden by the app); keeps the stock size when the
	 * dimen is not defined.
	 */
	private void applyTextSizeDimen(TextView view, String dimenName) {
		int dimenId = _activity.getResources().getIdentifier(dimenName, "dimen", _activity.getPackageName());
		if (dimenId != 0) {
			view.setTextSize(TypedValue.COMPLEX_UNIT_PX, _activity.getResources().getDimension(dimenId));
		}
	}

	@SuppressWarnings("deprecation")
	private void configureTimePicker(TimePicker timePicker, DateTimePickerOptions options, Calendar calendar, boolean spinnerMode, boolean[] minuteIntervalApplied) {
		timePicker.setIs24HourView(options.is24HourView);

		if (!spinnerMode) {
			styleClockHeader(timePicker, timePicker.getContext());
		}

		int hour = calendar.get(Calendar.HOUR_OF_DAY);
		int minute = calendar.get(Calendar.MINUTE);

		// The minute interval is only supported by the spinner (wheels) picker:
		// restrict its minute wheel to the allowed values.
		int interval = options.minuteInterval;
		if (spinnerMode && interval > 1 && 60 % interval == 0) {
			int minuteId = Resources.getSystem().getIdentifier("minute", "id", "android");
			View minuteView = minuteId == 0 ? null : timePicker.findViewById(minuteId);
			if (minuteView instanceof NumberPicker) {
				NumberPicker minuteSpinner = (NumberPicker) minuteView;
				minuteSpinner.setMinValue(0);
				minuteSpinner.setMaxValue((60 / interval) - 1);

				List<String> displayedValues = new ArrayList<String>();
				for (int i = 0; i < 60; i += interval) {
					displayedValues.add(String.format(Locale.US, "%02d", i));
				}
				minuteSpinner.setDisplayedValues(displayedValues.toArray(new String[0]));

				minuteIntervalApplied[0] = true;
				minute = minute / interval;
			}
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			timePicker.setHour(hour);
			timePicker.setMinute(minute);
		} else {
			timePicker.setCurrentHour(hour);
			timePicker.setCurrentMinute(minute);
		}
	}

	private void readDate(DatePicker datePicker, Calendar calendar) {
		datePicker.clearFocus();
		calendar.set(Calendar.YEAR, datePicker.getYear());
		calendar.set(Calendar.MONTH, datePicker.getMonth());
		calendar.set(Calendar.DAY_OF_MONTH, datePicker.getDayOfMonth());
	}

	@SuppressWarnings("deprecation")
	private void readTime(TimePicker timePicker, Calendar calendar, DateTimePickerOptions options, boolean minuteIntervalApplied) {
		timePicker.clearFocus();

		int hour;
		int minute;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			hour = timePicker.getHour();
			minute = timePicker.getMinute();
		} else {
			hour = timePicker.getCurrentHour();
			minute = timePicker.getCurrentMinute();
		}
		if (minuteIntervalApplied) {
			minute *= options.minuteInterval;
		}

		calendar.set(Calendar.HOUR_OF_DAY, hour);
		calendar.set(Calendar.MINUTE, minute);
		calendar.set(Calendar.SECOND, 0);
		calendar.set(Calendar.MILLISECOND, 0);
	}

	/**
	 * Success callback for when a new date or time is set.
	 *
	 * @param calendar        The calendar with the new date and/or time.
	 * @param callbackContext The callback context.
	 */
	private synchronized void onCalendarSet(final Calendar calendar, final CallbackContext callbackContext) {
		Date selectedDate = calendar.getTime();

		try {
			JSONObject result = new JSONObject();
			// Due to lack of browser/user agent support for ISO 8601 parsing, we provide ticks since epoch.
			// The Javascript date constructor works far more reliably this way, even on old JS engines.
			result.put("ticks", selectedDate.getTime());
			result.put("cancelled", false);
			callbackContext.success(result);
		} catch (JSONException ex) {
			callbackContext.error("Failed to serialize date. " + selectedDate.toString());
		} finally {
			cleanup();
		}
	}

	private synchronized void sendCancelled(final CallbackContext callbackContext) {
		if (callbackContext == null) return;
		try {
			JSONObject result = new JSONObject();
			result.put("cancelled", true);
			callbackContext.success(result);
		} catch (JSONException ex) {
			callbackContext.error("Failed to cancel.");
		}
	}

	private synchronized void cleanup() {
		_runnable = null;
		_dialog = null;
		_showCallbackContext = null;
	}
}
