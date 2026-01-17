;; Repo/URL picker overlay (global) + file picker (repo-relative) via a compact webview.
;;
;; This is intentionally self-contained: it renders UI in a borderless webview and
;; captures keystrokes with an eventtap so it works in any app without needing focus.
;;
;; Build:
;;   `cd ~/dotfiles && make hammerspoon` → `.hammerspoon/init.generated.lua`

(local config
  {:dotfilesBin (.. (or (os.getenv "HOME") "") "/dotfiles/bin")

   ;; Hotkeys
   :hotkeyRepoUrl {:mods ["ctrl" "alt" "cmd"] :key "u"}
   :hotkeyRepoFile {:mods ["ctrl" "alt" "cmd"] :key "t"}
   :hotkeyRepoFilePickRepo {:mods ["ctrl" "alt" "cmd" "shift"] :key "t"}
   :hotkeyToggleDebug {:mods ["ctrl" "alt" "cmd" "shift"] :key "d"}
   :hotkeyShowLog {:mods ["ctrl" "alt" "cmd" "shift"] :key "l"}

   ;; UI
   :width 560
   :height 260
   :primaryWidth 250
   :maxResults 6
   :maxMatches 2000
   :asyncFilterThreshold 8000
   :enableAsyncFilter false
   :margin 10
   :offset 8})

;; Logging ----------------------------------------------------------------
(hs.logger.historySize 500)

(local log (hs.logger.new "repoOverlay" "info"))
(local logLevelSettingKey "repoOverlay.logLevel")

(local logFile (.. (or (os.getenv "HOME") "") "/Library/Logs/Hammerspoon/repoOverlay.log"))

(fn _appendLogFile [level msg]
  (let [cur (log.getLogLevel)
        required {:error 1 :warning 2 :info 3 :debug 4 :verbose 5}
        minLevel (or (. required level) 99)]
    (when (>= cur minLevel)
      (let [dir (or (: logFile :match "^(.*)/[^/]+$") "")]
        (when (~= dir "")
          (pcall hs.fs.mkdir dir)))

      (local (ok f) (pcall io.open logFile "a"))
      (when (and ok f)
        (let [line (string.format "%s [%s] %s\n"
                                  (os.date "%Y-%m-%d %H:%M:%S")
                                  (: level :upper)
                                  msg)]
          (pcall f.write f line)
          (pcall f.close f))))))

