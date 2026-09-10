(module asl-harness/browser-vector-engine-test
  :d "Unit test suite for Browser Reactive Vector Engine & Spatial ASN"
  :x [test-spatial-box-creation
      test-asn-vector-tree-initialization
      test-transpile-asn-to-dom-svg
      test-transpile-canvas-stream
      test-extract-spatial-vdom
      run-tests]
  :i [(browser_vector_engine :a bve)])

(df test-spatial-box-creation [] -> Bool
  :d "Verifies SpatialBox coordinate and dimension bounds"
  (let [(b (bve/make-spatial-box 10.0 20.0 150.0 80.0 "button"))]
    (assert (= (.-x b) 10.0) "Box X coordinate must match")
    (assert (= (.-y b) 20.0) "Box Y coordinate must match")
    (assert (= (.-width b) 150.0) "Box width must match")
    (assert (= (.-label b) "button") "Box label must match")
    true))

(df test-asn-vector-tree-initialization [] -> Bool
  :d "Verifies AsnVectorTree construction and properties"
  (let [(tree (bve/make-vector-tree "svg" "0 0 100 100" 2 "(:svg (:rc :x 0 :y 0))"))]
    (assert (= (.-root-tag tree) "svg") "Root tag must match svg")
    (assert (= (.-viewbox tree) "0 0 100 100") "Viewbox must match specification")
    (assert (= (.-element-count tree) 2) "Element count must equal 2")
    (assert (> (string-length (.-raw-asn tree)) 0) "Raw ASN must be non-empty")
    true))

(df test-transpile-asn-to-dom-svg [] -> Bool
  :d "Verifies pure ASN to SVG DOM emission"
  (let [(eng (bve/make-vector-engine 60 false true))
        (tree (bve/make-vector-tree "svg" "0 0 500 500" 1 "(:svg (:rc :f red))"))
        (dom (bve/transpile-asn-to-dom tree eng))]
    (assert (string-contains? dom "<svg") "DOM output must contain svg element")
    (assert (string-contains? dom "viewBox="0 0 500 500"") "DOM output must contain viewBox")
    (assert (string-contains? dom "<rect") "DOM output must convert :rc to rect")
    (assert (string-contains? dom "</svg>") "DOM output must close svg container")
    true))

(df test-transpile-canvas-stream [] -> Bool
  :d "Verifies Canvas 2D path stream emission"
  (let [(eng (bve/make-vector-engine 60 true true))
        (tree (bve/make-vector-tree "canvas" "0 0 800 600" 1 "(:canvas (:path))"))
        (stream (bve/transpile-asn-to-dom tree eng))]
    (assert (string-contains? stream "ctx.beginPath()") "Canvas stream must invoke beginPath")
    (assert (string-contains? stream "canvas") "Canvas stream must reference root tag")
    (assert (.-emit-canvas eng) "Engine must have emit-canvas active")
    true))

(df test-extract-spatial-vdom [] -> Bool
  :d "Verifies spatial bounding box extraction for rect and circle elements"
  (let [(tree-rc (bve/make-vector-tree "svg" "0 0 100 100" 1 "(:svg (:rc))"))
        (tree-circ (bve/make-vector-tree "svg" "0 0 100 100" 1 "(:svg (:circ))"))
        (box-rc (bve/extract-spatial-vdom tree-rc))
        (box-circ (bve/extract-spatial-vdom tree-circ))]
    (assert (= (.-label box-rc) "rect") "Rect tree must produce rect box")
    (assert (= (.-width box-rc) 100.0) "Rect width must be 100.0")
    (assert (= (.-label box-circ) "circle") "Circ tree must produce circle box")
    (assert (= (.-x box-circ) 50.0) "Circle X position must be 50.0")
    true))

(df run-tests [] -> Bool
  :d "Executes all browser vector engine test cases"
  (and (test-spatial-box-creation)
       (and (test-asn-vector-tree-initialization)
            (and (test-transpile-asn-to-dom-svg)
                 (and (test-transpile-canvas-stream)
                      (test-extract-spatial-vdom))))))
