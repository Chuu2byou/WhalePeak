// Tests for contents/code/palette.js (colour themes and opacity).
const assert = require("node:assert/strict");
const test = require("node:test");
const { loadQmlLibrary, plain } = require("./helpers/qml_library.js");

const palette = loadQmlLibrary("contents/code/palette.js", [
    "themeNames", "isKnownTheme", "isSystemTheme", "displayName", "getTheme",
    "clampOpacityPercent", "SYSTEM_THEME", "DEFAULT_OPACITY",
    "MIN_GRAPHIC_CONTRAST", "MIN_STATE_LUMINANCE_RATIO",
    "hexToRgb", "relativeLuminance", "contrastRatio", "mixColors",
    "ensureContrast", "stateColors", "resolveTheme", "resolveThemeColors",
    "systemTheme"
]);

// Contract: every theme returns exactly these colour keys.
const KEYS = ["background", "foreground", "positive", "negative", "border"];
const HEX = /^#[0-9a-fA-F]{6}$/;

test("names the curated themes in picker order", () => {
    assert.deepEqual(plain(palette.themeNames()), [
        "tokyoNight", "catppuccinMocha", "nord", "rosePine", "everforest", "kanagawa"
    ]);
});

test("'system' is a mode, not a palette entry", () => {
    assert.equal(palette.SYSTEM_THEME, "system");
    assert.equal(palette.isSystemTheme("system"), true);
    assert.equal(palette.isSystemTheme("tokyoNight"), false);
    assert.equal(palette.isKnownTheme("system"), false);
});

test("every theme defines exactly the documented colours", () => {
    const names = palette.themeNames();
    assert.ok(names.length > 0);
    names.forEach((name) => {
        const theme = palette.getTheme(name);
        assert.notEqual(theme, null, name);
        assert.deepEqual(Object.keys(theme).sort(), KEYS.slice().sort(), name);
        KEYS.forEach((key) => {
            assert.match(String(theme[key]), HEX, name + "." + key);
        });
    });
});

test("display names are proper nouns and stay usable for the model", () => {
    assert.equal(palette.displayName("tokyoNight"), "Tokyo Night");
    assert.equal(palette.displayName("catppuccinMocha"), "Catppuccin Mocha");
    assert.equal(palette.displayName("rosePine"), "Rosé Pine");
    palette.themeNames().forEach((name) => {
        assert.ok(palette.displayName(name).length > 0, name);
    });
    // Unknown names are passed through, so the model does not end up empty.
    assert.equal(palette.displayName("nope"), "nope");
});

test("unknown and system themes resolve to null", () => {
    ["system", "", "nope", "TOKYONIGHT"].forEach((name) => {
        assert.equal(palette.getTheme(name), null, name);
    });
    assert.equal(palette.getTheme(null), null);
    assert.equal(palette.getTheme(undefined), null);
});

test("getTheme hands out copies so a view cannot change the table", () => {
    const first = palette.getTheme("nord");
    first.background = "#000000";
    assert.equal(palette.getTheme("nord").background, "#2e3440");
});

test("opacity is clamped to a whole percentage", () => {
    assert.equal(palette.DEFAULT_OPACITY, 55);
    assert.equal(palette.clampOpacityPercent(0), 0);
    assert.equal(palette.clampOpacityPercent(100), 100);
    assert.equal(palette.clampOpacityPercent(55), 55);
    assert.equal(palette.clampOpacityPercent(55.4), 55);
    assert.equal(palette.clampOpacityPercent(-5), 0);
    assert.equal(palette.clampOpacityPercent(300), 100);
    assert.equal(palette.clampOpacityPercent("70"), 70);
});

test("unusable opacity values fall back to the default", () => {
    [null, undefined, "", "abc", NaN, {}].forEach((value) => {
        assert.equal(palette.clampOpacityPercent(value), 55, String(value));
    });
});

// Colour helpers: pure functions on hex values, so the thresholds are testable
// without Plasma.
test("the colour helpers read and write hex values", () => {
    assert.deepEqual(plain(palette.hexToRgb("#a3be8c")), { r: 163, g: 190, b: 140 });
    // Alpha is read but not counted.
    assert.deepEqual(plain(palette.hexToRgb("#80a3be8c")), { r: 163, g: 190, b: 140 });
    ["nord", "#12345", "#zzzzzz", "", null, undefined].forEach((value) => {
        assert.equal(palette.hexToRgb(value), null, String(value));
    });
    assert.equal(palette.mixColors("#000000", "#ffffff", 0), "#000000");
    assert.equal(palette.mixColors("#000000", "#ffffff", 0.5), "#808080");
    assert.equal(palette.mixColors("#000000", "#ffffff", 5), "#ffffff");
    assert.equal(palette.mixColors("#000000", "nope", 0.5), null);
});

