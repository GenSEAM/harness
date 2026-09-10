(module asl-harness/voice-gateway
  :d "Voice Gateway for Aslany: streaming Parakeet-TDT-0.6B-v3 Multilingual ASR ingestion, raw transcript routing, and intent dispatch without TTS overhead"
  :x [VoicePcmFrame
      RawAsrTranscript
      VoiceRouteDecision
      make-pcm-frame
      ingest-pcm-frame
      is-search-intent?
      is-action-intent?
      classify-voice-intent
      get-gateway-version]
  :i [])

(dfs VoicePcmFrame
  :d "Streaming 16kHz PCM audio frame from AudioWorklet"
  (:f frame-id Str "Unique audio frame identifier")
  (:f sample-rate I64 "Audio sample rate fixed at 16000")
  (:f duration-ms I64 "Frame duration in milliseconds e.g. 160")
  (:f is-speech Bool "VAD voice activity detection flag"))

(dfs RawAsrTranscript
  :d "Raw ASR transcript token stream from Parakeet-TDT-0.6B-v3"
  (:f frame-id Str "Parent audio frame identifier")
  (:f text Str "Raw transcribed text in Russian or English")
  (:f language Str "Detected ISO language code e.g. ru or en")
  (:f is-final Bool "True if terminal endpoint reached")
  (:f confidence F64 "Acoustic confidence score")
  (:f latency-ms I64 "Inference latency in milliseconds"))

(dfs VoiceRouteDecision
  :d "1-Pass intent routing decision emitted by Aslany router"
  (:f route-tag Str "Route tag: :fast-search or :agent-action")
  (:f target-preset Str "Preset identifier for UI rendering")
  (:f normalized-query Str "Raw transcript passed to cognitive engine")
  (:f grounding-required Bool "True if live Google Search is required"))

(df get-gateway-version [] -> Str
  :d "Returns current voice gateway version"
  "1.0.0")

(df make-pcm-frame [(id Str) (is-speech Bool)] -> VoicePcmFrame
  :d "Constructs a standard 16kHz PCM audio frame"
  (VoicePcmFrame
    :frame-id id
    :sample-rate 16000
    :duration-ms 160
    :is-speech is-speech))

(df ingest-pcm-frame [(frame VoicePcmFrame) (text Str) (lang Str) (is-final Bool)] -> RawAsrTranscript
  :d "Simulates ingestion of PCM frame into Parakeet-TDT-v3 streaming transducer"
  (RawAsrTranscript
    :frame-id (.-frame-id frame)
    :text text
    :language lang
    :is-final is-final
    :confidence 0.96
    :latency-ms 22))

(df is-search-intent? [(text Str)] -> Bool
  :d "Determines if raw transcript matches informational search patterns"
  (let [(t (string-lower text))]
    (or (string-contains? t "что такое")
        (or (string-contains? t "какой")
            (or (string-contains? t "найди")
                (or (string-contains? t "сравни")
                    (or (string-contains? t "what is")
                        (or (string-contains? t "find")
                            (or (string-contains? t "search")
                                (string-contains? t "how to"))))))))))

(df is-action-intent? [(text Str)] -> Bool
  :d "Determines if raw transcript matches browser action patterns"
  (let [(t (string-lower text))]
    (or (string-contains? t "кликни")
        (or (string-contains? t "открой")
            (or (string-contains? t "заполни")
                (or (string-contains? t "перейди")
                    (or (string-contains? t "click")
                        (or (string-contains? t "open")
                            (or (string-contains? t "fill")
                                (string-contains? t "scroll"))))))))))

(df classify-voice-intent [(transcript RawAsrTranscript)] -> VoiceRouteDecision
  :d "1-Pass routing of raw transcript into Aslany task presets"
  (let [(text (.-text transcript))]
    (if (is-action-intent? text)
      (VoiceRouteDecision
        :route-tag ":agent-action"
        :target-preset "preset-agent-action"
        :normalized-query text
        :grounding-required false)
      (if (is-search-intent? text)
        (VoiceRouteDecision
          :route-tag ":fast-search"
          :target-preset "preset-fast-search"
          :normalized-query text
          :grounding-required true)
        (VoiceRouteDecision
          :route-tag ":fast-search"
          :target-preset "preset-fast-search"
          :normalized-query text
          :grounding-required false)))))
