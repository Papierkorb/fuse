module Fuse
  # Base class for user-defined file systems.  Sub-class it and build your own!
  # Use `#run!` to start it.
  #
  # There are many methods in this class, but you'll probably only need a
  # couple.  Most expect a return type of *something* (Which is the result and
  # is treated as success), `Int32` (Treated as errno code) or `nil` which will
  # return a **ENOSYS** (*Function not implemented*).
  #
  # Standard arguments are:
  #  * **path** `String`, the path of the file or directory
  #  * **handle** `UInt64`, a numeric file handle
  #  * **buffer** `Bytes`, a input or output buffer
  #  * **fi** `Binding::FileInfo`, handle information passed from FUSE
  #  * **offset** `LibC::OffT`, an offset in a file or directory listing
  #
  # These arguments may not have explicit data types for readability purposes.
  #
  # Exceptions are noted in each methods documentation.
  class FileSystem
    property operations : Binding::Operations

    def initialize
      @operations = Binding::Operations.new
      set_up_operations
    end

    # FUSE functions.  Override these as you need them.

    # Gets a `LibC::Stat` for the given *path*.  An example path is
    # `/foo/bar.txt`.
    def getattr(path) : LibC::Stat | Int32 | Nil
      nil
    end

    # Opens a file at *path*.
    # **Watch out**: Return a `UInt64` for a file-handle, and return a `Int32`
    # to return an errno error!
    def open(path) : UInt64 | Int32 | Nil
      nil
    end

    # Closes a file at *path*.  Please read more about it in
    # `Binding::Operations#release`.  Return `0` on success.
    def release(path, handle, fi) : Int32 | Nil
      0
    end

    # Reads an open file.  Return the read bytes on success.
    def read(path, handle, buffer : Bytes, offset, fi) : Int32 | Nil
      nil
    end

    # Reads a symlink.  Returns a string with the target path or nil.
    def readlink(path) : String | Nil
      nil
    end

    def write(path, handle, buffer : Bytes, offset, fi) : Int32 | Nil
      nil
    end

    # Opens a directory at *path*.  Analogous to `#open`
    def opendir(path) : UInt64 | Int32 | Nil
      0u64
    end

    # Closes a directory at *path*.  Analogous to `#release`
    def releasedir(path, handle, fi) : Int32 | Nil
      0
    end

    # Reads the entries of a directory.  The "." and ".." entries are added
    # automatically.  The result may be any enumerable of Strings, or a tuple
    # of a string and a `LibC::Stat`.  If the result is a integer, it's used
    # as resulting error code.
    def readdir(path, handle, offset, fi) : Enumerable(String) | Enumerable(Tuple(String, LibC::Stat)) | Int32 | Nil
      nil
    end

    # Runs the file system.  This will block until the file-system has been
    # unmounted.
    def run!(argv : Enumerable(String) = ARGV)
      arguments = ARGV.map(&.to_unsafe).to_unsafe
      data_ptr = self.as(Void*)
      Fuse::Binding.main(argv.size, arguments, pointerof(@operations), sizeof(Binding::Operations), data_ptr)
    end

    private def set_up_operations
      @operations.getattr = ->(path : LibC::Char*, stat : LibC::Stat*) do
        r = invoke getattr, String.new(path)
        stat.value = r if r.is_a?(LibC::Stat)
        result r
      end

      @operations.open = ->(path : LibC::Char*, fi : Binding::FileInfo*) do
        r = invoke open, String.new(path)
        fi.value.file_handle = r if r.is_a?(UInt64)
        result r
      end

      @operations.release = ->(path : LibC::Char*, fi : Binding::FileInfo*) do
        result invoke_file release, path, fi
      end

      @operations.read = ->(path : LibC::Char*, buf : LibC::Char*, size : LibC::SizeT, offset : LibC::OffT, fi : Binding::FileInfo*) do
        r = invoke_file read, path, fi, buf.as(UInt8*).to_slice(size), offset
        return r if r.is_a?(Int32)
        result r
      end

      @operations.readlink = ->(path : LibC::Char*, buf : LibC::Char*, size : LibC::SizeT) do
        r = invoke readlink, String.new(path)
        if r.nil?
          -LibC::ENOSYS
        else
          r.check_no_null_byte
          buffer = buf.as(UInt8*).to_slice(size)
          buffer.copy_from(r.to_unsafe, r.bytesize + 1) # + 1 to also include the terminating 0-byte
          0                                             # the return value should be 0 for success
        end
      end

      @operations.write = ->(path : LibC::Char*, buf : LibC::Char*, size : LibC::SizeT, offset : LibC::OffT, fi : Binding::FileInfo*) do
        w = invoke_file write, path, fi, buf.as(UInt8*).to_slice(size), offset
        return w if w.is_a?(Int32)
        result w
      end

      @operations.opendir = ->(path : LibC::Char*, fi : Binding::FileInfo*) do
        r = invoke opendir, String.new(path)
        fi.value.file_handle = r if r.is_a?(UInt64)
        result r
      end

      @operations.releasedir = ->(path : LibC::Char*, fi : Binding::FileInfo*) do
        result invoke_file releasedir, path, fi
      end

      @operations.readdir = ->(path : LibC::Char*, buf : Void*, filler : Binding::FillDir, offset : LibC::OffT, fi : Binding::FileInfo*) do
        r = invoke_file readdir, path, fi, offset

        result r if r.nil? || r.is_a?(Int32)

        filler.call buf, ".".to_unsafe, Pointer(LibC::Stat).null, 0i64
        filler.call buf, "..".to_unsafe, Pointer(LibC::Stat).null, 0i64

        if r.is_a?(Enumerable(String))
          r.each { |path| filler.call buf, path.to_unsafe, Pointer(LibC::Stat).null, 0i64 }
        else
          r.each { |path, stat| filler.call buf, path.to_unsafe, pointerof(stat), 0i64 }
        end

        0
      end
    end

    private macro invoke(method, *arguments)
      %ctx = Binding.get_context
      %fs = %ctx.value.private_data.as(FileSystem)
      %fs.{{ method }}({{ arguments.splat }})
    end

    private macro invoke_file(method, path, fi)
      invoke({{ method }}, String.new({{ path }}), {{ fi }}.value.file_handle, {{ fi }})
    end

    private macro invoke_file(method, path, fi, *arguments)
      invoke({{ method }}, String.new({{ path }}), {{ fi }}.value.file_handle, {{ arguments.splat }}, {{ fi }})
    end

    private macro result(data)
      return -{{ data }}.abs if {{ data }}.is_a?(Int32)
      return 0 unless {{ data }}.nil?
      return -LibC::ENOSYS
    end
  end
end
