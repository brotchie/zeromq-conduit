{-# LANGUAGE RankNTypes, GADTs #-} 
module Data.Conduit.ZMQ
       (
         SocketEnd(..)
       , SocketOpts(SockOpts, SubOpts)
       , zmqSource
       , zmqSink
       ) where

import Control.Monad.IO.Class (liftIO)
import qualified Data.ByteString.Internal as BS
import Data.Conduit
import Data.Conduit.Util
import Prelude hiding (init)
import System.ZMQ

-- | 'SocketEnd' defines whether we are going to @bind@ or @connect@ the @Socket@
data SocketEnd = Bind String | Connect String
     deriving Show

-- | 'SocketOpts' defines the 'SocketEnd' and the type of 'Socket'
data SocketOpts st where
     -- 'SockOpt' is the constructor for all 'Socket's except 'Sub'
     SockOpts :: (SType st) => SocketEnd -> st -> SocketOpts st
     -- 'SubOpts' is the contructor to use if you want a 'Sub' 'Socket'
     SubOpts :: (SubsType st) => SocketEnd -> st -> String -> SocketOpts st


attach :: Socket a -> SocketEnd -> IO ()
attach sock (Bind s) = bind sock s
attach sock (Connect s) = connect sock s

mkSocket :: (SType st) => Context -> SocketOpts st -> IO (Socket st)
mkSocket ctx so =
  case so of
        (SockOpts e st) -> do 
               sock <- socket ctx st
               attach sock e
               return sock
        (SubOpts e st sub) -> do
               sock <- socket ctx st
               attach sock e
               subscribe sock sub
               return sock

-- | A 'Source' for a 'Socket'
zmqSource :: (MonadResource m, SType st) => Context
                         -> SocketOpts st
                         -> Source m BS.ByteString
zmqSource ctx so = sourceIO
          (mkSocket ctx so)
          close
          (\sock -> liftIO $
              fmap IOOpen $ receive sock [])


zmqSink :: (MonadResource m, SType st) => Context
                       -> SocketOpts st
                       -> Sink BS.ByteString m ()
zmqSink ctx so = sinkIO
         (mkSocket ctx so)
         close
         (\sock msg -> do
           liftIO $ send sock msg [] 
           return IOProcessing)
         (\_ -> return ())

