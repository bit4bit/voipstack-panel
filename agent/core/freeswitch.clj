(defn- registration->id [registration]
  (str
   (get registration "reg_user")
   "@"
   (get registration "realm")))
(defn- registration->extension [registration]
  (let [id (registration->id registration)]
    {:id id}))
(defn- response->registrations [response]
  (get response "rows"))

(defn process-response [source state cmd response]
  (reduce (fn [state registration]
            (let [id (registration->id registration)
                  extensions (:extensions state {})
                  extension (registration->extension registration)]
              (merge state {:extensions
                            (conj extensions {id extension})})))
          state
          (response->registrations response)))

  
