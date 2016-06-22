-- Stolen from Carnival
--

{-# LANGUAGE GADTs             #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TypeFamilies      #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

module OAuth2 (
  User(..),
  userGravatar,
  intercomHash,
  findUsers,
  findUsers',
  authenticateUser
) where



import           Data.Digest.Pure.SHA    (hmacSha256)
import qualified Data.Text               as T
import           Import.NoFoundation
import           LN.T.Profile            (ProfileX (..))
import           Misc.Codec
-- import           Model.User.Function    (profileNameToNick)
import           Network.Gravatar
import           Yesod.Auth.GoogleEmail2



userGravatar :: User -> Text
userGravatar = T.pack . gravatar def . userEmail



intercomHash :: UserId -> Text -> Text
intercomHash userId secret = pack $ show $ hmacSha256 secret' userId'

  where
    secret' = textToLbs secret
    userId' = textToLbs $ toPathPiece userId



findUsers :: [UserId] -> DB [Entity User]
findUsers userIds = selectList [UserId <-. userIds] []



-- | Same as @findUsers@, but discards the @entityKey@
findUsers' :: [UserId] -> DB [User]
findUsers' = fmap (map entityVal) . findUsers



-- data Creds
--
-- User credentials
--
-- credsPlugin :: Text -- How the user was authenticated
-- credsIdent :: Text -- Identifier. Exact meaning depends on plugin.
-- credsExtra :: [(Text, Text)]
--
authenticateUser :: AuthId m ~ UserId => Creds m -> DB (AuthenticationResult m)
authenticateUser creds@Creds{..} = do

  liftIO $ print credsPlugin
  liftIO $ print credsIdent
  liftIO $ print credsExtra

  liftIO $ putStrLn "ATTEMPTING AUTHENTICATION"

  mapM_ updateByEmail
    $ fmap profileEmail
    $ extraToProfileX credsPlugin credsExtra

  muser <- getBy $ UniqueUser credsPlugin credsIdent

  now <- liftIO $ getCurrentTime

  let
    euser = credsToUser now creds
    muserId = entityKey <$> muser

  maybe (authNew euser) (authExisting euser) $ muserId

  where
  updateByEmail email = updateWhere
    [ UserPlugin !=. credsPlugin
    , UserIdent !=. credsIdent
    , UserEmail ==. email
    ]
    [ UserPlugin =. credsPlugin
    , UserIdent =. credsIdent
    ]

  authNew (Left err) = return $ ServerError $ credsPlugin ++ ": " ++ err
  authNew (Right user) = Authenticated <$> insert user

  authExisting euser userId = do
    mapM_ (replace userId) euser
    return $ Authenticated userId



credsToUser :: UTCTime -> Creds m -> Either Text User
credsToUser now Creds{..} = User
  <$> (profileName <$> eprofile)
  <*> (profileName <$> eprofile)
  <*> (profileName <$> eprofile)
  <*> (profileEmail <$> eprofile)
  <*> pure email_md5
  <*> pure credsPlugin
  <*> pure credsIdent
  <*> pure Nothing
  <*> pure True
  <*> pure 0
  <*> pure (Just now)
  <*> pure Nothing
  <*> pure Nothing
  where
  eprofile = extraToProfileX credsPlugin credsExtra
  email_md5 = case eprofile of
                Left _ -> "md5"
                Right ProfileX{..} -> md5Text profileEmail



extraToProfileX :: Text -> [(Text, Text)] -> Either Text ProfileX
extraToProfileX "dummy" extra        = githubProfileX extra
extraToProfileX "github" extra       = githubProfileX extra
extraToProfileX "googleemail2" extra = googleProfileX extra
extraToProfileX plugin _             = Left $ "Invalid plugin: " ++ plugin



githubProfileX :: [(Text, Text)] -> Either Text ProfileX
githubProfileX extra = ProfileX
  <$> lookupExtra "login" extra
  <*> lookupExtra "name" extra
  <*> lookupExtra "email" extra



googleProfileX :: [(Text, Text)] -> Either Text ProfileX
googleProfileX extra = ProfileX
  <$> (handleLogin =<< decodeEitherText =<< lookupExtra "login" extra)
  <*> (handleName =<< decodeEitherText =<< lookupExtra "name" extra)
  <*> (handleEmails =<< decodeEitherText =<< lookupExtra "emails" extra)

  where
    handleName :: Name -> Either Text Text
    handleName Name{..} =
        case (nameFormatted, nameGiven, nameFamily) of
            (Just formatted, _, _) -> Right $ formatted
            (_, Just given, Just family) -> Right $ given ++ " " ++ family
            (_, Just given, _) -> Right given
            (_, _, Just family) -> Right family
            _ -> Left "user has no name"

    handleLogin :: Text -> Either Text Text
    handleLogin login = Left "TODO FIXME"

    handleEmails :: [Email] -> Either Text Text
    handleEmails [] = Left "user has no emails"
    handleEmails (email:_) = Right $ emailValue email




lookupExtra :: Text -> [(Text, b)] -> Either Text b
lookupExtra k extra =
  maybe (Left $ "missing key " ++ k) Right $ lookup k extra
