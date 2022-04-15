(ns backend.routes.agent
  (:require
   [clojure.tools.logging :as log]
   [backend-core.agent :as core]
   [ring.util.response]
   [ring.util.http-response :as response]
   [taoensso.sente :as sente]
   [taoensso.sente.server-adapters.http-kit :refer [get-sch-adapter]]
   [mount.core :as mount]
   [backend.middleware :as middleware]))

(declare receive-message! handle-message)

(mount/defstate socket
  :start (sente/make-channel-socket!
          (get-sch-adapter)
          {
           :csrf-token-fn nil
           :user-id-fn (fn [ring-req]
                         (get-in ring-req [:params :client-id]))}))

(mount/defstate channel-router
  :start (sente/start-chsk-router!
          (:ch-recv socket)
          #'receive-message!)
  :stop (when-let [stop-fn channel-router]
          (stop-fn)))

(mount/defstate core-agent-runner
  :start (core/new-core-runner-sync (:send-fn socket)))

(mount/defstate core-agent
  :start (core/start! core-agent-runner)
  :stop (when-let [stop-fn (:stop-fn core-agent)]
          (stop-fn)))

(defn send-ws! [uid message]
  ((:send-fn socket) uid message))

(def state-demo {:source "demo"
               :content {:extensions [{:id "test" :realm "demo" :name "test"}]}})

(defmulti handle-message
  (fn [{:keys [id]}]
    id))
(defmethod handle-message :default
  [{:keys [id]}]
  (log/debug "Got unhandle message: " id))
(defmethod handle-message :chsk/uidport-open
  [_]
  ((:dispatch-fn core-agent) "demo" state-demo))
(defmethod handle-message :chsk/ws-ping
  [_]
  ((:dispatch-fn core-agent) "demo" state-demo))

 
(defn receive-message! [{:keys [id] :as message}]
  (log/debug "Got message with id: " id)
  (handle-message message))

(defn agent-state [{:keys [path-params] :as request}]
  "Handle state from agent"
  (let [agent-id (:agent-id path-params)]
    ;; TODO decode json body
    ((:dispatch-fn core-agent) agent-id (:body request))
    (response/created "/")))

(defn agent-routes []
  [
   ""
   {:middleware [middleware/wrap-formats]}
   ["/agent/:agent-id/state" {:post agent-state}]
   ["/ws"
    {
     :get (:ajax-get-or-ws-handshake-fn socket)
     :post (:ajax-post-fn socket)
     }]
   ])
