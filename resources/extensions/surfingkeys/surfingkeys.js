// Compatibility Prefix
const {
    Clipboard,
    Front,
    Hints,
    Normal,
    RUNTIME,
    Visual,
    aceVimMap,
    addSearchAlias,
    cmap,
    getClickableElements,
    imap,
    imapkey,
    iunmap,
    map,
    mapkey,
    readText,
    removeSearchAlias,
    tabOpenLink,
    unmap,
    unmapAllExcept,
    vmapkey,
    vunmap,
    isElementPartiallyInViewport,
} = api;

settings.hintAlign = "left";
settings.tabsMRUOrder = false;
settings.smoothScroll = false;
settings.showModeStatus = false;

// Next & Previous regex
settings.nextLinkRegex = /((>>|next|بعد(ی)?)+)/i;
settings.prevLinkRegex = /((<<|prev(ious)?|قبل(ی)?)+)/i;
// settings.focusAfterClosed = 'last';

// Use omni bar for searching tabs
settings.tabsThreshold = 0;

// ---- Unmap -----
// Proxy Stuff
unmap("spa");
unmap("spb");
unmap("spc");
unmap("spd");
unmap("sps");
unmap("cp");
unmap(";cp");
unmap(";ap");
unmap(";pa");
unmap(";pb");
unmap(";pc");
unmap(";pd");
unmap(";ps");

// Emoji
iunmap(":");

// Misc
unmap(";t");
unmap("si");
unmap("ga");
unmap("gc");
unmap("gn");
unmap("gr");
unmap("ob");
unmap("gw");
unmap("gt");
// unmap('og');
unmap("od");
unmap("oy");

// Closing Tabs
unmap("gx0");
unmap("gxt");
unmap("gxT");
unmap("gx$");
unmap("gxx");
unmap("X")

// Open tab
unmap("on")

// Unused features
unmap("g0");

// Search Aliases
removeSearchAlias("b", "s");
removeSearchAlias("d", "s");
// removeSearchAlias('g', 's');
removeSearchAlias("h", "s");
removeSearchAlias("w", "s");
// removeSearchAlias('y', 's');
removeSearchAlias("s", "s");
removeSearchAlias("e", "s");

// ---- Map -----
// --- Hints ---
// Open Multiple Links
map("<Alt-f>", "cf");

// Open Hint in new tab
map("F", "C");

// --- Focus ---
// Focus on main frame
// map(';;', ';fss')
map(";;", ";fs");

// --- Nav ---
// Move Tab

// NOTE:: Used vivaldi shortcuts

// unmap('>>')
// unmap('>>')
// unmap('<<')
map(">", ">>");
map("<", "<<");

// Open Clipboard URL in current tab
mapkey("p", "Open the clipboard's URL in the current tab", () => {
    Clipboard.read(function(response) {
        window.location.href = response.data;
    });
});

// Open Clipboard URL in new tab
map("P", "cc");

// Open a URL in new tab
map("O", "t");

// Open a URL in current tab
map("oo", "go");

// Edit current URL, and open in same tab
map("ge", ";U");

// Edit current URL, and open in new tab
map("gE", ";u");

// History Back/Forward
map("H", "S");
map("L", "D");

// Open closed tabs
unmap("<Ctrl-X>");
map("<Ctrl-x>", "X");
unmap("X");

// Scroll Page Down/Up
map("u", "e");
mapkey("<Ctrl-d>", "scroll full page down", function() {
    Normal.scroll("fullPageDown");
});
mapkey("<Ctrl-u>", "scroll full page up", function() {
    Normal.scroll("fullPageUp");
});

// Next/Prev Page
map("K", "[[");
map("J", "]]");

// NOTE:: Used vivaldi shortcuts
// unmap("E");
// unmap("R");
// map('<Ctrl-n>', 'R');
// map('<Ctrl-p>', 'E');

// --- Input ---
// use vim editor by default
map("gi", "i");
map("i", "I");

// Get out with Control+c and Control+[
imap("<Ctrl-c>", "<Esc>");
imap("<Ctrl-[>", "<Esc>");

// --- Omnibar ---
// Map Control + w to Control + Backspace in Omnibar
// cmap("<Ctrl-w>", "<Ctrl-Backspace>");

