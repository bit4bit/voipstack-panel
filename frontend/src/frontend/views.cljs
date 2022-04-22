(ns frontend.views
  (:require
   [re-frame.core :as re-frame]
   [frontend.subs :as subs]
   ))

(defn extension-view [extension]
  [:li
   [:h4 (:name extension)]])

(defn main-panel []
  (let [extensions @(re-frame/subscribe [::subs/extensions])
        calls @(re-frame/subscribe [::subs/calls])]
    [:div
     [:h1 "Extensions"]
     [:ul
      (for [extension (vals extensions)]
        ^{:key (:id extension)} [extension-view extension])]
     [:h1 "Calls"]
     [:ul
      (for [call (vals calls)]
        ^{:key (:id call)} [:li [:h4 (:direction call) (:destination call)]])]]))
