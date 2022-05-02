(ns frontend.views
  (:require
   [re-frame.core :as re-frame]
   [frontend.subs :as subs]
   ))

(defn extension-view [extension calls-by-extension]
  (println (pr-str calls-by-extension))
  (let [calls (get calls-by-extension (:id extension))]
    [:div {:class "column"}
     [:table {:class "table is-bordered"}
      [:thead
       [:tr
        [:th {:colspan (count calls)} (:name extension)]]]
      [:tbody
       [:tr
        (for [call calls]
          ^{:key (:id call)} [:td (:destination call)])]]]]))

(defn main-panel []
  (let [extensions @(re-frame/subscribe [::subs/extensions])
        calls-by-extension @(re-frame/subscribe [::subs/calls-by-extension])]
    [:div {:class "container is-max-widescreen"}
     [:h6 "Extensions"]
     [:div {:class "columns"}
      (for [extension (vals extensions)]
        ^{:key (:id extension)} [extension-view extension calls-by-extension])]]))
