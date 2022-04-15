(ns frontend.websockets
  (:require-macros [mount.core :as mount])
  (:require [re-frame.core :as re-frame]
            [taoensso.sente :as sente]
            mount.core))

(declare handle-message! receive-message! send!)

(mount/defstate socket
  :start (sente/make-channel-socket!
          "/ws"
          "token"
          {:type :auto
           :host "localhost"
           :port 3000
           :client-id "demo"
           :wrap-recv-evs? false}))

(mount/defstate channel-router
  :start (sente/start-chsk-router!
          (:ch-recv @socket)
          #'receive-message!)
  :stop (when-let [stop-fn @channel-router]
          (stop-fn)))

(defmulti handle-message!
  (fn [{:keys [id]} _]
    id))

(defmethod handle-message! :event/state
  [_ event]
  (let [event-type (first event)
        event (last event)]
    (.log js/console "Event state: " (pr-str event))
    (re-frame/dispatch [event-type event])))

(defmethod handle-message! :chsk/handshake
  [{:keys [event]} _]
  (.log js/console "Connection Established: " (pr-str event)))
(defmethod handle-message! :chsk/state
  [{:keys [event]} _]
  (.log js/console "State changed: " (pr-str event)))
(defmethod handle-message! :default
  [{:keys [event]} _]
  (.warn js/console "Unknown websocket message: " (pr-str event)))

(defn receive-message!
  [{:keys [id event] :as ws-message}]
  (handle-message! ws-message event))

(defn send! [message]
  (if-let [send-fn (:send-fn @socket)]
    (send-fn message)
    (throw (ex-info "Could't send message, channel isn't open!"
                    {:message message}))))
