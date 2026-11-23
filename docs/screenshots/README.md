# Phone player icon comparison

These are rendered native Plasma TabBar component previews at 2× scale, using
the same desktop theme, layout and MPRIS fixtures. The labels below the tabs are
documentation annotations. They are not full desktop screenshots.

`phone-player-icons-before.png` uses the icon binding from upstream commit
`5a72f2f`. `phone-player-icons-after.png` uses the production `PlayerIcon` component.

The automatic tab uses `emblem-favorite`. Signal and NewPipe have identities
`Signal - Phone` / `NewPipe - Phone`, desktop entry `org.kde.kdeconnect.app`,
and the generic model icon. FreeTube demonstrates an empty desktop entry and
the generic model icon, with identity `FreeTube`.

The preview uses a Kora-derived icon theme. Signal and FreeTube resolve from
installed theme icons; NewPipe resolves from the optional helper's F-Droid cache.
The widget itself does not download or bundle these application icons. On other
desktops the selected icon theme and its inherited themes determine their appearance.
