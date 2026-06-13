module PlasmaSafe.Manifest
  ( writeManifest
  , readManifest
  ) where

import Data.Aeson
import qualified Data.ByteString.Lazy as BL
import PlasmaSafe.Types

writeManifest :: FilePath -> SnapshotManifest -> IO ()
writeManifest path manifest =
  BL.writeFile path (encode manifest)

readManifest :: FilePath -> IO (Either String SnapshotManifest)
readManifest path = eitherDecode <$> BL.readFile path
