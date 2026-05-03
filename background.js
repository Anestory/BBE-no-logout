// Rewrites the auto-logoff threshold (1800 seconds = 30 minutes) to a value
// that effectively never triggers. The patch targets the inequality:
//   ub.get_lastInteractionActivityTimestamp() + 1800 < Q.get_now()
// in the AppAutoLogoutModule.onAutoLogoffTimerEvent handler.

const MARKER = "lastInteractionActivityTimestamp";

// Both spaced and unspaced variants of the inequality, since the live script
// may have been minified differently than the dev copy.
const PATTERNS = [
    { from: /\+\s*1800\s*</g, to: "+ 999999999 <" }
];

function patch(source) {
    if (!source.includes(MARKER)) {
        return { source, patched: false };
    }
    let patched = source;
    let hits = 0;
    for (const { from, to } of PATTERNS) {
        patched = patched.replace(from, (match) => {
            hits++;
            return to;
        });
    }
    return { source: patched, patched: hits > 0, hits };
}

browser.webRequest.onBeforeRequest.addListener(
    (details) => {
        const filter = browser.webRequest.filterResponseData(details.requestId);
        const decoder = new TextDecoder("utf-8");
        const encoder = new TextEncoder();
        const chunks = [];

        filter.ondata = (event) => {
            chunks.push(decoder.decode(event.data, { stream: true }));
        };

        filter.onstop = () => {
            chunks.push(decoder.decode());
            const original = chunks.join("");
            const result = patch(original);
            if (result.patched) {
                console.log(
                    `[BBE No Logout] patched ${result.hits} occurrence(s) in ${details.url}`
                );
            }
            filter.write(encoder.encode(result.source));
            filter.disconnect();
        };

        filter.onerror = () => {
            console.error(`[BBE No Logout] filter error on ${details.url}: ${filter.error}`);
        };
    },
    {
        urls: ["https://bbe-static.akamaized.net/assets/html5/BBE.min.js"],
        types: ["script"]
    },
    ["blocking"]
);

console.log("[BBE No Logout] background script loaded");
