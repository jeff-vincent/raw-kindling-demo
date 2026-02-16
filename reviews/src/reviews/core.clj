(ns reviews.core
  (:require [ring.adapter.jetty :as jetty]
            [ring.middleware.json :refer [wrap-json-body wrap-json-response]]
            [compojure.core :refer [defroutes GET POST]]
            [compojure.route :as route]
            [cheshire.core :as json]
            [monger.core :as mg]
            [monger.collection :as mc]
            [monger.json])
  (:import [org.bson.types ObjectId])
  (:gen-class))

(def mongo-uri (or (System/getenv "MONGO_URL") "mongodb://localhost:27017/reviews"))

(defonce conn (atom nil))
(defonce db (atom nil))

(defn init-db! []
  (let [{:keys [conn db]} (mg/connect-via-uri mongo-uri)]
    (reset! reviews.core/conn conn)
    (reset! reviews.core/db db)))

(defn health-handler [req]
  {:status 200
   :body {:status "ok" :service "reviews"}})

(defn list-reviews [req]
  (let [product-id (get-in req [:params :product_id])
        reviews (if product-id
                  (mc/find-maps @db "reviews" {:product_id product-id})
                  (mc/find-maps @db "reviews"))]
    {:status 200
     :body {:reviews (map #(dissoc % :_id) reviews)
            :count (count reviews)}}))

(defn create-review [req]
  (let [body (:body req)
        review (merge body
                      {:id (str (ObjectId.))
                       :created_at (java.time.Instant/now)})]
    (mc/insert @db "reviews" review)
    {:status 201
     :body (dissoc review :_id)}))

(defroutes app-routes
  (GET "/health" [] health-handler)
  (GET "/reviews" [] list-reviews)
  (POST "/reviews" [] create-review)
  (route/not-found {:status 404 :body {:error "not found"}}))

(def app
  (-> app-routes
      (wrap-json-body {:keywords? true})
      wrap-json-response))

(defn -main [& args]
  (init-db!)
  (let [port (Integer/parseInt (or (System/getenv "PORT") "3012"))]
    (println (str "Reviews service listening on :" port))
    (jetty/run-jetty app {:port port :join? true})))
