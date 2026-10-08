.pragma library
// Colour themes for the card, status dot and timeline. Pure data: UI strings and
// translations stay in QML, because i18n() is not available here.
//
// Every theme defines the same five keys:
//   background  card surface
//   foreground  text
//   positive    off-peak (green; Rosé Pine uses cyan there, see below)
//   negative    peak (red)
//   border      thin card border
//
// "system" is deliberately not an entry in this table: then the colours of the
// Plasma colour scheme (Kirigami.Theme) apply, and main.qml resolves that.
//
// The table keeps the upstream values unchanged. What gets drawn, however, are
// the derived values from resolveTheme(): only that keeps off-peak and peak above
// the contrast threshold (see the colour maths below).
//
// Sources of the colour values (the hex codes are facts, the palettes themselves
// are MIT licensed - see the "Colour themes" section of the README):
//   Tokyo Night       tokyo-night/tokyo-night-vscode-theme
//   Catppuccin Mocha  catppuccin/palette 1.8.0
//   Nord              nordtheme.com/docs/colors-and-palettes
//   Rosé Pine         rosepinetheme.com/palette
//   Everforest        sainnhe/everforest, palette.md (dark, medium)
//   Kanagawa          rebelot/kanagawa.nvim, colors.lua (wave)

var SYSTEM_THEME = "system";
var DEFAULT_OPACITY = 55;

// Display names are proper nouns and therefore not translated.
var DISPLAY_NAMES = {
    tokyoNight: "Tokyo Night",
    catppuccinMocha: "Catppuccin Mocha",
    nord: "Nord",
    rosePine: "Rosé Pine",
    everforest: "Everforest",
    kanagawa: "Kanagawa"
};

var THEMES = {
    tokyoNight: {
        background: "#1a1b26",
        foreground: "#c0caf5",
        positive: "#9ece6a",
        negative: "#f7768e",
        border: "#414868"
    },
    catppuccinMocha: {
        background: "#1e1e2e",
        foreground: "#cdd6f4",
        positive: "#a6e3a1",
        negative: "#f38ba8",
        border: "#45475a"
    },
    nord: {
        background: "#2e3440",
        foreground: "#d8dee9",
        positive: "#a3be8c",
        negative: "#bf616a",
        border: "#4c566a"
    },
    rosePine: {
        background: "#191724",
        foreground: "#e0def4",
        positive: "#9ccfd8",
        negative: "#eb6f92",
        border: "#403d52"
    },
    everforest: {
        background: "#2d353b",
        foreground: "#d3c6aa",
        positive: "#a7c080",
        negative: "#e67e80",
        border: "#475258"
    },
    kanagawa: {
        background: "#1f1f28",
        foreground: "#dcd7ba",
        positive: "#98bb6c",
        negative: "#e46876",
        border: "#54546d"
    }
};

// Order of the picker list in the settings.
var THEME_ORDER = ["tokyoNight", "catppuccinMocha", "nord", "rosePine", "everforest", "kanagawa"];

function themeNames() {
    var names = [];
    for (var i = 0; i < THEME_ORDER.length; i += 1) {
        names.push(THEME_ORDER[i]);
    }
    return names;
}

function isSystemTheme(name) {
    return String(name) === SYSTEM_THEME;
}

function isKnownTheme(name) {
    return Object.prototype.hasOwnProperty.call(THEMES, String(name));
}

function displayName(name) {
    return isKnownTheme(name) ? DISPLAY_NAMES[String(name)] : String(name);
}

// Hand out a copy, so a view cannot modify the table.
function getTheme(name) {
    if (!isKnownTheme(name)) {
        return null;
    }
    var source = THEMES[String(name)];
    var result = {};
    for (var key in source) {
        if (Object.prototype.hasOwnProperty.call(source, key)) {
            result[key] = source[key];
        }
    }
    return result;
}

// Opacity from the configuration: whole number 0..100. Unusable values (for
// example from a hand-edited configuration) fall back to the default; the views
// divide by 100 and get the alpha 0..1 from it.
function clampOpacityPercent(value) {
    if (value === null || value === undefined || value === "") {
        return DEFAULT_OPACITY;
    }
    var number = Number(value);
    if (isNaN(number)) {
        return DEFAULT_OPACITY;
    }
    number = Math.round(number);
    if (number < 0) {
        return 0;
    }
    if (number > 100) {
        return 100;
    }
    return number;
}

