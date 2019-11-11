{-# LANGUAGE TemplateHaskell #-}

module Polysemy.Input
  ( -- * Effect
    Input (..)

    -- * Actions
  , input

    -- * Interpretations
  , runInputConst
  , runInputList
  , runInputSem
  , raceInput
  ) where

import Control.Concurrent.Async (race)
import Data.Coerce
import Data.Foldable (for_)
import Data.List (uncons)
import Polysemy
import Polysemy.Final
import Polysemy.Internal
import Polysemy.State


------------------------------------------------------------------------------
-- | An effect which can provide input to an application. Useful for dealing
-- with streaming input.
data Input i m a where
  Input :: Input i m i

makeSem ''Input


------------------------------------------------------------------------------
-- | Run an 'Input' effect by always giving back the same value.
runInputConst :: i -> Sem (Input i ': r) a -> Sem r a
runInputConst c = interpret $ \case
  Input -> pure c
{-# INLINE runInputConst #-}


------------------------------------------------------------------------------
-- | Run an 'Input' effect by providing a different element of a list each
-- time. Returns 'Nothing' after the list is exhausted.
runInputList
    :: [i]
    -> Sem (Input (Maybe i) ': r) a
    -> Sem r a
runInputList is = fmap snd . runState is . reinterpret
  (\case
      Input -> do
        s <- gets uncons
        for_ s $ put . snd
        pure $ fmap fst s
  )
{-# INLINE runInputList #-}


------------------------------------------------------------------------------
-- | Runs an 'Input' effect by evaluating a monadic action for each request.
runInputSem :: forall i r a. Sem r i -> Sem (Input i ': r) a -> Sem r a
runInputSem m = interpret $ \case
  Input -> m
{-# INLINE runInputSem #-}


------------------------------------------------------------------------------
-- | Given two blocking interpretations of 'Input', use whichever one completes
-- first for each invocation of 'input'. The interpreter provided by
-- 'raceInput' is itself a blocking interpretation of 'Input', and can thus be
-- used as an argument to itself.
raceInput
  :: forall i r
   . Member (Final IO) r
  => InterpreterFor (Input i) r
  -> InterpreterFor (Input i) (RacedInput i ': r)
  -> InterpreterFor (Input i) r
raceInput intr1 intr2 =
     intr1 . rewrite coerce
   . intr2
   . (reinterpret2 $ \Input -> withStrategicToFinal $ do
        input1 <- runS $ send $ RacedInput Input
        input2 <- runS $ input
        pure $ either id id <$> race input1 input2
     )


------------------------------------------------------------------------------
-- | An unexposed newtype to ensure nobody in 'raceInput' monkeys with the
-- input.
newtype RacedInput i m a = RacedInput (Input i m a)

