{-# LANGUAGE OverloadedStrings #-}

module LN.Socket (
  socketHub
) where



import           Import
import           Yesod.WebSockets



socketHub :: WebSocketsT Handler ()
socketHub = do
  sendTextData ("Welcome" :: Text)