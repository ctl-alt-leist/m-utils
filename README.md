# m-utils

Small macOS utilities, each in its own directory with its own `Makefile`. Every
utility builds from source with the Swift toolchain that ships with the Xcode
Command Line Tools; nothing else is required.

```sh
make install         # build and install every utility
make coffee          # build and install one
make clean
```

Apps install to `~/Applications`.

## Utilities

### coffee

A menu bar switch that keeps the Mac from sleeping. It holds the same power
assertions as `caffeinate -di`, so neither the display nor the system idles to
sleep while it is on.

The icon is an outlined cup when off and a filled cup when on, with the time
remaining beside it when a limit is set. The menu offers:

- **Indefinitely**, **1 hour**, **2 hours**, **3 hours**
- **Until…** a clock time such as `5pm`, `5:30pm`, or `17:00`; leaving the field
  empty and pressing **Start** takes the suggested `5:00pm`
- **Add 1 hour** and **Stop** while active
- **Show Countdown** to hide or show the remaining time in the menu bar
- **Launch at Login**

Quitting the app releases the assertions and lets the Mac sleep normally.

## License

MIT License - see LICENSE file for details.

---

*Claude Code was used in the development of this project.*
