(module asl-harness/browser-cdp
  :d "Pure AgentScript Chrome DevTools Protocol (CDP) client and accessibility navigator."
  :x [CdpConnection
      make-cdp-connection
      navigate
      extract-axtree
      dispatch-click]
  :i [])

(dfs CdpConnection
  (:f target-url Str "Target WebSocket endpoint")
  (:f session-id Str "Active target session identifier")
  (:f is-connected Bool "Connection state flag"))

(df make-cdp-connection [(url Str) (session Str)] -> CdpConnection
  :d "Constructs CDP connection instance."
  (CdpConnection :target-url url :session-id session :is-connected true))

(df navigate [(conn CdpConnection) (dest-url Str)] -> Str
  :d "Dispatches Page.navigate command."
  (str "{\"id\":1,\"method\":\"Page.navigate\",\"params\":{\"url\":\"" dest-url "\"}}"))

(df extract-axtree [(conn CdpConnection)] -> Str
  :d "Dispatches Accessibility.getFullAXTree command."
  "{\"id\":2,\"method\":\"Accessibility.getFullAXTree\",\"params\":{}}")

(df dispatch-click [(conn CdpConnection) (node-id I64)] -> Str
  :d "Dispatches Input.dispatchMouseEvent click command to target element."
  (str "{\"id\":3,\"method\":\"Input.dispatchMouseEvent\",\"params\":{\"type\":\"mousePressed\",\"button\":\"left\",\"clickCount\":1}}"))
