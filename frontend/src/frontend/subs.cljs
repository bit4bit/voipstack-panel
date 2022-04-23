(ns frontend.subs
  (:require
   [re-frame.core :as re-frame]))

(re-frame/reg-sub
 ::extensions
 (fn [db]
   (:extensions db)))

(re-frame/reg-sub
 ::calls-by-extension
 (fn [db]
   (let [calls (vals (:calls db))]
     (group-by #(:extension_id %) calls))))
