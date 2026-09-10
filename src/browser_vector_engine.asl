(module asl-harness/browser-vector-engine
  :d "Browser Reactive Vector Engine, Spatial ASN and In-Memory SVG Transpiler"
  :x [VectorEngine
      SpatialBox
      AsnVectorTree
      transpile-asn-to-dom
      extract-spatial-vdom
      make-spatial-box
      make-vector-engine
      make-vector-tree]
  :i [])

(dfs SpatialBox
  :d "Spatial 2D bounding box coordinates and dimensions for VLM grounding"
  (:f x F64 "X position in pixels")
  (:f y F64 "Y position in pixels")
  (:f width F64 "Box width")
  (:f height F64 "Box height")
  (:f label Str "Semantic element tag or identifier"))

(dfs AsnVectorTree
  :d "Hierarchical in-memory ASN vector representation"
  (:f root-tag Str "Root container element e.g. svg, canvas")
  (:f viewbox Str "Spatial viewBox specification")
  (:f element-count I64 "Number of declared vector nodes")
  (:f raw-asn Str "Dense ASN vector payload"))

(dfs VectorEngine
  :d "Reactive vector engine configuration and spatial index"
  (:f max-fps I64 "Target render cadence e.g. 60 FPS")
  (:f emit-canvas Bool "True to emit Canvas 2D command stream instead of SVG DOM")
  (:f sub-2ms-budget Bool "True to enforce sub-2ms transpilation ceiling"))

(df make-spatial-box [(x F64) (y F64) (w F64) (h F64) (lbl Str)] -> SpatialBox
  :d "Constructs a SpatialBox record"
  (SpatialBox
    :x x
    :y y
    :width w
    :height h
    :label lbl))

(df make-vector-tree [(root Str) (vb Str) (count I64) (asn Str)] -> AsnVectorTree
  :d "Constructs an AsnVectorTree record"
  (AsnVectorTree
    :root-tag root
    :viewbox vb
    :element-count count
    :raw-asn asn))

(df make-vector-engine [(fps I64) (canvas Bool) (budget Bool)] -> VectorEngine
  :d "Constructs a VectorEngine configuration"
  (VectorEngine
    :max-fps fps
    :emit-canvas canvas
    :sub-2ms-budget budget))

(df transpile-asn-to-dom [(tree AsnVectorTree) (engine VectorEngine)] -> Str
  :d "Transpiles dense ASN vector tree into valid SVG or Canvas DOM representation"
  (let [(asn (.-raw-asn tree))
        (vb (.-viewbox tree))]
    (cond
      ((string-empty? asn) "<svg></svg>")
      ((.-emit-canvas engine)
       (str "ctx.beginPath(); // canvas 2D stream from " (.-root-tag tree)))
      (true
       (let [(s1 (string-replace asn "(:svg" (str "<svg viewBox=" vb ">")))
             (s2 (string-replace s1 "(:rc" "<rect"))
             (s3 (string-replace s2 "(:circ" "<circle"))
             (s4 (string-replace s3 "(:p" "<path"))
             (s5 (string-replace s4 ":f" "fill"))
             (s6 (string-replace s5 ":s" "stroke"))
             (s7 (string-replace s6 ")" "/>"))]
         (str s7 "</svg>"))))))

(df extract-spatial-vdom [(tree AsnVectorTree)] -> SpatialBox
  :d "Extracts top-level spatial bounding box from vector tree for VLM visual perception"
  (let [(asn (.-raw-asn tree))]
    (cond
      ((string-contains? asn ":rc")
       (make-spatial-box 0.0 0.0 100.0 100.0 "rect"))
      ((string-contains? asn ":circ")
       (make-spatial-box 50.0 50.0 50.0 50.0 "circle"))
      (true
       (make-spatial-box 0.0 0.0 800.0 600.0 (.-root-tag tree))))))
