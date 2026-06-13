{-# LANGUAGE DeriveGeneric #-}

module PlasmaSafe.Types
  ( SnapshotName
  , SnapshotId
  , RelativePath
  , SnapshotManifest(..)
  , SnapshotEntry(..)
  , EntryType(..)
  , Profile(..)
  ) where

import Data.Aeson
import Data.Text (Text)
import Data.Time
import GHC.Generics

type SnapshotName = String
type SnapshotId = String
type RelativePath = FilePath

data EntryType
  = EntryFile
  | EntryDirectory
  deriving (Show, Eq, Generic)

instance ToJSON EntryType
instance FromJSON EntryType

data SnapshotEntry = SnapshotEntry
  { entrySourceRelative :: RelativePath
  , entryStoredRelative :: RelativePath
  , entryType           :: EntryType
  , entryExists         :: Bool
  } deriving (Show, Eq, Generic)

instance ToJSON SnapshotEntry
instance FromJSON SnapshotEntry

data SnapshotManifest = SnapshotManifest
  { manifestVersion      :: Int
  , snapshotId           :: SnapshotId
  , snapshotName         :: SnapshotName
  , createdAt            :: UTCTime
  , hostName             :: Text
  , profileName          :: Text
  , entries              :: [SnapshotEntry]
  } deriving (Show, Eq, Generic)

instance ToJSON SnapshotManifest
instance FromJSON SnapshotManifest

data Profile = Profile
  { profileLabel :: Text
  , profileFiles :: [RelativePath]
  , profileDirs  :: [RelativePath]
  } deriving (Show, Eq)
