module All.SPA (
  getSPAR
) where



import           All.Prelude
import           Misc.Widget
import           Socket
import           Yesod.WebSockets



getSPAR :: Handler Html
getSPAR = do

  void $ requireAuthId

  webSockets socketHub
  defaultLayout $ do
    setTitle "adarq.org"

    addScriptRemoteBustCache "/static/pure/ln.js"
