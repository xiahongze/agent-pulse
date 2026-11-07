.pragma library

function compactTokens(value) {
    const n = Math.max(0, Number(value) || 0);
    if (n >= 1000000) return (n / 1000000).toFixed(n < 10000000 ? 1 : 0) + "M";
    if (n >= 1000) return (n / 1000).toFixed(n < 10000 ? 1 : 0) + "K";
    return String(Math.round(n));
}

function percentage(window, now) {
    if (!window || window.expired || window.used_percent === null || window.used_percent === undefined)
        return "—";
    if (window.reset_epoch !== null && window.reset_epoch !== undefined && window.reset_epoch * 1000 <= now)
        return "—";
    const value = Number(window.used_percent);
    return isFinite(value) ? String(Math.round(Math.max(0, Math.min(100, value)))) : "—";
}

// Keep both columns stable: five-hour usage / weekly usage, even when a source
// supplies model-specific windows first or omits one of the standard windows.
function rows(providers, allAgents, codex, claude, now, failed) {
    return providers.filter(p => allAgents || (p.name === "Codex" && codex) || (p.name === "Claude" && claude)).map(p => {
        const name = p.name === "Codex" ? "CX" : p.name === "Claude" ? "CL" : p.name.slice(0, 2).toUpperCase();
        const stale = Boolean(failed || (p.usage_status && p.usage_status !== "disabled"));
        let value = "—";
        if (p.available) {
            const windows = p.rate_windows || [];
            const short = windows.find(w => w.label === "5 HOUR");
            const weekly = windows.find(w => w.label === "WEEKLY");
            value = short || weekly
                ? percentage(short, now) + "/" + percentage(weekly, now) + "%"
                : compactTokens(p.tokens_today) + " tok";
        }
        return {name: p.name, text: name + " " + (stale ? "~" : "") + value, stale: stale || !p.available};
    });
}
