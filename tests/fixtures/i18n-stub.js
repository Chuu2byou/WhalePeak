.pragma library

function tr(text) {
    var args = Array.prototype.slice.call(arguments, 1);
    return String(text).replace(/%([0-9]+)/g, function (match, index) {
        var value = args[Number(index) - 1];
        return value === undefined ? match : String(value);
    });
}

function trc(context, text) {
    return tr.apply(null, Array.prototype.slice.call(arguments, 1));
}

function trp(singular, plural, count) {
    var rest = Array.prototype.slice.call(arguments, 3);
    return tr.apply(null, [count === 1 ? singular : plural, count].concat(rest));
}

function trcp(context, singular, plural, count) {
    return trp.apply(null, Array.prototype.slice.call(arguments, 1));
}
