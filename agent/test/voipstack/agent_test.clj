(ns voipstack.agent-test
  (:require
   [clojure.test :refer :all]
   [voipstack.agent.runtime :as runtime]))

(deftest runtime
  (testing "update state on softswitch event"
    (let [rt (runtime/string->new "
(defn process-event [source state event]
  (merge state {:test \"from scripting\"}))
")
          rt (runtime/process-event rt :test {})]
      (is (= "from scripting" (:test (runtime/state rt)))))))

