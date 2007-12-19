--------------------------------------------------------------------
-- |
-- Module    : Text.JSON
-- Copyright : (c) Galois, Inc. 2007
-- License   : BSD3
--
-- Maintainer:  Don Stewart <dons@galois.com>
-- Stability :  provisional
-- Portability: portable
--
--------------------------------------------------------------------
--
-- Serialising Haskell values to and from JSON encoded Strings.
--

module Text.JSON (
    -- * JSON Types
    JSType(..)

    -- * Serialization to and from JSTypes
  , JSON(..)

    -- * Encoding and Decoding
  , encode -- :: JSON a => a -> String
  , decode -- :: JSON a => String -> Either String a

    -- * Wrapper Types
  , JSONString(JSONString)
  , fromJSString

  , JSONObject(JSONObject)
  , fromJSObject

    -- * Low leve parsing
    -- ** Reading JSON
  , readJSNull, readJSBool, readJSString, readJSInteger, readJSRational
  , readJSArray, readJSObject, readJSType

    -- ** Writing JSON
  , showJSNull, showJSBool, showJSInteger, showJSDouble, showJSArray
  , showJSObject, showJSType

  ) where

import Text.BasicJSON

import Data.Char
import Data.List
import Data.Int
import Data.Word
import Data.Either

import qualified Data.ByteString.Char8 as S
import qualified Data.ByteString.Lazy.Char8 as L
import qualified Data.IntSet as I
import qualified Data.Map as M

-- | Convenient error generation
mkError :: (JSON a) => String -> Either String a
mkError s = Left s

-- | Decode a JSON String
decode :: (JSON a) => String -> Either String a
decode s = readJSON =<< runGetJSON readJSType s

encode :: (JSON a) => a -> String
encode = (flip showJSType [] . showJSON)

class JSON a where
  readJSON :: JSType -> Either String a
  showJSON :: a -> JSType

--------------------------------------------------------------------
--
-- | To ensure we generate valid JSON, we map Haskell types to JSType
-- internally, then pretty print that.
--
instance JSON JSType where
    showJSON = id
    readJSON = return

second :: (a -> b) -> (x,a) -> (x,b)
second f (a,b) = (a, f b)

(<$>) :: (Functor f) => (a -> b) -> f a -> f b
(<$>) = fmap

instance Monad (Either x) where
  return = Right
  Right a >>= f = f a
  Left e >>= _  = Left e


--------------------------------------------------------------------
-- Some simple JSON wrapper types, to avoid overlapping instances

instance JSON JSONString where
  readJSON (JSString s) = return s
  readJSON _            = mkError "Unable to read JSONString"
  showJSON = JSString

instance (JSON a) => JSON (JSONObject a) where
  readJSON (JSObject (JSONObject o)) =
      let f (x,y) = do y' <- readJSON y; return (x,y')
       in mapM f o >>= return . JSONObject
  readJSON _ = mkError "Unable to read JSONObject"
  showJSON (JSONObject o) = JSObject . JSONObject
                          $ map (second showJSON) o


-- -----------------------------------------------------------------
-- Instances
--

instance JSON () where
  showJSON _ = JSNull
  readJSON JSNull = return ()
  readJSON _      = mkError "Unable to read ()"

instance JSON Bool where
  showJSON = JSBool
  readJSON (JSBool b) = return b
  readJSON _          = mkError "Unable to read Bool"

instance JSON Char where
  showJSON = JSString . JSONString . (:[])
  readJSON (JSString (JSONString s)) = return $ head s
  readJSON _                         = mkError "Unable to read Char"

instance JSON Ordering where
  showJSON LT = JSInteger (-1)
  showJSON EQ = JSInteger 0
  showJSON GT = JSInteger 1
  readJSON (JSInteger (-1)) = return LT
  readJSON (JSInteger 0)    = return EQ
  readJSON (JSInteger 1)    = return GT
  readJSON _ = mkError "Unable to read Ordering"

-- -----------------------------------------------------------------
-- Integral types

instance JSON Integer where
  showJSON = JSInteger
  readJSON (JSInteger i) = return i
  readJSON _             = mkError "Unable to read Integer"

-- constrained:
instance JSON Int where
  showJSON = JSInteger . toInteger
  readJSON (JSInteger i) = return $ fromIntegral i
  readJSON _             = mkError "Unable to read Int"

-- constrained:
instance JSON Word where
  showJSON = JSInteger . toInteger
  readJSON (JSInteger i) = return $ fromIntegral i
  readJSON _             = mkError "Unable to read Word"

-- -----------------------------------------------------------------

instance JSON Word8 where
  showJSON = JSInteger . toInteger
  readJSON (JSInteger i) = return $ fromIntegral i
  readJSON _             = mkError "Unable to read Word8"

instance JSON Word16 where
  showJSON = JSInteger . toInteger
  readJSON (JSInteger i) = return $ fromIntegral i
  readJSON _             = mkError "Unable to read Word16"

instance JSON Word32 where
  showJSON = JSInteger . toInteger
  readJSON (JSInteger i) = return $ fromIntegral i
  readJSON _             = mkError "Unable to read Word32"

