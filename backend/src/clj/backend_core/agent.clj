(ns backend-core.agent
  (:require
   [backend-core.state :as state]))


(defprotocol core-runner
  (start [this] "start runner")
  (stop [this] "stop current runner")
  (dispatch [this agent-id content] "returns dispatcher"))


;; first implementation of core
;; for high traffic maybe we new a decoupled implementation core
(deftype core-runner-sync [send-fn]
  core-runner
  (start [this] nil)
  (stop [this] nil)
  (dispatch [this agent-id event]
      (send-fn agent-id [:event/state event])))

(defn new-core-runner-sync [send-fn]
  (core-runner-sync. send-fn))

(defn run-dispatcher [runner]
  (fn [id event]
    (state/validate event)
    (dispatch runner id event)))

(defn start! [runner]
  "start agent handler"
  {:dispatch-fn (run-dispatcher runner)
   :stop-fn
   (fn []
     (stop runner))})


