(defproject reviews "0.1.0"
  :description "Product reviews service"
  :dependencies [[org.clojure/clojure "1.11.1"]
                 [ring/ring-core "1.11.0"]
                 [ring/ring-jetty-adapter "1.11.0"]
                 [compojure "1.7.1"]
                 [cheshire "5.12.0"]
                 [com.novemberain/monger "3.6.0"]]
  :main reviews.core
  :aot [reviews.core]
  :profiles {:uberjar {:aot :all}})