instance JSON Word64 where
  showJSON = JSInteger . toInteger
  readJSON (JSInteger i) = return $ fromIntegral i
  readJSON _             = mkError "Unable to read Word64"

instance JSON Int8 where
  showJSON = JSInteger . toInteger
  readJSON (JSInteger i) = return $ fromIntegral i
  readJSON _             = mkError "Unable to read Int8"

instance JSON Int16 where
  showJSON = JSInteger . toInteger
  readJSON (JSInteger i) = return $ fromIntegral i
  readJSON _             = mkError "Unable to read Int16"

instance JSON Int32 where
  showJSON = JSInteger . toInteger
  readJSON (JSInteger i) = return $ fromIntegral i
  readJSON _             = mkError "Unable to read Int32"

instance JSON Int64 where
  showJSON = JSInteger . toInteger
  readJSON (JSInteger i) = return $ fromIntegral i
  readJSON _             = mkError "Unable to read Int64"

-- -----------------------------------------------------------------

instance JSON Double where
  showJSON = JSRational
  readJSON (JSRational d) = return d
  readJSON _              = mkError "Unable to read Double"
    -- can't use JSRational here, due to ambiguous '0' parse
    -- it will parse as Integer.

instance JSON Float where
  showJSON = JSRational . (realToFrac :: Float -> Double)
  readJSON (JSRational r) = return $ (realToFrac :: Double -> Float) r
  readJSON _              = mkError "Unable to read Float"

-- -----------------------------------------------------------------
-- Sums

instance (JSON a) => JSON (Maybe a) where
  readJSON (JSObject (JSONObject o)) = case "just" `lookup` o of
      Just x -> Just <$> readJSON x
      _      -> case "nothing" `lookup` o of
          Just JSNull -> return Nothing
          _           -> mkError "Unable to read Maybe"
  readJSON _ = mkError "Unable to read Maybe"
  showJSON (Just x) = JSObject $ JSONObject [("just", showJSON x)]
  showJSON Nothing  = JSObject $ JSONObject [("nothing", JSNull)]

instance (JSON a, JSON b) => JSON (Either a b) where
  readJSON (JSObject (JSONObject o)) = case "left" `lookup` o of
      Just a  -> Left <$> readJSON a
      Nothing -> case "right" `lookup` o of
          Just b  -> Right <$> readJSON b
          Nothing -> mkError "Unable to read Either"
  readJSON _ = mkError "Unable to read Either"
  showJSON (Left a)  = JSObject $ JSONObject [("left",  showJSON a)]
  showJSON (Right b) = JSObject $ JSONObject [("right", showJSON b)]

-- -----------------------------------------------------------------
-- Products
instance (JSON a, JSON b) => JSON (a,b) where
  showJSON (a,b) = JSObject $ JSONObject [ (show (0 :: Int), showJSON a)
                                         , (show (1 :: Int), showJSON b)
                                         ]
  readJSON (JSObject (JSONObject o)) = case o of
      [("0",a),("1",b)] -> do x <- readJSON a
                              y <- readJSON b
                              return (x,y)
      _                 -> mkError "Unable to read Pair"
  readJSON _ = mkError "Unable to read Pair"

instance (JSON a, JSON b, JSON c) => JSON (a,b,c) where
  showJSON (a,b,c) = JSObject $ JSONObject
      [ (tag 0, showJSON a)
      , (tag 1, showJSON b)
      , (tag 2, showJSON c)
      ]
    where tag i = show (i :: Int)
  readJSON (JSObject (JSONObject o)) = case o of
      [("0",a),("1",b),("2",c)] -> do x <- readJSON a
                                      y <- readJSON b
                                      z <- readJSON c
                                      return (x,y,z)
      _                         -> mkError "Unable to read Triple"
  readJSON _ = mkError "Unable to read Triple"

-- -----------------------------------------------------------------
-- List-like types

instance JSON a => JSON [a] where
  showJSON = JSArray . map showJSON
  readJSON (JSArray as) = mapM readJSON as
  readJSON _            = mkError "Unable to read List"

instance (Ord a, JSON a, JSON b) => JSON (M.Map a b) where
  showJSON = showJSON . M.toList
  readJSON a@(JSArray _) = M.fromList <$> readJSON a
  readJSON _ = mkError "Unable to read Map"

instance JSON I.IntSet where
  showJSON = showJSON . I.toList
  readJSON a@(JSArray _) = I.fromList <$> readJSON a
  readJSON _ = mkError "Unable to read IntSet"

-- -----------------------------------------------------------------
-- ByteStrings

instance JSON S.ByteString where
  showJSON = JSString . JSONString . S.unpack
  readJSON (JSString (JSONString s)) = return $ S.pack s
  readJSON _ = mkError "Unable to read ByteString"

instance JSON L.ByteString where
  showJSON = JSString . JSONString . L.unpack
  readJSON (JSString (JSONString s)) = return $ L.pack s
  readJSON _ = mkError "Unable to read ByteString"