// --- Sites ---
// open notifications with n
mapkey(
    "n",
    "Open notifications",
    function() {
        document.querySelector('button[aria-label="Notifications"]').click();
    },
    { domain: /youtube.com/i },
);

mapkey(
    "<Space>",
    "pause/resume on youtube",
    function() {
        var btn =
            document.querySelector("button.ytp-ad-overlay-close-button") ||
            document.querySelector("button.ytp-ad-skip-button") ||
            document.querySelector("ytd-watch-flexy button.ytp-play-button");
        btn.click();
    },
    { domain: /youtube.com/i },
);

// use h and l as arrow keys in youtube
mapkey(
    "l",
    "seek forward 5 seconds on youtube",
    function() {
        var video = document.querySelector("video");
        video.currentTime += 5;
    },
    { domain: /youtube.com/i },
);

mapkey(
    "h",
    "seek backward 5 seconds on youtube",
    function() {
        var video = document.querySelector("video");
        video.currentTime -= 5;
    },
    { domain: /youtube.com/i },
);

// Increase volume with 'K' in fullscreen
mapkey(
    "K",
    "increase volume on youtube in fullscreen",
    function() {
        var video = document.querySelector("video");
        if (video) {
            video.volume = Math.min(1, video.volume + 0.05); // increase volume by 5%
        }
    },
    { domain: /youtube.com/i },
);

// Toggle fullscreen with q
mapkey(
    "q",
    "Toggle fullscreen in youtube",
    function() {
        var btn = document.querySelector("button.ytp-fullscreen-button.ytp-button");
        if (btn) {
            btn.click()
        }
    },
    { domain: /youtube.com/i },
);
// toggle fullscreen with m
// unmap("m", /youtube.com/i);
// map("m", "gF");

// mapkey(
//   "A",
//   "Open video",
//   function () {
//     Hints.dispatchMouseClick("*[id='video-title']", function (element) {
//       RUNTIME("openLink", {
//         tab: {
//           tabbed: true,
//           active: false,
//         },
//         url: element.a["href"],
//       });
//     });
//   },
//   { domain: /youtube.com/i },
// );
// mapkey("C", "Open channel", function () {
//   util.createHints("*[id='byline']");
// });
// mapkey("gH", "Goto homepage", () =>
//   actions.openLink("https://www.youtube.com/feed/subscriptions?flow=2"),
// );
map("m", "gF", /youtube.com/i);

// mapkey(
//   "n",
//   "Toggle fullscreen",
//   function () {
//     document.querySelector("#movie_player.ytp-fullscreen-button").click();
//   },
//   { domain: /youtube.com/i },
// );
// map("Yt", "Copy YouTube video link for current time", () =>
//   Clipboard.write(actions.yt.getCurrentTimestampLink()),
// );
// map("Ym", "Copy YouTube video markdown link for current time", () =>
//   Clipboard.write(actions.yt.getCurrentTimestampMarkdownLink()),
// );

// Google
// NOTE: best script ever written

function getSearchResult(index) {
    // Select the #search div
    var searchDiv = document.querySelector("#search");

    if (!searchDiv) {
        console.error("Search div not found");
        return null;
    }

    // Get all links within the searchDiv
    var links = searchDiv.querySelectorAll("a[jsname]");

    if (index === NaN) {
        return;
    }

    // Adjust the index to be zero-based
    var adjustedIndex = index - 1;
    // Adjust index so that 1 is first visible link
    for (var i = 0; i < links.length; i++) {
        if (!isElementPartiallyInViewport(links[i], true)) {
            adjustedIndex++;
        } else {
            break;
        }
    }

    // Check if the requested index is within the range of available links
    if (adjustedIndex < 0 || adjustedIndex >= links.length) {
        console.error("Index out of range");
        return null;
    }

    return links[adjustedIndex].href;
}

