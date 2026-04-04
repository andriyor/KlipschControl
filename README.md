# KlipschControl
 
## What's this?

The official Klipsch Connect application for IOS has a few issues.
The ones that bothered me most were:

* Slow startup + connection time (5.5 seconds)
* Regularly fails to find and connect to the speaker
* The interface is relatively complex for something which should be a simple remote control

This is an IOS app that serves as a remote control specifically for the Klipsch The Three Plus, with a limited interface that starts up in < 1 second.

## How did we get here?

At first I wanted to control my Klipsch The Three Plus with Home Assistant, but this didn't work.
After some sleuthing, I learned that [BlueZ doesn't play well with this device](https://github.com/bluez/bluez/issues/712), even though Android, MacOS and IOS worked fine.

With this in mind, I settled on building a very simple app to act as a remote control.

## Limitations

In order to remain a simple remote control, I've implemented a subset of features of the official app.
Because of this, it will be of little use even to other Klipsch The Three Plus owners.
For example, it only support the inputs I use (Digital and USB Computer).


# TODO

- [ ] read volume level from a speaker
- [x] fix bluetooth connection