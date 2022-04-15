(ns frontend.subs
  (:require
   [re-frame.core :as re-frame]))

(re-frame/reg-sub
 ::extensions
 (fn [db]
   (:extensions db)))

(re-frame/reg-sub
 ::name
 (fn [db]
   (:name db)))