function addNumberToSearch(links) {
    let visibleLinks = 0;

    const goldenRatio = 137.508; // Golden ratio in degrees for color generation

    // Add numbers next to each link
    links.forEach((link, i) => {
        // if (!link.previousSibling && isElementPartiallyInViewport(link, true)) {
        if (isElementPartiallyInViewport(link, true)) {
            visibleLinks++;

            var numberSpan = document.createElement("span");
            numberSpan.className = "result-number";
            // numberSpan.textContent = ` ${i + 1} `;
            numberSpan.textContent = ` ${visibleLinks} `;

            // Calculate color based on golden ratio
            let hue = (visibleLinks * 10 * goldenRatio) % 360;
            let color = `hsl(${hue}, 60%, 70%)`; // Using HSL color model

            // background-color: #E6E6FA; /* Light background for contrast */

            numberSpan.style.cssText = `
  display: inline-block;
  margin-right: 8px;
  color: #0000EE; /* Typical color for a hyperlink */
  background-color: ${color}; /* Light background for contrast */
  border: 1px solid #0000EE; /* Border color similar to a hyperlink */
  border-radius: 4px; /* Rounded corners for a squared look */
  padding: 2px 6px; /* Padding for background */
  vertical-align: top;
  font-size: 1.1em; /* Slightly larger font size */
  font-weight: bold; /* Making the font bold */
  z-index: 1000; /* Ensuring it's above other elements */
  position: relative; /* Required for z-index to work */
`;

            link.parentNode.insertBefore(numberSpan, link.nextSibling);
        }
    });
}

function addNumberToSearchGoogle() {
    // Select the #search div
    var searchDiv = document.querySelector("#search");

    if (!searchDiv) {
        return;
    }
    // Remove existing spans
    var existingSpans = searchDiv.querySelectorAll(".result-number");
    existingSpans.forEach(function(span) {
        span.parentNode.removeChild(span);
    });

    // Get all links within the searchDiv
    var links = searchDiv.querySelectorAll("a[jsname]");

    addNumberToSearch(links);
}

if (window.location.hostname == "www.google.com") {
    document.addEventListener("DOMContentLoaded", function() {
        addNumberToSearchGoogle();
    });
    // update on scroll
    document.addEventListener("scroll", function() {
        addNumberToSearchGoogle();
    });
}

// map 1 to 9 to search results: e.g. 1 = !, 2 = @, 3 = #, etc.
mapping = {
    1: "!",
    2: "@",
    3: "#",
    4: "$",
    5: "%",
    6: "^",
    7: "&",
    8: "*",
    9: "(",
};

for (let i = 1; i <= 9; i++) {
    // open in a non-active new tab
    mapkey(
        mapping[i],
        `Open the ${i}th search result in a non-active new tab`,
        function() {
            let url = getSearchResult(i);
            RUNTIME("openLink", {
                tab: {
                    tabbed: true,
                    active: false,
                },
                url: url,
            });
        },
        { domain: /google.com/i },
    );

    // open in an active new tab
    mapkey(
        `<Ctrl-${mapping[i]}>`,
        `Open the ${i}th search result in an active new tab`,
        function() {
            let url = getSearchResult(i);
            RUNTIME("openLink", {
                tab: {
                    tabbed: true,
                    active: true,
                },
                url: url,
            });
        },
        { domain: /google.com/i },
    );

    // open in the current tab
    mapkey(
        `<Ctrl-${i}>`,
        `Open the ${i}th search result in the current tab`,
        function() {
            let url = getSearchResult(i);
            RUNTIME("openLink", {
                tab: {
                    tabbed: false,
                },
                url: url,
            });
        },
        { domain: /google.com/i },
    );
}

// github
openGithubPagesRepo = () => {
    const user = window.location.pathname.split("/")[1] ?? "";
    const repo = window.location.pathname.split("/")[2] ?? "";
    Clipboard.write(`${user}/${repo}`);
};

mapkey("Y", "copy repo url", openGithubPagesRepo, { domain: /github.com/i });

// Decrease volume with 'J' in fullscreen
mapkey(
    "J",
    "decrease volume on youtube in fullscreen",
    function() {
        var video = document.querySelector("video");
        if (video) {
            video.volume = Math.max(0, video.volume - 0.05); // decrease volume by 5%
        }
    },
    { domain: /youtube.com/i },
);

function addNumberToSearchYoutube() {
    var searchDiv = document.querySelectorAll("#metadata");

    if (!searchDiv) {
        return;
    }
    // Remove existing spans
    var existingSpans = document.querySelectorAll(".result-number");
    existingSpans.forEach(function(span) {
        span.parentNode.removeChild(span);
    });

    addNumberToSearch(searchDiv);
}

