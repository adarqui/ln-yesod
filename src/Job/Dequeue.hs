{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

module Job.Dequeue (
  runJobs,
  runJob_CreateUserProfile
) where



import           All.Profile                  (profileRequestToProfile)
import           Api.Params
import           Control
import           Data.Aeson
import qualified Data.ByteString.Lazy.Char8   as BL
import           Data.List                    (nub)
import           Import
import           Job.Shared
import           LN.T.Internal.Types
import           LN.T.Job
import           Misc.Codec                   (int64ToKey')
import           Model.Misc
import           Network.AMQP
import qualified Prelude                      as Prelude



import           Control.Monad.Logger         (runStdoutLoggingT)
import           Control.Monad.Trans.Resource (runResourceT)
import           Data.Yaml
import qualified Database.Persist
import           Database.Persist.Postgresql  as P
import           Database.Persist.Postgresql  (PostgresConf)
import           Import                       hiding (loadConfig)
import           Model
import           Settings
import           Yesod.Default.Config



runJobs :: FilePath -> IO ()
runJobs path = do

  Just yaml <- decodeFile path
  conf      <- parseMonad P.loadConfig yaml
  dbconf    <- applyEnv (conf :: PostgresConf)
  pool      <- createPoolConfig dbconf

  bgRunDeq QCreateUserProfile (bgDeq $ runJob_CreateUserProfile dbconf pool)

--  closeConnection conn ??



runJob_CreateUserProfile dbconf pool (Message{..}, env) = do
  liftIO $ putStrLn "runJob_CreateUserProfile"
  let e_resp = eitherDecode msgBody :: Either String (UserId, ProfileRequest)
  case e_resp of
    Left err                         -> liftIO $ Prelude.putStrLn err
    Right (user_id, profile_request) -> do
      liftIO $ putStrLn "success"
      liftIO $ runStdoutLoggingT $ runResourceT $ Database.Persist.runPool dbconf go pool
      ackEnv env
      where
      go = do
        let profile = profileRequestToProfile user_id profile_request
        insertEntity profile
