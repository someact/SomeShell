// Calendar files (iCalendar / ICS) for the calendar page: read the events,
// then list the ones in a date range with repeating events expanded.
//   const events = parse(text)
//   occurrences(events, from, to) -> [{ title, place, start, end, allDay }]
// Repeats: FREQ DAILY/WEEKLY/MONTHLY/YEARLY with INTERVAL, COUNT, UNTIL,
// BYDAY (weekly days; monthly "2TU", "-1FR"), BYMONTHDAY, EXDATE, and moved
// single occurrences (RECURRENCE-ID). Times with a TZID are taken as local
// time; UTC times ("Z") are converted.
.pragma library

const DAY = 86400000;
const WEEKDAYS = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];

// Unfold continued lines and split "NAME;PARAMS:VALUE"
function lines(text) {
    const raw = text.replace(/\r\n/g, "\n").replace(/\n[ \t]/g, "").split("\n");
    const out = [];
    for (const l of raw) {
        const colon = findColon(l);
        if (colon < 0)
            continue;
        const head = l.slice(0, colon).split(";");
        const params = {};
        for (let i = 1; i < head.length; i++) {
            const eq = head[i].indexOf("=");
            if (eq > 0)
                params[head[i].slice(0, eq).toUpperCase()] = head[i].slice(eq + 1).replace(/^"|"$/g, "");
        }
        out.push({ name: head[0].toUpperCase(), params: params, value: l.slice(colon + 1) });
    }
    return out;
}
// The first colon outside quotes (parameter values may hold colons)
function findColon(l) {
    let quoted = false;
    for (let i = 0; i < l.length; i++) {
        if (l[i] === '"')
            quoted = !quoted;
        else if (l[i] === ":" && !quoted)
            return i;
    }
    return -1;
}

function unescape(v) {
    return v.replace(/\\n/gi, " ").replace(/\\([,;\\])/g, "$1").trim();
}

// "20261102" (a day) or "20261102T093000[Z]" -> { date, allDay }
function parseDate(value, params) {
    const m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/.exec(value.trim());
    if (!m)
        return null;
    const y = +m[1], mo = +m[2] - 1, d = +m[3];
    if (m[4] === undefined || params?.VALUE === "DATE")
        return { date: new Date(y, mo, d), allDay: true };
    const h = +m[4], mi = +m[5], s = +(m[6] ?? 0);
    const date = m[7] ? new Date(Date.UTC(y, mo, d, h, mi, s)) : new Date(y, mo, d, h, mi, s);
    return { date: date, allDay: false };
}

// "P1D", "PT1H30M", "P2W" -> milliseconds
function parseDuration(v) {
    const m = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(v.trim());
    if (!m)
        return 0;
    const ms = (+(m[2] ?? 0) * 7 + +(m[3] ?? 0)) * DAY + (+(m[4] ?? 0) * 3600 + +(m[5] ?? 0) * 60 + +(m[6] ?? 0)) * 1000;
    return m[1] === "-" ? -ms : ms;
}

function parseRule(v) {
    const r = {};
    for (const part of v.split(";")) {
        const eq = part.indexOf("=");
        if (eq > 0)
            r[part.slice(0, eq).toUpperCase()] = part.slice(eq + 1);
    }
    const rule = {
        freq: r.FREQ,
        interval: Math.max(1, parseInt(r.INTERVAL) || 1),
        count: r.COUNT ? parseInt(r.COUNT) : 0,
        until: r.UNTIL ? parseDate(r.UNTIL)?.date ?? null : null,
        byDay: [],
        byMonthDay: r.BYMONTHDAY ? r.BYMONTHDAY.split(",").map(Number) : []
    };
    if (r.BYDAY) {
        for (const d of r.BYDAY.split(",")) {
            const m = /^([+-]?\d+)?([A-Z]{2})$/.exec(d.trim());
            if (m && WEEKDAYS.indexOf(m[2]) >= 0)
                rule.byDay.push({ n: m[1] ? parseInt(m[1]) : 0, day: WEEKDAYS.indexOf(m[2]) });
        }
    }
    return rule;
}

function parse(text) {
    const events = [];
    let ev = null;
    for (const l of lines(text)) {
        if (l.name === "BEGIN" && l.value.toUpperCase() === "VEVENT") {
            ev = { uid: "", title: "", place: "", start: null, end: null, allDay: false, duration: -1, rule: null, exdates: [], recurrenceId: null, cancelled: false };
        } else if (l.name === "END" && l.value.toUpperCase() === "VEVENT") {
            if (ev && ev.start && !ev.cancelled) {
                if (!ev.end)
                    ev.end = new Date(ev.start.getTime() + (ev.duration >= 0 ? ev.duration : ev.allDay ? DAY : 0));
                events.push(ev);
            }
            ev = null;
        } else if (ev) {
            switch (l.name) {
            case "UID": ev.uid = l.value; break;
            case "SUMMARY": ev.title = unescape(l.value); break;
            case "LOCATION": ev.place = unescape(l.value); break;
            case "STATUS": ev.cancelled = l.value.toUpperCase() === "CANCELLED"; break;
            case "DTSTART": {
                const d = parseDate(l.value, l.params);
                if (d) { ev.start = d.date; ev.allDay = d.allDay; }
                break;
            }
            case "DTEND": {
                const d = parseDate(l.value, l.params);
                if (d) ev.end = d.date;
                break;
            }
            case "DURATION": ev.duration = parseDuration(l.value); break;
            case "RRULE": ev.rule = parseRule(l.value); break;
            case "EXDATE":
                for (const v of l.value.split(",")) {
                    const d = parseDate(v, l.params);
                    if (d) ev.exdates.push(d.date.getTime());
                }
                break;
            case "RECURRENCE-ID": {
                const d = parseDate(l.value, l.params);
                if (d) ev.recurrenceId = d.date.getTime();
                break;
            }
            }
        }
    }
    return events;
}