if (window.location.hostname == "www.youtube.com") {
    document.addEventListener("load", function() {
        addNumberToSearchYoutube();
    });
    document.addEventListener("DOMContentLoaded", function() {
        addNumberToSearchYoutube();
    });
    // update on scroll
    document.addEventListener("scroll", function() {
        addNumberToSearchYoutube();
    });
}

// open google search results with shift+number
// Define a mapping from shift numbers to keys
const shiftNumberMap = {
    "!": 1,
    "@": 2,
    "#": 3,
    $: 4,
};

// Loop over the keys in the map
// for (let key in shiftNumberMap) {
//   mapkey(key, `Open search result ${shiftNumberMap[key]} in new tab`, function() {
//     // Select the nth search result link
//     var link = document.querySelectorAll('div.r a')[shiftNumberMap[key] - 1];
//     if (link) {
//       // Simulate a Ctrl + Click to open in a new tab
//       var clickEvent = new MouseEvent("click", {
//         ctrlKey: true,
//         view: window,
//         bubbles: true,
//         cancelable: true
//       });
//       link.dispatchEvent(clickEvent);
//     }
//   }, { domain: /google\..*/i });
// }

// --- Search Engines ---
// addSearchAlias('ama', 'amazon', 'https://www.amazon.com/s?k=', 's');
// addSearchAlias('ap', 'arch pkg', 'https://www.archlinux.org/packages/?sort=&q=', 's');
// addSearchAlias('aur', 'aur', 'https://aur.archlinux.org/packages/?O=0&SeB=nd&K=', 's');
// addSearchAlias('aw', 'arch wiki', 'https://wiki.archlinux.org/index.php?title=Special:Search&search=', 's');
// addSearchAlias('d',  'ddg', 'https://duckduckgo.com/?q=', 's');
// addSearchAlias('dh', 'docker', 'https://hub.docker.com/search?type=image&q=', 's');
// addSearchAlias('fh', 'flathub', 'https://flathub.org/apps/search/', 's');
addSearchAlias("h", "github", "https://github.com/search?q=", "s");
// addSearchAlias('pdb', 'proton', 'https://www.protondb.com/search?q=', 's');
// addSearchAlias('r', 'reddit', 'https://libreddit.spike.codes/r/', 's');
// addSearchAlias('st', 'steam', 'https://store.steampowered.com/search/?term=', 's');
addSearchAlias(
    "wp",
    "wikipedia",
    "https://en.wikipedia.org/wiki/Special:Search/",
    "s",
);
addSearchAlias(
    "tf",
    "tutflix",
    "https://tutflix.org/search/?q={0}&o=date",
    "s",
);
addSearchAlias(
    "y",
    "youtube",
    "https://www.youtube.com/results?search_query=",
    "s",
);
addSearchAlias(
    "n",
    "nix packages",
    "https://search.nixos.org/packages?channel=unstable&sort=relevance&type=packages&query=",
    "s",
);
addSearchAlias(
    "N",
    "nix options",
    "https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=",
    "s",
);

// --- Theme ---
// ---- Hints ----
// Hints have to be defined separately
// Uncomment to enable

// Tomorrow-Night
// /* -- DELETE LINE TO ENABLE THEME
Hints.style("font-size: 12px");
// Hints.style('border: solid 2px #373B41; color:#52C196; background: initial; background-color: #1D1F21;');
// Hints.style("border: solid 2px #373B41 !important; padding: 1px !important; color: #C5C8C6 !important; background: #1D1F21 !important;", "text");
// Visual.style('marks', 'background-color: #52C19699;');
// Visual.style('cursor', 'background-color: #81A2BE;');
// -- DELETE LINE TO ENABLE THEME */

// Nord
/* -- DELETE LINE TO ENABLE THEME
Hints.style('border: solid 2px #4C566A; color:#A3BE8C; background: initial; background-color: #3B4252;');
Hints.style("border: solid 2px #4C566A !important; padding: 1px !important; color: #E5E9F0 !important; background: #3B4252 !important;", "text");
Visual.style('marks', 'background-color: #A3BE8C99;');
Visual.style('cursor', 'background-color: #88C0D0;');
-- DELETE LINE TO ENABLE THEME */

