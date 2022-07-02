(ns voipstack.agent-test
  (:require
   [clojure.test :refer :all]
   [clojure.spec.alpha :as s]
   [voipstack.agent.runtime :as runtime]))

(deftest runtime
  (testing "update state on softswitch event"
    (let [rt (runtime/string->new :test "
(defn process-event [source state event]
  (merge state {:test (str \"from scripting \" (:event-name event))}))
")
          rt (runtime/process-event rt {:event-name "voipstack"})]
      
      (is (= "from scripting voipstack" (:test (runtime/get-state rt))))))
 (testing "schema runtime state"
   (let [rt (runtime/string->new :test "")
         state {:source :test
                :extensions {"1000" {:id "1000"}}
                :calls [
                        {:caller-direction :outbound
                         :caller-destination "123"
                         :caller-device "carrier"
                         :callee-destination "1000"
                         :callee-device "extension"
                        }]}]
      
      (is (= true (s/valid? ::runtime/state state))))))


