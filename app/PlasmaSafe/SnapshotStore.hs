module PlasmaSafe.SnapshotStore
  ( findSnapshotDir
  , findSnapshotDirInRoot
  , endsWith
  ) where

import PlasmaSafe.Paths
import PlasmaSafe.Types
import System.Directory
import System.FilePath

findSnapshotDir :: SnapshotName -> IO (Maybe FilePath)
findSnapshotDir wanted = do
  root <- getSnapshotRoot
  findSnapshotDirInRoot root wanted

findSnapshotDirInRoot :: FilePath -> SnapshotName -> IO (Maybe FilePath)
findSnapshotDirInRoot root wanted = do
  exists <- doesDirectoryExist root
  if not exists
    then pure Nothing
    else do
      names <- listDirectory root
      let exactMatches = filter (== wanted) names
      let suffixMatches = filter (endsWith ("_" ++ wanted)) names

      case exactMatches ++ suffixMatches of
        []    -> pure Nothing
        x : _ -> pure (Just (root </> x))

endsWith :: String -> String -> Bool
endsWith suffix value =
  length suffix <= length value &&
  suffix == drop (length value - length suffix) value
