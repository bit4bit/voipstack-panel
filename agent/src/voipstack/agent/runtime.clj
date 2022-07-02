(ns voipstack.agent.runtime
  "runtime for voipstack agent.

  keep and update the state of softswitch.
  "
  (:require
   [sci.core :as sci]))

(defn string->new [code]
  (let [initial-state {}
        var-event (sci/new-dynamic-var 'event {})
        var-source (sci/new-dynamic-var 'source {})
        ;; https://github.com/babashka/sci
        ctx (sci/init {:bindings {'state initial-state 'event var-event 'source var-source}})]
    (sci/eval-string* ctx code)
    {:context ctx
     :state initial-state
     :vars {:event var-event :source var-source}}))

(defn process-event [runtime source event]
  (let [ctx (:context runtime)
        runtime-var-event (get-in runtime [:vars :event])
        runtime-var-source (get-in runtime [:vars :source])]
    
    (sci/binding [runtime-var-event event
                  runtime-var-source source]
      (merge
       runtime
       {:state (sci/eval-string* ctx "(process-event source state event)")}))))

(defn state [ctx]
  (:state ctx))
