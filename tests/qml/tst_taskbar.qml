import QtQuick
import QtTest
import "../../contents/ui" as UI
import "../../contents/ui/taskbar.js" as Taskbar

TestCase {
    name: "TaskbarUsage"
    Component { id: usageComponent; UI.TaskbarUsage { rows: []; width: implicitWidth; height: implicitHeight } }
    function test_stacked_component_resizes() {
        const item = createTemporaryObject(usageComponent, this);
        verify(item !== null);
        item.rows = [{text: "CX 24%/8%", stale: false}, {text: "CL 12%/6%", stale: true}];
        tryCompare(item, "implicitHeight", 28);
        tryVerify(() => item.implicitWidth > 40 && item.implicitWidth < 110);
        item.rows = [{text: "CX 24%/8%", stale: false}];
        tryCompare(item, "implicitHeight", 14);
    }
    function provider(name, windows) {
        return {name: name, available: true, tokens_today: 12345, rate_windows: windows || []};
    }
    function test_selection() {
        const agents = [provider("Codex"), provider("Claude"), provider("Other")];
        compare(Taskbar.rows(agents, true, false, false, 0, false).length, 3);
        compare(Taskbar.rows(agents, false, true, false, 0, false).map(r => r.name), ["Codex"]);
        compare(Taskbar.rows(agents, false, false, true, 0, false).map(r => r.name), ["Claude"]);
        compare(Taskbar.rows(agents, false, true, true, 0, false).length, 2);
        compare(Taskbar.rows(agents, false, false, false, 0, false).length, 0);
    }
    function test_stable_window_order() {
        const p = provider("Codex", [{label: "SONNET WEEKLY", used_percent: 99},
            {label: "WEEKLY", used_percent: 8.2}, {label: "5 HOUR", used_percent: 24.1}]);
        compare(Taskbar.rows([p], true, true, true, 0, false)[0].text, "CX 24%/8%");
        p.rate_windows = [{label: "WEEKLY", used_percent: 8}];
        compare(Taskbar.rows([p], true, true, true, 0, false)[0].text, "CX —%/8%");
    }
    function test_expired_and_missing_usage() {
        compare(Taskbar.percentage({used_percent: 0}, 10000), "0");
        compare(Taskbar.percentage({used_percent: 75, reset_epoch: 10}, 10000), "—");
        compare(Taskbar.percentage({used_percent: 75, reset_epoch: 11}, 10000), "75");
        compare(Taskbar.percentage({used_percent: 75, expired: true}, 0), "—");
        compare(Taskbar.percentage({used_percent: null}, 0), "—");
        compare(Taskbar.percentage({used_percent: "invalid"}, 0), "—");
    }
    function test_tokens_fallback_and_unavailable() {
        const p = provider("Claude");
        compare(Taskbar.rows([p], true, true, true, 0, false)[0].text, "CL 12K tok");
        p.available = false;
        compare(Taskbar.rows([p], true, true, true, 0, false)[0].text, "CL —");
        verify(Taskbar.rows([p], true, true, true, 0, false)[0].stale);
    }
    function test_stale_and_disabled() {
        const p = provider("Codex");
        p.usage_status = "rate_limited";
        verify(Taskbar.rows([p], true, true, true, 0, false)[0].text.indexOf("~") >= 0);
        p.usage_status = "disabled";
        verify(!Taskbar.rows([p], true, true, true, 0, false)[0].stale);
        verify(Taskbar.rows([p], true, true, true, 0, true)[0].stale);
    }
    function test_short_tokens() {
        compare(Taskbar.compactTokens(0), "0");
        compare(Taskbar.compactTokens(1200), "1.2K");
        compare(Taskbar.compactTokens(1200000), "1.2M");
        compare(Taskbar.compactTokens(12000000), "12M");
    }
}