// Doom One
/* -- DELETE LINE TO ENABLE THEME
Hints.style('border: solid 2px #282C34; color:#98be65; background: initial; background-color: #2E3440;');
Hints.style("border: solid 2px #282C34 !important; padding: 1px !important; color: #51AFEF !important; background: #2E3440 !important;", "text");
Visual.style('marks', 'background-color: #98be6599;');
Visual.style('cursor', 'background-color: #51AFEF;');
-- DELETE LINE TO ENABLE THEME */

// Monokai
/* -- DELETE LINE TO ENABLE THEME
Hints.style('border: solid 2px #2D2E2E; color:#F92660; background: initial; background-color: #272822;');
Hints.style("border: solid 2px #2D2E2E !important; padding: 1px !important; color: #A6E22E !important; background: #272822 !important;", "text");
Visual.style('marks', 'background-color: #A6E22E99;');
Visual.style('cursor', 'background-color: #F92660;');
-- DELETE LINE TO ENABLE THEME */

settings.theme = `
/* Edit these variables for easy theme making */
:root {
  /* Font */
  --font: Input Sans Condensed, Charcoal, sans-serif;
  --font-size: 18px;
  --font-weight: bold;

  /* -------------- */
  /* --- THEMES --- */
  /* -------------- */

  /* -------------------- */
  /* -- Tomorrow Night -- */
  /* -------------------- */
  --fg: #C5C8C6;
  --bg: #282A2E;
  --bg-dark: #1D1F21;
  --border: #373b41;
  --main-fg: #81A2BE;
  --accent-fg: #52C196;
  --info-fg: #AC7BBA;
  --select: #585858;

  /* Unused Alternate Colors */
  /* --cyan: #4CB3BC; */
  /* --orange: #DE935F; */
  /* --red: #CC6666; */
  /* --yellow: #CBCA77; */

  /* -------------------- */
  /* --      NORD      -- */
  /* -------------------- */
  /* -- DELETE LINE TO ENABLE THEME
  --fg: #E5E9F0;
  --bg: #3B4252;
  --bg-dark: #2E3440;
  --border: #4C566A;
  --main-fg: #88C0D0;
  --accent-fg: #A3BE8C;
  --info-fg: #5E81AC;
  --select: #4C566A;
  -- DELETE LINE TO ENABLE THEME */

  /* Unused Alternate Colors */
  /* --orange: #D08770; */
  /* --red: #BF616A; */
  /* --yellow: #EBCB8B; */

  /* -------------------- */
  /* --    DOOM ONE    -- */
  /* -------------------- */
  /* -- DELETE LINE TO ENABLE THEME
  --fg: #51AFEF;
  --bg: #2E3440;
  --bg-dark: #21242B;
  --border: #2257A0;
  --main-fg: #51AFEF;
  --accent-fg: #98be65;
  --info-fg: #C678DD;
  --select: #4C566A;
  -- DELETE LINE TO ENABLE THEME */

  /* Unused Alternate Colors */
  /* --border-alt: #282C34; */
  /* --cyan: #46D9FF; */
  /* --orange: #DA8548; */
  /* --red: #FF6C6B; */
  /* --yellow: #ECBE7B; */

  /* -------------------- */
  /* --    MONOKAI    -- */
  /* -------------------- */
  /* -- DELETE LINE TO ENABLE THEME
  --fg: #F8F8F2;
  --bg: #272822;
  --bg-dark: #1D1E19;
  --border: #2D2E2E;
  --main-fg: #F92660;
  --accent-fg: #E6DB74;
  --info-fg: #A6E22E;
  --select: #556172;
  -- DELETE LINE TO ENABLE THEME */

  /* Unused Alternate Colors */
  /* --red: #E74C3C; */
  /* --orange: #FD971F; */
  /* --blue: #268BD2; */
  /* --violet: #9C91E4; */
  /* --cyan: #66D9EF; */
}

/* ---------- Generic ---------- */
.sk_theme {
background: var(--bg);
color: var(--fg);
  background-color: var(--bg);
  border-color: var(--border);
  font-family: var(--font);
  font-size: var(--font-size);
  font-weight: var(--font-weight);
}

input {
  font-family: var(--font);
  font-weight: var(--font-weight);
}

.sk_theme tbody {
  color: var(--fg);
}

.sk_theme input {
  color: var(--fg);
}

/* Hints */
#sk_hints .begin {
  color: var(--accent-fg) !important;
}

#sk_tabs .sk_tab {
  background: var(--bg-dark);
  border: 1px solid var(--border);
}

#sk_tabs .sk_tab_title {
  color: var(--fg);
}

#sk_tabs .sk_tab_url {
  color: var(--main-fg);
}

#sk_tabs .sk_tab_hint {
  background: var(--bg);
  border: 1px solid var(--border);
  color: var(--accent-fg);
}

.sk_theme #sk_frame {
  background: var(--bg);
  opacity: 0.2;
  color: var(--accent-fg);
}

/* ---------- Omnibar ---------- */
/* Uncomment this and use settings.omnibarPosition = 'bottom' for Pentadactyl/Tridactyl style bottom bar */
/* .sk_theme#sk_omnibar {
  width: 100%;
  left: 0;
} */

.sk_theme .title {
  color: var(--accent-fg);
}

.sk_theme .url {
  color: var(--main-fg);
}

.sk_theme .annotation {
  color: var(--accent-fg);
}

.sk_theme .omnibar_highlight {
  color: var(--accent-fg);
}

.sk_theme .omnibar_timestamp {
  color: var(--info-fg);
}

.sk_theme .omnibar_visitcount {
  color: var(--accent-fg);
}

.sk_theme #sk_omnibarSearchResult ul li:nth-child(odd) {
  background: var(--bg-dark);
  font-size: 18px;
}

.sk_theme #sk_omnibarSearchResult ul li.focused {
  background: var(--border);
  font-size: 18px;
}

.sk_theme #sk_omnibarSearchArea {
  border-top-color: var(--border);
  border-bottom-color: var(--border);
}

.sk_theme #sk_omnibarSearchArea input,
.sk_theme #sk_omnibarSearchArea span {
  font-size: 22px;
}

.sk_theme .separator {
  color: var(--accent-fg);
}

/* ---------- Popup Notification Banner ---------- */
#sk_banner {
  font-family: var(--font);
  font-size: var(--font-size);
  font-weight: var(--font-weight);
  background: var(--bg);
  border-color: var(--border);
  color: var(--fg);
  opacity: 0.9;
}

/* ---------- Popup Keys ---------- */
#sk_keystroke {
  background-color: var(--bg);
}

.sk_theme kbd .candidates {
  color: var(--info-fg);
}

.sk_theme span.annotation {
  color: var(--accent-fg);
}

/* ---------- Popup Translation Bubble ---------- */
#sk_bubble {
  background-color: var(--bg) !important;
  color: var(--fg) !important;
  border-color: var(--border) !important;
}

#sk_bubble * {
  color: var(--fg) !important;
}

#sk_bubble div.sk_arrow div:nth-of-type(1) {
  border-top-color: var(--border) !important;
  border-bottom-color: var(--border) !important;
}

#sk_bubble div.sk_arrow div:nth-of-type(2) {
  border-top-color: var(--bg) !important;
  border-bottom-color: var(--bg) !important;
}

/* ---------- Search ---------- */
#sk_status,
#sk_find {
  font-size: var(--font-size);
  border-color: var(--border);
}

.sk_theme kbd {
  background: var(--bg-dark);
  border-color: var(--border);
  box-shadow: none;
  color: var(--fg);
}

.sk_theme .feature_name span {
  color: var(--main-fg);
}

/* ---------- ACE Editor ---------- */
#sk_editor {
  background: var(--bg-dark) !important;
  height: 50% !important;
  /* Remove this to restore the default editor size */
}

.ace_dialog-bottom {
  border-top: 1px solid var(--bg) !important;
}

.ace-chrome .ace_print-margin,
.ace_gutter,
.ace_gutter-cell,
.ace_dialog {
  background: var(--bg) !important;
}

.ace-chrome {
  color: var(--fg) !important;
}

.ace_gutter,
.ace_dialog {
  color: var(--fg) !important;
}

.ace_cursor {
  color: var(--fg) !important;
}

.normal-mode .ace_cursor {
  background-color: var(--fg) !important;
  border: var(--fg) !important;
  opacity: 0.7 !important;
}

.ace_marker-layer .ace_selection {
  background: var(--select) !important;
}

.ace_editor, .ace_editor div{
    font-family: "Monaco", "Menlo", "Ubuntu Mono", "Droid Sans Mono", "Consolas", monospace !important; font-size: 18px !important; font-weight: 400;
}

.ace_editor,
.ace_dialog span,
.ace_dialog input {
  font-family: monospace;
  font-size: var(--font-size);
  font-weight: var(--font-weight);
}
`;

