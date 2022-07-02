(ns voipstack.agent-test
  (:require
   [clojure.test :refer :all]
   [clojure.spec.alpha :as s]
   [voipstack.agent.config :as config]
   [voipstack.agent.runtime :as runtime]))

(defn- json->map [file]
  {})

(deftest runtime
  (testing "update state on softswitch event"
    (let [rt (runtime/string->new :test "
(defn process-event [source state event]
  (merge state {:test (str \"from scripting \" (:event-name event))}))
")]

      (runtime/process-event rt {:event-name "voipstack"})
      (is (= "from scripting voipstack" (:test (runtime/get-state rt))))))
  (testing "runtime/process-event not allowed to change shape of state"
    (let [rt (runtime/string->new :test "
(defn process-event [source state event]
false)
")]
      (is (thrown? AssertionError (runtime/process-event rt {:event-name "test"})))))
  (testing "runtime/process-response not allowed to change shape of state"
    (let [rt (runtime/string->new :test "
(defn process-response [source state cmd response]
false)
")]
      (is (thrown? AssertionError (runtime/process-response rt :registrations {})))))
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
      
     (is (= true (s/valid? ::runtime/state state)))))
  (testing "freeswitch process response of show registrations"
    (let [core-code (slurp config/freeswitch-runtime-implementation-script)
          rt (runtime/string->new :freeswitch core-code)
          api_response (json->map "registrations.json")
          expected_state {:source :freeswitch
                          :extensions {"1000" {:id "1000"}}}]

      (runtime/process-response rt :registrations api_response)
      (is (= expected_state (runtime/get-state rt))))))


