.pragma library

// Stand-in for the i18n() family the Plasma applet engine injects. tools/lib.sh
// (tracker_stub_i18n) stages it and rewrites the calls there: i18n() -> tr(),
// i18nc() -> trc(), i18np() -> trp(), i18ncp() -> trcp(). The text is the
// untranslated source with %1, %2 … filled in; without a translation there is no
// context handling and no plural rule beyond the English 1/other split.
function tr(text) {
    var args = Array.prototype.slice.call(arguments, 1);
    return String(text).replace(/%([0-9]+)/g, function (match, index) {
        var value = args[Number(index) - 1];
        return value === undefined ? match : String(value);
    });
}

// i18nc(context, text, ...): the context is dropped.
function trc(context, text) {
    return tr.apply(null, Array.prototype.slice.call(arguments, 1));
}

// i18np(singular, plural, count, ...): count selects the text and fills %1.
function trp(singular, plural, count) {
    var rest = Array.prototype.slice.call(arguments, 3);
    return tr.apply(null, [count === 1 ? singular : plural, count].concat(rest));
}

// i18ncp(context, singular, plural, count, ...): context dropped as in trc().
function trcp(context, singular, plural, count) {
    return trp.apply(null, Array.prototype.slice.call(arguments, 1));
}
