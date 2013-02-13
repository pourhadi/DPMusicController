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
This is still a work in progress. I put it on GitHub so I have a central place to store it -- but right now, some functions may not be finished, some notifications may not be sent out, etc.

Please feel free to install it and play with it, but be aware it's incomplete and probably buggy.

Features
---------
* iPod library wrapper for easy access to, presentation of, and playing of songs, artists, and albums
* Full playlist management
* Core Audio-based player (DPMusicPlayer)
* Crossfade, EQ
* Central controller (DPMusicController class) for managing all of the individual functions

Usage
-------
### Install
To install, drop the DPMusicController into your project and import "DPMusicController.h" wherever you plan to access the controller. You'll also need to link the MediaPlayer, CoreMedia,  AudioToolbox, and AVFoundation frameworks.

### Basic use
Access DPMusicController via [DPMusicController sharedController]. The first time you call this, the built-in library manager will import the device's songs, artists, and albums, and send out a notification (see DPMusicConstants.h) when the library has been loaded.

### Accessing library items
The DPMusicController instance has properties for songs, artists, and albums, as well as their indexed counter-parts (i.e., for UITableView indexing). These properties are arrays of DPMusicItemSong, DPMusicItemArtist, and DPMusicItemAlbum instances, respectively, and the indexed arrays contain DPMusicItemIndexSections with the appropriate DPMusicItem instances in their 'items' properties.

### Creating and modifying the playlist
Pass a DPMusicItemSong instance to -addSong:error:, -insertSong:atIndex:indexType:error:, and -removeSong:error: to manipulate the playlist. Similarly, you can pass a DPMusicItemCollection subclass (such as DPMusicItemArtist or DPMusicItemAlbum) to -addSongCollection:error: and similar methods to insert and arrange groups of songs into the playlist.

### Understanding the Playhead and playlist indexes
The playhead is the index of the now-playing song in the playlist array.

There are two ways to express indexes related to the playlist:

#### DPMusicControllerIndexTypePlaylistIndex
This is the literal index of the song in the playlist array.

#### DPMusicIndexTypeIndexRelativeToPlayhead
This is the index of the song relative to the playhead. So if the playhead is 4, a DPMusicIndexTypeIndexRelativeToPlayhead index of 2 would represent the literal index of 6 (4+2) in the playlist array.

(more coming soon)

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
