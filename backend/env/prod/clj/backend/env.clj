(ns backend.env
  (:require [clojure.tools.logging :as log]))

(def defaults
  {:init
   (fn []
     (log/info "\n-=[backend started successfully]=-"))
   :stop
   (fn []
     (log/info "\n-=[backend has shut down successfully]=-"))
   :middleware identity})