// settings.theme= `
// :root {
//     --theme-ace-bg:#282828ab; /*Note the fourth channel, this adds transparency*/
//     --theme-ace-bg-accent:#3c3836;
//     --theme-ace-fg:#ebdbb2;
//     --theme-ace-fg-accent:#7c6f64;
//     --theme-ace-cursor:#928374;
//     --theme-ace-select:#458588;
// }
// #sk_editor {
//     height: 50% !important; /*Remove this to restore the default editor size*/
//     background: var(--theme-ace-bg) !important;
// }
// .ace_dialog-bottom{
//     border-top: 1px solid var(--theme-ace-bg) !important;
// }
// .ace-chrome .ace_print-margin, .ace_gutter, .ace_gutter-cell, .ace_dialog{
//     background: var(--theme-ace-bg-accent) !important;
// }
// .ace-chrome{
//     color: var(--theme-ace-fg) !important;
// }
// .ace_gutter, .ace_dialog {
//     color: var(--theme-ace-fg-accent) !important;
// }
// .ace_cursor{
//     color: var(--theme-ace-cursor) !important;
// }
// .normal-mode .ace_cursor{
//     background-color: var(--theme-ace-cursor) !important;
//     border: var(--theme-ace-cursor) !important;
// }
// .ace_marker-layer .ace_selection {
//     background: var(--theme-ace-select) !important;
// } `

