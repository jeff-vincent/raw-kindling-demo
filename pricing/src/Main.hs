{-# LANGUAGE OverloadedStrings #-}

module Main where

import Web.Scotty
import Data.Aeson (object, (.=), decode, Value)
import qualified Database.Redis as R
import qualified Data.Text.Lazy as TL
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import System.Environment (lookupEnv)
import Data.Maybe (fromMaybe)

main :: IO ()
main = do
    redisHost <- fromMaybe "localhost" <$> lookupEnv "REDIS_HOST"
    redisPort <- maybe 6379 read <$> lookupEnv "REDIS_PORT"
    port      <- maybe 3013 read <$> lookupEnv "PORT"

    conn <- R.checkedConnect R.defaultConnectInfo
        { R.connectHost = redisHost
        , R.connectPort = R.PortNumber (fromIntegral (redisPort :: Int))
        }

    putStrLn $ "Pricing service listening on :" ++ show (port :: Int)

    scotty port $ do
        get "/health" $ do
            json $ object ["status" .= ("ok" :: String), "service" .= ("pricing" :: String)]

        get "/price/:product_id" $ do
            productId <- captureParam "product_id" :: ActionM TL.Text
            let key = BS.pack $ "price:" ++ TL.unpack productId
            result <- liftIO $ R.runRedis conn $ R.get key
            case result of
                Right (Just cached) ->
                    json $ object
                        [ "product_id" .= productId
                        , "price" .= BS.unpack cached
                        , "source" .= ("cache" :: String)
                        ]
                _ -> do
                    -- Default pricing logic
                    let basePrice = "29.99"
                    _ <- liftIO $ R.runRedis conn $ R.setex key 3600 (BS.pack basePrice)
                    json $ object
                        [ "product_id" .= productId
                        , "price" .= basePrice
                        , "source" .= ("computed" :: String)
                        ]

        post "/price/:product_id" $ do
            productId <- captureParam "product_id" :: ActionM TL.Text
            b <- body
            let key = BS.pack $ "price:" ++ TL.unpack productId
            case decode b :: Maybe Value of
                Just val -> do
                    _ <- liftIO $ R.runRedis conn $ R.setex key 3600 (LBS.toStrict b)
                    json $ object
                        [ "product_id" .= productId
                        , "updated" .= True
                        ]
                Nothing ->
                    json $ object ["error" .= ("invalid JSON body" :: String)]
