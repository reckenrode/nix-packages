This repository contains packages that I use in my [nixos-configs][1].  They were moved out of my
config in case they might be useful to other people.  However, if they do prove useful, those
packages should and may be upstreamed into [nixpkgs][2] then removed from this repository.

The repository structure is patterned after the simple package paths organization described in
[RFC-140][3].  As RFC-140 evolves, this repo will try to keep up with it, but it may drift out of
sync. `pkgsCross` and other package sets (such as `pkgsx86_64Darwin`) are also provided for
connivence.

[1]: https://github.com/reckenrode/nixos-configs/
[2]: https://github.com/NixOS/nixpkgs/
[3]: https://github.com/nixpkgs-architecture/rfcs/blob/master/rfcs/0140-simple-package-paths.md
