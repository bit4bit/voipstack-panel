(ns backend.routes.ws
  (:require
   [clojure.tools.logging :as log]
   [taoensso.sente :as sente]
   [backend.middleware :as middleware]
   [mount.core :as mount]
   [taoensso.sente.server-adapters.http-kit :refer [get-sch-adapter]]))

(mount/defstate socket
  :start (sente/make-channel-socket!
          (get-sch-adapter)
          {
           :csrf-token-fn nil
           :user-id-fn (fn [ring-req]
                         (get-in ring-req [:params :client-id]))}))

(defn receive-message! [{:keys [id] :as message}]
  (log/debug "Got message with id: " id))

(mount/defstate channel-router
  :start (sente/start-chsk-router!
          (:ch-recv socket)
          #'receive-message!)
  :stop (when-let [stop-fn channel-router]
          (stop-fn)))

(defn websocket-routes []
  ["/ws"
   {:middleware [middleware/wrap-formats]
    :get (:ajax-get-or-ws-handshake-fn socket)
    :post (:ajax-post-fn socket)}])
  
