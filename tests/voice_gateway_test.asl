(module asl-harness/voice-gateway-test
  :d "Unit and verification test suite for Aslany Voice Gateway"
  :x [test-make-pcm-frame
      test-ingest-pcm-frame
      test-intent-classification-search
      test-intent-classification-action
      test-gateway-version
      run-tests]
  :i [(voice_gateway :a vg)])

(df test-make-pcm-frame [] -> Bool
  :d "Verifies construction of standard 16kHz PCM audio frame"
  (let [(f (vg/make-pcm-frame "pcm-01" true))]
    (assert (= (.-frame-id f) "pcm-01") "Frame ID must match")
    (assert (= (.-sample-rate f) 16000) "Sample rate must be 16000")
    (assert (= (.-duration-ms f) 160) "Duration must be 160ms")
    (assert (.-is-speech f) "Speech flag must be true")
    true))

(df test-ingest-pcm-frame [] -> Bool
  :d "Verifies raw PCM frame ingestion into RawAsrTranscript"
  (let [(f (vg/make-pcm-frame "pcm-02" true))
        (tr (vg/ingest-pcm-frame f "найди документацию по bun" "ru" true))]
    (assert (= (.-frame-id tr) "pcm-02") "Transcript must inherit parent frame ID")
    (assert (= (.-language tr) "ru") "Language must match detected code")
    (assert (.-is-final tr) "Terminal flag must be true")
    (assert (> (.-confidence tr) 0.90) "Confidence must exceed 0.90")
    (assert (< (.-latency-ms tr) 50) "Inference latency must be sub-50ms")
    true))

(df test-intent-classification-search [] -> Bool
  :d "Verifies classification of informational queries into :fast-search"
  (let [(f (vg/make-pcm-frame "pcm-03" true))
        (tr-ru (vg/ingest-pcm-frame f "что такое WebGPU буфер" "ru" true))
        (tr-en (vg/ingest-pcm-frame f "what is the latest release of Bun" "en" true))
        (dec-ru (vg/classify-voice-intent tr-ru))
        (dec-en (vg/classify-voice-intent tr-en))]
    (assert (= (.-route-tag dec-ru) ":fast-search") "Russian query must route to :fast-search")
    (assert (.-grounding-required dec-ru) "Russian query must require live search")
    (assert (= (.-target-preset dec-ru) "preset-fast-search") "Target preset must be preset-fast-search")
    (assert (= (.-route-tag dec-en) ":fast-search") "English query must route to :fast-search")
    (assert (.-grounding-required dec-en) "English query must require live search")
    true))

(df test-intent-classification-action [] -> Bool
  :d "Verifies classification of browser commands into :agent-action"
  (let [(f (vg/make-pcm-frame "pcm-04" true))
        (tr-ru (vg/ingest-pcm-frame f "кликни на кнопку checkout" "ru" true))
        (tr-en (vg/ingest-pcm-frame f "click on the submit button" "en" true))
        (dec-ru (vg/classify-voice-intent tr-ru))
        (dec-en (vg/classify-voice-intent tr-en))]
    (assert (= (.-route-tag dec-ru) ":agent-action") "Russian command must route to :agent-action")
    (assert (not (.-grounding-required dec-ru)) "Action command must not require web search")
    (assert (= (.-target-preset dec-ru) "preset-agent-action") "Target preset must be preset-agent-action")
    (assert (= (.-route-tag dec-en) ":agent-action") "English command must route to :agent-action")
    true))

(df test-gateway-version [] -> Bool
  :d "Verifies gateway version string"
  (let [(v (vg/get-gateway-version))]
    (assert (= v "1.0.0") "Version must be 1.0.0")
    true))

(df run-tests [] -> Bool
  :d "Runs all test cases in suite"
  (do
    (assert (test-make-pcm-frame) "PCM frame test failed")
    (assert (test-ingest-pcm-frame) "Ingest PCM frame test failed")
    (assert (test-intent-classification-search) "Search intent test failed")
    (assert (test-intent-classification-action) "Action intent test failed")
    (assert (test-gateway-version) "Gateway version test failed")
    true))
