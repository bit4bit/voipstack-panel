(ns frontend.views
  (:require
   [re-frame.core :as re-frame]
   [frontend.subs :as subs]
   ))

(defn extension-view [extension calls-by-extension]
 (println (pr-str calls-by-extension))
  [:li
   [:h4
    (:name extension)
    [:ul
     [:li
      (for [call (get calls-by-extension (:id extension))]
        ^{:key (:id call)} (:destination call))
    ]]]])

(defn main-panel []
  (let [extensions @(re-frame/subscribe [::subs/extensions])
        calls-by-extension @(re-frame/subscribe [::subs/calls-by-extension])]
    [:div
     [:h1 "Extensions"]
     [:ul
      (for [extension (vals extensions)]
        ^{:key (:id extension)} [extension-view extension calls-by-extension])]]))
