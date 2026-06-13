module PlasmaSafe.Doctor
  ( runDoctor
  ) where

import Control.Monad
import PlasmaSafe.Paths
import PlasmaSafe.Profile
import PlasmaSafe.Types
import System.Directory
import System.Environment
import System.FilePath

runDoctor :: IO ()
runDoctor = do
  putStrLn "PlasmaSafe Doctor"
  putStrLn "================="
  putStrLn ""

  checkHome
  putStrLn ""

  checkSession
  putStrLn ""

  checkTools
  putStrLn ""

  checkSnapshotStorage
  putStrLn ""

  checkProfilePaths defaultProfile

checkHome :: IO ()
checkHome = do
  home <- getHomeDir
  putStrLn "Home"
  putStrLn "----"
  putStrLn ("PlasmaSafe home: " ++ home)

  homeExists <- doesDirectoryExist home
  putCheck "home directory exists" homeExists

  fakeHome <- lookupEnv "PLASMASAFE_HOME"
  case fakeHome of
    Just value -> do
      putCheck "PLASMASAFE_HOME is set" True
      putStrLn ("       value: " ++ value)
    Nothing ->
      putCheck "PLASMASAFE_HOME is not set, using real home" True

checkSession :: IO ()
checkSession = do
  putStrLn "Session"
  putStrLn "-------"

  sessionType <- lookupEnv "XDG_SESSION_TYPE"
  desktop <- lookupEnv "XDG_CURRENT_DESKTOP"
  sessionDesktop <- lookupEnv "XDG_SESSION_DESKTOP"
  kdeFullSession <- lookupEnv "KDE_FULL_SESSION"
  plasmaPlatform <- lookupEnv "PLASMA_PLATFORM"

  printEnv "XDG_SESSION_TYPE" sessionType
  printEnv "XDG_CURRENT_DESKTOP" desktop
  printEnv "XDG_SESSION_DESKTOP" sessionDesktop
  printEnv "KDE_FULL_SESSION" kdeFullSession
  printEnv "PLASMA_PLATFORM" plasmaPlatform

  putStrLn ""

  case sessionType of
    Just "wayland" ->
      putCheck "Wayland session detected" True

    Just "x11" ->
      putCheck "X11 session detected" True

    Just other -> do
      putCheck "known session type" False
      putStrLn ("       unknown XDG_SESSION_TYPE: " ++ other)

    Nothing ->
      putCheck "XDG_SESSION_TYPE is set" False

  case desktop of
    Just value ->
      if containsWord "KDE" value || containsWord "plasma" value
        then putCheck "KDE/Plasma desktop detected" True
        else do
          putCheck "KDE/Plasma desktop detected" False
          putStrLn ("       XDG_CURRENT_DESKTOP=" ++ value)

    Nothing ->
      putCheck "XDG_CURRENT_DESKTOP is set" False

checkTools :: IO ()
checkTools = do
  putStrLn "External tools"
  putStrLn "--------------"

  checkCommand "pacman" "used to save package list"
  checkCommand "diff" "used to compare snapshots"
  checkCommand "tar" "used to export and import snapshots"

checkSnapshotStorage :: IO ()
checkSnapshotStorage = do
  putStrLn "Snapshot storage"
  putStrLn "----------------"

  root <- getSnapshotRoot
  putStrLn ("Snapshot root: " ++ root)

  exists <- doesDirectoryExist root
  putCheck "snapshot root exists" exists

  writable <- canCreateDirectory root
  putCheck "snapshot root is writable or can be created" writable

  when exists $ do
    names <- listDirectory root
    putStrLn ("       snapshots found: " ++ show (length names))

checkProfilePaths :: Profile -> IO ()
checkProfilePaths profile = do
  putStrLn "Profile paths"
  putStrLn "-------------"

  home <- getHomeDir

  putStrLn "Files:"
  forM_ (profileFiles profile) $ \rel -> do
    exists <- doesFileExist (home </> rel)
    putCheck rel exists

  putStrLn ""
  putStrLn "Directories:"
  forM_ (profileDirs profile) $ \rel -> do
    exists <- doesDirectoryExist (home </> rel)
    putCheck rel exists

checkCommand :: String -> String -> IO ()
checkCommand command purpose = do
  result <- findExecutable command
  case result of
    Just path -> do
      putCheck (command ++ " found") True
      putStrLn ("       path: " ++ path)
      putStrLn ("       use:  " ++ purpose)

    Nothing -> do
      putCheck (command ++ " found") False
      putStrLn ("       use:  " ++ purpose)

canCreateDirectory :: FilePath -> IO Bool
canCreateDirectory path = do
  exists <- doesDirectoryExist path
  if exists
    then pure True
    else do
      let parent = takeDirectory path
      if parent == path
        then pure False
        else do
          parentExists <- doesDirectoryExist parent
          if parentExists
            then pure True
            else canCreateDirectory parent

printEnv :: String -> Maybe String -> IO ()
printEnv name value =
  case value of
    Just v  -> putStrLn (name ++ "=" ++ v)
    Nothing -> putStrLn (name ++ "=<not set>")

putCheck :: String -> Bool -> IO ()
putCheck label ok =
  putStrLn (status ++ " " ++ label)
  where
    status =
      if ok
        then "[OK]  "
        else "[WARN]"

containsWord :: String -> String -> Bool
containsWord needle haystack =
  lowerString needle `isIn` lowerString haystack

isIn :: String -> String -> Bool
isIn needle haystack =
  any (prefixOf needle) (tailsOf haystack)

prefixOf :: String -> String -> Bool
prefixOf [] _ = True
prefixOf _ [] = False
prefixOf (x:xs) (y:ys) =
  x == y && prefixOf xs ys

tailsOf :: [a] -> [[a]]
tailsOf [] = [[]]
tailsOf xs@(_:rest) = xs : tailsOf rest

lowerString :: String -> String
lowerString =
  map toLowerAscii

toLowerAscii :: Char -> Char
toLowerAscii c
  | c >= 'A' && c <= 'Z' = toEnum (fromEnum c + 32)
  | otherwise = c
