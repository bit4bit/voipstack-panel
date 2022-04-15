(ns frontend.events
  (:require
   [re-frame.core :as re-frame]
   [frontend.db :as db]
   [day8.re-frame.tracing :refer-macros [fn-traced]]
   ))

(re-frame/reg-event-db
 ::initialize-db
 (fn-traced [_ _]
   db/default-db))

(re-frame/reg-event-db
 :event/state
 (fn-traced [db [before [_ event]]]
            (.log js/console "Event before " (pr-str before))
            (.log js/console "Event " (pr-str event))
   (assoc db :extensions (get-in event [:content :extensions]))))
