module Fuse
  @[Link("fuse")]
  lib Binding
    type Handle = Void
    type Command = Void
    type Session = Void
    type Chan = Void
    type Pollhandle = Void

    struct Context
      fuse : Handle*
      uid : LibC::UidT
      gid : LibC::GidT
      pid : LibC::PidT
      private_data : Void*
      umask : LibC::ModeT
    end

    @[Flags]
    enum FileInfoOption : LibC::UInt
      DirectIo = 0x1
      KeepCache = 0x2
      Flush = 0x4
      NonSeekable = 0x8
    end

    struct FileInfo
      flags : LibC::Int
      writepage : LibC::Int
      options : FileInfoOption
      file_handle : LibC::UInt64T
      lock_owner : LibC::UInt64T
    end

    struct ConnInfo
      proto_major : LibC::UInt
      proto_minor : LibC::UInt
      async_read : LibC::UInt
      max_write : LibC::UInt
      max_readahead : LibC::UInt
      capable : LibC::UInt
      want : LibC::UInt
      max_background : LibC::UInt
      congestion_threshold : LibC::UInt
      reserved : LibC::UInt[23]
    end

    alias FillDir = Void*, LibC::Char*, LibC::Stat*, LibC::OffT -> LibC::Int

    alias DeprecatedFunc = Void*
    alias NotSupportedFunc = Void*

    alias GetAttr = LibC::Char*, LibC::Stat* -> LibC::Int
    alias Readlink = LibC::Char*, LibC::Char*, LibC::SizeT -> LibC::Int
    alias Mknod = LibC::Char*, LibC::ModeT, LibC::DevT -> LibC::Int
    alias Mkdir = LibC::Char*, LibC::ModeT -> LibC::Int
    alias Unlink = LibC::Char* -> LibC::Int
    alias Rmdir =  LibC::Char* -> LibC::Int
    alias Symlink = LibC::Char*, LibC::Char* -> LibC::Int
    alias Rename = LibC::Char*, LibC::Char* -> LibC::Int
    alias Link = LibC::Char*, LibC::Char* -> LibC::Int
    alias Chmod = LibC::Char*, LibC::ModeT -> LibC::Int
    alias Chown = LibC::Char*, LibC::UidT, LibC::GidT -> LibC::Int

    alias Truncate = LibC::Char*, LibC::OffT -> LibC::Int
    alias Open = LibC::Char*, FileInfo* -> LibC::Int
    alias Read = LibC::Char*, LibC::Char*, LibC::SizeT, LibC::OffT, FileInfo* -> LibC::Int
    alias Write = LibC::Char*, LibC::Char*, LibC::SizeT, LibC::OffT, FileInfo* -> LibC::Int
    # alias Statfs = LibC::Char*, Statvfs* -> LibC::Int
    alias Flush = LibC::Char*, FileInfo* -> LibC::Int
    alias Release = LibC::Char*, FileInfo* -> LibC::Int
    alias Fsync = LibC::Char*, LibC::Int, FileInfo* -> LibC::Int

    alias Setxattr = LibC::Char*, LibC::Char*, LibC::Char*, LibC::SizeT, LibC::Int -> LibC::Int
    alias Getxattr = LibC::Char*, LibC::Char*, LibC::Char*, LibC::SizeT -> LibC::Int
    alias Listxattr = LibC::Char*, LibC::Char*, LibC::SizeT -> LibC::Int
    alias Removexattr = LibC::Char*, LibC::Char* -> LibC::Int

    alias Opendir = LibC::Char*, FileInfo* -> LibC::Int
    alias Readdir = LibC::Char*, Void*, FillDir, LibC::OffT, FileInfo* -> LibC::Int
    alias Releasedir = LibC::Char*, FileInfo* -> LibC::Int
    alias Fsyncdir = LibC::Char*, LibC::Int, FileInfo* -> LibC::Int

    alias Init = ConnInfo* -> Void*
    alias Destroy = Void* -> Void

    alias Access = LibC::Char*, LibC::Int -> LibC::Int
    alias Create = LibC::Char*, LibC::ModeT, FileInfo* -> LibC::Int
    alias Ftruncate = LibC::Char*, LibC::OffT, FileInfo* -> LibC::Int
    alias Fgetattr = LibC::Char*, LibC::Stat*, FileInfo* -> LibC::Int

    alias Lock = LibC::Char*, FileInfo*, LibC::Int, LibC::Flock -> LibC::Int
    alias Utimens = LibC::Char*, LibC::Timespec[2] -> LibC::Int
    alias Bmap = LibC::Char*, LibC::SizeT, LibC::UInt64T* -> LibC::Int

    alias Ioctl = LibC::Char*, LibC::Int, Void*, FileInfo*, LibC::UInt, Void* -> LibC::Int
    alias Poll = LibC::Char*, FileInfo*, Pollhandle*, LibC::UInt* -> LibC::Int

    alias Flock = LibC::Char*, FileInfo*, LibC::Int -> LibC::Int
    alias Fallocate = LibC::Char*, LibC::Int, LibC::OffT, LibC::OffT, FileInfo* -> LibC::Int

    @[Flags]
    enum OperationsFlag : LibC::UInt
      # Flag indicating that the filesystem can accept a NULL path
      # as the first argument for the following operations:
      # read, write, flush, release, fsync, readdir, releasedir,
      # fsyncdir, ftruncate, fgetattr, lock, ioctl and poll
      #
      # If this flag is set these operations continue to work on
      # unlinked files even if "-ohard_remove" option was specified.
      NullpathOk = 0x01

      # Flag indicating that the path need not be calculated for
      # the following operations:
      #
      # read, write, flush, release, fsync, readdir, releasedir,
      # fsyncdir, ftruncate, fgetattr, lock, ioctl and poll
      #
      # Closely related to flag_nullpath_ok, but if this flag is
      # set then the path will not be calculaged even if the file
      # wasn't unlinked.  However the path can still be non-NULL if
      # it needs to be calculated for some other reason.
      NoPath = 0x02

      # Flag indicating that the filesystem accepts special
	    # UTIME_NOW and UTIME_OMIT values in its utimens operation.
      UtimeOmitOk = 0x04
    end

    struct Operations
      # Get file attributes.
      # Similar to stat().  The 'st_dev' and 'st_blksize' fields are
      # ignored.   The 'st_ino' field is ignored except if the 'use_ino'
      # mount option is given.
      getattr : GetAttr

      # Read the target of a symbolic link
      # The buffer should be filled with a null terminated string.  The
      # buffer size argument includes the space for the terminating
      # null character.  If the linkname is too long to fit in the
      # buffer, it should be truncated.  The return value should be 0
      # for success.
      readlink : Readlink

      # Deprecated, use readdir() instead
      getdir : DeprecatedFunc

      # Create a file node
      # This is called for creation of all non-directory, non-symlink
      # nodes.  If the filesystem defines a create() method, then for
      # regular files that will be called instead.
      mknod : Mknod

      # Create a directory
      # Note that the mode argument may not have the type specification
      # bits set, i.e. S_ISDIR(mode) can be false.  To obtain the
      # correct directory type bits use  mode|S_IFDIR
      mkdir : Mkdir

      # Remove a file
      unlink : Unlink

      # Remove a directory
      rmdir : Rmdir

      # Create a symbolic link
      symlink : Symlink

      # Rename a file
      rename : Rename

      # Create a hard link to a file
      link : Link

      # Change the permission bits of a file
      chmod : Chmod

      # Change the owner and group of a file
      chown : Chown

      # Change the size of a file
      truncate : Truncate

      # Change the access and/or modification times of a file
      # Deprecated, use utimens() instead.
      utime : DeprecatedFunc

      # File open operation
      # No creation (O_CREAT, O_EXCL) and by default also no
      # truncation (O_TRUNC) flags will be passed to open(). If an
      # application specifies O_TRUNC, fuse first calls truncate()
      # and then open(). Only if 'atomic_o_trunc' has been
      # specified and kernel version is 2.6.24 or later, O_TRUNC is
      # passed on to open.
      # Unless the 'default_permissions' mount option is given,
      # open should check if the operation is permitted for the
      # given flags. Optionally open may also return an arbitrary
      # filehandle in the fuse_file_info structure, which will be
      # passed to all file operations.
      # Changed in version 2.2
      open : Open

      # Read data from an open file
      # Read should return exactly the number of bytes requested except
      # on EOF or error, otherwise the rest of the data will be
      # substituted with zeroes.   An exception to this is when the
      # 'direct_io' mount option is specified, in which case the return
      # value of the read system call will reflect the return value of
      # this operation.
      # Changed in version 2.2
      read : Read

      # Write data to an open file
      # Write should return exactly the number of bytes requested
      # except on error.   An exception to this is when the 'direct_io'
      # mount option is specified (see read operation).
      # Changed in version 2.2
      write : Write

      # Get file system statistics
      # The 'f_frsize', 'f_favail', 'f_fsid' and 'f_flag' fields are ignored
      # Replaced 'struct statfs' parameter with 'struct statvfs' in
      # version 2.5
      statfs : NotSupportedFunc

      # Possibly flush cached data
      # BIG NOTE: This is not equivalent to fsync().  It's not a
      # request to sync dirty data.
      # Flush is called on each close() of a file descriptor.  So if a
      # filesystem wants to return write errors in close() and the file
      # has cached dirty data, this is a good place to write back data
      # and return any errors.  Since many applications ignore close()
      # errors this is not always useful.
      # NOTE: The flush() method may be called more than once for each
      # open().  This happens if more than one file descriptor refers
      # to an opened file due to dup(), dup2() or fork() calls.  It is
      # not possible to determine if a flush is final, so each flush
      # should be treated equally.  Multiple write-flush sequences are
      # relatively rare, so this shouldn't be a problem.
      # Filesystems shouldn't assume that flush will always be called
      # after some writes, or that if will be called at all.
      # Changed in version 2.2
      flush : Flush

      # Release an open file
      # Release is called when there are no more references to an open
      # file: all file descriptors are closed and all memory mappings
      # are unmapped.
      # For every open() call there will be exactly one release() call
      # with the same flags and file descriptor.   It is possible to
      # have a file opened more than once, in which case only the last
      # release will mean, that no more reads/writes will happen on the
      # file.  The return value of release is ignored.
      # Changed in version 2.2
      release : Release

      # Synchronize file contents
      # If the datasync parameter is non-zero, then only the user data
      # should be flushed, not the meta data.
      # Changed in version 2.2
      fsync : Fsync

      # Set extended attributes
      setxattr : Setxattr

      # Get extended attributes
      getxattr : Getxattr

      # List extended attributes
      listxattr : Listxattr

      # Remove extended attributes
      removexattr : Removexattr

      # Open directory
      # Unless the 'default_permissions' mount option is given,
      # this method should check if opendir is permitted for this
      # directory. Optionally opendir may also return an arbitrary
      # filehandle in the fuse_file_info structure, which will be
      # passed to readdir, closedir and fsyncdir.
      # Introduced in version 2.3
      opendir : Opendir

      # Read directory
      # This supersedes the old getdir() interface.  New applications
      # should use this.
      # The filesystem may choose between two modes of operation:
      # 1) The readdir implementation ignores the offset parameter, and
      # passes zero to the filler function's offset.  The filler
      # function will not return '1' (unless an error happens), so the
      # whole directory is read in a single readdir operation.  This
      # works just like the old getdir() method.
      # 2) The readdir implementation keeps track of the offsets of the
      # directory entries.  It uses the offset parameter and always
      # passes non-zero offset to the filler function.  When the buffer
      # is full (or an error happens) the filler function will return
      # '1'.
      # Introduced in version 2.3
      readdir : Readdir

      # Release directory
      # Introduced in version 2.3
      releasedir : Releasedir

      # Synchronize directory contents
      # If the datasync parameter is non-zero, then only the user data
      # should be flushed, not the meta data
      # Introduced in version 2.3
      fsyncdir : Fsyncdir

      # Initialize filesystem
      # The return value will passed in the private_data field of
      # fuse_context to all file operations and as a parameter to the
      # destroy() method.
      # Introduced in version 2.3
      # Changed in version 2.6
      init : Init

      # Clean up filesystem
      # Called on filesystem exit.
      # Introduced in version 2.3
      destroy : Destroy

      # Check file access permissions
      # This will be called for the access() system call.  If the
      # 'default_permissions' mount option is given, this method is not
      # called.
      # This method is not called under Linux kernel versions 2.4.x
      # Introduced in version 2.5
      access : Access

      # Create and open a file
      # If the file does not exist, first create it with the specified
      # mode, and then open it.
      # If this method is not implemented or under Linux kernel
      # versions earlier than 2.6.15, the mknod() and open() methods
      # will be called instead.
      # Introduced in version 2.5
      create : Create

      # Change the size of an open file
      # This method is called instead of the truncate() method if the
      # truncation was invoked from an ftruncate() system call.
      # If this method is not implemented or under Linux kernel
      # versions earlier than 2.6.15, the truncate() method will be
      # called instead.
      # Introduced in version 2.5
      ftruncate : Ftruncate

      # Get attributes from an open file
      # This method is called instead of the getattr() method if the
      # file information is available.
      # Currently this is only called after the create() method if that
      # is implemented (see above).  Later it may be called for
      # invocations of fstat() too.
      # Introduced in version 2.5
      fgetattr : Fgetattr

      # Perform POSIX file locking operation
      # The cmd argument will be either F_GETLK, F_SETLK or F_SETLKW.
      # For the meaning of fields in 'struct flock' see the man page
      # for fcntl(2).  The l_whence field will always be set to
      # SEEK_SET.
      # For checking lock ownership, the 'fuse_file_info->owner'
      # argument must be used.
      # For F_GETLK operation, the library will first check currently
      # held locks, and if a conflicting lock is found it will return
      # information without calling this method.   This ensures, that
      # for local locks the l_pid field is correctly filled in.  The
      # results may not be accurate in case of race conditions and in
      # the presence of hard links, but it's unlikely that an
      # application would rely on accurate GETLK results in these
      # cases.  If a conflicting lock is not found, this method will be
      # called, and the filesystem may fill out l_pid by a meaningful
      # value, or it may leave this field zero.
      # For F_SETLK and F_SETLKW the l_pid field will be set to the pid
      # of the process performing the locking operation.
      # Note: if this method is not implemented, the kernel will still
      # allow file locking to work locally.  Hence it is only
      # interesting for network filesystems and similar.
      # Introduced in version 2.6
      lock : Lock

      # Change the access and modification times of a file with
      # nanosecond resolution
      # This supersedes the old utime() interface.  New applications
      # should use this.
      # See the utimensat(2) man page for details.
      # Introduced in version 2.6
      utimens : Utimens

      # Map block index within file to block index within device
      # Note: This makes sense only for block device backed filesystems
      # mounted with the 'blkdev' option
      # Introduced in version 2.6
      bmap : Bmap

      flags : OperationsFlag

      # Ioctl
      # flags will have FUSE_IOCTL_COMPAT set for 32bit ioctls in
      # 64bit environment.  The size and direction of data is
      # determined by _IOC_*() decoding of cmd.  For _IOC_NONE,
      # data will be NULL, for _IOC_WRITE data is out area, for
      # _IOC_READ in area and if both are set in/out area.  In all
      # non-NULL cases, the area is of _IOC_SIZE(cmd) bytes.
      # If flags has FUSE_IOCTL_DIR then the fuse_file_info refers to a
      # directory file handle.
      # Introduced in version 2.8
      ioctl : Ioctl

      # Poll for IO readiness events
      # Note: If ph is non-NULL, the client should notify
      # when IO readiness events occur by calling
      # fuse_notify_poll() with the specified ph.
      # Regardless of the number of times poll with a non-NULL ph
      # is received, single notification is enough to clear all.
      # Notifying more times incurs overhead but doesn't harm
      # correctness.
      # The callee is responsible for destroying ph with
      # fuse_pollhandle_destroy() when no longer in use.
      # Introduced in version 2.8
      poll : Poll

      # Write contents of buffer to an open file
      # Similar to the write() method, but data is supplied in a
      # generic buffer.  Use fuse_buf_copy() to transfer data to
      # the destination.
      # Introduced in version 2.9
      write_buf : NotSupportedFunc

      # Store data from an open file in a buffer
      # Similar to the read() method, but data is stored and
      # returned in a generic buffer.
      # No actual copying of data has to take place, the source
      # file descriptor may simply be stored in the buffer for
      # later data transfer.
      # The buffer must be allocated dynamically and stored at the
      # location pointed to by bufp.  If the buffer contains memory
      # regions, they too must be allocated using malloc().  The
      # allocated memory will be freed by the caller.
      # Introduced in version 2.9
      read_buf : NotSupportedFunc

      # Perform BSD file locking operation
      # The op argument will be either LOCK_SH, LOCK_EX or LOCK_UN
      # Nonblocking requests will be indicated by ORing LOCK_NB to
      # the above operations
      # For more information see the flock(2) manual page.
      # Additionally fi->owner will be set to a value unique to
      # this open file.  This same value will be supplied to
      # ->release() when the file is released.
      # Note: if this method is not implemented, the kernel will still
      # allow file locking to work locally.  Hence it is only
      # interesting for network filesystems and similar.
      # Introduced in version 2.9
      flock : Flock

      # Allocates space for an open file
      # This function ensures that required space is allocated for specified
      # file.  If this function returns success then any subsequent write
      # request to specified range is guaranteed not to fail because of lack
      # of space on the file system media.
      # Introduced in version 2.9.1
      fallocate : Fallocate
    end

    # Functions
    fun main = fuse_main_real(argc : LibC::Int, argv : LibC::Char**, op : Operations*, op_size : LibC::SizeT, user_data : Void*) : LibC::Int

    fun unmount = fuse_unmount(mountpoint : LibC::Char*, chan : Chan*) : Void
    fun get_context = fuse_get_context() : Context*
  end
end
