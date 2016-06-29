{-# LANGUAGE RecordWildCards #-}

module LN.All.Pack.Leuron (
  -- LN.Handler
  getLeuronPacksR,
  getLeuronPackR,

  -- Model
  getLeuronPacksM,
  getLeuronPackM
) where



import           LN.All.Leuron
import           LN.All.LeuronTraining
import           LN.All.Prelude
import           LN.All.User



--
-- LN.Handler
--

getLeuronPacksR :: LN.Handler Value
getLeuronPacksR = run $ do
  user_id <- _requireAuthId
  sp      <- lookupStandardParams
  errorOrJSON id $ getLeuronPacksM (pure sp) user_id



getLeuronPackR :: LeuronId -> LN.Handler Value
getLeuronPackR leuron_id = run $ do
  user_id <- _requireAuthId
  errorOrJSON id $ getLeuronPackM user_id leuron_id







--
-- Model
--

getLeuronPacksM :: Maybe StandardParams -> UserId -> LN.HandlerErrorEff LeuronPackResponses
getLeuronPacksM m_sp user_id = do

  e_leurons <- getLeuronsM m_sp user_id
  rehtie e_leurons left $ \leurons -> do

    leuron_packs <- fmap rights $ mapM (\leuron -> getLeuronPack_ByLeuronM user_id leuron) leurons

    right $ LeuronPackResponses {
      leuronPackResponses = leuron_packs
    }



getLeuronPackM :: UserId -> LeuronId -> LN.HandlerErrorEff LeuronPackResponse
getLeuronPackM user_id leuron_id = do

  e_leuron <- getLeuronM user_id leuron_id
  rehtie e_leuron left $ \leuron -> getLeuronPack_ByLeuronM user_id leuron



getLeuronPack_ByLeuronM :: UserId -> Entity Leuron -> LN.HandlerErrorEff LeuronPackResponse
getLeuronPack_ByLeuronM user_id leuron@(Entity leuron_id Leuron{..}) = do

  lr <- runEitherT $ do
    leuron_user     <- isT $ getUserM user_id leuronUserId
    leuron_stat     <- isT $ getLeuronStatM user_id leuron_id
    leuron_training <- isT $ insertLeuronTrainingM user_id leuron_id $ LeuronTrainingRequest LTS_View 0

    pure (leuron_user
         ,leuron_stat
         ,leuron_training)

  rehtie lr left $ \(leuron_user, leuron_stat, leuron_training) -> do

    right $ LeuronPackResponse {
      leuronPackResponseLeuron      = leuronToResponse leuron,
      leuronPackResponseLeuronId    = keyToInt64 leuron_id,
      leuronPackResponseUser        = userToSanitizedResponse leuron_user,
      leuronPackResponseUserId      = entityKeyToInt64 leuron_user,
      -- TODO FIXME
      leuronPackResponseTraining    = leuronTrainingToResponse leuron_training,
      -- TODO FIXME
      -- leuronPackResponseTrainingId
      leuronPackResponseStat        = leuron_stat,
      leuronPackResponseLike        = Nothing,
      leuronPackResponseStar        = Nothing,
      leuronPackResponsePermissions = emptyPermissions
  --    leuronPackResponseLike     = fmap leuronLikeToResponse leuron_like,
  --    leuronPackResponseStar     = fmap leuronStarToResponse leuron_star
    }