(fn _wrapLog [methodName level isFormat]
  (local orig (. log methodName))
  (when (= (type orig) "function")
    (tset log methodName
          (fn [& args]
            (var msg "")
            (when (>= (# args) 1)
              (let [first (. args 1)]
                (if (and isFormat (= (type first) "string"))
                  (do
                    (local (ok formatted) (pcall string.format first (table.unpack args 2)))
                    (set msg (if ok formatted (tostring first))))
                  (set msg (tostring first)))))
            (_appendLogFile level msg)
            (orig (table.unpack args))))))

;; Mirror logs to file for post-mortem debugging (honors log level).
(_wrapLog "e" "error" false)
(_wrapLog "ef" "error" true)
(_wrapLog "w" "warning" false)
(_wrapLog "wf" "warning" true)
(_wrapLog "i" "info" false)
(_wrapLog "f" "info" true)
(_wrapLog "d" "debug" false)
(_wrapLog "df" "debug" true)

(fn _levelName [level]
  (local names {[0] "nothing" [1] "error" [2] "warning" [3] "info" [4] "debug" [5] "verbose"})
  (or (. names level) (tostring level)))

(fn _setLogLevel [level]
  (local (ok _) (pcall (fn []
                         (log.setLogLevel level)
                         (hs.settings.set logLevelSettingKey level))))
  (if ok
    (log.f "log level: %s" (_levelName (log.getLogLevel)))
    (log.wf "failed to set log level (invalid?): %s" (tostring level))))

(let [configured (or (hs.settings.get logLevelSettingKey)
                     (os.getenv "HS_REPOOVERLAY_LOG_LEVEL")
                     "info")]
  (_setLogLevel configured))

(log.f "env: HOME=%s PATH=%s" (tostring (os.getenv "HOME")) (tostring (or (os.getenv "PATH") "")))
(log.f "config: dotfilesBin=%s" (tostring config.dotfilesBin))

(local state
  {:active false
   :mode nil ;; spec id (string)
   :spec nil
   :prompt ""
   :query ""
   :cursor 0
   :killBuffer ""
   :loading false
   :loadingText ""
   :emptyText ""
   :items []
   :filtered []
   :selectedIndex 1
   :viewOffset 0
   :marked {}
   :allowMulti false
   :recency {}
   :returnApp nil
   :webview nil
   :tap nil
   :onAccept nil
   :sourceCancel nil
   :loadTask nil
   :loadGen 0
   :activityGen 0
   :activityTimer nil
   :filterGen 0
   :filterTimer nil
   :searchGen 0
   :searchTimer nil
   :searching false})

;; FuzzyOverlay: a reusable “fzf-like” picker overlay component (webview + eventtap).
;; TODO(prateek): Move this into a Spoon once stable.
(tset _G :FuzzyOverlay (or (. _G :FuzzyOverlay) {}))
(local FuzzyOverlay (. _G :FuzzyOverlay))
(tset _G :RepoOverlay FuzzyOverlay) ;; back-compat alias (console snippets / bindings)
(local RepoOverlay (. _G :RepoOverlay))

(tset FuzzyOverlay :setLogLevel _setLogLevel)
(tset FuzzyOverlay :toggleDebug
      (fn []
        (if (>= (log.getLogLevel) 4)
          (_setLogLevel "info")
          (_setLogLevel "debug"))))
(tset FuzzyOverlay :logFile logFile)
(tset FuzzyOverlay :dump
      (fn []
        (var markedCount 0)
        (each [_ _ (pairs (or state.marked {}))]
          (set markedCount (+ markedCount 1)))
        (log.f
          "state: active=%s id=%s allowMulti=%s query_len=%d items=%d filtered=%d selectedIndex=%d viewOffset=%d marked=%d"
          (tostring state.active)
          (tostring state.mode)
          (tostring state.allowMulti)
          (# (or state.query ""))
          (# state.items)
          (# state.filtered)
          state.selectedIndex
          state.viewOffset
          markedCount)))

(fn _cfg [key]
  (local spec state.spec)
  (if spec
    (let [theme spec.theme]
      (if (and theme (not= nil (. theme key)))
        (. theme key)
        (if (not= nil (. spec key))
          (. spec key)
          (. config key))))
    (. config key)))

(local recencySettingKey "repoOverlay.recency")
(local json (require "hs.json"))

(fn _loadRecency []
  (local t (hs.settings.get recencySettingKey))
  (if (~= (type t) "table")
    {}
    (do
      ;; Normalize to numeric timestamps.
      (each [k v (pairs t)]
        (when (~= (type v) "number")
          (tset t k nil)))
      t)))

(fn _saveRecency [t]
  (hs.settings.set recencySettingKey t))

(fn _trimRecency [t maxEntries]
  (let [maxEntries (or maxEntries 500)]
    (var count 0)
    (each [_ _ (pairs t)]
      (set count (+ count 1)))
    (if (<= count maxEntries)
      t
      (do
        (local entries [])
        (each [k v (pairs t)]
          (table.insert entries {:k k :v v}))
        (table.sort entries (fn [a b] (> a.v b.v)))
        (local out {})
        (for [i 1 (math.min maxEntries (# entries))]
          (tset out (. (. entries i) :k) (. (. entries i) :v)))
        out))))

(set state.recency (_loadRecency))

(fn _trim [s]
  (var out (or s ""))
  (set out (: out :gsub "^%s+" ""))
  (set out (: out :gsub "%s+$" ""))
  out)

(fn _clampCursor []
  (let [q (or state.query "")
        len (# q)]
    (when (~= (type state.cursor) "number")
      (set state.cursor len))
    (when (< state.cursor 0)
      (set state.cursor 0))
    (when (> state.cursor len)
      (set state.cursor len))))

(fn _setQuery [q cursor]
  (set state.query (or q ""))
  (set state.cursor (if (= (type cursor) "number") cursor (# state.query)))
  (_clampCursor))

(fn _insertText [text]
  (when (and text (~= text ""))
    (_clampCursor)
    (let [q (or state.query "")
          c (or state.cursor (# q))
          left (: q :sub 1 c)
          right (: q :sub (+ c 1))]
      (set state.query (.. left text right))
      (set state.cursor (+ c (# text))))))

(fn _deleteBackward []
  (_clampCursor)
  (let [q (or state.query "")
        c (or state.cursor (# q))]
    (when (> c 0)
      (let [left (: q :sub 1 (- c 1))
            right (: q :sub (+ c 1))]
        (set state.query (.. left right))
        (set state.cursor (- c 1))))))

(fn _deleteForward []
  (_clampCursor)
  (let [q (or state.query "")
        c (or state.cursor (# q))]
    (when (< c (# q))
      (let [left (: q :sub 1 c)
            right (: q :sub (+ c 2))]
        (set state.query (.. left right))))))

(fn _isWordChar [ch]
  (and ch (~= nil (: ch :match "[%w_]"))))

(fn _moveWordBackward []
  (_clampCursor)
  (let [q (or state.query "")
        c (or state.cursor (# q))]
    (var i c)
    (while (and (> i 0) (not (_isWordChar (: q :sub i i))))
      (set i (- i 1)))
    (while (and (> i 0) (_isWordChar (: q :sub i i)))
      (set i (- i 1)))
    (set state.cursor i)))

(fn _moveWordForward []
  (_clampCursor)
  (let [q (or state.query "")
        c (or state.cursor (# q))
        len (# q)]
    (var i (+ c 1))
    (while (and (<= i len) (not (_isWordChar (: q :sub i i))))
      (set i (+ i 1)))
    (while (and (<= i len) (_isWordChar (: q :sub i i)))
      (set i (+ i 1)))
    (set state.cursor (- i 1))))

(fn _killToStart []
  (_clampCursor)
  (let [q (or state.query "")
        c (or state.cursor (# q))]
    (when (> c 0)
      (set state.killBuffer (: q :sub 1 c))
      (set state.query (: q :sub (+ c 1)))
      (set state.cursor 0))))

(fn _killToEnd []
  (_clampCursor)
  (let [q (or state.query "")
        c (or state.cursor (# q))]
    (when (< c (# q))
      (set state.killBuffer (: q :sub (+ c 1)))
      (set state.query (: q :sub 1 c))
      (set state.cursor (# state.query)))))

(fn _backwardKillWord []
  (_clampCursor)
  (let [q (or state.query "")
        c (or state.cursor (# q))]
    (when (> c 0)
      (var i c)
      (while (and (> i 0) (not (_isWordChar (: q :sub i i))))
        (set i (- i 1)))
      (while (and (> i 0) (_isWordChar (: q :sub i i)))
        (set i (- i 1)))

      (let [start (+ i 1)
            killed (: q :sub start c)]
        (when (~= killed "")
          (set state.killBuffer killed))
        (set state.query (.. (: q :sub 1 (- start 1)) (: q :sub (+ c 1))))
        (set state.cursor (- start 1))))))

(fn _killWordForward []
  (_clampCursor)
  (let [q (or state.query "")
        c (or state.cursor (# q))
        len (# q)]
    (when (< c len)
      (var i (+ c 1))
      (while (and (<= i len) (not (_isWordChar (: q :sub i i))))
        (set i (+ i 1)))
      (while (and (<= i len) (_isWordChar (: q :sub i i)))
        (set i (+ i 1)))

      (let [start (+ c 1)
            finish (- i 1)]
        (when (>= finish start)
          (let [killed (: q :sub start finish)]
            (when (~= killed "")
              (set state.killBuffer killed))
            (set state.query (.. (: q :sub 1 c) (: q :sub (+ finish 1))))
            (set state.cursor c)))))))

(fn _yank []
  (when (and state.killBuffer (~= state.killBuffer ""))
    (_insertText state.killBuffer)))

(fn _escapeHtml [s]
  (var s (or s ""))
  (set s (: s :gsub "&" "&amp;"))
  (set s (: s :gsub "<" "&lt;"))
  (set s (: s :gsub ">" "&gt;"))
  (set s (: s :gsub "\"" "&quot;"))
  s)

(fn _sh [cmd]
  (let [full (string.format "/bin/zsh -lc %q" cmd)]
    (local (out ok) (hs.execute full))
    (if (not ok)
      (do
        (log.df "command failed: %s" cmd)
        "")
      (or out ""))))

(fn _shAsync [cmd cb]
  (let [t (hs.task.new "/bin/zsh"
                       (fn [exitCode stdOut stdErr]
                         (let [ok (= exitCode 0)]
                           (when (not ok)
                             (log.df "command failed (%d): %s" exitCode cmd))
                           (when cb
                             (cb ok (or stdOut "") (or stdErr "")))))
                       ["-lc" cmd])]
    (if (not t)
      (do
        (when cb
          (cb false "" "hs.task.new failed"))
        nil)
      (do
        (: t :start)
        t))))

(fn _lines [s]
  (local t [])
  (each [line (: (or s "") :gmatch "[^\r\n]+")]
    (let [line (_trim line)]
      (when (~= line "")
        (table.insert t line))))
  t)

(fn _itemKey [item]
  (if (not item)
    ""
    (or item.key item.value item.primary "")))

(fn _fuzzyScore [text query]
  (if (= query "")
    0
    (do
      (var text (: (or text "") :lower))
      (var query (: (or query "") :lower))

      (var score 0)
      (var ti 1)
      (var last 0)
      (var streak 0)
      (var qi 1)
      (var ok true)

      (while (and ok (<= qi (# query)))
        (let [qc (: query :sub qi qi)
              found (: text :find qc ti true)]
          (if (not found)
            (set ok false)
            (do
              (if (= found (+ last 1))
                (do
                  (set streak (+ streak 1))
                  (set score (+ score 20 (* streak 6))))
                (do
                  (set streak 0)
                  (set score (+ score 10))))

              (if (= found 1)
                (set score (+ score 25))
                (let [prev (: text :sub (- found 1) (- found 1))]
                  (when (: prev :match "[%s/_%-%.]")
                    (set score (+ score 18)))))

              (set score (+ score (math.max 0 (- 30 found))))
              (set last found)
              (set ti (+ found 1)))))
        (set qi (+ qi 1)))

      (if ok score nil))))

(fn _recencyBonus [key]
  (let [ts (. state.recency key)]
    (if (or (~= (type ts) "number") (<= ts 0))
      0
      (let [age (- (os.time) ts)]
        (if (< age 3600) 120
          (< age 86400) 80
          (< age (* 7 86400)) 45
          (< age (* 30 86400)) 25
          0)))))

(var _scoreForQuery nil)
(var _cmpScored nil)

(fn _filter [items query]
  (local scored [])

  (each [_ item (ipairs (or items []))]
    (local (score tie) (_scoreForQuery item query))
    (when (not= score nil)
      (table.insert scored {:item item
                            :score score
                            :tie (or tie 0)
                            :primary (or item.primary "")
                            :sortScore item.sortScore
                            :activityTs item.activityTs})))

  (table.sort scored _cmpScored)

  (local out [])
  (local maxKeep (_cfg "maxMatches"))
  (for [i 1 (math.min (# scored) maxKeep)]
    (tset out i (. (. scored i) :item)))
  out)

(fn _frontmostFontCss []
  (let [app (hs.application.frontmostApplication)
        bid (if app (or (: app :bundleID) "") "")]
    ;; Try to look "native" in most apps; use monospace for terminal-ish apps.
    (var fontFamily "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif")
    (var fontSize 13)

    (when (or (= bid "com.apple.Terminal")
              (= bid "com.googlecode.iterm2")
              (= bid "com.github.wez.wezterm")
              (= bid "net.kovidgoyal.kitty")
              (= bid "com.mitchellh.ghostty"))
      (set fontFamily "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace")
      (set fontSize 12))

    (string.format "font-family:%s;font-size:%dpx;" fontFamily fontSize)))

(fn _caretRect []
  (var result nil)
  (let [sys (hs.axuielement.systemWideElement)]
    (if (not sys)
      (log.d "AX: missing systemWideElement")
      (let [focused (: sys :attributeValue "AXFocusedUIElement")]
        (if (not focused)
          (log.d "AX: missing focused element")
          (do
            (local (okRange range) (pcall (fn [] (: focused :attributeValue "AXSelectedTextRange"))))
            (when (and okRange range)
              (local (okBounds bounds)
                (pcall (fn [] (: focused :parameterizedAttributeValue "AXBoundsForRange" range))))
              (when (and okBounds bounds bounds.x bounds.y bounds.h)
                (when (< bounds.h 8) (set bounds.h 16))
                (when (< bounds.w 1) (set bounds.w 1))
                (log.df "AX caret: x=%.1f y=%.1f w=%.1f h=%.1f" bounds.x bounds.y bounds.w bounds.h)
                (set result bounds)))

            ;; Fallback: focused element frame (less precise, but better than nothing)
            (when (not result)
              (local (okFrame frame) (pcall (fn [] (: focused :attributeValue "AXFrame"))))
              (when (and okFrame frame frame.x frame.y frame.w frame.h)
                (log.df "AX frame fallback: x=%.1f y=%.1f w=%.1f h=%.1f" frame.x frame.y frame.w frame.h)
                (set result frame))))))))
  result)

(fn _screenForPoint [pt]
  (local main (hs.screen.mainScreen))
  (if (not pt)
    main
    (do
      (var chosen nil)
      (each [_ screen (ipairs (hs.screen.allScreens))]
        (when (not chosen)
          (let [f (: screen :frame)]
            (when (and (>= pt.x f.x)
                       (<= pt.x (+ f.x f.w))
                       (>= pt.y f.y)
                       (<= pt.y (+ f.y f.h)))
              (set chosen screen)))))
      (or chosen main))))

(fn _computeFrame []
  (local caret (_caretRect))
  (var anchorPt nil)
  (var anchorBelowY nil)
  (var anchorHow "")

  (if caret
    (do
      ;; Prefer “below caret”; if caret is actually a large element frame, we still anchor near its bottom-left.
      (set anchorPt {:x caret.x :y caret.y})
      (set anchorBelowY (+ caret.y caret.h))
      (set anchorHow "caret"))
    (do
      (local win (hs.window.focusedWindow))
      (local wf (and win (: win :frame)))
      (if wf
        (do
          (set anchorPt {:x wf.x :y wf.y})
          (set anchorBelowY (+ wf.y 30))
          (set anchorHow "focused_window"))
        (let [mp (hs.mouse.absolutePosition)]
          (set anchorPt {:x mp.x :y mp.y})
          (set anchorBelowY mp.y)
          (set anchorHow "mouse")))))

  (local screen (_screenForPoint anchorPt))
  (local sf (: screen :frame))

  (local w (_cfg "width"))
  (local h (_cfg "height"))
  (var x anchorPt.x)
  (var y (+ anchorBelowY (_cfg "offset")))

  (local margin (_cfg "margin"))
  (when (> (+ x w margin) (+ sf.x sf.w))
    (set x (- (+ sf.x sf.w) w margin)))
  (when (< x (+ sf.x margin))
    (set x (+ sf.x margin)))

  (when (> (+ y h margin) (+ sf.y sf.h))
    (set y (- anchorPt.y h (_cfg "offset"))))
  (when (> (+ y h margin) (+ sf.y sf.h))
    (set y (- (+ sf.y sf.h) h margin)))
  (when (< y (+ sf.y margin))
    (set y (+ sf.y margin)))

  (log.df "frame: how=%s x=%.1f y=%.1f w=%.1f h=%.1f screen=(%.1f %.1f %.1f %.1f)"
          anchorHow x y w h sf.x sf.y sf.w sf.h)
  {:x x :y y :w w :h h})

(fn _markedCount []
  (var c 0)
  (each [_ _ (pairs (or state.marked {}))]
    (set c (+ c 1)))
  c)

(fn _hasMarks []
  (not= nil (next (or state.marked {}))))

(fn _markedItemsInOrder []
  (local out [])
  (each [_ item (ipairs state.items)]
    (when (. state.marked (_itemKey item))
      (table.insert out item)))
  out)

(fn _baseHtml []
  (local fontCss (_frontmostFontCss))
  (local buf [])

  (table.insert buf "<!doctype html><html><head><meta charset=\"utf-8\" />")
  (table.insert buf "<style>")
  (table.insert buf "html,body{margin:0;padding:0;width:100%;height:100%;background:rgba(28,28,30,0.96);overflow:hidden;}")
  (table.insert buf (string.format "body{%s -webkit-font-smoothing:antialiased;}" fontCss))
  (table.insert buf ".wrap{width:100%;height:100%;box-sizing:border-box;padding:10px;overflow:hidden;}")
  (table.insert buf ".panel{width:100%;height:100%;box-sizing:border-box;display:flex;flex-direction:column;")
  (table.insert buf "background:rgba(28,28,30,0.96);border:1px solid rgba(255,255,255,0.12);")
  (table.insert buf "border-radius:12px;box-shadow:0 14px 50px rgba(0,0,0,0.45);overflow:hidden;}")

  (table.insert buf ".prompt{flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;gap:12px;")
  (table.insert buf "padding:10px 12px;border-bottom:1px solid rgba(255,255,255,0.10);}")
  (table.insert buf ".promptLeft{flex:1 1 auto;min-width:0;display:flex;align-items:center;gap:0;overflow:hidden;}")
  (table.insert buf ".promptText{min-width:0;color:rgba(255,255,255,0.92);font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}")
  (table.insert buf ".placeholder{color:rgba(255,255,255,0.55);}")
  (table.insert buf ".cursor{display:inline-block;width:7px;height:1.05em;margin-left:3px;border-radius:1px;")
  (table.insert buf "background:rgba(255,255,255,0.65);animation:blink 1.1s steps(1) infinite;}")
  (table.insert buf "@keyframes blink{0%,49%{opacity:1}50%,100%{opacity:0}}")
  (table.insert buf ".meta{flex:0 0 auto;display:flex;gap:8px;align-items:center;white-space:nowrap;}")
  (table.insert buf ".badge{color:rgba(255,255,255,0.70);font-size:0.90em;font-weight:600;")
  (table.insert buf "padding:2px 7px;border-radius:999px;border:1px solid rgba(255,255,255,0.14);")
  (table.insert buf "background:rgba(255,255,255,0.05);}")

  (table.insert buf ".list{flex:1 1 auto;overflow:hidden;padding:6px 0;}")
  (table.insert buf ".item{padding:7px 12px;display:flex;align-items:center;gap:4px;")
  (table.insert buf "white-space:nowrap;overflow:hidden;text-overflow:ellipsis;transition:background-color 80ms ease-out;}")
  (table.insert buf ".prefix{width:14px;flex:0 0 auto;text-align:right;color:rgba(255,255,255,0.55);")
  (table.insert buf "font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,'Liberation Mono',monospace;}")
  (table.insert buf (string.format ".p{flex:0 0 %dpx;color:rgba(255,255,255,0.92);font-weight:600;overflow:hidden;text-overflow:ellipsis;}" (_cfg "primaryWidth")))
  (table.insert buf ".s{color:rgba(255,255,255,0.60);overflow:hidden;text-overflow:ellipsis;}")
  (table.insert buf ".item.sel{background:rgba(120,120,255,0.22);}")
  (table.insert buf ".item.marked .prefix{color:rgba(180,220,255,0.90);}")
  (table.insert buf ".hint{flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;gap:12px;")
  (table.insert buf "padding:8px 12px;border-top:1px solid rgba(255,255,255,0.10);")
  (table.insert buf "color:rgba(255,255,255,0.55);font-size:0.90em;}")
  (table.insert buf ".hintLeft{min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}")
  (table.insert buf ".hintRight{flex:0 0 auto;white-space:nowrap;}")
  (table.insert buf "</style></head><body><div class=\"wrap\"><div class=\"panel\">")

  (table.insert buf "<div class=\"prompt\">")
  (table.insert buf "<div class=\"promptLeft\"><div id=\"promptTextLeft\" class=\"promptText placeholder\"></div><div id=\"cursor\" class=\"cursor\"></div><div id=\"promptTextRight\" class=\"promptText\"></div></div>")
  (table.insert buf "<div id=\"meta\" class=\"meta\"></div>")
  (table.insert buf "</div>")
  (table.insert buf "<div id=\"list\" class=\"list\"></div>")
  (table.insert buf "<div class=\"hint\"><div id=\"hintLeft\" class=\"hintLeft\"></div><div id=\"hintRight\" class=\"hintRight\"></div></div>")
  (table.insert buf "</div></div>")

  (table.insert buf "<script>")
  (table.insert buf "(function(){")
  (table.insert buf (string.format "  var MAX_ROWS = %d;" (_cfg "maxResults")))
  (table.insert buf "  var ready = false;")
  (table.insert buf "  var lastState = window.__repoOverlayState || null;")
  (table.insert buf "  var rows = [];")
  (table.insert buf "  var metaCount = null;")
  (table.insert buf "  var metaSelected = null;")
  (table.insert buf "  function ensureRows(){")
  (table.insert buf "    if(rows.length) return;")
  (table.insert buf "    var list = document.getElementById('list');")
  (table.insert buf "    for(var i=0;i<MAX_ROWS;i++){")
  (table.insert buf "      var row = document.createElement('div'); row.className='item';")
  (table.insert buf "      var prefix = document.createElement('div'); prefix.className='prefix';")
  (table.insert buf "      var p = document.createElement('div'); p.className='p';")
  (table.insert buf "      var s = document.createElement('div'); s.className='s';")
  (table.insert buf "      row.appendChild(prefix); row.appendChild(p); row.appendChild(s);")
  (table.insert buf "      list.appendChild(row);")
  (table.insert buf "      rows.push({row:row,prefix:prefix,p:p,s:s});")
  (table.insert buf "    }")
  (table.insert buf "  }")
  (table.insert buf "  function badge(text){")
  (table.insert buf "    var span=document.createElement('span'); span.className='badge'; span.textContent=text; return span;")
  (table.insert buf "  }")
  (table.insert buf "  function ensureMeta(){")
  (table.insert buf "    if(metaCount) return;")
  (table.insert buf "    var meta = document.getElementById('meta');")
  (table.insert buf "    metaCount = badge('0'); meta.appendChild(metaCount);")
  (table.insert buf "    metaSelected = badge(''); metaSelected.style.display='none'; meta.appendChild(metaSelected);")
  (table.insert buf "  }")
  (table.insert buf "  function render(state){")
  (table.insert buf "    lastState = state;")
  (table.insert buf "    if(!ready) return;")
  (table.insert buf "    ensureRows();")
  (table.insert buf "    ensureMeta();")
  (table.insert buf "    var promptLeft = document.getElementById('promptTextLeft');")
  (table.insert buf "    var promptRight = document.getElementById('promptTextRight');")
  (table.insert buf "    if(state.query && state.query.length>0){")
  (table.insert buf "      promptLeft.textContent = state.queryLeft || state.query;")
  (table.insert buf "      promptRight.textContent = state.queryRight || '';")
  (table.insert buf "      promptLeft.classList.remove('placeholder');")
  (table.insert buf "    } else {")
  (table.insert buf "      promptLeft.textContent = state.placeholder || '';")
  (table.insert buf "      promptRight.textContent = '';")
  (table.insert buf "      promptLeft.classList.add('placeholder');")
  (table.insert buf "    }")
  (table.insert buf "    metaCount.textContent = String(state.total || 0);")
  (table.insert buf "    if(state.allowMulti && state.markedCount && state.markedCount>0){ metaSelected.textContent = String(state.markedCount)+' selected'; metaSelected.style.display=''; }")
  (table.insert buf "    else { metaSelected.style.display='none'; }")
  (table.insert buf "    var items = state.items || [];")
  (table.insert buf "    if((state.total||0)===0){")
  (table.insert buf "      rows[0].row.style.display='flex'; rows[0].row.className='item sel'; rows[0].prefix.textContent='   '; rows[0].p.textContent=(state.emptyText||'No matches'); rows[0].s.textContent='';")
  (table.insert buf "      for(var j=1;j<rows.length;j++){ rows[j].row.style.display='none'; }")
  (table.insert buf "    } else {")
  (table.insert buf "      for(var i=0;i<rows.length;i++){")
  (table.insert buf "        var it = items[i];")
  (table.insert buf "        if(!it){ rows[i].row.style.display='none'; continue; }")
  (table.insert buf "        rows[i].row.style.display='flex';")
  (table.insert buf "        rows[i].row.className = 'item' + (it.selected ? ' sel' : '') + (it.marked ? ' marked' : '');")
  (table.insert buf "        rows[i].prefix.textContent = it.prefix || '   ';")
  (table.insert buf "        rows[i].p.textContent = it.primary || '';")
  (table.insert buf "        rows[i].s.textContent = it.secondary || '';")
  (table.insert buf "      }")
  (table.insert buf "    }")
  (table.insert buf "    document.getElementById('hintLeft').textContent = state.hintLeft || '';")
  (table.insert buf "    document.getElementById('hintRight').textContent = state.hintRight || '';")
  (table.insert buf "  }")
  (table.insert buf "  window.repoOverlayRender = render;")
  (table.insert buf "  document.addEventListener('DOMContentLoaded', function(){")
  (table.insert buf "    ready = true;")
  (table.insert buf "    if(window.__repoOverlayState){ render(window.__repoOverlayState); }")
  (table.insert buf "    else if(lastState){ render(lastState); }")
  (table.insert buf "  });")
  (table.insert buf "})();")
  (table.insert buf "</script></body></html>")

  (table.concat buf "\n"))

(fn _viewModel []
  (local spec state.spec)
  (_clampCursor)
  (local query (or state.query ""))
  (local cursor (or state.cursor (# query)))

  (local total (# state.filtered))
  (local maxVisible (_cfg "maxResults"))

  (var emptyText (if (and state.emptyText (~= state.emptyText "")) state.emptyText "No matches"))
  (if state.loading
    (set emptyText (if (and state.loadingText (~= state.loadingText "")) state.loadingText "Loading…"))
    (when (and state.searching (= total 0))
      (set emptyText "Searching…")))

  (var startIndex 0)
  (var endIndex 0)
  (when (> total 0)
    (set startIndex (+ state.viewOffset 1))
    (set endIndex (math.min total (+ state.viewOffset maxVisible))))

  (local items [])
  (when (> total 0)
    (for [idx startIndex endIndex]
      (local item (. state.filtered idx))
      (local key (_itemKey item))
      (local selected (= idx state.selectedIndex))
      (local marked (if (and state.allowMulti (. state.marked key)) true false))
      (table.insert items {:prefix (.. (if selected ">" " ") (if marked "*" " "))
                           :primary (or item.primary "")
                           :secondary (or item.secondary "")
                           :selected selected
                           :marked marked})))

  (var hintLeft "↵ paste • esc cancel • ↑↓ move • ⌫ delete")
  (when state.allowMulti
    (set hintLeft (.. "tab mark • " hintLeft)))
  (when (and spec (= (type spec.hintLeft) "string"))
    (set hintLeft spec.hintLeft))

  (var hintRight nil)
  (if (= total 0)
    (set hintRight "0")
    (if (<= total maxVisible)
      (set hintRight (tostring total))
      (set hintRight (string.format "%d-%d/%d" startIndex endIndex total))))
  (when (and spec (= (type spec.hintRight) "string"))
    (set hintRight spec.hintRight))

  {:query query
   :queryLeft (: query :sub 1 cursor)
   :queryRight (: query :sub (+ cursor 1))
   :placeholder (or state.prompt "search>")
   :emptyText emptyText
   :total total
   :allowMulti (if state.allowMulti true false)
   :markedCount (_markedCount)
   :items items
   :hintLeft hintLeft
   :hintRight hintRight})

(fn _render []
  (when state.webview
    (let [payload (json.encode (_viewModel))
          js (.. "window.__repoOverlayState=" payload "; if(window.repoOverlayRender){ window.repoOverlayRender(window.__repoOverlayState); }")]
      (: state.webview :evaluateJavaScript js))))

(fn _clampView []
  (local total (# state.filtered))

  (if (= total 0)
    (do
      (set state.selectedIndex 1)
      (set state.viewOffset 0))
    (do
      (when (< state.selectedIndex 1)
        (set state.selectedIndex 1))
      (when (> state.selectedIndex total)
        (set state.selectedIndex total))

      (let [maxVisible (_cfg "maxResults")
            maxOffset (math.max 0 (- total maxVisible))]
        (when (< state.viewOffset 0)
          (set state.viewOffset 0))
        (when (> state.viewOffset maxOffset)
          (set state.viewOffset maxOffset))

        (when (<= state.selectedIndex state.viewOffset)
          (set state.viewOffset (- state.selectedIndex 1)))
        (when (> state.selectedIndex (+ state.viewOffset maxVisible))
          (set state.viewOffset (- state.selectedIndex maxVisible)))

        (when (< state.viewOffset 0)
          (set state.viewOffset 0))
        (when (> state.viewOffset maxOffset)
          (set state.viewOffset maxOffset)))))

  (when (< state.viewOffset 0)
    (set state.viewOffset 0)))

(fn _refresh []
  (_clampView)
  (when state.webview
    (_render)))

(fn _update []
  (set state.filtered (_filter state.items state.query))
  (_refresh))

(fn _stopSearch []
  (when state.searchTimer
    (pcall (fn [] (: state.searchTimer :stop)))
    (set state.searchTimer nil))
  (set state.searching false))

(fn _defaultScoreForQuery [item query]
  (local key (_itemKey item))

  (if (= query "")
    (let [base (if (= (type item.sortScore) "number")
                 item.sortScore
                 (if (= (type item.activityTs) "number")
                   item.activityTs
                   0))
          tie (if (= (type (. state.recency key)) "number") (. state.recency key) 0)]
      (values base tie))
    (let [hay (if (= item.kind "file")
                (or item.primary "")
                (.. (or item.primary "") " " (or item.secondary "")))
          s (_fuzzyScore hay query)]
      (if (not s)
        nil
        (values (+ s (_recencyBonus key)) 0)))))

(set _scoreForQuery
  (fn [item query]
    (let [spec state.spec]
      (if (and spec (= (type spec.score) "function"))
        (do
          (local (ok s tie) (pcall spec.score item query))
          (if ok
            (if (= s nil)
              nil
              (values s (or tie 0)))
            (do
              (log.df "score: error: %s" (tostring s))
              (_defaultScoreForQuery item query))))
        (_defaultScoreForQuery item query)))))

(set _cmpScored
  (fn [a b]
    (if (not= a.score b.score)
      (> a.score b.score)
      (let [as (if (= (type a.sortScore) "number") a.sortScore 0)
            bs (if (= (type b.sortScore) "number") b.sortScore 0)]
        (if (not= as bs)
          (> as bs)
          (let [at (if (= (type a.activityTs) "number") a.activityTs 0)
                bt (if (= (type b.activityTs) "number") b.activityTs 0)]
            (if (not= at bt)
              (> at bt)
              (let [ta (if (= (type a.tie) "number") a.tie 0)
                    tb (if (= (type b.tie) "number") b.tie 0)]
                (if (not= ta tb)
                  (> ta tb)
                  (< (or a.primary "") (or b.primary "")))))))))))

(fn _cmpWorse [a b]
  (_cmpScored b a))

(fn _heapPush [heap node]
  (table.insert heap node)
  (var i (# heap))
  (while (> i 1)
    (let [p (math.floor (/ i 2))]
      (if (not (_cmpWorse (. heap i) (. heap p)))
        (set i 1) ;; exit loop
        (do
          (let [tmp (. heap i)]
            (tset heap i (. heap p))
            (tset heap p tmp))
          (set i p))))))

(fn _heapDown [heap i]
  (local n (# heap))
  (var i i)
  (var done false)
  (while (not done)
    (let [l (* i 2)
          r (+ l 1)]
      (var m i)
      (when (and (<= l n) (_cmpWorse (. heap l) (. heap m)))
        (set m l))
      (when (and (<= r n) (_cmpWorse (. heap r) (. heap m)))
        (set m r))
      (if (= m i)
        (set done true)
        (do
          (let [tmp (. heap i)]
            (tset heap i (. heap m))
            (tset heap m tmp))
          (set i m))))))

(fn _heapReplaceRoot [heap node]
  (tset heap 1 node)
  (_heapDown heap 1))

(fn _heapSortedItems [heap]
  (local scored [])
  (for [i 1 (# heap)]
    (tset scored i (. heap i)))
  (table.sort scored _cmpScored)
  (local out [])
  (for [i 1 (# scored)]
    (tset out i (. (. scored i) :item)))
  out)

(fn _searchAsync []
  (_stopSearch)

  (local query (or state.query ""))
  (local items (or state.items []))

  ;; Only do async filtering when enabled and the candidate set is large.
  (local enableAsync (if (_cfg "enableAsyncFilter") true false))
  (local threshold (or (_cfg "asyncFilterThreshold") 8000))
  (local isBig (and enableAsync (> (# items) threshold)))
  (if (not isBig)
    (do
      (set state.searching false)
      (_update))
    (do
      (set state.searching true)
      (local maxKeep (_cfg "maxMatches"))
      (set state.searchGen (+ state.searchGen 1))
      (local gen state.searchGen)

      (var idx 1)
      (local heap [])
      (var lastUi (hs.timer.secondsSinceEpoch))

      (set state.searchTimer
           (hs.timer.new 0.01
                         (fn []
                           (if (or (not state.active) (not= state.searchGen gen))
                             (_stopSearch)
                             (do
                               (local chunk 500)
                               (local limit (math.min (# items) (+ idx chunk -1)))

                               (while (<= idx limit)
                                 (local item (. items idx))
                                 (set idx (+ idx 1))
                                 (local (score tie) (_scoreForQuery item query))
                                 (when score
                                   (local node {:item item
                                                :score score
                                                :tie tie
                                                :sortScore item.sortScore
                                                :activityTs item.activityTs
                                                :primary item.primary})

                                   (if (< (# heap) maxKeep)
                                     (_heapPush heap node)
                                     (when (_cmpScored node (. heap 1))
                                       (_heapReplaceRoot heap node)))))

                               (let [now (hs.timer.secondsSinceEpoch)]
                                 (when (> (- now lastUi) 0.12)
                                   (set lastUi now)
                                   (set state.filtered (_heapSortedItems heap))
                                   (_refresh)))

                               (when (> idx (# items))
                                 (: state.searchTimer :stop)
                                 (set state.searchTimer nil)
                                 (set state.searching false)
                                 (local out (_heapSortedItems heap))
                                 (set state.filtered out)
                                 (log.df "search: done items=%d kept=%d query_len=%d" (# items) (# out) (# query))
                                 (_refresh))))))))

      (: state.searchTimer :start)))

(fn _scheduleUpdate []
  (set state.filterGen (+ state.filterGen 1))
  (local gen state.filterGen)

  (when state.filterTimer
    (: state.filterTimer :stop)
    (set state.filterTimer nil))

  (set state.filterTimer
       (hs.timer.doAfter 0.02
                         (fn []
                           (when (and state.active (= state.filterGen gen))
                             (set state.filterTimer nil)
                             (_searchAsync))))))

(fn _paste [text]
  (when (and text (~= text ""))
    (local prev (hs.pasteboard.getContents))
    (hs.pasteboard.setContents text)

    (hs.timer.doAfter 0.03
                      (fn []
                        (hs.eventtap.keyStroke ["cmd"] "v" 0)
                        (hs.timer.doAfter 0.15
                                          (fn []
                                            (when (and prev (~= prev ""))
                                              (hs.pasteboard.setContents prev))))))))

(fn _close []
  (when state.active
    (log.i "close overlay"))

  (when state.sourceCancel
    (pcall state.sourceCancel)
    (set state.sourceCancel nil))

  (when state.loadTask
    (pcall (fn [] (: state.loadTask :terminate)))
    (set state.loadTask nil))
  (when state.activityTimer
    (pcall (fn [] (: state.activityTimer :stop)))
    (set state.activityTimer nil))
  (when state.filterTimer
    (pcall (fn [] (: state.filterTimer :stop)))
    (set state.filterTimer nil))
  (_stopSearch)

  (set state.active false)
  (set state.mode nil)
  (set state.spec nil)
  (set state.prompt "")
  (set state.query "")
  (set state.cursor 0)
  (set state.killBuffer "")
  (set state.loading false)
  (set state.loadingText "")
  (set state.emptyText "")
  (set state.items [])
  (set state.filtered [])
  (set state.selectedIndex 1)
  (set state.viewOffset 0)
  (set state.marked {})
  (set state.allowMulti false)
  (set state.onAccept nil)

  (when state.tap
    (: state.tap :stop)
    (set state.tap nil))

  (when state.webview
    (: state.webview :delete)
    (set state.webview nil)))

(fn _cancel []
  (let [spec state.spec]
    (when (and spec (= (type spec.onCancel) "function"))
      (pcall spec.onCancel)))
  (_close))

(fn _accept []
  (var choices [])
  (if (and state.allowMulti (_hasMarks))
    (set choices (_markedItemsInOrder))
    (let [choice (. state.filtered state.selectedIndex)]
      (when choice
        (table.insert choices choice))))

  (if (= (# choices) 0)
    (do
      (log.d "accept: no selection")
      (_close))
    (do
      (log.df "accept: count=%d first=%s" (# choices) (tostring (. (. choices 1) :primary)))

      (local now (os.time))
      (var touched false)
      (each [_ c (ipairs choices)]
        (let [key (_itemKey c)]
          (when (~= key "")
            (tset state.recency key now)
            (set touched true))))
      (when touched
        (set state.recency (_trimRecency state.recency 500))
        (_saveRecency state.recency))

      (local cb state.onAccept)
      (local returnApp state.returnApp)
      (_close)

      (when returnApp
        (: returnApp :activate))
      (when cb
        (cb choices)))))

(fn _start [mode items prompt allowMulti onAccept opts]
  (local opts (or opts {}))

  (set state.active true)
  (set state.mode mode)
  (set state.query "")
  (set state.cursor 0)
  (set state.killBuffer "")
  (set state.items (or items []))
  (set state.filtered [])
  (set state.prompt (or prompt "search>"))
  (set state.loading (if opts.loading true false))
  (set state.loadingText (or opts.loadingText ""))
  (set state.emptyText (or opts.emptyText ""))
  (set state.allowMulti (if allowMulti true false))
  (set state.selectedIndex 1)
  (set state.viewOffset 0)
  (set state.marked {})
  (set state.returnApp (hs.application.frontmostApplication))
  (set state.onAccept onAccept)

  (log.f "open overlay: mode=%s prompt=%s items=%d multi=%s"
         (tostring state.mode)
         (tostring state.prompt)
         (# state.items)
         (tostring state.allowMulti))

  (let [frame (_computeFrame)
        w (hs.webview.new frame)]
    ;; Borderless, always-on-top, and visible across Spaces.
    (: w :windowStyle 0)
    (: w :level hs.drawing.windowLevels.popUpMenu)
    (: w :behaviorAsLabels ["canJoinAllSpaces" "fullScreenAuxiliary"])
    (: w :transparent true)

    (: w :html (_baseHtml))
    (: w :show)
    (set state.webview w))

  (local kc hs.keycodes.map)

  (fn _resetToTop []
    (set state.selectedIndex 1)
    (set state.viewOffset 0))

  (fn _moveSelection [delta]
    (when (> (# state.filtered) 0)
      (set state.selectedIndex
           (math.max 1 (math.min (# state.filtered) (+ state.selectedIndex delta))))
      (_refresh)))

  (fn _toggleMarkAt [index]
    (let [item (. state.filtered index)]
      (when item
        (let [key (_itemKey item)]
          (when (~= key "")
            (if (. state.marked key)
              (tset state.marked key nil)
              (tset state.marked key true)))))))

  (fn _handleKeyDown [ev]
    (if (not state.active)
      false
      (do
        (local code (: ev :getKeyCode))
        (local flags (: ev :getFlags))
        (local altNoCmdCtrl (and flags.alt (not flags.cmd) (not flags.ctrl)))
        (local ctrlNoCmdAlt (and flags.ctrl (not flags.cmd) (not flags.alt)))
        (local cmdNoCtrlAlt (and flags.cmd (not flags.ctrl) (not flags.alt)))
        (local plainNoMods (and (not flags.cmd) (not flags.ctrl) (not flags.alt)))

        (var handled false)
        (var result true)
        (fn handle [r]
          (when (not handled)
            (set handled true)
            (set result r)))

        ;; Let app-switching happen and close the overlay.
        (when (and (not handled) flags.cmd (= code kc.tab))
          (_cancel)
          (handle false))

        (when (and (not handled) (= code kc.escape))
          (_cancel)
          (handle true))

        (when (and (not handled) (or (= code (. kc "return")) (= code (. kc "padenter"))))
          (_accept)
          (handle true))

        (when (and (not handled) (= code kc.up))
          (_moveSelection -1)
          (handle true))

        (when (and (not handled) (= code kc.down))
          (_moveSelection 1)
          (handle true))

        (when (and (not handled) (= code kc.left))
          (if altNoCmdCtrl
            (_moveWordBackward)
            (set state.cursor (math.max 0 (- (or state.cursor 0) 1))))
          (_refresh)
          (handle true))

        (when (and (not handled) (= code kc.right))
          (if altNoCmdCtrl
            (_moveWordForward)
            (do
              (_clampCursor)
              (set state.cursor (math.min (# (or state.query "")) (+ (or state.cursor 0) 1)))))
          (_refresh)
          (handle true))

        (when (and (not handled) (= code (. kc "pageup")))
          (_moveSelection (- (_cfg "maxResults")))
          (handle true))

        (when (and (not handled) (= code (. kc "pagedown")))
          (_moveSelection (_cfg "maxResults"))
          (handle true))

        (when (and (not handled) (= code (. kc "home")))
          (set state.selectedIndex 1)
          (_refresh)
          (handle true))

        (when (and (not handled) (= code (. kc "end")))
          (set state.selectedIndex (# state.filtered))
          (_refresh)
          (handle true))

        (when (and (not handled) (= code kc.tab) plainNoMods)
          (when (and state.allowMulti (> (# state.filtered) 0))
            (_toggleMarkAt state.selectedIndex)
            (if flags.shift
              (_moveSelection -1)
              (_moveSelection 1)))
          (handle true))

        ;; Backspace / forward-delete.
        (when (and (not handled) (or (= code kc.delete) (= code kc.forwarddelete)))
          (if altNoCmdCtrl
            (if (= code kc.delete) (_backwardKillWord) (_killWordForward))
            (if (= code kc.delete) (_deleteBackward) (_deleteForward)))
          (_resetToTop)
          (_scheduleUpdate)
          (handle true))

        ;; Ctrl: readline-ish editing + fzf-ish list nav (Ctrl-N / Ctrl-P).
        (when (and (not handled) ctrlNoCmdAlt)
          (let [ch (: ev :getCharacters)]
            (case ch
              "a" (do (set state.cursor 0) (_refresh))
              "e" (do (set state.cursor (# (or state.query ""))) (_refresh))
              "b" (do (set state.cursor (math.max 0 (- (or state.cursor 0) 1))) (_refresh))
              "f" (do
                    (_clampCursor)
                    (set state.cursor (math.min (# (or state.query "")) (+ (or state.cursor 0) 1)))
                    (_refresh))
              "n" (_moveSelection 1)
              "p" (_moveSelection -1)
              "u" (do (_killToStart) (_resetToTop) (_scheduleUpdate))
              "k" (do (_killToEnd) (_resetToTop) (_scheduleUpdate))
              "w" (do (_backwardKillWord) (_resetToTop) (_scheduleUpdate))
              "y" (do (_yank) (_resetToTop) (_scheduleUpdate))
              "d" (do (_deleteForward) (_resetToTop) (_scheduleUpdate))
              _ nil))
          (handle true))

        ;; Cmd-V inserts clipboard into the query.
        (when (and (not handled) cmdNoCtrlAlt)
          (let [ch (: ev :getCharacters)]
            (when (= ch "v")
              (let [clip (or (hs.pasteboard.getContents) "")]
                (when (~= clip "")
                  (_insertText clip)
                  (_resetToTop)
                  (_scheduleUpdate)))))
          (handle true))

        ;; Accept basic printable characters; swallow everything else while active.
        (when (and (not handled) plainNoMods)
          (let [ch (: ev :getCharacters)]
            (when (and ch (~= ch "") (not= ch "\r") (not= ch "\n"))
              (_insertText ch)
              (_resetToTop)
              (_scheduleUpdate)))
          (handle true))

        result)))

  (set state.tap
       (hs.eventtap.new [hs.eventtap.event.types.keyDown] _handleKeyDown))

  (: state.tap :start)
  (_update))

(tset FuzzyOverlay :close (fn [] (_close)))

(tset FuzzyOverlay :open
      (fn [spec]
        (if (~= (type spec) "table")
          (log.w "FuzzyOverlay.open: spec must be a table")
          (let [id (or spec.id spec.mode spec.name)]
            (if (or (~= (type id) "string") (= id ""))
              (log.w "FuzzyOverlay.open: missing spec.id")
              (do
                (_close)
                (set state.spec spec)

                (set state.loadGen (+ state.loadGen 1))
                (local gen state.loadGen)

                (fn emit [patch]
                  (when (and state.active (= state.mode id) (= state.loadGen gen))
                    (local patch (or patch {}))
                    (when (not= patch.loading nil)
                      (set state.loading (if patch.loading true false)))
                    (when (not= patch.loadingText nil)
                      (set state.loadingText (or patch.loadingText "")))
                    (when (not= patch.emptyText nil)
                      (set state.emptyText (or patch.emptyText "")))
                    (when (not= patch.items nil)
                      (set state.items (or patch.items [])))
                    (_searchAsync)))

                (fn onAccept [choices]
                  (when (= (type spec.onAccept) "function")
                    (local (ok err) (pcall spec.onAccept choices))
                    (when (not ok)
                      (log.wf "onAccept: %s" (tostring err)))))

                (_start id
                        (or spec.items [])
                        (or spec.prompt "search>")
                        (if spec.allowMulti true false)
                        onAccept
                        {:loading true
                         :loadingText (or spec.loadingText "Loading…")
                         :emptyText (or spec.emptyText "")})

                (if (= (type spec.source) "function")
                  (do
                    (local (ok cancel) (pcall spec.source {:gen gen :id id} emit))
                    (if (and ok (= (type cancel) "function"))
                      (set state.sourceCancel cancel)
                      (when (not ok)
                        (log.wf "source: %s" (tostring cancel))
                        (emit {:loading false :items [] :emptyText "Failed to load (see logfile)"}))))
                  (emit {:loading false :items (or spec.items [])}))))))))

(fn _parseRepoIndexTsv [out]
  (local items [])
  (local rawLines (_lines out))
  (if (= (# rawLines) 0)
    (log.w "repo-index: no output (did you run dotfiles bootstrap?)")
    (log.df "repo-index: lines=%d" (# rawLines)))

  (each [_ line (ipairs rawLines)]
    (local (slug url path) (: line :match "([^\t]+)\t([^\t]+)\t(.+)"))
    (when (and slug url path)
      (table.insert items {:key slug
                           :kind "repo"
                           :primary slug
                           :secondary url
                           :value url
                           :repoPath path
                           :slug slug
                           :url url
                           :activityTs 0})))

  (when (and (= (# items) 0) (> (# rawLines) 0))
    (log.wf "repo-index: output was not parseable TSV (sample=%s)" (tostring (. rawLines 1))))

  (log.df "repo-index: parsed_items=%d" (# items))
  (table.sort items (fn [a b] (< (or a.primary "") (or b.primary ""))))
  items)

(fn _repoIndexItems []
  (local repoIndex (string.format "%q" (.. config.dotfilesBin "/repo-index")))
  (local out (_sh (.. repoIndex " --format tsv 2>/dev/null")))
  (_parseRepoIndexTsv out))

(fn _repoIndexItemsAsync [gen cb]
  (local repoIndex (string.format "%q" (.. config.dotfilesBin "/repo-index")))
  (set state.loadTask
       (_shAsync (.. repoIndex " --format tsv 2>/dev/null")
                 (fn [ok out err]
                   (when (= state.loadGen gen)
                     (set state.loadTask nil)
                     (when state.active
                       (if (not ok)
                         (do
                           (log.wf "repo-index: failed (%s)" (_trim (or err "")))
                           (when cb (cb [] false)))
                         (do
                           (local items (_parseRepoIndexTsv out))
                           (log.f "repo-index: loaded items=%d" (# items))
                           (when cb (cb items true))))))))))

(fn _mtime [path]
  (local attr (hs.fs.attributes path))
  (local ts (and attr attr.modification))
  (if (= (type ts) "number") ts 0))

(fn _maxMtimeUnder [root maxEntries maxDepth]
  (if (not= (hs.fs.attributes root "mode") "directory")
    (values 0 false)
    (do
      (local maxEntries (or maxEntries 4000))
      (local maxDepth (or maxDepth 4))

      (var maxTs 0)
      (var seen 0)
      (local stack [{:path root :depth maxDepth}])
      (var truncated false)

      (while (and (> (# stack) 0) (not truncated))
        (let [node (table.remove stack)]
          (each [entry (hs.fs.dir node.path)]
            (when (and (not truncated) (not= entry ".") (not= entry ".."))
              (let [full (.. node.path "/" entry)
                    attr (hs.fs.attributes full)]
                (when attr
                  (let [ts (or (tonumber attr.modification) 0)]
                    (when (> ts maxTs) (set maxTs ts)))

                  (set seen (+ seen 1))
                  (when (>= seen maxEntries)
                    (set truncated true))

                  (when (and (= attr.mode "directory") (> node.depth 0))
                    (table.insert stack {:path full :depth (- node.depth 1)}))))))))

      (values maxTs truncated))))

(fn _repoActivityTs [repoPath]
  (local gitdir (.. repoPath "/.git"))
  (if (not= (hs.fs.attributes gitdir "mode") "directory")
    0
    (do
      (var maxTs 0)
      (fn bump [p]
        (let [ts (_mtime p)]
          (when (> ts maxTs) (set maxTs ts))))

      (bump (.. gitdir "/logs/HEAD"))
      (bump (.. gitdir "/index"))
      (bump (.. gitdir "/FETCH_HEAD"))
      (bump (.. gitdir "/packed-refs"))
      (bump (.. gitdir "/HEAD"))
      (bump (.. gitdir "/ORIG_HEAD"))

      (local (refsTs refsTrunc) (_maxMtimeUnder (.. gitdir "/refs") 5000 5))
      (when (> refsTs maxTs) (set maxTs refsTs))
      (local (logsTs logsTrunc) (_maxMtimeUnder (.. gitdir "/logs/refs") 5000 5))
      (when (> logsTs maxTs) (set maxTs logsTs))

      (when (or refsTrunc logsTrunc)
        (log.df "activity: truncated scan for %s (refs=%s logs=%s)"
                repoPath
                (tostring refsTrunc)
                (tostring logsTrunc)))

      maxTs)))

(fn _startActivityScan [gen]
  (when state.activityTimer
    (: state.activityTimer :stop)
    (set state.activityTimer nil))

  (var idx 1)
  (set state.activityGen gen)

  (set state.activityTimer
       (hs.timer.new 0.01
                     (fn []
                       (if (or (not state.active) (not= state.activityGen gen))
                         (do
                           (when state.activityTimer
                             (: state.activityTimer :stop)
                             (set state.activityTimer nil)))
                         (let [item (. state.items idx)]
                           (set idx (+ idx 1))
                           (if (not item)
                             (do
                               (: state.activityTimer :stop)
                               (set state.activityTimer nil)
                               (log.df "activity: done")
                               (_update))
                             (when (and (= item.kind "repo") item.repoPath)
                               (set item.activityTs (_repoActivityTs item.repoPath)))))))))

  (: state.activityTimer :start))

(fn _repoFilesItems [repoPath]
  (local safeRepo (: repoPath :gsub "'" "'\\''"))
  (local statusOut (_sh (.. "/usr/bin/git -C '" safeRepo "' status --porcelain=v1 2>/dev/null")))
  (local statusMap {})
  (each [_ line (ipairs (_lines statusOut))]
    (local (xy path) (: line :match "^(..)%s+(.*)$"))
    (when (and xy path)
      (let [to (: path :match ".* %-> (.+)$")
            path2 (or to path)]
        (tset statusMap path2 xy))))

  (local out (_sh (.. "/usr/bin/git -C '" safeRepo "' ls-files -co --exclude-standard 2>/dev/null")))
  (local items [])
  (each [_ rel (ipairs (_lines out))]
    (local st (. statusMap rel))
    (local sortScore (if (= st "??") 2 (and st (~= st "  ")) 1 0))

    (var secondary repoPath)
    (when (and st (~= st "  "))
      (set secondary (.. st " · " repoPath)))

    (table.insert items {:key (.. repoPath "/" rel)
                         :kind "file"
                         :primary rel
                         :secondary secondary
                         :value (.. repoPath "/" rel)
                         :relPath rel
                         :repoPath repoPath
                         :sortScore sortScore
                         :activityTs 0}))
  items)

(fn _repoFilesItemsAsync [repoPath gen cb]
  (local safeRepo (: repoPath :gsub "'" "'\\''"))
  (local statusCmd (.. "/usr/bin/git -C '" safeRepo "' status --porcelain=v1 2>/dev/null"))

  (set state.loadTask
       (_shAsync statusCmd
                 (fn [okStatus statusOut statusErr]
                   (when (and (= state.loadGen gen) state.active)
                     (when (not okStatus)
                       (log.df "git status failed: %s" (_trim (or statusErr ""))))

                     (local statusMap {})
                     (each [_ line (ipairs (_lines statusOut))]
                       (local (xy path) (: line :match "^(..)%s+(.*)$"))
                       (when (and xy path)
                         (let [to (: path :match ".* %-> (.+)$")
                               path2 (or to path)]
                           (tset statusMap path2 xy))))

                     (local lsCmd (.. "/usr/bin/git -C '" safeRepo "' ls-files -co --exclude-standard 2>/dev/null"))
                     (set state.loadTask
                          (_shAsync lsCmd
                                    (fn [okLs out err]
                                      (when (= state.loadGen gen)
                                        (set state.loadTask nil)
                                        (when state.active
                                          (if (not okLs)
                                            (do
                                              (log.wf "git ls-files failed: %s" (_trim (or err "")))
                                              (when cb (cb [] false)))
                                            (do
                                              (local items [])
                                              (each [_ rel (ipairs (_lines out))]
                                                (local st (. statusMap rel))
                                                (local sortScore (if (= st "??") 2 (and st (~= st "  ")) 1 0))

                                                (var secondary repoPath)
                                                (when (and st (~= st "  "))
                                                  (set secondary (.. st " · " repoPath)))

                                                (table.insert items {:key (.. repoPath "/" rel)
                                                                     :kind "file"
                                                                     :primary rel
                                                                     :secondary secondary
                                                                     :value (.. repoPath "/" rel)
                                                                     :relPath rel
                                                                     :repoPath repoPath
                                                                     :sortScore sortScore
                                                                     :activityTs 0}))

                                              (log.df "repo-files: repo=%s items=%d" repoPath (# items))
                                              (when cb (cb items true))))))))))))))

;; Public commands -------------------------------------------------------

(var repoFileLastRepoPath nil)

(fn _pasteChoices [choices]
  (local out [])
  (each [_ c (ipairs (or choices []))]
    (when (and c c.value)
      (table.insert out c.value)))
  (_paste (table.concat out "\n")))

(fn pickRepoFiles [repoPath]
  (FuzzyOverlay.open {:id "repoFilePath"
                      :prompt "file>"
                      :allowMulti true
                      :loadingText "Loading files…"
                      :emptyText ""
                      :theme {:enableAsyncFilter true}
                      :onCancel (fn [] (set repoFileLastRepoPath nil))
                      :onAccept (fn [choices]
                                  (when (and choices (> (# choices) 0))
                                    (set repoFileLastRepoPath repoPath))
                                  (_pasteChoices choices))
                      :source (fn [ctx emit]
                                (_repoFilesItemsAsync repoPath ctx.gen
                                                     (fn [items ok]
                                                       (if (not ok)
                                                         (emit {:loading false :items [] :emptyText "Failed to load files (see logfile)"})
                                                         (let [items (or items [])]
                                                           (emit {:loading false
                                                                  :items items
                                                                  :emptyText (if (= (# items) 0) "No files found" "")}))))))}))

(fn pickRepoUrl []
  (FuzzyOverlay.open {:id "repoUrl"
                      :prompt "repo url>"
                      :allowMulti true
                      :loadingText "Loading repos…"
                      :emptyText ""
                      :onAccept (fn [choices] (_pasteChoices choices))
                      :source (fn [ctx emit]
                                (_repoIndexItemsAsync ctx.gen
                                                     (fn [items ok]
                                                       (if (not ok)
                                                         (emit {:loading false :items [] :emptyText "Failed to load repos (see logfile)"})
                                                         (let [items (or items [])]
                                                           (emit {:loading false
                                                                  :items items
                                                                  :emptyText (if (= (# items) 0) "No repos found" "")})
                                                           (_startActivityScan ctx.gen))))))}))

(fn pickRepoFile [forcePickRepo]
  (if (and (not forcePickRepo)
           repoFileLastRepoPath
           (= (hs.fs.attributes repoFileLastRepoPath "mode") "directory"))
    (pickRepoFiles repoFileLastRepoPath)
    (FuzzyOverlay.open {:id "repoFileRepo"
                        :prompt "repo>"
                        :allowMulti false
                        :loadingText "Loading repos…"
                        :emptyText ""
                        :onCancel (fn [] (set repoFileLastRepoPath nil))
                        :onAccept (fn [choices]
                                    (let [choice (and choices (. choices 1))]
                                      (when choice
                                        (pickRepoFiles choice.repoPath))))
                        :source (fn [ctx emit]
                                  (_repoIndexItemsAsync ctx.gen
                                                       (fn [items ok]
                                                         (if (not ok)
                                                           (emit {:loading false :items [] :emptyText "Failed to load repos (see logfile)"})
                                                           (let [items (or items [])]
                                                             (emit {:loading false
                                                                    :items items
                                                                    :emptyText (if (= (# items) 0) "No repos found" "")})
                                                             (_startActivityScan ctx.gen))))))})))

(hs.hotkey.bind config.hotkeyRepoUrl.mods config.hotkeyRepoUrl.key pickRepoUrl)
(hs.hotkey.bind config.hotkeyRepoFile.mods config.hotkeyRepoFile.key (fn [] (pickRepoFile false)))
(hs.hotkey.bind config.hotkeyRepoFilePickRepo.mods config.hotkeyRepoFilePickRepo.key (fn [] (pickRepoFile true)))

(hs.hotkey.bind config.hotkeyToggleDebug.mods config.hotkeyToggleDebug.key
               (fn []
                 (RepoOverlay.toggleDebug)
                 (let [lvl (_levelName (log.getLogLevel))]
                   (log.f "log level: %s" lvl)
                   (hs.alert.show (.. "FuzzyOverlay log: " lvl) 0.8))))

(hs.hotkey.bind config.hotkeyShowLog.mods config.hotkeyShowLog.key
               (fn []
                 (hs.pasteboard.setContents logFile)
                 (hs.alert.show "FuzzyOverlay log path copied" 0.8)))

;; Recompile + reload (Fennel -> Lua)
(local hyper ["ctrl" "alt" "cmd" "shift"])
(hs.hotkey.bind hyper "r"
               (fn []
                 (log.i "hyper-r: make hammerspoon")
                 (hs.alert.show "Hammerspoon: build…" 0.6)

                 (_shAsync "cd \"$HOME/dotfiles\" && make hammerspoon"
                           (fn [ok _ err]
                             (if ok
                               (do
                                 (hs.alert.show "Hammerspoon: reload…" 0.6)
                                 (hs.reload))
                               (let [msg "Hammerspoon build failed (see log)"]
                                 (hs.alert.show msg 2.0)
                                 (log.wf "%s: %s" msg (_trim (or err "")))))))))

(log.f "loaded (logfile: %s)" logFile)
(when (>= (log.getLogLevel) 4)
  (hs.alert.show "FuzzyOverlay loaded (debug)"))

nil
