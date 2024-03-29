This is a small perl/gtk3 frontend for hamlib using a minimum of external libraries.

![screenshot](https://github.com/pripyatautomations/rustyrigs/blob/main/doc/screenshot.png?raw=true)

Installing
==========
Install needed perl packages:
- sudo apt install -y libgtk3-perl libglib-perl libyaml-perl libhamlib-perl libexpect-perl

Then try it out before installing:
-	./rustyrigs

If successful, optionally install it:
-	make install

Configuring
===========
Configuration file defaults to ~/.config/rustyrigs.yaml

This can be changed with -f newfile.yaml

Most settings can be changed in the dialog, but for now it must restart to apply.

You'll probably want to quiet down the debug level in the settings.

Running
=======
Run from source tree:
	./rustyrigs

Or if installed:
	rustyrigs

For help, try rustyrigs -h

Log output will be in ~/rustyrigs.log as well as the logview window.

BUGS
====
Things that are broken but should be fixed soon:
	For now, you might need to restart for many settings to apply.
	- This is in work as we move things to rr_gtk_ui::apply()

Right now this seems to only work reasonably if you run rigctld connected to
flrig as such:
	rigctld -m 4 -P RIG -t 4532 -o &


Good luck!
~ rustyaxe
