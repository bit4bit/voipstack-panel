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
(def direction? #{:inbound :outbound})
(s/def ::caller-direction direction?) ;; :inbound | :outbound
(s/def ::caller-destination string?)
(s/def ::caller-device string?)
(s/def ::callee-destination string?)
(s/def ::callee-device string?)
(s/def ::caller-name string?)
(s/def ::caller-number string?)
(s/def ::callee-name string?)
(s/def ::callee-number string?)
(s/def ::extension (s/keys :req-un [::id]
                           :opt-un [::alias]))
(s/def ::extensions (s/map-of string? ::extension))
(s/def ::call (s/keys :req-un [::caller-direction
                               ::caller-destination
                               ::caller-device
                               ::callee-destination
                               ::callee-device]
                      :opt-un [::caller-name
                               ::caller-number
                               ::callee-name
                               ::callee-number]))
                               
(s/def ::calls (s/* ::call))
(s/def ::state (s/keys :req-un [::source]
                       :opt-un [::extensions ::calls]))

(defn string->new [source code]
  (let [initial-state {:source source}
        var-event (sci/new-dynamic-var 'event {})
        var-source (sci/new-dynamic-var 'source {})
        var-cmd (sci/new-dynamic-var 'cmd {})
        var-response (sci/new-dynamic-var 'response {})
        ;; https://github.com/babashka/sci
        ctx (sci/init {:bindings {'state initial-state 'event var-event 'source var-source 'cmd var-cmd 'response var-response}})]
    (sci/eval-string* ctx code)
    (atom {:context ctx
     :source source
     :state initial-state
     :vars {:event var-event :source var-source :cmd var-cmd :response var-response}})))

(defn process-event
  "process event of softswitch"
  [runtime event]
  {:post [(s/valid? ::state (:state @runtime))]}
  (let [ctx (:context @runtime)
        source (:source @runtime)
        runtime-var-event (get-in @runtime [:vars :event])
        runtime-var-source (get-in @runtime [:vars :source])]
    
    (sci/binding [runtime-var-event event
                  runtime-var-source source]
      (let [result (sci/eval-string* ctx "(process-event source state event)")]
        (swap! runtime #(merge % {:state result}))
        runtime))))


(defn process-response
  "process response of softswitch command"
  [runtime cmd response]
  {:pre [(map? response)]
   :post [(s/valid? ::state (:state @runtime))]
   }
  (let [ctx (:context @runtime)
        runtime-var-cmd (get-in @runtime [:vars :cmd])
        runtime-var-response (get-in @runtime [:vars :response])]
    (sci/binding [runtime-var-cmd cmd
                  runtime-var-response response]
      (let [result (sci/eval-string* ctx "(process-response source state cmd response)")]
        (swap! runtime #(merge % {:state result}))))))

(defn get-state [runtime]
  (:state @runtime))
