// Loads a QML JavaScript library (".pragma library") into a Node VM context, so
// the pure logic can be tested without a Plasma runtime.
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const projectRoot = path.resolve(__dirname, "..", "..");

function loadQmlLibrary(relativePath, exportNames) {
    const filePath = path.join(projectRoot, relativePath);
    // The directive is invalid for JavaScript parsers and is removed. Do not
    // search only at the absolute start of the file: a BOM, a blank line or a
    // leading comment must not break loading with a syntax error.
    const source = fs.readFileSync(filePath, "utf8")
        .replace(/^[ \t]*\.pragma library[^\n]*\r?\n/m, "");
    const context = vm.createContext({});
    vm.runInContext(source + "\nthis.api = {" + exportNames.join(", ") + "};", context);
    return context.api;
}

// Objects from the VM context have a foreign prototype and therefore fail
// assert.deepEqual. JSON normalises them into the test world.
function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

module.exports = { loadQmlLibrary, plain, projectRoot };
