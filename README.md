DPMusicController
=================
A library manager and Core Audio wrapper for the iOS MediaPlayer framework

Introduction
--------------
DPMusicController is the foundational base upon which OnCue, The Music Player was built. It is the result of over two years of near-full-time work dissecting the MediaPlayer, AVFoundation, and Core Audio frameworks.

When I originally developed OnCue, it never occurred to me to package its features in an open-source resource. So DPMusicController is a rough representation of the actual code used in OnCue.

DPMusicController is basically an all-in-one tool for browsing your music library, creating a playlist, and playing that playlist through Core Audio. The idea is to be able to just drop it into your Xcode project and have all the features of a powerful music player without having to spend too much time dissecting the different frameworks necessary for this kind of functionality.

Important note
------------
This is still a work in process. I put it on GitHub so I have a central place to store it -- but right now, some functions may not be finished, some notifications may not be sent out, etc.

Please feel free to install it and play with it, but be aware it's incomplete and probably buggy.

Features
---------
* iPod library wrapper for easy access to, presentation of, and playing of songs, artists, and albums
* Full playlist management
* Core Audio-based player (DPMusicPlayer)
* Crossfade, EQ
* Central controller (DPMusicController class) for managing all of the individual functions

Classes
--------
### DPMusicController
The primary controller (represented as a singleton) that manages all the functions in a single location.

### DPMusicItem
The abstract base class for representing items from the user's iPod library.

### DPMusicItemCollection
Abstract subclass of DPMusicItem for representing collections of items (i.e., artists and albums)

### DPMusicItemSong
Subclass of DPMusicItem representing an individual song in the user's iPod library.

### DPMusicItemArtist and DPMusicItemAlbum
Subclasses of DPMusicItemCollection representing the artists and albums in the user's iPod library

### DPMusicItemIndexSection
Used for indexing songs, artists, and albums, particularly for use in indexed UITableViews

### DPMusicLibraryManager
Imports and parses the user's iPod library, creating the relevant DPMusicItem objects for songs, artists, and albums, and packaging them in DPMusicItemIndexSections

### DPMusicPlayer
The Core Audio wrapper for playing iPod library items
