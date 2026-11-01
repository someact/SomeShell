// Quick math for the search page. A small recursive-descent parser: numbers,
// + - * / % ^ (or **), parentheses, unary minus, the constants pi and e, and
// sqrt abs round floor ceil sin cos tan log ln. Never evaluates code.
//   evaluate("2 + 3 * 4")  -> 14
//   evaluate("hello")      -> null (not math)
.pragma library

const FUNCS = {
    sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    sin: Math.sin, cos: Math.cos, tan: Math.tan, log: Math.log10, ln: Math.log
};
const CONSTS = { pi: Math.PI, e: Math.E };

function tokenize(s) {
    const tokens = [];
    let i = 0;
    while (i < s.length) {
        const c = s[i];
        if (c === " ") { i++; continue; }
        const num = /^(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?/.exec(s.slice(i));
        if (num) { tokens.push({ t: "n", v: parseFloat(num[0]) }); i += num[0].length; continue; }
        const word = /^[a-z]+/i.exec(s.slice(i));
        if (word) { tokens.push({ t: "w", v: word[0].toLowerCase() }); i += word[0].length; continue; }
        if (s.startsWith("**", i)) { tokens.push({ t: "o", v: "^" }); i += 2; continue; }
        if ("+-*/%^()×÷,".includes(c)) {
            tokens.push({ t: "o", v: c === "×" ? "*" : c === "÷" ? "/" : c });
            i++;
            continue;
        }
        return null;
    }
    return tokens;
}

function evaluate(text) {
    const s = String(text).trim().replace(/,(?=\d{3}\b)/g, "");
    // Must contain an operator or a function, so a plain number is not "math"
    if (!s || !/[-+*/%^×÷(]/.test(s.replace(/^-/, "")))
        return null;
    const tokens = tokenize(s);
    if (!tokens || tokens.length === 0)
        return null;
    let p = 0;
    const peek = () => tokens[p];
    const take = () => tokens[p++];
    const isOp = v => peek() && peek().t === "o" && peek().v === v;

    function primary() {
        const tk = take();
        if (!tk) throw "end";
        if (tk.t === "n") return tk.v;
        if (tk.t === "o" && tk.v === "(") {
            const v = sum();
            if (!isOp(")")) throw "paren";
            take();
            return v;
        }
        if (tk.t === "o" && tk.v === "-") return -power();
        if (tk.t === "o" && tk.v === "+") return power();
        if (tk.t === "w") {
            if (tk.v in CONSTS) return CONSTS[tk.v];
            if (tk.v in FUNCS) return FUNCS[tk.v](power());
        }
        throw "token";
    }
    function power() {
        const base = primary();
        if (isOp("^")) { take(); return Math.pow(base, unary()); }
        return base;
    }
    function unary() {
        if (isOp("-")) { take(); return -unary(); }
        return power();
    }
    function product() {
        let v = unary();
        while (isOp("*") || isOp("/") || isOp("%")) {
            const op = take().v;
            const r = unary();
            v = op === "*" ? v * r : op === "/" ? v / r : v % r;
        }
        return v;
    }
    function sum() {
        let v = product();
        while (isOp("+") || isOp("-")) {
            const op = take().v;
            const r = product();
            v = op === "+" ? v + r : v - r;
        }
        return v;
    }

    try {
        const v = sum();
        if (p !== tokens.length || !isFinite(v))
            return null;
        return v;
    } catch (e) {
        return null;
    }
}

// 1234567.891 -> "1,234,567.891" (at most 10 significant decimals)
function format(v) {
    const rounded = Math.round(v * 1e10) / 1e10;
    const parts = String(rounded).split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return parts.join(".");
}
