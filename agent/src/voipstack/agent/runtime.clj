(ns voipstack.agent.runtime
  "runtime for voipstack agent.

  keep and update the state of softswitch.
  "
  (:require
   [sci.core :as sci]
   [clojure.spec.alpha :as s]))

(s/def ::source keyword?)
(s/def ::id string?)
(s/def ::alias string?)
(s/def ::source-endpoint string?)
(s/def ::source-id string?)
(s/def ::destination-endpoint string?)
(s/def ::destination-id string?)
(s/def ::extension (s/keys :req-un [::id]
                           :opt-un [::alias]))
(s/def ::extensions (s/map-of string? ::extension))
(s/def ::call (s/keys :req-un [::source-endpoint
                               ::source-id
                               ::destination-endpoint
                               ::destination-id]))
(s/def ::calls (s/* ::call))
(s/def ::state (s/keys :req-un [::source]
                       :opt-un [::extensions ::calls]))

(defn string->new [source code]
  (let [initial-state {:source source}
        var-event (sci/new-dynamic-var 'event {})
        var-source (sci/new-dynamic-var 'source {})
        ;; https://github.com/babashka/sci
        ctx (sci/init {:bindings {'state initial-state 'event var-event 'source var-source}})]
    (sci/eval-string* ctx code)
    {:context ctx
     :source source
     :state initial-state
     :vars {:event var-event :source var-source}}))

(defn process-event [runtime event]
  (let [ctx (:context runtime)
        source (:source runtime)
        runtime-var-event (get-in runtime [:vars :event])
        runtime-var-source (get-in runtime [:vars :source])]
    
    (sci/binding [runtime-var-event event
                  runtime-var-source source]
      (merge
       runtime
       {:state (sci/eval-string* ctx "(process-event source state event)")}))))

(defn get-state [ctx]
  (:state ctx))
