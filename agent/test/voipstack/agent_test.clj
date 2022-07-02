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
 (testing "spec runtime state"
   (let [rt (runtime/string->new :test "")
         state {:source :test
                :extensions {"1000" {:id "1000"}}
                :calls [
                        {:source-endpoint "mod_sofia"
                         :source-id "sip-profile"
                         :destination-endpoint "mod_sofia"
                         :destination-id "1000"
                        }]}]
      
      (is (= true (s/valid? ::runtime/state state))))))