/* set theme */
// settings.theme = `
// .sk_theme {
//     font-family: Input Sans Condensed, Charcoal, sans-serif;
//     font-size: 10pt;
//     background: #282828;
//     color: #ebdbb2;
// }
// .sk_theme tbody {
//     color: #b8bb26;
// }
// .sk_theme input {
//     color: #d9dce0;
// }
// .sk_theme .url {
//     color: #98971a;
// }
// .sk_theme .annotation {
//     color: #b16286;
// }
// .sk_theme .omnibar_highlight {
//     color: #ebdbb2;
// }
// .sk_theme #sk_omnibarSearchResult ul li:nth-child(odd) {
//     background: #282828;
// }
// .sk_theme #sk_omnibarSearchResult ul li.focused {
//     background: #d3869b;
// }
// #sk_status, #sk_find {
//     font-size: 20pt;
// }`;
// Hints.style("border: solid 1px #000000; color:#000000;");
// Hints.style(
//   "div{border: solid 3px #707070; color:#efe1eb; background: none; background-color: #707070;} div.begin{color:red;}",
//   "text",
// );

// Hints.style(
//   "border: solid 3px #552a48; color:#efe1eb; background: none; background-color: #552a48;",
// );
// Hints.style(
//   "background-color: #d4a00f; color: #000000; font-weight: bold; font-size: medium; letter-spacing: 0.025em;",
// );
let customHintStyle = `
    background-color: #d4a00f; /* Dark yellow background */
    color: #000000; /* Black text color */
    font-weight: 900; /* Heavier font weight for bolder text */
    // font-weight: bold; /* Bold text */
    font-size: 13px; /* Larger text size */
    letter-spacing: 0.07em; /* Slightly increased space between characters */
    text-shadow: 1px 1px 2px #888; /* Subtle text shadow for depth */
    border: 1px solid #333; /* Border for definition */
    border-radius: 4px; /* Rounded corners for the border */
    padding: 5px; /* Padding inside the hint box */
    font-family: Arial, sans-serif; /* Readable font family */
    box-shadow: 0px 2px 4px rgba(0, 0, 0, 0.2); /* Box shadow for a subtle 3D effect */
`;

Hints.style(customHintStyle);
Hints.style(customHintStyle, "text");

// Visual.style("marks", customHintStyle);
// Visual.style("cursor", customHintStyle);

// Hints.style("div{border: solid 3px #707070; color:#efe1eb; background: none; background-color: #707070;} div.begin{color:red;}", "text");