function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}
function atTime(day, from) {
    return new Date(day.getFullYear(), day.getMonth(), day.getDate(), from.getHours(), from.getMinutes(), from.getSeconds());
}
// The nth (1-based; negative counts from the end) weekday of a month
function nthWeekday(year, month, weekday, n) {
    if (n > 0) {
        const first = new Date(year, month, 1).getDay();
        const d = 1 + (weekday - first + 7) % 7 + (n - 1) * 7;
        return d <= new Date(year, month + 1, 0).getDate() ? d : 0;
    }
    const lastDay = new Date(year, month + 1, 0).getDate();
    const last = new Date(year, month, lastDay).getDay();
    const d = lastDay - (last - weekday + 7) % 7 + (n + 1) * 7;
    return d >= 1 ? d : 0;
}

// The start times of a repeating event, in order, from its first one
function* starts(ev) {
    const r = ev.rule, s = ev.start;
    const max = 5000;
    let k = 0;
    while (k < max) {
        let days = [];
        if (r.freq === "DAILY") {
            days = [new Date(s.getFullYear(), s.getMonth(), s.getDate() + k * r.interval)];
        } else if (r.freq === "WEEKLY") {
            const weekStart = new Date(s.getFullYear(), s.getMonth(), s.getDate() - s.getDay() + k * 7 * r.interval);
            const wd = r.byDay.length ? r.byDay.map(b => b.day).sort((a, b) => a - b) : [s.getDay()];
            days = wd.map(d => new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate() + d));
        } else if (r.freq === "MONTHLY") {
            const y = s.getFullYear(), m = s.getMonth() + k * r.interval;
            const first = new Date(y, m, 1);
            const len = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
            let nums = [];
            if (r.byDay.length)
                nums = r.byDay.map(b => b.n ? nthWeekday(first.getFullYear(), first.getMonth(), b.day, b.n) : 0).filter(Boolean);
            else if (r.byMonthDay.length)
                nums = r.byMonthDay.map(d => d > 0 ? d : len + d + 1).filter(d => d >= 1 && d <= len);
            else if (s.getDate() <= len)
                nums = [s.getDate()];
            days = nums.sort((a, b) => a - b).map(d => new Date(first.getFullYear(), first.getMonth(), d));
        } else if (r.freq === "YEARLY") {
            const d = new Date(s.getFullYear() + k * r.interval, s.getMonth(), s.getDate());
            days = d.getMonth() === s.getMonth() ? [d] : [];   // no 29 Feb in other years
        } else {
            return;
        }
        for (const day of days) {
            const t = ev.allDay ? day : atTime(day, s);
            if (t < s)
                continue;
            yield t;
        }
        k++;
    }
}

// Events between `from` and `to` (Dates), repeats expanded, sorted by start
function occurrences(events, from, to) {
    const moved = {};
    for (const ev of events)
        if (ev.recurrenceId !== null)
            (moved[ev.uid] = moved[ev.uid] || {})[ev.recurrenceId] = true;

    const out = [];
    const add = (ev, start) => {
        const end = new Date(start.getTime() + (ev.end - ev.start));
        if (end > from && start < to || (start >= from && start < to))
            out.push({ title: ev.title || "(no title)", place: ev.place, start: start, end: end, allDay: ev.allDay });
    };
    for (const ev of events) {
        if (!ev.rule || ev.recurrenceId !== null) {
            add(ev, ev.start);
            continue;
        }
        const r = ev.rule;
        let n = 0;
        for (const t of starts(ev)) {
            if (r.until && t > r.until)
                break;
            n++;
            if (r.count && n > r.count)
                break;
            if (t >= to)
                break;
            const ms = t.getTime();
            if (ev.exdates.indexOf(ms) >= 0 || (moved[ev.uid] && moved[ev.uid][ms]))
                continue;
            add(ev, t);
        }
    }
    out.sort((a, b) => a.start - b.start || (b.allDay - a.allDay));
    return out;
}

// Events on one day (all-day ones first)
function onDay(list, day) {
    const a = new Date(day.getFullYear(), day.getMonth(), day.getDate());
    const b = new Date(a.getTime() + DAY);
    return list.filter(e => e.start < b && e.end > a || sameDay(e.start, a));
}
