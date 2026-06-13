module PlasmaSafe.Paths
  ( getHomeDir
  , getStateDir
  , getSnapshotRoot
  , snapshotDir
  , snapshotFilesDir
  , manifestPath
  , pacmanPath
  ) where

import System.Directory
import System.Environment
import System.FilePath

getHomeDir :: IO FilePath
getHomeDir = do
  fakeHome <- lookupEnv "PLASMASAFE_HOME"
  case fakeHome of
    Just h  -> pure h
    Nothing -> getHomeDirectory

getStateDir :: IO FilePath
getStateDir = do
  fakeHome <- lookupEnv "PLASMASAFE_HOME"
  case fakeHome of
    Just h -> pure (h </> ".local" </> "state")
    Nothing -> do
      xdgState <- lookupEnv "XDG_STATE_HOME"
      case xdgState of
        Just p  -> pure p
        Nothing -> do
          home <- getHomeDirectory
          pure (home </> ".local" </> "state")

getSnapshotRoot :: IO FilePath
getSnapshotRoot = do
  stateDir <- getStateDir
  pure (stateDir </> "plasmasafe" </> "snapshots")

snapshotDir :: FilePath -> FilePath -> FilePath
snapshotDir root sid = root </> sid

snapshotFilesDir :: FilePath -> FilePath
snapshotFilesDir snap = snap </> "files"

manifestPath :: FilePath -> FilePath
manifestPath snap = snap </> "manifest.json"

pacmanPath :: FilePath -> FilePath
pacmanPath snap = snap </> "pacman.txt"
