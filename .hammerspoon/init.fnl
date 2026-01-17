;; Hammerspoon config (Fennel source-of-truth)
;;
;; This file compiles to `.hammerspoon/init.generated.lua` via:
;;   `make hammerspoon`
;;
;; NOTE:
;; - The implementation is currently maintained as Lua (commented out below).
;; - A compile-time macro extracts the Lua block and splices it into the compiled output.
;; - This keeps a single file as the source of truth while we incrementally migrate to real Fennel.

(macro emit-embedded-lua [path]
  (local f (assert (io.open path "r")))
  (local src (f:read "*all"))
  (f:close)

  (local out [])
  (var in? false)
  (var done? false)

  (each [line (: (.. src "\n") :gmatch "(.-)\n")]
    (if (and (not done?) (= line ";; BEGIN_EMBEDDED_LUA"))
      (set in? true)
      (if (and (not done?) (= line ";; END_EMBEDDED_LUA"))
        (do
          (set in? false)
          (set done? true))
        (when (and (not done?) in?)
          (let [is-comment? (= (: line :sub 1 1) ";")
                lua-line (if is-comment? (: line :sub 2) line)]
            (table.insert out lua-line))))))

  (local code (table.concat out "\n"))
  `(lua ,code))

(emit-embedded-lua ".hammerspoon/init.fnl")

;; BEGIN_EMBEDDED_LUA
;-- Repo/URL picker overlay (global) + file picker (repo-relative) via a compact webview.
;--
;-- This is intentionally self-contained: it renders UI in a borderless webview and
;-- captures keystrokes with an eventtap so it works in any app without needing focus.
;
;local config = {
;  dotfilesBin = os.getenv("HOME") .. "/dotfiles/bin",
;
;  -- Hotkeys
;  hotkeyRepoUrl = { mods = { "ctrl", "alt", "cmd" }, key = "u" },
;  hotkeyRepoFile = { mods = { "ctrl", "alt", "cmd" }, key = "t" },
;  hotkeyRepoFilePickRepo = { mods = { "ctrl", "alt", "cmd", "shift" }, key = "t" },
;  hotkeyToggleDebug = { mods = { "ctrl", "alt", "cmd", "shift" }, key = "d" },
;  hotkeyShowLog = { mods = { "ctrl", "alt", "cmd", "shift" }, key = "l" },
;
;  -- UI
;  width = 560,
;  height = 260,
;  primaryWidth = 250,
;  maxResults = 6,
;  maxMatches = 2000,
;  asyncFilterThreshold = 8000,
;  enableAsyncFilter = false,
;  margin = 10,
;  offset = 8,
;}
;
;-- Logging ----------------------------------------------------------------
;hs.logger.historySize(500)
;
;local log = hs.logger.new("repoOverlay", "info")
;local logLevelSettingKey = "repoOverlay.logLevel"
;
;local logFile = (os.getenv("HOME") or "") .. "/Library/Logs/Hammerspoon/repoOverlay.log"
;local function _appendLogFile(level, msg)
;  local cur = log.getLogLevel()
;  local required = { error = 1, warning = 2, info = 3, debug = 4, verbose = 5 }
;  local minLevel = required[level] or 99
;  if cur < minLevel then return end
;
;  local dir = logFile:match("^(.*)/[^/]+$") or ""
;  if dir ~= "" then pcall(hs.fs.mkdir, dir) end
;
;  local ok, f = pcall(io.open, logFile, "a")
;  if not ok or not f then return end
;
;  local line = string.format("%s [%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), level:upper(), msg)
;  pcall(f.write, f, line)
;  pcall(f.close, f)
;end
;
;local function _wrapLog(methodName, level, isFormat)
;  local orig = log[methodName]
;  if type(orig) ~= "function" then return end
;  log[methodName] = function(...)
;    local msg = ""
;    local args = { ... }
;    if #args >= 1 then
;      if isFormat and type(args[1]) == "string" then
;        local ok, formatted = pcall(string.format, args[1], table.unpack(args, 2))
;        msg = ok and formatted or tostring(args[1])
;      else
;        msg = tostring(args[1])
;      end
;    end
;    _appendLogFile(level, msg)
;    return orig(...)
;  end
;end
;
;-- Mirror logs to file for post-mortem debugging (honors log level).
;_wrapLog("e", "error", false)
;_wrapLog("ef", "error", true)
;_wrapLog("w", "warning", false)
;_wrapLog("wf", "warning", true)
;_wrapLog("i", "info", false)
;_wrapLog("f", "info", true)
;_wrapLog("d", "debug", false)
;_wrapLog("df", "debug", true)
;
;local function _levelName(level)
;  local names = { [0] = "nothing", [1] = "error", [2] = "warning", [3] = "info", [4] = "debug", [5] = "verbose" }
;  return names[level] or tostring(level)
;end
;
;local function _setLogLevel(level)
;  local ok = pcall(function()
;    log.setLogLevel(level)
;    hs.settings.set(logLevelSettingKey, level)
;  end)
;  if ok then
;    log.f("log level: %s", _levelName(log.getLogLevel()))
;  else
;    log.wf("failed to set log level (invalid?): %s", tostring(level))
;  end
;end
;
;do
;  local configured = hs.settings.get(logLevelSettingKey) or os.getenv("HS_REPOOVERLAY_LOG_LEVEL") or "info"
;  _setLogLevel(configured)
;end
;
;log.f("env: HOME=%s PATH=%s", tostring(os.getenv("HOME")), tostring(os.getenv("PATH") or ""))
;log.f("config: dotfilesBin=%s", tostring(config.dotfilesBin))
;
;local state = {
;  active = false,
;  mode = nil, -- spec id (string)
;  spec = nil,
;  prompt = "",
;  query = "",
;  cursor = 0,
;  killBuffer = "",
;  loading = false,
;  loadingText = "",
;  emptyText = "",
;  items = {},
;  filtered = {},
;  selectedIndex = 1,
;  viewOffset = 0,
;  marked = {},
;  allowMulti = false,
;  recency = {},
;  returnApp = nil,
;  webview = nil,
;  tap = nil,
;  onAccept = nil,
;  sourceCancel = nil,
;  loadTask = nil,
;  loadGen = 0,
;  activityGen = 0,
;  activityTimer = nil,
;  filterGen = 0,
;  filterTimer = nil,
;  searchGen = 0,
;  searchTimer = nil,
;  searching = false,
;}
;
;-- FuzzyOverlay: a reusable “fzf-like” picker overlay component (webview + eventtap).
;-- TODO(prateek): Move this into a Spoon once stable.
;FuzzyOverlay = FuzzyOverlay or {}
;FuzzyOverlay.setLogLevel = _setLogLevel
;FuzzyOverlay.toggleDebug = function()
;  if log.getLogLevel() >= 4 then _setLogLevel("info") else _setLogLevel("debug") end
;end
;FuzzyOverlay.logFile = logFile
;FuzzyOverlay.dump = function()
;  local markedCount = 0
;  for _ in pairs(state.marked or {}) do
;    markedCount = markedCount + 1
;  end
;  log.f(
;    "state: active=%s id=%s allowMulti=%s query_len=%d items=%d filtered=%d selectedIndex=%d viewOffset=%d marked=%d",
;    tostring(state.active),
;    tostring(state.mode),
;    tostring(state.allowMulti),
;    #(state.query or ""),
;    #state.items,
;    #state.filtered,
;    state.selectedIndex,
;    state.viewOffset,
;    markedCount
;  )
;end
;
;-- Back-compat alias (older console snippets / bindings).
;RepoOverlay = FuzzyOverlay
;
;local function _cfg(key)
;  local spec = state.spec
;  if spec then
;    local theme = spec.theme
;    if theme and theme[key] ~= nil then return theme[key] end
;    if spec[key] ~= nil then return spec[key] end
;  end
;  return config[key]
;end
;
;local recencySettingKey = "repoOverlay.recency"
;local json = require("hs.json")
;
;local function _loadRecency()
;  local t = hs.settings.get(recencySettingKey)
;  if type(t) ~= "table" then return {} end
;
;  -- Normalize to numeric timestamps.
;  for k, v in pairs(t) do
;    if type(v) ~= "number" then t[k] = nil end
;  end
;
;  return t
;end
;
;local function _saveRecency(t)
;  hs.settings.set(recencySettingKey, t)
;end
;
;local function _trimRecency(t, maxEntries)
;  maxEntries = maxEntries or 500
;
;  local count = 0
;  for _ in pairs(t) do count = count + 1 end
;  if count <= maxEntries then return t end
;
;  local entries = {}
;  for k, v in pairs(t) do table.insert(entries, { k = k, v = v }) end
;  table.sort(entries, function(a, b) return a.v > b.v end)
;
;  local out = {}
;  for i = 1, math.min(maxEntries, #entries) do
;    out[entries[i].k] = entries[i].v
;  end
;  return out
;end
;
;state.recency = _loadRecency()
;
;local function _trim(s)
;  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
;end
;
;local function _clampCursor()
;  local q = state.query or ""
;  local len = #q
;  if type(state.cursor) ~= "number" then state.cursor = len end
;  if state.cursor < 0 then state.cursor = 0 end
;  if state.cursor > len then state.cursor = len end
;end
;
;local function _setQuery(q, cursor)
;  state.query = q or ""
;  state.cursor = type(cursor) == "number" and cursor or #state.query
;  _clampCursor()
;end
;
;local function _insertText(text)
;  if not text or text == "" then return end
;  _clampCursor()
;  local q = state.query or ""
;  local c = state.cursor or #q
;  local left = q:sub(1, c)
;  local right = q:sub(c + 1)
;  state.query = left .. text .. right
;  state.cursor = c + #text
;end
;
;local function _deleteBackward()
;  _clampCursor()
;  local q = state.query or ""
;  local c = state.cursor or #q
;  if c <= 0 then return end
;  local left = q:sub(1, c - 1)
;  local right = q:sub(c + 1)
;  state.query = left .. right
;  state.cursor = c - 1
;end
;
;local function _deleteForward()
;  _clampCursor()
;  local q = state.query or ""
;  local c = state.cursor or #q
;  if c >= #q then return end
;  local left = q:sub(1, c)
;  local right = q:sub(c + 2)
;  state.query = left .. right
;end
;
;local function _isWordChar(ch)
;  return ch:match("[%w_]") ~= nil
;end
;
;local function _moveWordBackward()
;  _clampCursor()
;  local q = state.query or ""
;  local c = state.cursor or #q
;  local i = c
;  while i > 0 and (not _isWordChar(q:sub(i, i))) do i = i - 1 end
;  while i > 0 and _isWordChar(q:sub(i, i)) do i = i - 1 end
;  state.cursor = i
;end
;
;local function _moveWordForward()
;  _clampCursor()
;  local q = state.query or ""
;  local c = state.cursor or #q
;  local len = #q
;  local i = c + 1
;  while i <= len and (not _isWordChar(q:sub(i, i))) do i = i + 1 end
;  while i <= len and _isWordChar(q:sub(i, i)) do i = i + 1 end
;  state.cursor = i - 1
;end
;
;local function _killToStart()
;  _clampCursor()
;  local q = state.query or ""
;  local c = state.cursor or #q
;  if c <= 0 then return end
;  state.killBuffer = q:sub(1, c)
;  state.query = q:sub(c + 1)
;  state.cursor = 0
;end
;
;local function _killToEnd()
;  _clampCursor()
;  local q = state.query or ""
;  local c = state.cursor or #q
;  if c >= #q then return end
;  state.killBuffer = q:sub(c + 1)
;  state.query = q:sub(1, c)
;  state.cursor = #state.query
;end
;
;local function _backwardKillWord()
;  _clampCursor()
;  local q = state.query or ""
;  local c = state.cursor or #q
;  if c <= 0 then return end
;
;  local i = c
;  while i > 0 and (not _isWordChar(q:sub(i, i))) do i = i - 1 end
;  while i > 0 and _isWordChar(q:sub(i, i)) do i = i - 1 end
;
;  local start = i + 1
;  local killed = q:sub(start, c)
;  if killed ~= "" then state.killBuffer = killed end
;  state.query = q:sub(1, start - 1) .. q:sub(c + 1)
;  state.cursor = start - 1
;end
;
;local function _killWordForward()
;  _clampCursor()
;  local q = state.query or ""
;  local c = state.cursor or #q
;  local len = #q
;  if c >= len then return end
;
;  local i = c + 1
;  while i <= len and (not _isWordChar(q:sub(i, i))) do i = i + 1 end
;  while i <= len and _isWordChar(q:sub(i, i)) do i = i + 1 end
;
;  local start = c + 1
;  local finish = i - 1
;  if finish < start then return end
;  local killed = q:sub(start, finish)
;  if killed ~= "" then state.killBuffer = killed end
;  state.query = q:sub(1, c) .. q:sub(finish + 1)
;  state.cursor = c
;end
;
;local function _yank()
;  if not state.killBuffer or state.killBuffer == "" then return end
;  _insertText(state.killBuffer)
;end
;
;local function _escapeHtml(s)
;  s = s:gsub("&", "&amp;")
;  s = s:gsub("<", "&lt;")
;  s = s:gsub(">", "&gt;")
;  s = s:gsub("\"", "&quot;")
;  return s
;end
;
;local function _sh(cmd)
;  local full = string.format("/bin/zsh -lc %q", cmd)
;  local out, ok = hs.execute(full)
;  if not ok then
;    log.df("command failed: %s", cmd)
;    return ""
;  end
;  return out or ""
;end
;
;local function _shAsync(cmd, cb)
;  local t = hs.task.new("/bin/zsh", function(exitCode, stdOut, stdErr)
;    local ok = (exitCode == 0)
;    if not ok then log.df("command failed (%d): %s", exitCode, cmd) end
;    if cb then cb(ok, stdOut or "", stdErr or "") end
;  end, { "-lc", cmd })
;  if not t then
;    if cb then cb(false, "", "hs.task.new failed") end
;    return nil
;  end
;  t:start()
;  return t
;end
;
;local function _lines(s)
;  local t = {}
;  for line in (s or ""):gmatch("[^\r\n]+") do
;    line = _trim(line)
;    if line ~= "" then table.insert(t, line) end
;  end
;  return t
;end
;
;local function _itemKey(item)
;  if not item then return "" end
;  return item.key or item.value or item.primary or ""
;end
;
;local function _fuzzyScore(text, query)
;  if query == "" then return 0 end
;  text = text:lower()
;  query = query:lower()
;
;  local score = 0
;  local ti = 1
;  local last = 0
;  local streak = 0
;
;  for qi = 1, #query do
;    local qc = query:sub(qi, qi)
;    local found = text:find(qc, ti, true)
;    if not found then return nil end
;
;    if found == last + 1 then
;      streak = streak + 1
;      score = score + 20 + (streak * 6)
;    else
;      streak = 0
;      score = score + 10
;    end
;
;    if found == 1 then
;      score = score + 25
;    else
;      local prev = text:sub(found - 1, found - 1)
;      if prev:match("[%s/_%-%.]") then score = score + 18 end
;    end
;
;    score = score + math.max(0, 30 - found)
;    last = found
;    ti = found + 1
;  end
;
;  return score
;end
;
;local function _recencyBonus(key)
;  local ts = state.recency[key]
;  if type(ts) ~= "number" or ts <= 0 then return 0 end
;
;  local age = os.time() - ts
;  if age < 3600 then return 120 end
;  if age < 86400 then return 80 end
;  if age < 7 * 86400 then return 45 end
;  if age < 30 * 86400 then return 25 end
;  return 0
;end
;
;local _scoreForQuery, _cmpScored
;
;local function _filter(items, query)
;  local scored = {}
;
;  for _, item in ipairs(items or {}) do
;    local score, tie = _scoreForQuery(item, query)
;    if score ~= nil then
;      table.insert(scored, {
;        item = item,
;        score = score,
;        tie = tie or 0,
;        primary = item.primary or "",
;        sortScore = item.sortScore,
;        activityTs = item.activityTs,
;      })
;    end
;  end
;
;  table.sort(scored, _cmpScored)
;
;  local out = {}
;  local maxKeep = _cfg("maxMatches")
;  for i = 1, math.min(#scored, maxKeep) do out[i] = scored[i].item end
;  return out
;end
;
;local function _frontmostFontCss()
;  local app = hs.application.frontmostApplication()
;  local bid = app and app:bundleID() or ""
;
;  -- Try to look "native" in most apps; use monospace for terminal-ish apps.
;  local fontFamily = "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif"
;  local fontSize = 13
;
;  if bid == "com.apple.Terminal" or bid == "com.googlecode.iterm2"
;      or bid == "com.github.wez.wezterm" or bid == "net.kovidgoyal.kitty"
;      or bid == "com.mitchellh.ghostty" then
;    fontFamily = "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace"
;    fontSize = 12
;  end
;
;  return string.format("font-family:%s;font-size:%dpx;", fontFamily, fontSize)
;end
;
;local function _caretRect()
;  local sys = hs.axuielement.systemWideElement()
;  if not sys then
;    log.d("AX: missing systemWideElement")
;    return nil
;  end
;  local focused = sys:attributeValue("AXFocusedUIElement")
;  if not focused then
;    log.d("AX: missing focused element")
;    return nil
;  end
;
;  local okRange, range = pcall(function() return focused:attributeValue("AXSelectedTextRange") end)
;  if okRange and range then
;    local okBounds, bounds = pcall(function()
;      return focused:parameterizedAttributeValue("AXBoundsForRange", range)
;    end)
;    if okBounds and bounds and bounds.x and bounds.y and bounds.h then
;      if bounds.h < 8 then bounds.h = 16 end
;      if bounds.w < 1 then bounds.w = 1 end
;      log.df("AX caret: x=%.1f y=%.1f w=%.1f h=%.1f", bounds.x, bounds.y, bounds.w, bounds.h)
;      return bounds
;    end
;  end
;
;  -- Fallback: focused element frame (less precise, but better than nothing)
;  local okFrame, frame = pcall(function() return focused:attributeValue("AXFrame") end)
;  if okFrame and frame and frame.x and frame.y and frame.w and frame.h then
;    log.df("AX frame fallback: x=%.1f y=%.1f w=%.1f h=%.1f", frame.x, frame.y, frame.w, frame.h)
;    return frame
;  end
;
;  return nil
;end
;
;local function _screenForPoint(pt)
;  if not pt then return hs.screen.mainScreen() end
;  for _, screen in ipairs(hs.screen.allScreens()) do
;    local f = screen:frame()
;    if pt.x >= f.x and pt.x <= (f.x + f.w) and pt.y >= f.y and pt.y <= (f.y + f.h) then
;      return screen
;    end
;  end
;  return hs.screen.mainScreen()
;end
;
;local function _computeFrame()
;  local caret = _caretRect()
;  local anchorPt = nil
;  local anchorBelowY = nil
;  local anchorHow = ""
;
;  if caret then
;    -- Prefer “below caret”; if caret is actually a large element frame, we still anchor near its bottom-left.
;    anchorPt = { x = caret.x, y = caret.y }
;    anchorBelowY = caret.y + caret.h
;    anchorHow = "caret"
;  else
;    local win = hs.window.focusedWindow()
;    local wf = win and win:frame() or nil
;    if wf then
;      anchorPt = { x = wf.x, y = wf.y }
;      anchorBelowY = wf.y + 30
;      anchorHow = "focused_window"
;    else
;      local mp = hs.mouse.absolutePosition()
;      anchorPt = { x = mp.x, y = mp.y }
;      anchorBelowY = mp.y
;      anchorHow = "mouse"
;    end
;  end
;
;  local screen = _screenForPoint(anchorPt)
;  local sf = screen:frame()
;
;  local w, h = _cfg("width"), _cfg("height")
;  local x = anchorPt.x
;  local y = anchorBelowY + _cfg("offset")
;
;  local margin = _cfg("margin")
;  if (x + w + margin) > (sf.x + sf.w) then x = (sf.x + sf.w) - w - margin end
;  if x < (sf.x + margin) then x = sf.x + margin end
;
;  if (y + h + margin) > (sf.y + sf.h) then
;    y = (anchorPt.y - h - _cfg("offset"))
;  end
;  if (y + h + margin) > (sf.y + sf.h) then y = (sf.y + sf.h) - h - margin end
;  if y < (sf.y + margin) then y = sf.y + margin end
;
;  log.df("frame: how=%s x=%.1f y=%.1f w=%.1f h=%.1f screen=(%.1f %.1f %.1f %.1f)", anchorHow, x, y, w, h, sf.x, sf.y, sf.w, sf.h)
;  return { x = x, y = y, w = w, h = h }
;end
;
;local function _markedCount()
;  local c = 0
;  for _ in pairs(state.marked or {}) do c = c + 1 end
;  return c
;end
;
;local function _hasMarks()
;  for _ in pairs(state.marked or {}) do return true end
;  return false
;end
;
;local function _markedItemsInOrder()
;  local out = {}
;  for _, item in ipairs(state.items) do
;    if state.marked[_itemKey(item)] then
;      table.insert(out, item)
;    end
;  end
;  return out
;end
;
;local function _baseHtml()
;  local fontCss = _frontmostFontCss()
;  local buf = {}
;
;  table.insert(buf, "<!doctype html><html><head><meta charset=\"utf-8\" />")
;  table.insert(buf, "<style>")
;  table.insert(buf, "html,body{margin:0;padding:0;width:100%;height:100%;background:rgba(28,28,30,0.96);overflow:hidden;}")
;  table.insert(buf, string.format("body{%s -webkit-font-smoothing:antialiased;}", fontCss))
;  table.insert(buf, ".wrap{width:100%;height:100%;box-sizing:border-box;padding:10px;overflow:hidden;}")
;  table.insert(buf, ".panel{width:100%;height:100%;box-sizing:border-box;display:flex;flex-direction:column;")
;  table.insert(buf, "background:rgba(28,28,30,0.96);border:1px solid rgba(255,255,255,0.12);")
;  table.insert(buf, "border-radius:12px;box-shadow:0 14px 50px rgba(0,0,0,0.45);overflow:hidden;}")
;
;  table.insert(buf, ".prompt{flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;gap:12px;")
;  table.insert(buf, "padding:10px 12px;border-bottom:1px solid rgba(255,255,255,0.10);}")
;  table.insert(buf, ".promptLeft{flex:1 1 auto;min-width:0;display:flex;align-items:center;gap:0;overflow:hidden;}")
;  table.insert(buf, ".promptText{min-width:0;color:rgba(255,255,255,0.92);font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}")
;  table.insert(buf, ".placeholder{color:rgba(255,255,255,0.55);}")
;  table.insert(buf, ".cursor{display:inline-block;width:7px;height:1.05em;margin-left:3px;border-radius:1px;")
;  table.insert(buf, "background:rgba(255,255,255,0.65);animation:blink 1.1s steps(1) infinite;}")
;  table.insert(buf, "@keyframes blink{0%,49%{opacity:1}50%,100%{opacity:0}}")
;  table.insert(buf, ".meta{flex:0 0 auto;display:flex;gap:8px;align-items:center;white-space:nowrap;}")
;  table.insert(buf, ".badge{color:rgba(255,255,255,0.70);font-size:0.90em;font-weight:600;")
;  table.insert(buf, "padding:2px 7px;border-radius:999px;border:1px solid rgba(255,255,255,0.14);")
;  table.insert(buf, "background:rgba(255,255,255,0.05);}")
;
;  table.insert(buf, ".list{flex:1 1 auto;overflow:hidden;padding:6px 0;}")
;  table.insert(buf, ".item{padding:7px 12px;display:flex;align-items:center;gap:4px;")
;  table.insert(buf, "white-space:nowrap;overflow:hidden;text-overflow:ellipsis;transition:background-color 80ms ease-out;}")
;  table.insert(buf, ".prefix{width:14px;flex:0 0 auto;text-align:right;color:rgba(255,255,255,0.55);")
;  table.insert(buf, "font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,'Liberation Mono',monospace;}")
;  table.insert(buf, string.format(".p{flex:0 0 %dpx;color:rgba(255,255,255,0.92);font-weight:600;overflow:hidden;text-overflow:ellipsis;}", _cfg("primaryWidth")))
;  table.insert(buf, ".s{color:rgba(255,255,255,0.60);overflow:hidden;text-overflow:ellipsis;}")
;  table.insert(buf, ".item.sel{background:rgba(120,120,255,0.22);}")
;  table.insert(buf, ".item.marked .prefix{color:rgba(180,220,255,0.90);}")
;  table.insert(buf, ".hint{flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;gap:12px;")
;  table.insert(buf, "padding:8px 12px;border-top:1px solid rgba(255,255,255,0.10);")
;  table.insert(buf, "color:rgba(255,255,255,0.55);font-size:0.90em;}")
;  table.insert(buf, ".hintLeft{min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}")
;  table.insert(buf, ".hintRight{flex:0 0 auto;white-space:nowrap;}")
;  table.insert(buf, "</style></head><body><div class=\"wrap\"><div class=\"panel\">")
;
;  table.insert(buf, "<div class=\"prompt\">")
;  table.insert(buf, "<div class=\"promptLeft\"><div id=\"promptTextLeft\" class=\"promptText placeholder\"></div><div id=\"cursor\" class=\"cursor\"></div><div id=\"promptTextRight\" class=\"promptText\"></div></div>")
;  table.insert(buf, "<div id=\"meta\" class=\"meta\"></div>")
;  table.insert(buf, "</div>")
;  table.insert(buf, "<div id=\"list\" class=\"list\"></div>")
;  table.insert(buf, "<div class=\"hint\"><div id=\"hintLeft\" class=\"hintLeft\"></div><div id=\"hintRight\" class=\"hintRight\"></div></div>")
;  table.insert(buf, "</div></div>")
;
;  table.insert(buf, "<script>")
;  table.insert(buf, "(function(){")
;  table.insert(buf, string.format("  var MAX_ROWS = %d;", _cfg("maxResults")))
;  table.insert(buf, "  var ready = false;")
;  table.insert(buf, "  var lastState = window.__repoOverlayState || null;")
;  table.insert(buf, "  var rows = [];")
;  table.insert(buf, "  var metaCount = null;")
;  table.insert(buf, "  var metaSelected = null;")
;  table.insert(buf, "  function ensureRows(){")
;  table.insert(buf, "    if(rows.length) return;")
;  table.insert(buf, "    var list = document.getElementById('list');")
;  table.insert(buf, "    for(var i=0;i<MAX_ROWS;i++){")
;  table.insert(buf, "      var row = document.createElement('div'); row.className='item';")
;  table.insert(buf, "      var prefix = document.createElement('div'); prefix.className='prefix';")
;  table.insert(buf, "      var p = document.createElement('div'); p.className='p';")
;  table.insert(buf, "      var s = document.createElement('div'); s.className='s';")
;  table.insert(buf, "      row.appendChild(prefix); row.appendChild(p); row.appendChild(s);")
;  table.insert(buf, "      list.appendChild(row);")
;  table.insert(buf, "      rows.push({row:row,prefix:prefix,p:p,s:s});")
;  table.insert(buf, "    }")
;  table.insert(buf, "  }")
;  table.insert(buf, "  function badge(text){")
;    table.insert(buf, "    var span=document.createElement('span'); span.className='badge'; span.textContent=text; return span;")
;  table.insert(buf, "  }")
;  table.insert(buf, "  function ensureMeta(){")
;  table.insert(buf, "    if(metaCount) return;")
;  table.insert(buf, "    var meta = document.getElementById('meta');")
;  table.insert(buf, "    metaCount = badge('0'); meta.appendChild(metaCount);")
;  table.insert(buf, "    metaSelected = badge(''); metaSelected.style.display='none'; meta.appendChild(metaSelected);")
;  table.insert(buf, "  }")
;  table.insert(buf, "  function render(state){")
;  table.insert(buf, "    lastState = state;")
;  table.insert(buf, "    if(!ready) return;")
;  table.insert(buf, "    ensureRows();")
;  table.insert(buf, "    ensureMeta();")
;  table.insert(buf, "    var promptLeft = document.getElementById('promptTextLeft');")
;  table.insert(buf, "    var promptRight = document.getElementById('promptTextRight');")
;  table.insert(buf, "    if(state.query && state.query.length>0){")
;  table.insert(buf, "      promptLeft.textContent = state.queryLeft || state.query;")
;  table.insert(buf, "      promptRight.textContent = state.queryRight || '';")
;  table.insert(buf, "      promptLeft.classList.remove('placeholder');")
;  table.insert(buf, "    } else {")
;  table.insert(buf, "      promptLeft.textContent = state.placeholder || '';")
;  table.insert(buf, "      promptRight.textContent = '';")
;  table.insert(buf, "      promptLeft.classList.add('placeholder');")
;  table.insert(buf, "    }")
;  table.insert(buf, "    metaCount.textContent = String(state.total || 0);")
;  table.insert(buf, "    if(state.allowMulti && state.markedCount && state.markedCount>0){ metaSelected.textContent = String(state.markedCount)+' selected'; metaSelected.style.display=''; }")
;  table.insert(buf, "    else { metaSelected.style.display='none'; }")
;  table.insert(buf, "    var items = state.items || [];")
;  table.insert(buf, "    if((state.total||0)===0){")
;  table.insert(buf, "      rows[0].row.style.display='flex'; rows[0].row.className='item sel'; rows[0].prefix.textContent='   '; rows[0].p.textContent=(state.emptyText||'No matches'); rows[0].s.textContent='';")
;  table.insert(buf, "      for(var j=1;j<rows.length;j++){ rows[j].row.style.display='none'; }")
;  table.insert(buf, "    } else {")
;  table.insert(buf, "      for(var i=0;i<rows.length;i++){")
;  table.insert(buf, "        var it = items[i];")
;  table.insert(buf, "        if(!it){ rows[i].row.style.display='none'; continue; }")
;  table.insert(buf, "        rows[i].row.style.display='flex';")
;  table.insert(buf, "        rows[i].row.className = 'item' + (it.selected ? ' sel' : '') + (it.marked ? ' marked' : '');")
;  table.insert(buf, "        rows[i].prefix.textContent = it.prefix || '   ';")
;  table.insert(buf, "        rows[i].p.textContent = it.primary || '';")
;  table.insert(buf, "        rows[i].s.textContent = it.secondary || '';")
;  table.insert(buf, "      }")
;  table.insert(buf, "    }")
;  table.insert(buf, "    document.getElementById('hintLeft').textContent = state.hintLeft || '';")
;  table.insert(buf, "    document.getElementById('hintRight').textContent = state.hintRight || '';")
;  table.insert(buf, "  }")
;  table.insert(buf, "  window.repoOverlayRender = render;")
;  table.insert(buf, "  document.addEventListener('DOMContentLoaded', function(){")
;  table.insert(buf, "    ready = true;")
;  table.insert(buf, "    if(window.__repoOverlayState){ render(window.__repoOverlayState); }")
;  table.insert(buf, "    else if(lastState){ render(lastState); }")
;  table.insert(buf, "  });")
;  table.insert(buf, "})();")
;  table.insert(buf, "</script></body></html>")
;
;  return table.concat(buf, "\n")
;end
;
;local function _viewModel()
;  local spec = state.spec
;  _clampCursor()
;  local query = state.query or ""
;  local cursor = state.cursor or #query
;
;  local total = #state.filtered
;  local maxVisible = _cfg("maxResults")
;
;  local emptyText = (state.emptyText and state.emptyText ~= "") and state.emptyText or "No matches"
;  if state.loading then
;    emptyText = (state.loadingText and state.loadingText ~= "") and state.loadingText or "Loading…"
;  elseif state.searching and total == 0 then
;    emptyText = "Searching…"
;  end
;
;  local startIndex = 0
;  local endIndex = 0
;  if total > 0 then
;    startIndex = state.viewOffset + 1
;    endIndex = math.min(total, state.viewOffset + maxVisible)
;  end
;
;  local items = {}
;  if total > 0 then
;    for idx = startIndex, endIndex do
;      local item = state.filtered[idx]
;      local key = _itemKey(item)
;      local selected = (idx == state.selectedIndex)
;      local marked = (state.allowMulti and state.marked[key]) and true or false
;      table.insert(items, {
;        prefix = (selected and ">" or " ") .. (marked and "*" or " "),
;        primary = item.primary or "",
;        secondary = item.secondary or "",
;        selected = selected,
;        marked = marked,
;      })
;    end
;  end
;
;  local hintLeft = "↵ paste • esc cancel • ↑↓ move • ⌫ delete"
;  if state.allowMulti then hintLeft = "tab mark • " .. hintLeft end
;  if spec and type(spec.hintLeft) == "string" then hintLeft = spec.hintLeft end
;
;  local hintRight
;  if total == 0 then
;    hintRight = "0"
;  elseif total <= maxVisible then
;    hintRight = tostring(total)
;  else
;    hintRight = string.format("%d-%d/%d", startIndex, endIndex, total)
;  end
;  if spec and type(spec.hintRight) == "string" then hintRight = spec.hintRight end
;
;  return {
;    query = query,
;    queryLeft = query:sub(1, cursor),
;    queryRight = query:sub(cursor + 1),
;    placeholder = state.prompt or "search>",
;    emptyText = emptyText,
;    total = total,
;    allowMulti = state.allowMulti and true or false,
;    markedCount = _markedCount(),
;    items = items,
;    hintLeft = hintLeft,
;    hintRight = hintRight,
;  }
;end
;
;local function _render()
;  if not state.webview then return end
;  local payload = json.encode(_viewModel())
;  state.webview:evaluateJavaScript("window.__repoOverlayState=" .. payload .. "; if(window.repoOverlayRender){ window.repoOverlayRender(window.__repoOverlayState); }")
;end
;
;local function _clampView()
;  local total = #state.filtered
;
;  if total == 0 then
;    state.selectedIndex = 1
;    state.viewOffset = 0
;  else
;    if state.selectedIndex < 1 then state.selectedIndex = 1 end
;    if state.selectedIndex > total then state.selectedIndex = total end
;
;    local maxVisible = _cfg("maxResults")
;    local maxOffset = math.max(0, total - maxVisible)
;    if state.viewOffset < 0 then state.viewOffset = 0 end
;    if state.viewOffset > maxOffset then state.viewOffset = maxOffset end
;
;    if state.selectedIndex <= state.viewOffset then
;      state.viewOffset = state.selectedIndex - 1
;    elseif state.selectedIndex > (state.viewOffset + maxVisible) then
;      state.viewOffset = state.selectedIndex - maxVisible
;    end
;
;    if state.viewOffset < 0 then state.viewOffset = 0 end
;    if state.viewOffset > maxOffset then state.viewOffset = maxOffset end
;  end
;
;  if state.viewOffset < 0 then state.viewOffset = 0 end
;end
;
;local function _refresh()
;  _clampView()
;  if state.webview then _render() end
;end
;
;local function _update()
;  state.filtered = _filter(state.items, state.query)
;  _refresh()
;end
;
;local function _stopSearch()
;  if state.searchTimer then
;    pcall(function() state.searchTimer:stop() end)
;    state.searchTimer = nil
;  end
;  state.searching = false
;end
;
;_scoreForQuery = function(item, query)
;  local spec = state.spec
;  if spec and type(spec.score) == "function" then
;    local ok, s, tie = pcall(spec.score, item, query)
;    if ok then
;      if s == nil then return nil end
;      return s, tie or 0
;    end
;    log.df("score: error: %s", tostring(s))
;  end
;
;  local key = _itemKey(item)
;
;  if query == "" then
;    local base = type(item.sortScore) == "number" and item.sortScore or (type(item.activityTs) == "number" and item.activityTs or 0)
;    return base, (type(state.recency[key]) == "number" and state.recency[key] or 0)
;  end
;
;  local hay
;  if item.kind == "file" then
;    hay = item.primary or ""
;  else
;    hay = (item.primary or "") .. " " .. (item.secondary or "")
;  end
;
;  local s = _fuzzyScore(hay, query)
;  if not s then return nil end
;  s = s + _recencyBonus(key)
;  return s, 0
;end
;
;_cmpScored = function(a, b)
;  if a.score ~= b.score then return a.score > b.score end
;  local as = type(a.sortScore) == "number" and a.sortScore or 0
;  local bs = type(b.sortScore) == "number" and b.sortScore or 0
;  if as ~= bs then return as > bs end
;
;  local at = type(a.activityTs) == "number" and a.activityTs or 0
;  local bt = type(b.activityTs) == "number" and b.activityTs or 0
;  if at ~= bt then return at > bt end
;
;  local ta = type(a.tie) == "number" and a.tie or 0
;  local tb = type(b.tie) == "number" and b.tie or 0
;  if ta ~= tb then return ta > tb end
;
;  return (a.primary or "") < (b.primary or "")
;end
;
;local function _cmpWorse(a, b)
;  return _cmpScored(b, a)
;end
;
;local function _heapPush(heap, node)
;  table.insert(heap, node)
;  local i = #heap
;  while i > 1 do
;    local p = math.floor(i / 2)
;    if not _cmpWorse(heap[i], heap[p]) then break end
;    heap[i], heap[p] = heap[p], heap[i]
;    i = p
;  end
;end
;
;local function _heapDown(heap, i)
;  local n = #heap
;  while true do
;    local l = i * 2
;    local r = l + 1
;    local m = i
;    if l <= n and _cmpWorse(heap[l], heap[m]) then m = l end
;    if r <= n and _cmpWorse(heap[r], heap[m]) then m = r end
;    if m == i then return end
;    heap[i], heap[m] = heap[m], heap[i]
;    i = m
;  end
;end
;
;local function _heapReplaceRoot(heap, node)
;  heap[1] = node
;  _heapDown(heap, 1)
;end
;
;local function _searchAsync()
;  _stopSearch()
;
;  local query = state.query or ""
;  local items = state.items or {}
;
;  -- Only do async filtering when enabled and the candidate set is large.
;  local enableAsync = _cfg("enableAsyncFilter") and true or false
;  local threshold = _cfg("asyncFilterThreshold") or 8000
;  local isBig = enableAsync and (#items > threshold)
;  if not isBig then
;    state.searching = false
;    _update()
;    return
;  end
;
;  state.searching = true
;  local maxKeep = _cfg("maxMatches")
;  state.searchGen = state.searchGen + 1
;  local gen = state.searchGen
;
;  local idx = 1
;  local heap = {}
;  local processed = 0
;  local lastUi = hs.timer.secondsSinceEpoch()
;
;  state.searchTimer = hs.timer.new(0.01, function()
;    if not state.active or state.searchGen ~= gen then
;      _stopSearch()
;      return
;    end
;
;    local chunk = 500
;    local limit = math.min(#items, idx + chunk - 1)
;    while idx <= limit do
;      local item = items[idx]
;      idx = idx + 1
;      processed = processed + 1
;
;      local score, tie = _scoreForQuery(item, query)
;      if score then
;        local node = {
;          item = item,
;          score = score,
;          tie = tie,
;          sortScore = item.sortScore,
;          activityTs = item.activityTs,
;          primary = item.primary,
;        }
;
;        if #heap < maxKeep then
;          _heapPush(heap, node)
;        else
;          if _cmpScored(node, heap[1]) then
;            _heapReplaceRoot(heap, node)
;          end
;        end
;      end
;    end
;
;    local now = hs.timer.secondsSinceEpoch()
;    if (now - lastUi) > 0.12 then
;      lastUi = now
;      local scored = {}
;      for i = 1, #heap do scored[i] = heap[i] end
;      table.sort(scored, _cmpScored)
;      local out = {}
;      for i = 1, #scored do out[i] = scored[i].item end
;      state.filtered = out
;      _refresh()
;    end
;
;    if idx > #items then
;      state.searchTimer:stop()
;      state.searchTimer = nil
;      state.searching = false
;
;      local scored = {}
;      for i = 1, #heap do scored[i] = heap[i] end
;      table.sort(scored, _cmpScored)
;      local out = {}
;      for i = 1, #scored do out[i] = scored[i].item end
;      state.filtered = out
;      log.df("search: done items=%d kept=%d query_len=%d", #items, #out, #query)
;      _refresh()
;    end
;  end)
;
;  state.searchTimer:start()
;end
;
;local function _scheduleUpdate()
;  state.filterGen = state.filterGen + 1
;  local gen = state.filterGen
;
;  if state.filterTimer then
;    state.filterTimer:stop()
;    state.filterTimer = nil
;  end
;
;  state.filterTimer = hs.timer.doAfter(0.02, function()
;    if not state.active then return end
;    if state.filterGen ~= gen then return end
;    state.filterTimer = nil
;    _searchAsync()
;  end)
;end
;
;local function _paste(text)
;  if not text or text == "" then return end
;  local prev = hs.pasteboard.getContents()
;  hs.pasteboard.setContents(text)
;
;  hs.timer.doAfter(0.03, function()
;    hs.eventtap.keyStroke({ "cmd" }, "v", 0)
;    hs.timer.doAfter(0.15, function()
;      if prev and prev ~= "" then hs.pasteboard.setContents(prev) end
;    end)
;  end)
;end
;
;local function _close()
;  if state.active then log.i("close overlay") end
;
;  if state.sourceCancel then
;    pcall(state.sourceCancel)
;    state.sourceCancel = nil
;  end
;
;  if state.loadTask then
;    pcall(function() state.loadTask:terminate() end)
;    state.loadTask = nil
;  end
;  if state.activityTimer then
;    pcall(function() state.activityTimer:stop() end)
;    state.activityTimer = nil
;  end
;  if state.filterTimer then
;    pcall(function() state.filterTimer:stop() end)
;    state.filterTimer = nil
;  end
;  _stopSearch()
;
;  state.active = false
;  state.mode = nil
;  state.spec = nil
;  state.prompt = ""
;  state.query = ""
;  state.cursor = 0
;  state.killBuffer = ""
;  state.loading = false
;  state.loadingText = ""
;  state.emptyText = ""
;  state.items = {}
;  state.filtered = {}
;  state.selectedIndex = 1
;  state.viewOffset = 0
;  state.marked = {}
;  state.allowMulti = false
;  state.onAccept = nil
;
;  if state.tap then
;    state.tap:stop()
;    state.tap = nil
;  end
;
;  if state.webview then
;    state.webview:delete()
;    state.webview = nil
;  end
;end
;
;local function _cancel()
;  local spec = state.spec
;  if spec and type(spec.onCancel) == "function" then
;    pcall(spec.onCancel)
;  end
;  _close()
;end
;
;local function _accept()
;  local choices = {}
;  if state.allowMulti and _hasMarks() then
;    choices = _markedItemsInOrder()
;  else
;    local choice = state.filtered[state.selectedIndex]
;    if choice then table.insert(choices, choice) end
;  end
;
;  if #choices == 0 then
;    log.d("accept: no selection")
;    _close()
;    return
;  end
;
;  log.df("accept: count=%d first=%s", #choices, tostring(choices[1].primary))
;
;  local now = os.time()
;  local touched = false
;  for _, c in ipairs(choices) do
;    local key = _itemKey(c)
;    if key ~= "" then
;      state.recency[key] = now
;      touched = true
;    end
;  end
;  if touched then
;    state.recency = _trimRecency(state.recency, 500)
;    _saveRecency(state.recency)
;  end
;
;  local cb = state.onAccept
;  local returnApp = state.returnApp
;  _close()
;
;  if returnApp then returnApp:activate() end
;  if cb then cb(choices) end
;end
;
;local function _start(mode, items, prompt, allowMulti, onAccept, opts)
;  opts = opts or {}
;
;  state.active = true
;  state.mode = mode
;  state.query = ""
;  state.cursor = 0
;  state.killBuffer = ""
;  state.items = items or {}
;  state.filtered = {}
;  state.prompt = prompt or "search>"
;  state.loading = opts.loading and true or false
;  state.loadingText = opts.loadingText or ""
;  state.emptyText = opts.emptyText or ""
;  state.allowMulti = allowMulti and true or false
;  state.selectedIndex = 1
;  state.viewOffset = 0
;  state.marked = {}
;  state.returnApp = hs.application.frontmostApplication()
;  state.onAccept = onAccept
;  log.f(
;    "open overlay: mode=%s prompt=%s items=%d multi=%s",
;    tostring(state.mode),
;    tostring(state.prompt),
;    #state.items,
;    tostring(state.allowMulti)
;  )
;
;  local frame = _computeFrame()
;  local w = hs.webview.new(frame)
;
;  -- Borderless, always-on-top, and visible across Spaces.
;  w:windowStyle(0)
;  w:level(hs.drawing.windowLevels.popUpMenu)
;  w:behaviorAsLabels({ "canJoinAllSpaces", "fullScreenAuxiliary" })
;  w:transparent(true)
;
;  w:html(_baseHtml())
;  w:show()
;  state.webview = w
;
;  local kc = hs.keycodes.map
;
;  local function _resetToTop()
;    state.selectedIndex = 1
;    state.viewOffset = 0
;  end
;
;  local function _moveSelection(delta)
;    if #state.filtered == 0 then return end
;    state.selectedIndex = math.max(1, math.min(#state.filtered, state.selectedIndex + delta))
;    _refresh()
;  end
;
;  local function _toggleMarkAt(index)
;    local item = state.filtered[index]
;    if not item then return end
;    local key = _itemKey(item)
;    if key == "" then return end
;    if state.marked[key] then state.marked[key] = nil else state.marked[key] = true end
;  end
;
;  state.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(ev)
;    if not state.active then return false end
;
;    local code = ev:getKeyCode()
;    local flags = ev:getFlags()
;
;	    -- Let app-switching happen and close the overlay.
;	    if flags.cmd and code == kc.tab then
;	      _cancel()
;	      return false
;	    end
;
;	    if code == kc.escape then
;	      _cancel()
;	      return true
;	    end
;
;    if code == kc["return"] or code == kc["padenter"] then
;      _accept()
;      return true
;    end
;
;    if code == kc.up then
;      _moveSelection(-1)
;      return true
;    end
;
;	    if code == kc.down then
;	      _moveSelection(1)
;	      return true
;	    end
;
;	    if code == kc.left then
;	      if flags.alt and not flags.cmd and not flags.ctrl then
;	        _moveWordBackward()
;	      else
;	        state.cursor = math.max(0, (state.cursor or 0) - 1)
;	      end
;	      _refresh()
;	      return true
;	    end
;
;	    if code == kc.right then
;	      if flags.alt and not flags.cmd and not flags.ctrl then
;	        _moveWordForward()
;	      else
;	        _clampCursor()
;	        state.cursor = math.min(#(state.query or ""), (state.cursor or 0) + 1)
;	      end
;	      _refresh()
;	      return true
;	    end
;
;	    if code == kc["pageup"] then
;	      _moveSelection(-_cfg("maxResults"))
;	      return true
;	    end
;
;    if code == kc["pagedown"] then
;      _moveSelection(_cfg("maxResults"))
;      return true
;    end
;
;    if code == kc["home"] then
;      state.selectedIndex = 1
;      _refresh()
;      return true
;    end
;
;    if code == kc["end"] then
;      state.selectedIndex = #state.filtered
;      _refresh()
;      return true
;    end
;
;	    if code == kc.tab and not flags.cmd and not flags.ctrl and not flags.alt then
;	      if state.allowMulti and #state.filtered > 0 then
;	        _toggleMarkAt(state.selectedIndex)
;	        if flags.shift then _moveSelection(-1) else _moveSelection(1) end
;	      end
;	      return true
;	    end
;
;	    -- Backspace / forward-delete.
;	    if code == kc.delete or code == kc.forwarddelete then
;	      if flags.alt and not flags.cmd and not flags.ctrl then
;	        if code == kc.delete then _backwardKillWord() else _killWordForward() end
;	      else
;	        if code == kc.delete then _deleteBackward() else _deleteForward() end
;	      end
;	      _resetToTop()
;	      _scheduleUpdate()
;	      return true
;	    end
;
;	    -- Ctrl: readline-ish editing + fzf-ish list nav (Ctrl-N / Ctrl-P).
;	    if flags.ctrl and not flags.cmd and not flags.alt then
;	      local ch = ev:getCharacters()
;	      if ch == "a" then
;	        state.cursor = 0
;	        _refresh()
;	        return true
;	      elseif ch == "e" then
;	        state.cursor = #(state.query or "")
;	        _refresh()
;	        return true
;	      elseif ch == "b" then
;	        state.cursor = math.max(0, (state.cursor or 0) - 1)
;	        _refresh()
;	        return true
;	      elseif ch == "f" then
;	        _clampCursor()
;	        state.cursor = math.min(#(state.query or ""), (state.cursor or 0) + 1)
;	        _refresh()
;	        return true
;	      elseif ch == "n" then
;	        _moveSelection(1)
;	        return true
;	      elseif ch == "p" then
;	        _moveSelection(-1)
;	        return true
;	      elseif ch == "u" then
;	        _killToStart()
;	        _resetToTop()
;	        _scheduleUpdate()
;	        return true
;	      elseif ch == "k" then
;	        _killToEnd()
;	        _resetToTop()
;	        _scheduleUpdate()
;	        return true
;	      elseif ch == "w" then
;	        _backwardKillWord()
;	        _resetToTop()
;	        _scheduleUpdate()
;	        return true
;	      elseif ch == "y" then
;	        _yank()
;	        _resetToTop()
;	        _scheduleUpdate()
;	        return true
;	      elseif ch == "d" then
;	        _deleteForward()
;	        _resetToTop()
;	        _scheduleUpdate()
;	        return true
;	      end
;	    end
;
;    -- Cmd-V inserts clipboard into the query.
;	    if flags.cmd and not flags.ctrl and not flags.alt then
;	      local ch = ev:getCharacters()
;	      if ch == "v" then
;	        local clip = hs.pasteboard.getContents() or ""
;	        if clip ~= "" then
;	          _insertText(clip)
;	          _resetToTop()
;	          _scheduleUpdate()
;	        end
;	        return true
;	      end
;	    end
;
;    -- Accept basic printable characters; swallow everything else while active.
;	    if not flags.cmd and not flags.ctrl and not flags.alt then
;	      local ch = ev:getCharacters()
;	      if ch and ch ~= "" and ch ~= "\r" and ch ~= "\n" then
;	        _insertText(ch)
;	        _resetToTop()
;	        _scheduleUpdate()
;	      end
;	      return true
;	    end
;
;    return true
;  end)
;  state.tap:start()
;
;  _update()
;end
;
;FuzzyOverlay.close = function()
;  _close()
;end
;
;FuzzyOverlay.open = function(spec)
;  if type(spec) ~= "table" then
;    log.w("FuzzyOverlay.open: spec must be a table")
;    return
;  end
;
;  local id = spec.id or spec.mode or spec.name
;  if type(id) ~= "string" or id == "" then
;    log.w("FuzzyOverlay.open: missing spec.id")
;    return
;  end
;
;  _close()
;
;  state.spec = spec
;
;  state.loadGen = state.loadGen + 1
;  local gen = state.loadGen
;
;  local function emit(patch)
;    if not state.active or state.mode ~= id or state.loadGen ~= gen then return end
;    patch = patch or {}
;
;    if patch.loading ~= nil then state.loading = patch.loading and true or false end
;    if patch.loadingText ~= nil then state.loadingText = patch.loadingText or "" end
;    if patch.emptyText ~= nil then state.emptyText = patch.emptyText or "" end
;    if patch.items ~= nil then state.items = patch.items or {} end
;
;    _searchAsync()
;  end
;
;  local function onAccept(choices)
;    if type(spec.onAccept) == "function" then
;      local ok, err = pcall(spec.onAccept, choices)
;      if not ok then log.wf("onAccept: %s", tostring(err)) end
;    end
;  end
;
;  _start(
;    id,
;    spec.items or {},
;    spec.prompt or "search>",
;    spec.allowMulti and true or false,
;    onAccept,
;    { loading = true, loadingText = spec.loadingText or "Loading…", emptyText = spec.emptyText or "" }
;  )
;
;  if type(spec.source) == "function" then
;    local ok, cancel = pcall(spec.source, { gen = gen, id = id }, emit)
;    if ok and type(cancel) == "function" then
;      state.sourceCancel = cancel
;    elseif not ok then
;      log.wf("source: %s", tostring(cancel))
;      emit({ loading = false, items = {}, emptyText = "Failed to load (see logfile)" })
;    end
;  else
;    emit({ loading = false, items = spec.items or {} })
;  end
;end
;
;local function _parseRepoIndexTsv(out)
;  local items = {}
;
;  local rawLines = _lines(out)
;  if #rawLines == 0 then
;    log.w("repo-index: no output (did you run dotfiles bootstrap?)")
;  else
;    log.df("repo-index: lines=%d", #rawLines)
;  end
;
;  for _, line in ipairs(rawLines) do
;    local slug, url, path = line:match("([^\t]+)\t([^\t]+)\t(.+)")
;    if slug and url and path then
;      table.insert(items, {
;        key = slug,
;        kind = "repo",
;        primary = slug,
;        secondary = url,
;        value = url,
;        repoPath = path,
;        slug = slug,
;        url = url,
;        activityTs = 0,
;      })
;    end
;  end
;
;  if #items == 0 and #rawLines > 0 then
;    log.wf("repo-index: output was not parseable TSV (sample=%s)", tostring(rawLines[1]))
;  end
;
;  log.df("repo-index: parsed_items=%d", #items)
;  table.sort(items, function(a, b) return (a.primary or "") < (b.primary or "") end)
;  return items
;end
;
;local function _repoIndexItems()
;  local repoIndex = string.format("%q", config.dotfilesBin .. "/repo-index")
;  local out = _sh(repoIndex .. " --format tsv 2>/dev/null")
;  return _parseRepoIndexTsv(out)
;end
;
;local function _repoIndexItemsAsync(gen, cb)
;  local repoIndex = string.format("%q", config.dotfilesBin .. "/repo-index")
;  state.loadTask = _shAsync(repoIndex .. " --format tsv 2>/dev/null", function(ok, out, err)
;    if state.loadGen ~= gen then return end
;    state.loadTask = nil
;
;    if not state.active then return end
;    if not ok then
;      log.wf("repo-index: failed (%s)", _trim(err or ""))
;      if cb then cb({}, false) end
;      return
;    end
;
;    local items = _parseRepoIndexTsv(out)
;    log.f("repo-index: loaded items=%d", #items)
;    if cb then cb(items, true) end
;  end)
;end
;
;local function _mtime(path)
;  local attr = hs.fs.attributes(path)
;  local ts = attr and attr.modification or nil
;  if type(ts) == "number" then return ts end
;  return 0
;end
;
;local function _maxMtimeUnder(root, maxEntries, maxDepth)
;  if hs.fs.attributes(root, "mode") ~= "directory" then return 0, false end
;
;  maxEntries = maxEntries or 4000
;  maxDepth = maxDepth or 4
;
;  local maxTs = 0
;  local seen = 0
;  local stack = { { path = root, depth = maxDepth } }
;
;  while #stack > 0 do
;    local node = table.remove(stack)
;    for entry in hs.fs.dir(node.path) do
;      if entry ~= "." and entry ~= ".." then
;        local full = node.path .. "/" .. entry
;        local attr = hs.fs.attributes(full)
;        if attr then
;          local ts = tonumber(attr.modification) or 0
;          if ts > maxTs then maxTs = ts end
;
;          seen = seen + 1
;          if seen >= maxEntries then return maxTs, true end
;
;          if attr.mode == "directory" and node.depth > 0 then
;            table.insert(stack, { path = full, depth = node.depth - 1 })
;          end
;        end
;      end
;    end
;  end
;
;  return maxTs, false
;end
;
;local function _repoActivityTs(repoPath)
;  local gitdir = repoPath .. "/.git"
;  if hs.fs.attributes(gitdir, "mode") ~= "directory" then return 0 end
;
;  local maxTs = 0
;  local function bump(p)
;    local ts = _mtime(p)
;    if ts > maxTs then maxTs = ts end
;  end
;
;  bump(gitdir .. "/logs/HEAD")
;  bump(gitdir .. "/index")
;  bump(gitdir .. "/FETCH_HEAD")
;  bump(gitdir .. "/packed-refs")
;  bump(gitdir .. "/HEAD")
;  bump(gitdir .. "/ORIG_HEAD")
;
;  local refsTs, refsTrunc = _maxMtimeUnder(gitdir .. "/refs", 5000, 5)
;  if refsTs > maxTs then maxTs = refsTs end
;  local logsTs, logsTrunc = _maxMtimeUnder(gitdir .. "/logs/refs", 5000, 5)
;  if logsTs > maxTs then maxTs = logsTs end
;
;  if refsTrunc or logsTrunc then
;    log.df("activity: truncated scan for %s (refs=%s logs=%s)", repoPath, tostring(refsTrunc), tostring(logsTrunc))
;  end
;
;  return maxTs
;end
;
;local function _startActivityScan(gen)
;  if state.activityTimer then
;    state.activityTimer:stop()
;    state.activityTimer = nil
;  end
;
;  local idx = 1
;  state.activityGen = gen
;
;  state.activityTimer = hs.timer.new(0.01, function()
;    if not state.active or state.activityGen ~= gen then
;      if state.activityTimer then
;        state.activityTimer:stop()
;        state.activityTimer = nil
;      end
;      return
;    end
;
;    local item = state.items[idx]
;    idx = idx + 1
;    if not item then
;      state.activityTimer:stop()
;      state.activityTimer = nil
;      log.df("activity: done")
;      _update()
;      return
;    end
;
;    if item.kind == "repo" and item.repoPath then
;      item.activityTs = _repoActivityTs(item.repoPath)
;    end
;  end)
;
;  state.activityTimer:start()
;end
;
;local function _repoFilesItems(repoPath)
;  local safeRepo = repoPath:gsub("'", "'\\''")
;  local statusOut = _sh("/usr/bin/git -C '" .. safeRepo .. "' status --porcelain=v1 2>/dev/null")
;  local statusMap = {}
;  for _, line in ipairs(_lines(statusOut)) do
;    local xy, path = line:match("^(..)%s+(.*)$")
;    if xy and path then
;      local to = path:match(".* %-> (.+)$")
;      if to then path = to end
;      statusMap[path] = xy
;    end
;  end
;
;  local out = _sh("/usr/bin/git -C '" .. safeRepo .. "' ls-files -co --exclude-standard 2>/dev/null")
;  local items = {}
;  for _, rel in ipairs(_lines(out)) do
;    local st = statusMap[rel]
;    local sortScore = 0
;    if st == "??" then sortScore = 2 elseif st and st ~= "  " then sortScore = 1 end
;
;    local secondary = repoPath
;    if st and st ~= "  " then secondary = st .. " · " .. repoPath end
;
;    table.insert(items, {
;      key = repoPath .. "/" .. rel,
;      kind = "file",
;      primary = rel,
;      secondary = secondary,
;      value = repoPath .. "/" .. rel,
;      relPath = rel,
;      repoPath = repoPath,
;      sortScore = sortScore,
;      activityTs = 0,
;    })
;  end
;  return items
;end
;
;local function _repoFilesItemsAsync(repoPath, gen, cb)
;  local safeRepo = repoPath:gsub("'", "'\\''")
;  local statusCmd = "/usr/bin/git -C '" .. safeRepo .. "' status --porcelain=v1 2>/dev/null"
;
;  state.loadTask = _shAsync(statusCmd, function(okStatus, statusOut, statusErr)
;    if state.loadGen ~= gen then return end
;    if not state.active then return end
;
;    if not okStatus then
;      log.df("git status failed: %s", _trim(statusErr or ""))
;    end
;
;    local statusMap = {}
;    for _, line in ipairs(_lines(statusOut)) do
;      local xy, path = line:match("^(..)%s+(.*)$")
;      if xy and path then
;        local to = path:match(".* %-> (.+)$")
;        if to then path = to end
;        statusMap[path] = xy
;      end
;    end
;
;    local lsCmd = "/usr/bin/git -C '" .. safeRepo .. "' ls-files -co --exclude-standard 2>/dev/null"
;    state.loadTask = _shAsync(lsCmd, function(okLs, out, err)
;      if state.loadGen ~= gen then return end
;      state.loadTask = nil
;      if not state.active then return end
;
;      if not okLs then
;        log.wf("git ls-files failed: %s", _trim(err or ""))
;        if cb then cb({}, false) end
;        return
;      end
;
;      local items = {}
;      for _, rel in ipairs(_lines(out)) do
;        local st = statusMap[rel]
;        local sortScore = 0
;        if st == "??" then sortScore = 2 elseif st and st ~= "  " then sortScore = 1 end
;
;        local secondary = repoPath
;        if st and st ~= "  " then secondary = st .. " · " .. repoPath end
;
;        table.insert(items, {
;          key = repoPath .. "/" .. rel,
;          kind = "file",
;          primary = rel,
;          secondary = secondary,
;          value = repoPath .. "/" .. rel,
;          relPath = rel,
;          repoPath = repoPath,
;          sortScore = sortScore,
;          activityTs = 0,
;        })
;      end
;
;      log.df("repo-files: repo=%s items=%d", repoPath, #items)
;      if cb then cb(items, true) end
;    end)
;  end)
;end
;
;-- Public commands -------------------------------------------------------
;
;local repoFileLastRepoPath = nil
;
;local function _pasteChoices(choices)
;  local out = {}
;  for _, c in ipairs(choices or {}) do
;    if c and c.value then table.insert(out, c.value) end
;  end
;  _paste(table.concat(out, "\n"))
;end
;
;local function pickRepoFiles(repoPath)
;  FuzzyOverlay.open({
;    id = "repoFilePath",
;    prompt = "file>",
;    allowMulti = true,
;    loadingText = "Loading files…",
;    emptyText = "",
;    theme = { enableAsyncFilter = true },
;    onCancel = function()
;      repoFileLastRepoPath = nil
;    end,
;    onAccept = function(choices)
;      if choices and #choices > 0 then repoFileLastRepoPath = repoPath end
;      _pasteChoices(choices)
;    end,
;    source = function(ctx, emit)
;      _repoFilesItemsAsync(repoPath, ctx.gen, function(items, ok)
;        if not ok then
;          emit({ loading = false, items = {}, emptyText = "Failed to load files (see logfile)" })
;          return
;        end
;        items = items or {}
;        emit({ loading = false, items = items, emptyText = (#items == 0 and "No files found" or "") })
;      end)
;    end,
;  })
;end
;
;local function pickRepoUrl()
;  FuzzyOverlay.open({
;    id = "repoUrl",
;    prompt = "repo url>",
;    allowMulti = true,
;    loadingText = "Loading repos…",
;    emptyText = "",
;    onAccept = function(choices)
;      _pasteChoices(choices)
;    end,
;    source = function(ctx, emit)
;      _repoIndexItemsAsync(ctx.gen, function(items, ok)
;        if not ok then
;          emit({ loading = false, items = {}, emptyText = "Failed to load repos (see logfile)" })
;          return
;        end
;        items = items or {}
;        emit({ loading = false, items = items, emptyText = (#items == 0 and "No repos found" or "") })
;        _startActivityScan(ctx.gen)
;      end)
;    end,
;  })
;end
;
;local function pickRepoFile(forcePickRepo)
;  if (not forcePickRepo)
;      and repoFileLastRepoPath
;      and hs.fs.attributes(repoFileLastRepoPath, "mode") == "directory" then
;    pickRepoFiles(repoFileLastRepoPath)
;    return
;  end
;
;  FuzzyOverlay.open({
;    id = "repoFileRepo",
;    prompt = "repo>",
;    allowMulti = false,
;    loadingText = "Loading repos…",
;    emptyText = "",
;    onCancel = function()
;      repoFileLastRepoPath = nil
;    end,
;    onAccept = function(choices)
;      local choice = choices and choices[1] or nil
;      if not choice then return end
;      pickRepoFiles(choice.repoPath)
;    end,
;    source = function(ctx, emit)
;      _repoIndexItemsAsync(ctx.gen, function(items, ok)
;        if not ok then
;          emit({ loading = false, items = {}, emptyText = "Failed to load repos (see logfile)" })
;          return
;        end
;        items = items or {}
;        emit({ loading = false, items = items, emptyText = (#items == 0 and "No repos found" or "") })
;        _startActivityScan(ctx.gen)
;      end)
;    end,
;  })
;end
;
;hs.hotkey.bind(config.hotkeyRepoUrl.mods, config.hotkeyRepoUrl.key, pickRepoUrl)
;hs.hotkey.bind(config.hotkeyRepoFile.mods, config.hotkeyRepoFile.key, function() pickRepoFile(false) end)
;hs.hotkey.bind(config.hotkeyRepoFilePickRepo.mods, config.hotkeyRepoFilePickRepo.key, function() pickRepoFile(true) end)
;
;hs.hotkey.bind(config.hotkeyToggleDebug.mods, config.hotkeyToggleDebug.key, function()
;  RepoOverlay.toggleDebug()
;  local lvl = _levelName(log.getLogLevel())
;  log.f("log level: %s", lvl)
;  hs.alert.show("FuzzyOverlay log: " .. lvl, 0.8)
;end)
;
;hs.hotkey.bind(config.hotkeyShowLog.mods, config.hotkeyShowLog.key, function()
;  hs.pasteboard.setContents(logFile)
;  hs.alert.show("FuzzyOverlay log path copied", 0.8)
;end)
;
;-- Recompile + reload (Fennel -> Lua)
;local hyper = { "ctrl", "alt", "cmd", "shift" }
;hs.hotkey.bind(hyper, "r", function()
;  log.i("hyper-r: make hammerspoon")
;  hs.alert.show("Hammerspoon: build…", 0.6)
;
;  _shAsync("cd \"$HOME/dotfiles\" && make hammerspoon", function(ok, _, err)
;    if ok then
;      hs.alert.show("Hammerspoon: reload…", 0.6)
;      hs.reload()
;    else
;      local msg = "Hammerspoon build failed (see log)"
;      hs.alert.show(msg, 2.0)
;      log.wf("%s: %s", msg, _trim(err or ""))
;    end
;  end)
;end)
;
;log.f("loaded (logfile: %s)", logFile)
;if log.getLogLevel() >= 4 then
;  hs.alert.show("FuzzyOverlay loaded (debug)")
;end
;; END_EMBEDDED_LUA
