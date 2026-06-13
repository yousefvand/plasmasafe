{-# LANGUAGE OverloadedStrings #-}

module PlasmaSafe.Profile
  ( defaultProfile
  , minimalProfile
  , desktopProfile
  , fullProfile
  , profileByName
  , availableProfiles
  , listProfiles
  ) where

import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import PlasmaSafe.Types

minimalProfile :: Profile
minimalProfile =
  Profile
    { profileLabel = "minimal"
    , profileFiles =
        [ ".config/plasma-org.kde.plasma.desktop-appletsrc"
        , ".config/plasmarc"
        , ".config/plasmashellrc"
        , ".config/kwinrc"
        , ".config/kglobalshortcutsrc"
        , ".config/kdeglobals"
        ]
    , profileDirs = []
    }

desktopProfile :: Profile
desktopProfile =
  Profile
    { profileLabel = "desktop"
    , profileFiles =
        unique
          ( profileFiles minimalProfile
         ++ [ ".config/kscreenlockerrc"
            , ".config/dolphinrc"
            , ".config/konsolerc"
            , ".config/krunnerrc"
            , ".config/ksmserverrc"
            , ".config/kcminputrc"
            , ".config/kaccessrc"
            , ".config/breezerc"
            , ".config/Trolltech.conf"
            ]
          )
    , profileDirs =
        [ ".local/share/konsole"
        , ".local/share/plasma"
        ]
    }

fullProfile :: Profile
fullProfile =
  Profile
    { profileLabel = "full"
    , profileFiles =
        unique
          ( profileFiles desktopProfile
         ++ [ ".config/gtkrc"
            , ".config/gtkrc-2.0"
            , ".config/kactivitymanagerdrc"
            , ".config/kactivitymanagerd-statsrc"
            , ".config/kcminputrc"
            , ".config/kded5rc"
            , ".config/kded6rc"
            , ".config/khotkeysrc"
            , ".config/ksplashrc"
            , ".config/ktimezonedrc"
            , ".config/kwalletrc"
            , ".config/kwinrulesrc"
            , ".config/kxkbrc"
            , ".config/powermanagementprofilesrc"
            , ".config/systemsettingsrc"
            , ".config/mimeapps.list"
            , ".local/share/applications/mimeapps.list"
            ]
          )
    , profileDirs =
        unique
          ( profileDirs desktopProfile
         ++ [ ".local/share/color-schemes"
            , ".local/share/icons"
            , ".local/share/aurorae"
            , ".local/share/kwin"
            , ".local/share/wallpapers"
            , ".local/share/plasma-systemmonitor"
            , ".local/share/applications"
            ]
          )
    }

defaultProfile :: Profile
defaultProfile = desktopProfile

availableProfiles :: [String]
availableProfiles =
  [ "minimal"
  , "desktop"
  , "full"
  ]

allProfiles :: [Profile]
allProfiles =
  [ minimalProfile
  , desktopProfile
  , fullProfile
  ]

profileByName :: String -> Either String Profile
profileByName rawName =
  case T.toLower (T.pack rawName) of
    "minimal" ->
      Right minimalProfile

    "desktop" ->
      Right desktopProfile

    "full" ->
      Right fullProfile

    unknown ->
      Left
        ( "Unknown profile: " ++ T.unpack unknown
       ++ "\nAvailable profiles: " ++ unwords availableProfiles
        )

listProfiles :: IO ()
listProfiles = do
  putStrLn "Available PlasmaSafe profiles"
  putStrLn "============================"
  putStrLn ""

  mapM_ printProfile allProfiles

printProfile :: Profile -> IO ()
printProfile profile = do
  TIO.putStrLn ("Profile: " <> profileLabel profile)
  putStrLn ("Files: " ++ show (length (profileFiles profile)))
  putStrLn ("Directories: " ++ show (length (profileDirs profile)))
  putStrLn ""

  putStrLn "  Files:"
  mapM_ (\path -> putStrLn ("    - " ++ path)) (profileFiles profile)

  putStrLn ""
  putStrLn "  Directories:"
  if null (profileDirs profile)
    then putStrLn "    - <none>"
    else mapM_ (\path -> putStrLn ("    - " ++ path)) (profileDirs profile)

  putStrLn ""

unique :: Eq a => [a] -> [a]
unique =
  foldr addIfMissing []
  where
    addIfMissing item acc =
      if item `elem` acc
        then acc
        else item : acc
