package com.skwas.cordova.datetimepicker;

import android.app.Dialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.res.Configuration;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.google.android.material.bottomsheet.BottomSheetDialog;

/**
 * Builds a Material 3 styled container for a picker widget: an optional title
 * on top, the picker itself, and - unless the toolbar is hidden - a footer
 * with plain text buttons below a hairline separator. The container is shown
 * either as a centered dialog ("popup") or as a bottom sheet ("sheet"), so the
 * picker looks the same on every device instead of following the OEM theme.
 */
final class PickerDialog {

	interface Listener {
		void onDone();
		void onClear();
		void onCancel();
	}

	private static final int CORNER_RADIUS_DP = 28;
	private static final int DEFAULT_POPUP_WIDTH_DP = 360;
	private static final int POPUP_SCREEN_MARGIN_DP = 10;
	private static final int TITLE_HEIGHT_DP = 48;
	private static final int FOOTER_HEIGHT_DP = 52;
	private static final int FOOTER_BOTTOM_PADDING_DP = 8;
	private static final int FOOTER_SIDE_PADDING_DP = 16;
	private static final int FOOTER_BUTTON_GAP_DP = 8;
	private static final int CONTENT_PADDING_DP = 8;
	private static final int NO_TOOLBAR_BOTTOM_PADDING_DP = 16;
	// Trim of the framework calendar widget's own generous side padding.
	private static final int CALENDAR_SIDE_TRIM_DP = -4;

	private PickerDialog() {
	}

	/**
	 * Creates the dialog. The caller is responsible for showing it.
	 *
	 * When the toolbar is shown, dismissing the dialog (back button/outside
	 * touch) cancels; without a toolbar there are no buttons, so dismissing
	 * confirms the selection instead.
	 */
	static Dialog create(final Context context, final boolean asSheet, final View pickerView,
						 final CharSequence titleText, final CharSequence okText, final CharSequence cancelText,
						 final CharSequence clearText, final boolean showToolbar, final int popupWidthDp,
						 final boolean hugContent, final boolean trimPickerSides, final Listener listener) {
		final boolean night = isNight(context);
		final int surfaceColor = resolveColor(context, materialAttr(context, "colorSurfaceContainerHigh"), night ? 0xFF2B2930 : 0xFFECE6F0);
		final int onSurfaceColor = resolveColor(context, materialAttr(context, "colorOnSurface"), night ? 0xFFE6E0E9 : 0xFF1D1B20);
		final int primaryColor = resolveColor(context, materialAttr(context, "colorPrimary"), night ? 0xFFD0BCFF : 0xFF6750A4);

		final LinearLayout content = new LinearLayout(context);
		content.setOrientation(LinearLayout.VERTICAL);

		// Title (only when the toolbar is shown and a title is set).
		if (showToolbar && !TextUtils.isEmpty(titleText)) {
			TextView title = new TextView(context);
			title.setText(titleText);
			title.setGravity(Gravity.CENTER);
			title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
			title.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
			title.setTextColor(onSurfaceColor);
			content.addView(title, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(context, TITLE_HEIGHT_DP)));
		}

		// Picker. Kept at its natural width and centered: the framework
		// calendar picker aligns its grid to the start when stretched wider
		// than its content, which looks off-center in a full-width sheet.
		LinearLayout.LayoutParams pickerParams = new LinearLayout.LayoutParams(
				ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
		pickerParams.gravity = Gravity.CENTER_HORIZONTAL;
		int contentPadding = dp(context, CONTENT_PADDING_DP);
		// For the calendar, trim part of the framework widget's own generous
		// side padding with a small negative margin; only empty padding is
		// clipped, the grid itself is centered well within it.
		int sideMargin = trimPickerSides ? dp(context, CALENDAR_SIDE_TRIM_DP) : contentPadding;
		int topMargin = showToolbar && !TextUtils.isEmpty(titleText) ? 0 : contentPadding;
		// Without a footer the picker needs its own breathing room at the bottom.
		int bottomMargin = showToolbar ? 0 : dp(context, NO_TOOLBAR_BOTTOM_PADDING_DP);
		pickerParams.setMargins(sideMargin, topMargin, sideMargin, bottomMargin);
		content.addView(pickerView, pickerParams);

		// The one callback that wins; ignore anything after it.
		final boolean[] handled = new boolean[] { false };

		if (showToolbar) {
			// Footer: all buttons right-aligned ([clear] cancel ok), the
			// Material dialog convention (no separator line, like M3 dialogs).
			LinearLayout footer = new LinearLayout(context);
			footer.setOrientation(LinearLayout.HORIZONTAL);
			footer.setGravity(Gravity.CENTER_VERTICAL);
			int footerSidePadding = dp(context, FOOTER_SIDE_PADDING_DP);
			footer.setPadding(footerSidePadding, 0, footerSidePadding, 0);
			LinearLayout.LayoutParams footerParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(context, FOOTER_HEIGHT_DP));
			// Breathing room below the buttons, matching the rounded corners.
			footerParams.bottomMargin = dp(context, FOOTER_BOTTOM_PADDING_DP);
			content.addView(footer, footerParams);

			View space = new View(context);
			footer.addView(space, new LinearLayout.LayoutParams(0, 0, 1));

			if (!TextUtils.isEmpty(clearText)) {
				footer.addView(createTextButton(context, clearText, primaryColor, false));
			}
			footer.addView(createTextButton(context, cancelText, primaryColor, false), footerButtonParams(context));
			footer.addView(createTextButton(context, okText, primaryColor, true), footerButtonParams(context));
			// Children: space, [clear], cancel, done - wired below once the
			// dialog exists.
		}

