---
layout: post
title: My Dev Environment
tags: dotfiles shell
---

I spend a lot of time on my computer, and have built up some fairly
opinionated ways of how I like my system set up. Nearly everything
here is managed through my [dotfiles](https://github.com/bradschwartz/dotfiles).

## My System

```bash
$ neofetch 
                    'c.          brad@Brads-MBP.lan 
                 ,xNMM.          ------------------ 
               .OMMMMo           OS: macOS 13.3.1 22E261 arm64 
               OMMM0,            Host: MacBookPro18,3 
     .;loddo:' loolloddol;.      Kernel: 22.4.0 
   cKMMMMMMMMMMNWMMMMMMMMMM0:    Uptime: 1 day, 1 hour 
 .KMMMMMMMMMMMMMMMMMMMMMMMWd.    Packages: 172 (brew) 
 XMMMMMMMMMMMMMMMMMMMMMMMX.      Shell: bash 5.2.15 
;MMMMMMMMMMMMMMMMMMMMMMMM:       Resolution: 1512x982 
:MMMMMMMMMMMMMMMMMMMMMMMM:       DE: Aqua 
.MMMMMMMMMMMMMMMMMMMMMMMMX.      WM: Rectangle 
 kMMMMMMMMMMMMMMMMMMMMMMMMWd.    Terminal: Apple_Terminal 
 .XMMMMMMMMMMMMMMMMMMMMMMMMMMk   Terminal Font: SFMonoPowerline-Medium 
  .XMMMMMMMMMMMMMMMMMMMMMMMMK.   CPU: Apple M1 Pro 
    kMMMMMMMMMMMMMMMMMMMMMMd     GPU: Apple M1 Pro 
     ;KMMMMMMMWXXWMMMMMMMk.      Memory: 3818MiB / 32768MiB 
       .cooc,.    .,coo:.
```

## Installing Tools

For now, I use [Homebrew](https://brew.sh) to manage installing as
much as possible. I recently had to bootstrap my machine from start and outside
of a half dozen commands and installing brew, everything is managed for me.

I leverage [Homebrew Bundle](https://github.com/Homebrew/homebrew-bundle) especially
hard - it essentially lets me generate manifests of everything I have installed
in a [Brewfile](https://github.com/bradschwartz/dotfiles/blob/HEAD/Brewfile)
(and accompanying lockfile).

Definitely interested in checking out some of the more fancy package managers,
like Nix or Guix, but they seem to have a much steeper learning curve
and installation process - for now I'm happy with Homebrew and no build daemons.


## Writing Code

For the last few years I've been rocking [VSCode](https://code.visualstudio.com/).
I played around with the a full FOSS build of it ([VSCodium](https://vscodium.com/))
but found it was more trouble than it was worth getting extensions installed,
and missed some of the propietary only ones. Again, all of those configurations
are stored in my [dotfiles](https://github.com/bradschwartz/dotfiles/blob/HEAD/visual-studio-code/Library/Application%20Support/Code/User/settings.json).

When I first started programming as an intern in college, my boss
made me use Emacs - and I definitely still would say it won the editor war ;).
I've been getting back into it recently and have really figured out all
my prior shortcomings were due to not going deep into customization.
I just upgrade to Emacs version 29 (unreleased) for a lot of the new builtin
capabilities like `use-package` for package management, native compilation,
and `tramp-container`. The tramp-contaner package is especially powerful
with recent tools like DevContainers, which I'm slowly introducing to my
workflows. 

Emacs customizations has been great to really setup my environment the way I like it,
while also not hiding how everything is working. Installing a new package,
adding a language server for it, and hooking up emacs to actually run the LSP
is super easy. For Rust it was as simple as:

```bash
## Install the language server for Rust and ensure it's in the PATH
$ brew install rust-analyzer
```

```elisp
;; $HOME/emacs.d/init.el
;; Install rust major mode and configure the built-in LSP server to run!
(use-package rust-mode
	:hook ((rust-mode . eglot-ensure))
)
```

## Shell

I'm a strong Bash purist, although I always make sure to upgrade from the
MacOS default of 3.2 to whatever is latest, currently 5.x. I've played around
with a few of the popular terminal emulators like
[Alacritty](https://github.com/alacritty/alacritty), [Warp](https://www.warp.dev/),
and [Wezterm](https://wezfurlong.org/wezterm/), but haven't found a convincing
enough reason to stop using the default Terminal.app.

All installed through Homebrew and in no particular order, some of my must-have
CLI tools that I always reach for:

1. [brew](https://brew.sh) - how everything is (un)installed
1. [ripgrep](https://github.com/BurntSushi/ripgrep) - a better `grep`
1. [bat](https://github.com/sharkdp/bat) - a better `cat`
1. [starship](https://starship.rs/) - a fast shell prompt with sane defaults
1. [stow](https://www.gnu.org/software/stow/) - symlink manager and how I manage my dotfiles!