// --- Colour maths ----------------------------------------------------------
// Pure functions on "#rrggbb" values; "#aarrggbb" is read too, with the alpha
// ignored. Testable without a Plasma runtime.
//
// Why derive at all? The upstream palettes are designed for syntax highlighting
// on their own surface, not for two states side by side. Measured against the
// card surface, the Nord red barely misses the graphical-object threshold at
// 3.05:1, and several themes separate green and red hardly in luminance - without
// colour vision peak and off-peak then look the same.

// WCAG 1.4.11 (non-text contrast) for graphical objects.
var MIN_GRAPHIC_CONTRAST = 3.0;
// Heuristic for red-green colour vision: luminance ratio between peak and
// off-peak. Deliberately not a WCAG value, WCAG defines no separation between
// states.
var MIN_STATE_LUMINANCE_RATIO = 1.5;

// Steps in which ensureContrast and stateColors approach the target.
var CONTRAST_STEPS = 32;
var LUMINANCE_STEP = 0.04;

// Reads a hex value; null instead of a guessed value when it does not fit.
// Eight-digit values are "#aarrggbb" (how QML prints a colour with alpha), the
// alpha is dropped.
function hexToRgb(hex) {
    var value = String(hex).trim();
    if (/^#[0-9a-fA-F]{8}$/.test(value)) {
        value = "#" + value.substr(3);
    }
    if (!/^#[0-9a-fA-F]{6}$/.test(value)) {
        return null;
    }
    return {
        r: parseInt(value.substr(1, 2), 16),
        g: parseInt(value.substr(3, 2), 16),
        b: parseInt(value.substr(5, 2), 16)
    };
}

// Counterpart to hexToRgb; rounds and clamps to 0..255.
function rgbToHex(rgb) {
    function channel(value) {
        var number = Math.round(value);
        if (number < 0) {
            number = 0;
        }
        if (number > 255) {
            number = 255;
        }
        var text = number.toString(16);
        return text.length === 1 ? "0" + text : text;
    }
    return "#" + channel(rgb.r) + channel(rgb.g) + channel(rgb.b);
}

// Single channel from sRGB to linear light (WCAG formula).
function linearize(channel) {
    var value = channel / 255;
    return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
}

// Relative luminance 0..1; null for an unusable hex value.
function relativeLuminance(hex) {
    var rgb = hexToRgb(hex);
    if (rgb === null) {
        return null;
    }
    return 0.2126 * linearize(rgb.r) + 0.7152 * linearize(rgb.g) + 0.0722 * linearize(rgb.b);
}

// WCAG contrast 1:1 .. 21:1; null as soon as one value is unusable. Orders the
// colours itself, so the result is independent of the argument order.
function contrastRatio(colorA, colorB) {
    var luminanceA = relativeLuminance(colorA);
    var luminanceB = relativeLuminance(colorB);
    if (luminanceA === null || luminanceB === null) {
        return null;
    }
    var lighter = luminanceA > luminanceB ? luminanceA : luminanceB;
    var darker = luminanceA > luminanceB ? luminanceB : luminanceA;
    return (lighter + 0.05) / (darker + 0.05);
}

// Mixes two colours; part is the share of the second. So 0.4 is 40 percent of
// the target colour. Unusable values give null, part is clamped to 0..1.
function mixColors(colorA, colorB, part) {
    var first = hexToRgb(colorA);
    var second = hexToRgb(colorB);
    if (first === null || second === null) {
        return null;
    }
    var share = Number(part);
    if (isNaN(share)) {
        return null;
    }
    if (share < 0) {
        share = 0;
    }
    if (share > 1) {
        share = 1;
    }
    return rgbToHex({
        r: first.r + (second.r - first.r) * share,
        g: first.g + (second.g - first.g) * share,
        b: first.b + (second.b - first.b) * share
    });
}

