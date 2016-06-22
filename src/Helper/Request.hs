-- Stolen from Carnival.
--

module Helper.Request
    ( allowCrossOrigin
    , fromMaybe404
    ) where

import Import

lookupUtf8Header :: HeaderName -> HandlerEff (Maybe Text)
lookupUtf8Header headerName = return . fmap decodeUtf8 =<< lookupHeader headerName

allowCrossOrigin :: HandlerEff ()
allowCrossOrigin = do
    mo <- lookupUtf8Header "Origin"
    mrh <- lookupUtf8Header "Access-Control-Req-Headers"

    case mo of
        Just o  -> addHeader "Access-Control-Allow-Origin" o
        Nothing -> return ()

    case mrh of
        Just rh -> addHeader "Access-Control-Allow-Headers" rh
        Nothing -> return ()

    addHeader "Access-Control-Allow-Methods" "POST, GET, OPTIONS"
    addHeader "Access-Control-Allow-Credentials" "true"

fromMaybe404 :: HandlerEff (Maybe a) -> HandlerEff a
fromMaybe404 f = maybe notFound return =<< f
