{-# LANGUAGE RecordWildCards #-}

module LN.All.Star (
  -- handler
  getStarsR,
  postStarR0,
  getStarR,
  putStarR,
  deleteStarR,

  getStarStatsR,
  getStarStatR,

  -- model/functions
  starRequestToStar,
  starToResponse,
  starsToResponses,

  -- model/internal
  getStarsM,
  insertStarM,
  getStarM,
  getStar_ByThreadPostM,
  getStar_ByThreadPostIdM,
  updateStarM,
  deleteStarM,

  getStarStatsM,
  getStarStatM
) where



import           LN.All.Prelude
import qualified LN.T.Star as L



--
-- LN.Handler
--

getStarsR :: LN.Handler Value
getStarsR = run $ do
  user_id <- _requireAuthId
  (toJSON . starsToResponses) <$> getStarsM user_id



postStarR0 :: LN.Handler Value
postStarR0 = run $ do

  sp <- lookupStandardParams

  case (lookupStarEnt sp) of

    Nothing            -> permissionDenied "Must supply a entity information"

    Just (ent, ent_id) -> do

      user_id <- _requireAuthId
      star_request <- requireJsonBody
      (toJSON . starToResponse) <$> insertStarM user_id ent ent_id star_request



getStarR :: StarId -> LN.Handler Value
getStarR star_id = run $ do
  user_id <- _requireAuthId
  (toJSON . starToResponse) <$> getStarM user_id star_id



putStarR :: StarId -> LN.Handler Value
putStarR star_id = run $ do
  user_id <- _requireAuthId
  star_request <- requireJsonBody
  (toJSON . starToResponse) <$> updateStarM user_id star_id star_request



deleteStarR :: StarId -> LN.Handler Value
deleteStarR star_id = run $ do
  user_id <- _requireAuthId
  void $ deleteStarM user_id star_id
  pure $ toJSON ()



getStarStatsR :: LN.Handler Value
getStarStatsR = run $ do
  user_id <- _requireAuthId
  toJSON <$> getStarStatsM user_id



getStarStatR :: StarId -> LN.Handler Value
getStarStatR star_id = run $ do
  user_id <- _requireAuthId
  toJSON <$> getStarStatM user_id star_id





--
-- Model/Function
--

starRequestToStar :: UserId -> Ent -> Int64 -> StarRequest -> Star
starRequestToStar user_id ent ent_id StarRequest{..} = Star {
  starUserId         = user_id,
  starEnt            = ent,
  starEntId          = ent_id,
  starReason         = starRequestReason,
  starActive         = True,
  starGuard          = starRequestGuard,
  starCreatedAt      = Nothing,
  starModifiedAt     = Nothing
}



starToResponse :: Entity Star -> StarResponse
starToResponse (Entity star_id Star{..}) = StarResponse {
  starResponseId         = keyToInt64 star_id,
  starResponseUserId     = keyToInt64 starUserId,
  starResponseEnt        = starEnt,
  starResponseEntId      = starEntId,
  starResponseReason     = starReason,
  starResponseActive     = starActive,
  starResponseGuard      = starGuard,
  starResponseCreatedAt  = starCreatedAt,
  starResponseModifiedAt = starModifiedAt
}



starsToResponses :: [Entity Star] -> StarResponses
starsToResponses stars = StarResponses {
  starResponses = map starToResponse stars
}



--
-- Model/Internal
--

getStarsM :: UserId -> LN.HandlerEff [Entity Star]
getStarsM user_id = do
  selectListDb Nothing [StarUserId ==. user_id, StarActive ==. True] [] StarId



insertStarM :: UserId -> Ent -> Int64 -> StarRequest -> LN.HandlerEff (Entity Star)
insertStarM user_id ent ent_id star_request = do

  ts <- timestampH'
  let
    star = (starRequestToStar user_id ent ent_id star_request) { starCreatedAt = Just ts }

  insertEntityDb star



getStarM :: UserId -> StarId -> LN.HandlerEff (Entity Star)
getStarM user_id star_id = do
  notFoundMaybe =<< selectFirstDb [ StarId ==. star_id, StarUserId ==. user_id ] []



getStar_ByThreadPostM :: UserId -> Entity ThreadPost -> LN.HandlerEff (Maybe (Entity Star))
getStar_ByThreadPostM user_id thread_post = do
  selectFirstDb [ StarUserId ==. user_id, StarEnt ==. Ent_ThreadPost, StarEntId ==. thread_post_id ] []
  where
  thread_post_id = entityKeyToInt64 thread_post



getStar_ByThreadPostIdM :: UserId -> ThreadPostId -> LN.HandlerEff (Maybe (Entity Star))
getStar_ByThreadPostIdM user_id thread_post_id = do
  selectFirstDb [ StarUserId ==. user_id, StarEnt ==. Ent_ThreadPost, StarEntId ==. thread_post_id' ] []
  where
  thread_post_id' = keyToInt64 thread_post_id



updateStarM :: UserId -> StarId -> StarRequest -> LN.HandlerEff (Entity Star)
updateStarM user_id star_id StarRequest{..} = do

  ts <- timestampH'

  updateWhereDb
    [ StarId ==. star_id, StarUserId ==. user_id ]

    [ StarModifiedAt =. Just ts
    , StarReason     =. starRequestReason
    ]

  notFoundMaybe =<< selectFirstDb [ StarId ==. star_id ] []



deleteStarM :: UserId -> StarId -> LN.HandlerEff ()
deleteStarM user_id star_id = do
  deleteWhereDb [ StarUserId ==. user_id, StarId ==. star_id ]



getStarStatsM :: UserId -> LN.HandlerEff StarStatResponses
getStarStatsM _ = do

  StandardParams{..} <- lookupStandardParams

  case spBoardId of

    Just _  -> notFound
    Nothing -> notFound




getStarStatM :: UserId -> StarId -> LN.HandlerEff StarStatResponse
getStarStatM user_id _ = do

  sp@StandardParams{..} <- lookupStandardParams

  case spThreadPostId of
    Just thread_post_id -> getStarStat_ByThreadPostIdM user_id thread_post_id
    _                   -> notFound



getStarStat_ByThreadPostIdM :: UserId -> ThreadPostId -> LN.HandlerEff StarStatResponse
getStarStat_ByThreadPostIdM user_id thread_post_id = do
--  <- countDb [ StarPostStarId ==. star_id ]
  stars <- selectListDb Nothing [StarEnt ==. Ent_ThreadPost, StarEntId ==. i64, StarActive ==. True] [] StarId

  pure $ StarStatResponse {
    starStatResponseEnt   = Ent_ThreadPost,
    starStatResponseEntId = i64,
    starStatResponseStars = fromIntegral $ length stars
  }
  where
  i64 = keyToInt64 thread_post_id
