## DNMKIT

[![Build Status](https://travis-ci.org/jsbean/DNMKit.svg)](https://travis-ci.org/jsbean/DNMKit)

iPad based music notation renderer. Work-in-progress.

### Create a file

Build and run **DNM Text Editor**. If that doesn't work, file an issue.

To create an account (which will enable you to transfer scores to any device), create a username and password. This will create an account within [Parse](https://github.com/ParsePlatform).

You can work offline, saving files to your computer locally. Use filename extension: `.dnm`.

When you save a file (and are logged in), the score will be saved in the cloud, to be displayed on an iPad elsewhere.



### Author a score

**Add a title**:
```
Title: This is my Title
```

This is the title which will show up on the iPad ScoreSelector to be chosen from by the performer.

N.B.: Richer metadata to be added over time (Composer, Dates, Ensembles, notes for Electronics, etc.).

**Declare Performers** (humans doing things) with:    
- `Performer identifier` (string, I've been using two uppercase letters)
- `1...n` pairs of
    - `Instrument identifier` (string, I've been using two lowercase letters)
    - `InstrumentTypes` (note: these `InstrumentTypes` must strictly match an item in this [list](https://github.com/jsbean/DNMKit/issues/18).)


**Example**:

Add a performer and their instruments: (Violinist who is just playing Violin)

```Swift
P: VN vn Violin
```

Add another performer: (Cellist who is just playing Violoncello)

```Swift
P: VN vn Violin
P: VC vc Violoncello
```

Add another instrument to a performer's arsenal, perhaps a foot-pedal: 

```Swift
P: VN vn Violin
P: VC vc Violoncello cc ContinuousController
```

#### Start a piece

`#` Add a Measure (you don't need to know the length, it gets calculated based on what's inside)

**Declare where to put a new event**
- `|` Start new rhythm on beat of current measure (optional if first rhythm of measure)
- `+` Start new rhythm after the last rhythm
- `-` Start new rhythm at the onset of the last rhythm (not supported yet, not tested)

**Start a rhythmic event**

`b s` Create a rhythmic container with the duration of Beats (`b`) and Subdivision value (`s`). Currently, only powers-of-two are allowed (`4, 8, 16, 32` etc...).

**Example**: `3 8`: Three eighth notes, or a dotted quarter.


To this point, we have only created a container of events, but we haven't actually create any events yet.

```Swift
# // start measure
| 3 8 // create dotted quarter rhythm container, starting on the downbeat

```

**Declare who is doing the rhythm**
```Swift
| 3 8 VN vn // PerformerID: VN, InstrumentID: vn (InstrumentType: Violin)
```

or

```Swift
| 3 8 VC cc // PerformerID: VC, InstrumentID: cc (InstrumentType: ContinuousController)
```

**Add events**

To add events, we indent and start with the relative durational value of an event.

```Swift
| 1 8 VN vn
    1 // relative durational value of 1
```

**Add ```Components``` to the rhythmic values**

**Top-level commands**
- `*` Rest
- `p` Pitch
    - Float values equivalent to MIDI values (60 = middle-c, 62 = d above middle-c)
- `a` Articulation
    - `>`
    - `.`
    - `-`
- `d` DynamicMarking
    - Any combination of values `opmf` (e.g., `fff`, `ppp`, `mp`, `offfp`)
    - Spanner{Start/Stop} `[`, `]`
- `(` Slur start
- `)` Slur stop
- `->` Start a durational extension ("tie") -- this will be deprecated soon, as it is superfluous
- `<-` Stop a durational extension ("tie")

```Swift
| 2 8 VN vn
    1 p 60 // do
    1 p 62 // re 
    1 p 64 // mi
```

In this case, we use the `p` command to declare a pitch value. Currently, MIDI values are the supported type. 

In the near future, string representations of pitch will be supported (e.g., `c_q#_up_4` = 60.75)

<img src="/img/do_re_mi.png" height="200">

And a little more complicated:

```Swift
| 2 8 VN vn
    1 p 60 a > . d fff [
    1 p 62 a .
    1 p 64 a - d ppp ] ->

+ 1 8 // PerformerID and InstrumentID remembered here
    1 <-
```

<img src="/img/do_re_mi_plus.png" height="200">

```Swift
P: VN vn Violin
P: VC vc Violoncello

#
| 2 8 VN vn
    1 p 60 a > . d fff [
    1 p 62 a .
    1 p 64 a - d ppp ] ->

+ 1 8
    1 <-

| 3 8 VC vc
    4 p 55.25 a - d p [ (
    1 p 60.5 a - > d f ] [ ) ->
    2 --
        1 <-
        3 p 41 a > d pp ] (
        1 p 59.75 a . d pppp )


```

<img src="/img/do_re_mi_plus_plus.png" height="275">

---

#### Projects

* **DNMMODEL**: iOS / OSX framework that includes:
    * Model of music
    * Parser for DNMShorthand
    * [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) for JSON i/o
    

* **DNM_iOS**: iOS application for graphical representation of music

* **DNM Text Editor**: Simple text editor with text highlighting specific to DNMShorthand

