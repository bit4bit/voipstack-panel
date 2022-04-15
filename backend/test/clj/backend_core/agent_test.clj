(ns backend-core.agent-test
  (:require
   [clojure.test :refer :all]
   [backend-core.agent :as core]))

(defn start-agent [send-fn]
  (->> send-fn
       (core/new-core-runner-sync)
       (core/start!)))

(defn send-fn-dumb [id content]
  nil)

(deftest test-app
  (testing "dispatch"
    (let [send-fn (fn [id content]
                    (throw (ex-info "send called" {})))
          core-agent (start-agent send-fn)]
      (is
       (thrown-with-msg? clojure.lang.ExceptionInfo #"send called"
                         (do
                           ((:dispatch-fn core-agent) 1 {:source "freeswitch"})))))
    (testing "invalid event"
      (let [core-agent (start-agent send-fn-dumb)
            dispatch (:dispatch-fn core-agent)]
        (is
         (thrown? clojure.lang.ExceptionInfo
                  (do
                    (dispatch 1 {:bob []}))))))
    (testing "valid event"
      (let [core-agent (start-agent send-fn-dumb)
            dispatch (:dispatch-fn core-agent)]
        (dispatch 1 {:source "freeswitch"
                     :content
                     {
                      :extensions
                      [
                       {:id "1"
                        :name "1001"
                        :realm "test.voipstack.com"}
                       ]
                      }})))))

    
