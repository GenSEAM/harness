(module asl-harness/tests/browser-cdp-test
  :d "Unit tests for pure ASL Chrome DevTools Protocol client and navigator."
  :x [run-tests]
  :i [(browser_cdp :a cdp)])

(df test-make-cdp-connection [] -> Bool
  :d "Verifies creation of CDP connection instance."
  (let [(conn (cdp/make-cdp-connection "ws://127.0.0.1:9222/devtools/page/1" "sess-42"))]
    (assert (= (.-target-url conn) "ws://127.0.0.1:9222/devtools/page/1") "target url matches")
    (assert (= (.-session-id conn) "sess-42") "session id matches")
    (assert (.-is-connected conn) "is connected is true")
    true))

(df test-navigate [] -> Bool
  :d "Verifies JSON-RPC command formatting for Page.navigate."
  (let [(conn (cdp/make-cdp-connection "ws://127.0.0.1:9222" "s1"))
        (cmd (cdp/navigate conn "https://example.com"))]
    (assert (string-contains? cmd "Page.navigate") "cmd contains Page.navigate")
    (assert (string-contains? cmd "https://example.com") "cmd contains target URL")
    true))

(df test-extract-axtree [] -> Bool
  :d "Verifies Accessibility.getFullAXTree command serialization."
  (let [(conn (cdp/make-cdp-connection "ws://127.0.0.1:9222" "s1"))
        (cmd (cdp/extract-axtree conn))]
    (assert (string-contains? cmd "Accessibility.getFullAXTree") "cmd contains getFullAXTree")
    (assert (not (string-contains? cmd "Page.navigate")) "cmd does not contain Page.navigate")
    true))

(df test-dispatch-click [] -> Bool
  :d "Verifies mouse click command serialization."
  (let [(conn (cdp/make-cdp-connection "ws://127.0.0.1:9222" "s1"))
        (cmd (cdp/dispatch-click conn 101))]
    (assert (string-contains? cmd "Input.dispatchMouseEvent") "cmd contains Input.dispatchMouseEvent")
    (assert (string-contains? cmd "mousePressed") "cmd contains mousePressed")
    true))

(df run-tests [] -> Bool
  :d "Runs all browser CDP client tests."
  (do
    (test-make-cdp-connection)
    (test-navigate)
    (test-extract-axtree)
    (test-dispatch-click)
    true))
