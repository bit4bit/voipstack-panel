(ns frontend.views
  (:require
   [re-frame.core :as re-frame]
   [frontend.subs :as subs]
   ))

(defn extension-view [extension]
  [:li
   [:h4 (:name extension)]])

(defn main-panel []
  (let [extensions @(re-frame/subscribe [::subs/extensions])]
    [:div
     [:h1 "Extensions"]
     [:ul
      (for [extension extensions]
        ^{:key (:id extension)} [extension-view extension])]]))
