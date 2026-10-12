.pragma library

// palette.js - the built-in colour themes, their names and the contrast fixes.

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

var THEME_ORDER = ["tokyoNight", "catppuccinMocha", "nord", "rosePine", "everforest", "kanagawa"];

// themeNames - the theme keys in the order the settings window lists them.
function themeNames() {
    var names = [];
    for (var i = 0; i < THEME_ORDER.length; i += 1) {
        names.push(THEME_ORDER[i]);
    }
    return names;
}

// isSystemTheme - true for the "system" pseudo theme (the Plasma colours).
function isSystemTheme(name) {
    return String(name) === SYSTEM_THEME;
}

// isKnownTheme - true when the name is one of the built-in themes.
function isKnownTheme(name) {
    return Object.prototype.hasOwnProperty.call(THEMES, String(name));
}

// displayName - the name to show, falling back to the raw string.
function displayName(name) {
    return isKnownTheme(name) ? DISPLAY_NAMES[String(name)] : String(name);
}

// getTheme - a copy of the theme's colour values, null for an unknown name.
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

// clampOpacityPercent - opacity as a whole number 0-100, else the default 55.
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

// Keep both states at 3:1 contrast and distinguish them by luminance.

var MIN_GRAPHIC_CONTRAST = 3.0;
// Heuristic; WCAG does not define a threshold between states.
var MIN_STATE_LUMINANCE_RATIO = 1.5;

var CONTRAST_STEPS = 32;
var LUMINANCE_STEP = 0.04;

// hexToRgb - parses #rrggbb (or #aarrggbb), null when the value does not fit.
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

// rgbToHex - the #rrggbb text of an r/g/b triple with clamped channels.
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

// linearize - one sRGB channel as a linear value (WCAG relative luminance).
function linearize(channel) {
    var value = channel / 255;
    return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
}

// relativeLuminance - WCAG relative luminance of a colour, null for a bad value.
function relativeLuminance(hex) {
    var rgb = hexToRgb(hex);
    if (rgb === null) {
        return null;
    }
    return 0.2126 * linearize(rgb.r) + 0.7152 * linearize(rgb.g) + 0.0722 * linearize(rgb.b);
}

// contrastRatio - WCAG contrast ratio of two colours, null for a bad value.
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

// mixColors - mixes two colours: part 0 = the first, 1 = the second.
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

// ensureContrast - moves a colour towards white/black until minRatio is reached.
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

// stateColors - peak/off-peak colours that keep contrast and differ in luminance.
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

// resolveTheme - the ready-to-use colours of a theme name; null for unknown/system.
function resolveTheme(name) {
    var base = getTheme(name);
    return base === null ? null : resolveThemeColors(base);
}

// resolveThemeColors - applies the contrast fixes to a theme or system colour set.
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

// systemTheme - resolves the Plasma colours the popup hands in.
function systemTheme(background, foreground, positive, negative, border) {
    return resolveThemeColors({
        background: background,
        foreground: foreground,
        positive: positive,
        negative: negative,
        border: border
    });
}
