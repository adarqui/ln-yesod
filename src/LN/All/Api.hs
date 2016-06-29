{-# LANGUAGE RecordWildCards #-}

module LN.All.Api (
  getApisR,
  postApisR,
  getApiR,
  putApiR,
  deleteApiR,

  -- Model/Function
  apiRequestToApi,
  apiToResponse,
  apisToResponses,

  -- Model/Internal
  getApisM,
  getApiM,
  insertApiM,
  updateApiM,
  deleteApiM
) where



import           LN.All.Prelude
import           Data.UUID    (toText)
import           Data.UUID.V4 (nextRandom)



getApisR :: LN.Handler Value
getApisR = run $ do
  user_id <- _requireAuthId
  sp      <- lookupStandardParams
  errorOrJSON apisToResponses $ getApisM (pure sp) user_id



postApisR :: LN.Handler Value
postApisR = run $ do
  user_id     <- _requireAuthId
  api_request <- requireJsonBody
  errorOrJSON apiToResponse $ insertApiM user_id api_request



getApiR :: ApiId -> LN.Handler Value
getApiR api_id = run $ do
  user_id <- _requireAuthId
  errorOrJSON apiToResponse $ getApiM user_id api_id



putApiR :: ApiId -> LN.Handler Value
putApiR api_id = run $ do
  user_id     <- _requireAuthId
  api_request <- requireJsonBody
  errorOrJSON apiToResponse $ updateApiM user_id api_id api_request



deleteApiR :: ApiId -> LN.Handler Value
deleteApiR api_id = run $ do
  user_id <- _requireAuthId
  errorOrJSON id $ deleteApiM user_id api_id





--
-- Model/Function
--

apiRequestToApi :: UserId -> ApiRequest -> Api
apiRequestToApi user_id ApiRequest{..} = Api {
  apiUserId     = user_id,
  apiComment    = apiRequestComment,
  apiKey        = "",
  apiActive     = True,
  apiGuard      = apiRequestGuard,
  apiCreatedAt  = Nothing,
  apiModifiedAt = Nothing
}



apiToResponse :: Entity Api -> ApiResponse
apiToResponse (Entity api_id Api{..}) = ApiResponse {
  apiResponseId         = keyToInt64 api_id,
  apiResponseUserId     = keyToInt64 apiUserId,
  apiResponseComment    = apiComment,
  apiResponseKey        = apiKey,
  apiResponseGuard      = apiGuard,
  apiResponseCreatedAt  = apiCreatedAt,
  apiResponseModifiedAt = apiModifiedAt
}



apisToResponses :: [Entity Api] -> ApiResponses
apisToResponses apis = ApiResponses {
  apiResponses = map apiToResponse apis
}



--
-- Model/Internal
--

getApisM :: Maybe StandardParams -> UserId -> LN.HandlerErrorEff [Entity Api]
getApisM m_sp user_id = do
  selectListDbE m_sp [ApiUserId ==. user_id, ApiActive ==. True] [] ApiId



getApiM :: UserId -> ApiId -> LN.HandlerErrorEff (Entity Api)
getApiM user_id api_id = do
  selectFirstDbE [ApiUserId ==. user_id, ApiId ==. api_id, ApiActive ==. True] []



insertApiM :: UserId -> ApiRequest -> LN.HandlerErrorEff (Entity Api)
insertApiM user_id api_request = do
  ts <- timestampH'
  uuid1 <- liftIO nextRandom
  uuid2 <- liftIO nextRandom
  -- TODO: uuid5? namespace to user?
  let api = (apiRequestToApi user_id api_request) { apiKey = (toText uuid1 <> toText uuid2), apiCreatedAt = Just ts }
  insertEntityDbE api



updateApiM :: UserId -> ApiId -> ApiRequest -> LN.HandlerErrorEff (Entity Api)
updateApiM user_id api_id api_request = do
  ts <- timestampH'
  updateWhereDb
    [ ApiUserId ==. user_id, ApiId ==. api_id, ApiActive ==. True ]
    [ ApiComment =. (apiRequestComment api_request), ApiModifiedAt =. Just ts ]
  selectFirstDbE [ApiUserId ==. user_id, ApiId ==. api_id, ApiActive ==. True] []



deleteApiM :: UserId -> ApiId -> LN.HandlerErrorEff ()
deleteApiM user_id api_id = do
  deleteWhereDbE [ApiUserId ==. user_id, ApiId ==. api_id, ApiActive ==. True]
