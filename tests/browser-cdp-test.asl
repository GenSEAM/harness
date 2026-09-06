(module asl-harness/tests/browser-cdp-test
  :d "Unit tests for pure ASL Chrome DevTools Protocol client and navigator."
  :x [run-tests]
  :i [(browser_cdp :a cdp)])

(df test-make-cdp-connection [] -> Bool
  :d "Verifies creation of CDP connection instance."
  (let [(conn (cdp/make-cdp-connection "ws://127.0.0.1:9222/devtools/page/1" "sess-42"))]
    (and (= (.-target-url conn) "ws://127.0.0.1:9222/devtools/page/1")
         (and (= (.-session-id conn) "sess-42")
              (.-is-connected conn)))))

(df test-navigate [] -> Bool
  :d "Verifies JSON-RPC command formatting for Page.navigate."
  (let [(conn (cdp/make-cdp-connection "ws://127.0.0.1:9222" "s1"))
        (cmd (cdp/navigate conn "https://example.com"))]
    (and (string-contains? cmd "Page.navigate")
         (string-contains? cmd "https://example.com"))))

(df test-extract-axtree [] -> Bool
  :d "Verifies Accessibility.getFullAXTree command serialization."
  (let [(conn (cdp/make-cdp-connection "ws://127.0.0.1:9222" "s1"))
        (cmd (cdp/extract-axtree conn))]
    (string-contains? cmd "Accessibility.getFullAXTree")))

(df test-dispatch-click [] -> Bool
  :d "Verifies mouse click command serialization."
  (let [(conn (cdp/make-cdp-connection "ws://127.0.0.1:9222" "s1"))
        (cmd (cdp/dispatch-click conn 101))]
    (and (string-contains? cmd "Input.dispatchMouseEvent")
         (string-contains? cmd "mousePressed"))))

(df run-tests [] -> Bool
  :d "Runs all browser CDP client tests."
  (and (test-make-cdp-connection)
       (and (test-navigate)
            (and (test-extract-axtree)
                 (test-dispatch-click)))))
