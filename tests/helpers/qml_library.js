const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const projectRoot = path.resolve(__dirname, "..", "..");

function loadQmlLibrary(relativePath, exportNames) {
    const filePath = path.join(projectRoot, relativePath);
    const source = fs.readFileSync(filePath, "utf8")
        .replace(/^[ \t]*\.pragma library[^\n]*\r?\n/m, "");
    const context = vm.createContext({});
    vm.runInContext(source + "\nthis.api = {" + exportNames.join(", ") + "};", context);
    return context.api;
}

// Normalize cross-context objects before deep equality checks.
function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

module.exports = { loadQmlLibrary, plain, projectRoot };
