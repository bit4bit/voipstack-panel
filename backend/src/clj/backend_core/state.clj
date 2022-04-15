(ns backend-core.state
  (:require
   [clojure.spec.alpha :as s]))

(s/def :extension/id string?)
(s/def :extension/name string?)
(s/def :extension/realm string?)
(s/def :extension/extension
  (s/keys :req-un [
                   :extension/id
                   :extension/name
                   :extension/realm
                   ]))
(s/def :extensions/extensions
  (s/coll-of :extension/extension))
(s/def :event/source string?)
(s/def :event/content
  (s/keys :req-un [:extensions/extensions]))
(s/def :event/event
  (s/keys :req-un [:event/source]
          :opt-un [:event/content]))

(defn validate [event]
  (when-not (s/valid? :event/event event)
    (throw (ex-info (s/explain-str :event/event event) {:event event}))))
