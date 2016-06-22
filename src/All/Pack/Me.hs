{-# LANGUAGE RecordWildCards #-}

module All.Pack.Me (
  -- Handler
  getMePackR
) where



import           All.Pack.User
import           All.Prelude
import           All.User



getMePackR :: Handler Value
getMePackR = do
  user_id <- requireAuthId
  toJSON <$> getUserPack_ByUserIdM user_id user_id defaultStandardParams
