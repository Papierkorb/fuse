# Sample code

This directory contains examples on how to use FUSE.  Start with `simple.cr`
to get a feel for a bare-bones file system.

**Important** Sample code is **not** licensed under the MIT license.  Instead,
The **Mozilla Public License Version 2** ("MPL-2") is used.  Please consult the
`LICENSE` file in this directory for details.

## Ext2

An example implementation for ext2 is given in `ext2.cr`.  This file focuses on
the interaction with FUSE, please see the files in the `ext2/` sub-directory for
implementation details.  The implementation is simple and read-only, but should
be enough for sample purposes :)

### How to try

```sh
# Create an empty file.  You can change the size of 64M to something else.
truncate -s64M ext2.img

# Format it
mkfs.ext2 ext2.img

# Now mount it writable
mkdir mnt
sudo mount ext2.img mnt

# Copy some files into it
sudo cp -r ../src/* mnt

# Unmount it
sudo umount mnt

# And now finally, use the sample
crystal run ext2.cr -- ext2.img -d -s -f mnt

# Now inspect mnt/ in another terminal window
ls mnt
cat mnt/fuse.cr
# ...
```