// Raises a colour until it reaches the minimum contrast against the surface. The
// direction follows the surface: towards white on a dark surface, towards black
// on a light one. Because the target direction pulls the colour away from the
// surface, the contrast grows monotonically. If the target is unreachable with
// either endpoint (a mid-grey surface lets neither white nor black reach 3:1),
// the endpoint with the higher contrast wins.
function ensureContrast(hex, backgroundHex, minRatio) {
    var rgb = hexToRgb(hex);
    if (rgb === null || hexToRgb(backgroundHex) === null) {
        return null;
    }
    var color = rgbToHex(rgb);
    var target = Number(minRatio);
    if (isNaN(target) || target < 1) {
        target = 1;
    }
    if (contrastRatio(color, backgroundHex) >= target) {
        return color;
    }
    var darkBackground = relativeLuminance(backgroundHex) < 0.5;
    var goal = darkBackground ? "#ffffff" : "#000000";
    var other = darkBackground ? "#000000" : "#ffffff";
    if (contrastRatio(goal, backgroundHex) < contrastRatio(other, backgroundHex)) {
        var swap = goal;
        goal = other;
        other = swap;
    }
    var reached = color;
    for (var step = 1; step <= CONTRAST_STEPS; step += 1) {
        var candidate = mixColors(color, goal, step / CONTRAST_STEPS);
        if (contrastRatio(candidate, backgroundHex) >= target) {
            return candidate;
        }
        reached = candidate;
    }
    return contrastRatio(goal, backgroundHex) > contrastRatio(reached, backgroundHex)
        ? goal
        : reached;
}

// Shapes off-peak and peak together: both hold the graphical threshold against
// the card surface, and they additionally differ in luminance. The distance
// always grows in the direction that also increases the surface contrast, so
// neither threshold undoes the other.
function stateColors(positiveHex, negativeHex, backgroundHex) {
    var positive = ensureContrast(positiveHex, backgroundHex, MIN_GRAPHIC_CONTRAST);
    var negative = ensureContrast(negativeHex, backgroundHex, MIN_GRAPHIC_CONTRAST);
    if (positive === null || negative === null) {
        return null;
    }
    var darkBackground = relativeLuminance(backgroundHex) < 0.5;
    var goal = darkBackground ? "#ffffff" : "#000000";
    for (var step = 0; step < CONTRAST_STEPS; step += 1) {
        if (contrastRatio(positive, negative) >= MIN_STATE_LUMINANCE_RATIO) {
            break;
        }
        // On a dark surface the lighter tone moves further up, on a light
        // surface the darker one moves further down.
        var positiveIsBrighter = relativeLuminance(positive) >= relativeLuminance(negative);
        var target = darkBackground === positiveIsBrighter ? positive : negative;
        var next = mixColors(target, goal, LUMINANCE_STEP);
        if (next === target) {
            break;
        }
        if (target === positive) {
            positive = next;
        } else {
            negative = next;
        }
    }
    return { positive: positive, negative: negative };
}

// Like getTheme, but with the drawn off-peak/peak colours. "system" and unknown
// names give null, so the views need no special case.
function resolveTheme(name) {
    var base = getTheme(name);
    return base === null ? null : resolveThemeColors(base);
}

// Takes an already resolved five-key object - the palette from THEMES or the
// values of the Plasma colour scheme - and returns a copy with contrast-checked
// positive/negative. The other keys stay untouched. Values that are not a hex
// colour (for example a QML colour with alpha) are passed through unchanged
// instead of tinting the view.
function resolveThemeColors(theme) {
    if (theme === null || theme === undefined) {
        return null;
    }
    var result = {};
    for (var key in theme) {
        if (Object.prototype.hasOwnProperty.call(theme, key)) {
            result[key] = theme[key];
        }
    }
    var derived = stateColors(String(theme.positive), String(theme.negative),
        String(theme.background));
    if (derived !== null) {
        result.positive = derived.positive;
        result.negative = derived.negative;
    }
    return result;
}

// The five values of the Plasma colour scheme (or Breeze Dark in the render
// fixture) as a theme object. The widget (main.qml) and the settings preview
// (configGeneral.qml) both build it here, so the key list and the contrast
// derivation live in one place. The border is passed in already dimmed, because
// Qt.rgba() is only available in QML, not in a .pragma library.
function systemTheme(background, foreground, positive, negative, border) {
    return resolveThemeColors({
        background: background,
        foreground: foreground,
        positive: positive,
        negative: negative,
        border: border
    });
}