		// Build the dialog itself.
		final Dialog dialog;
		if (asSheet) {
			// The Material 3 bottom sheet draws its own rounded surface.
			BottomSheetDialog sheetDialog = new BottomSheetDialog(context);
			sheetDialog.setContentView(content);
			dialog = sheetDialog;
		} else {
			dialog = new Dialog(context);
			dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
			dialog.setContentView(content);

			Window window = dialog.getWindow();
			if (window != null) {
				GradientDrawable background = new GradientDrawable();
				background.setColor(surfaceColor);
				background.setCornerRadius(dp(context, CORNER_RADIUS_DP));
				window.setBackgroundDrawable(background);

				if (hugContent) {
					// Hug the content (used for the calendar, whose width is
					// fixed by the framework): no artificial side margins.
					window.setLayout(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
				} else {
					int desiredWidth = dp(context, popupWidthDp > 0 ? popupWidthDp : DEFAULT_POPUP_WIDTH_DP);
					int maxWidth = context.getResources().getDisplayMetrics().widthPixels - 2 * dp(context, POPUP_SCREEN_MARGIN_DP);
					window.setLayout(Math.min(desiredWidth, maxWidth), ViewGroup.LayoutParams.WRAP_CONTENT);
				}
			}
		}

		dialog.setCancelable(true);
		dialog.setCanceledOnTouchOutside(true);

		// Back button/outside touch: cancel with a toolbar, confirm without one.
		dialog.setOnCancelListener(new DialogInterface.OnCancelListener() {
			@Override
			public void onCancel(DialogInterface ignored) {
				if (handled[0]) return;
				handled[0] = true;
				if (showToolbar) {
					listener.onCancel();
				} else {
					listener.onDone();
				}
			}
		});

		// Wire the footer buttons (they exist only when the toolbar is shown).
		if (showToolbar) {
			LinearLayout footer = (LinearLayout) content.getChildAt(content.getChildCount() - 1);
			// Order added above: space, [clear], cancel, done.
			Button doneButton = (Button) footer.getChildAt(footer.getChildCount() - 1);
			Button cancelButton = (Button) footer.getChildAt(footer.getChildCount() - 2);
			Button clearButton = TextUtils.isEmpty(clearText) ? null : (Button) footer.getChildAt(1);

			cancelButton.setOnClickListener(new View.OnClickListener() {
				@Override
				public void onClick(View v) {
					if (handled[0]) return;
					handled[0] = true;
					dialog.dismiss();
					listener.onCancel();
				}
			});
			if (clearButton != null) {
				clearButton.setOnClickListener(new View.OnClickListener() {
					@Override
					public void onClick(View v) {
						if (handled[0]) return;
						handled[0] = true;
						dialog.dismiss();
						listener.onClear();
					}
				});
			}
			doneButton.setOnClickListener(new View.OnClickListener() {
				@Override
				public void onClick(View v) {
					if (handled[0]) return;
					handled[0] = true;
					dialog.dismiss();
					listener.onDone();
				}
			});
		}

		return dialog;
	}

	/** Layout params adding a small gap to the button on the left. */
	private static LinearLayout.LayoutParams footerButtonParams(Context context) {
		LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
				ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
		params.leftMargin = dp(context, FOOTER_BUTTON_GAP_DP);
		return params;
	}

	private static Button createTextButton(Context context, CharSequence text, int textColor, boolean bold) {
		Button button = new Button(context, null, android.R.attr.borderlessButtonStyle);
		button.setText(text);
		button.setAllCaps(false);
		button.setTextColor(textColor);
		button.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
		// Optional color/size overrides from dtp_theme.xml (or app resources).
		int colorId = context.getResources().getIdentifier("dtp_button_text_color", "color", context.getPackageName());
		if (colorId != 0) {
			button.setTextColor(context.getResources().getColor(colorId));
		}
		int sizeDimenId = context.getResources().getIdentifier("dtp_button_text_size", "dimen", context.getPackageName());
		if (sizeDimenId != 0) {
			button.setTextSize(TypedValue.COMPLEX_UNIT_PX, context.getResources().getDimension(sizeDimenId));
		}
		if (bold) {
			button.setTypeface(Typeface.create("sans-serif-medium", Typeface.BOLD));
		} else {
			button.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
		}
		button.setMinWidth(0);
		button.setMinimumWidth(0);
		int padding = dp(context, 12);
		button.setPadding(padding, 0, padding, 0);
		return button;
	}

	static boolean isNight(Context context) {
		int nightMask = context.getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK;
		return nightMask == Configuration.UI_MODE_NIGHT_YES;
	}

	/**
	 * Looks up a Material attribute by name so this class does not depend on
	 * the material R class layout (returns 0 when unavailable).
	 */
	static int materialAttr(Context context, String name) {
		return context.getResources().getIdentifier(name, "attr", context.getPackageName());
	}

	static int resolveColor(Context context, int attr, int fallback) {
		if (attr == 0) return fallback;
		TypedValue value = new TypedValue();
		if (!context.getTheme().resolveAttribute(attr, value, true)) return fallback;
		if (value.resourceId != 0) {
			return context.getResources().getColor(value.resourceId);
		}
		if (value.type >= TypedValue.TYPE_FIRST_COLOR_INT && value.type <= TypedValue.TYPE_LAST_COLOR_INT) {
			return value.data;
		}
		return fallback;
	}

	private static int dp(Context context, int value) {
		return Math.round(value * context.getResources().getDisplayMetrics().density);
	}
}
