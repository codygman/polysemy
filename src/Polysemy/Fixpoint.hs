{-# LANGUAGE TemplateHaskell #-}

module Polysemy.Fixpoint
  ( Fixpoint ()
  , module Polysemy.Fixpoint
  ) where

import Control.Monad.Fix
import Polysemy
import Polysemy.Effect.New
import Polysemy.Fixpoint.Type


runFixpoint
    :: (∀ x. Semantic r x -> x)
    -> Semantic (Fixpoint ': r) a
    -> Semantic r a
runFixpoint lower = interpretH $ \case
  Fixpoint mf -> do
    c <- continue mf
    pure $ fix $ lower . runFixpoint lower . c

runFixpointM
    :: ( MonadFix m
       , Member (Lift m) r
       )
    => (∀ x. Semantic r x -> m x)
    -> Semantic (Fixpoint ': r) a
    -> Semantic r a
runFixpointM lower = interpretH $ \case
  Fixpoint mf -> do
    c <- continue mf
    sendM $ mfix $ lower . runFixpointM lower . c

