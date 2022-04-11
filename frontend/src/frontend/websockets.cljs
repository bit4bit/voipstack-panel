(ns frontend.websockets
  (:require-macros [mount.core :as mount])
  (:require [re-frame.core :as rf]
            [taoensso.sente :as sente]
            mount.core))

(declare receive-message! send!)

(mount/defstate socket
  :start (sente/make-channel-socket!
          "/ws"
          "token"
          {:type :auto
           :host "localhost"
           :port 3000
           :wrap-recv-evs? false}))

(mount/defstate channel-router
  :start (sente/start-chsk-router!
          (:ch-recv @socket)
          #'receive-message!)
  :stop (when-let [stop-fn @channel-router]
          (stop-fn)))

(defn receive-message!
  [{:keys [id event] :as ws-message}]
  (do
    (.log js/console "Event received: " (pr-str event))))

(defn send! [message]
  (if-let [send-fn (:send-fn @socket)]
    (send-fn message)
    (throw (ex-info "Could't send message, channel isn't open!"
                    {:message message}))))

