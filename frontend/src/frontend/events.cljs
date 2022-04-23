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
 (fn-traced [db [event-type event]]
            (let [extensions (get-in event [:content :extensions])
                  calls (get-in event [:content :calls])]
            
              ;;(.log js/console "Event Type " (pr-str event-type))
              ;;(.log js/console "Event " (pr-str event))
              ;;(.log js/console "Calls" (pr-str calls))
              (assoc db
                     :extensions extensions
                     :calls calls))))