test("contrast follows the WCAG formula and ignores the argument order", () => {
    assert.ok(Math.abs(palette.contrastRatio("#000000", "#ffffff") - 21) < 1e-9);
    assert.equal(palette.contrastRatio("#ffffff", "#000000"),
        palette.contrastRatio("#000000", "#ffffff"));
    assert.equal(palette.contrastRatio("#000000", "#000000"), 1);
    assert.equal(palette.relativeLuminance("#000000"), 0);
    assert.ok(Math.abs(palette.relativeLuminance("#ffffff") - 1) < 1e-9);
    assert.equal(palette.contrastRatio("nope", "#000000"), null);
    assert.equal(palette.ensureContrast("nope", "#000000", 3), null);
});

test("every theme keeps the graphic contrast threshold on its own surface", () => {
    assert.equal(palette.MIN_GRAPHIC_CONTRAST, 3);
    palette.themeNames().forEach((name) => {
        const theme = palette.resolveTheme(name);
        assert.ok(palette.contrastRatio(theme.positive, theme.background)
            >= palette.MIN_GRAPHIC_CONTRAST, name + ".positive");
        assert.ok(palette.contrastRatio(theme.negative, theme.background)
            >= palette.MIN_GRAPHIC_CONTRAST, name + ".negative");
    });
});

test("peak and off-peak stay apart in brightness", () => {
    assert.equal(palette.MIN_STATE_LUMINANCE_RATIO, 1.5);
    palette.themeNames().forEach((name) => {
        const theme = palette.resolveTheme(name);
        assert.ok(palette.contrastRatio(theme.positive, theme.negative)
            >= palette.MIN_STATE_LUMINANCE_RATIO, name);
    });
});

test("the drawn colours are a copy, the table keeps the upstream values", () => {
    const drawn = palette.resolveTheme("nord");
    drawn.positive = "#000000";
    assert.equal(palette.resolveTheme("nord").positive, "#a3be8c");
    assert.equal(palette.getTheme("nord").positive, "#a3be8c");
});

test("the derivation only moves the themes that fall short", () => {
    const moved = palette.themeNames().filter((name) => {
        const base = palette.getTheme(name);
        const drawn = palette.resolveTheme(name);
        return drawn.positive !== base.positive || drawn.negative !== base.negative;
    });
    assert.deepEqual(plain(moved), ["tokyoNight", "everforest", "kanagawa"]);
});

test("system and unknown names have no palette to derive from", () => {
    ["system", "nope", null, undefined].forEach((name) => {
        assert.equal(palette.resolveTheme(name), null, String(name));
    });
    assert.equal(palette.resolveThemeColors(null), null);
});

// Rosé Pine carries no green upstream: off-peak therefore stays Foam (cyan)
// rather than some foreign green.
test("Rose Pine keeps Foam as its off-peak colour", () => {
    assert.equal(palette.getTheme("rosePine").positive, "#9ccfd8");
    assert.equal(palette.resolveTheme("rosePine").positive, "#9ccfd8");
});

test("unusable colours are passed through instead of tinted", () => {
    const resolved = palette.resolveThemeColors({
        background: "#1e1e2e",
        foreground: "#cdd6f4",
        positive: "#a6e3a1",
        negative: "keine-farbe",
        border: "#45475a"
    });
    assert.equal(resolved.positive, "#a6e3a1");
    assert.equal(resolved.negative, "keine-farbe");
    assert.equal(resolved.foreground, "#cdd6f4");
    assert.equal(resolved.border, "#45475a");
});

// systemTheme is the shared builder for the Plasma colour scheme (main.qml and
// configGeneral.qml); it must produce the same five keys as a bundled theme.
test("systemTheme wraps the colour scheme in the five theme keys", () => {
    const theme = palette.systemTheme("#1e1e2e", "#cdd6f4", "#a6e3a1", "#f38ba8", "#45475a");
    assert.deepEqual(Object.keys(theme).sort(), KEYS.slice().sort());
    assert.equal(theme.background, "#1e1e2e");
    assert.equal(theme.border, "#45475a");
    // The derivation runs here too: the drawn states hold the graphic contrast.
    assert.ok(palette.contrastRatio(theme.positive, theme.background)
        >= palette.MIN_GRAPHIC_CONTRAST);
    assert.ok(palette.contrastRatio(theme.negative, theme.background)
        >= palette.MIN_GRAPHIC_CONTRAST);
});
