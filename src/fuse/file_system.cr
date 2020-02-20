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

    # Changes the timestamp of *path* to *time*.
    #
    # *time* will be of type `LibC::Timespec[2]`, which is the timestamp in nanoseconds.
    def utimens(path, time) : Int32 | Nil
      0
    end

    # Attempts to access a file at *path*. *mode* is either `LibC::F_OK` or a mask consisting of the bitwise OR of one or more of `LibC::R_OK`, `LibC::W_OK`, and `LibC::X_OK`.
    #
    # `LibC::F_OK` tests for the existence of the file. `LibC::R_OK`, `LibC::W_OK`, and `LibC::X_OK` test whether the file exists and grants read, write, and execute permissions, respectively.
    def access(path, mode) : Int32 | Nil
      0
    end

    # Closes a file at *path*.  Please read more about it in
    # `Binding::Operations#release`.  Return `0` on success.
    def release(path, handle, fi) : Int32 | Nil
      0
    end

    # Shortens the size of *path* by *offset*.
    #
    # ```
    # def truncate(path, offset)
    #   case path
    #   when "/file"
    #     text = "hello"
    #     new_text = text[...offset]
    #   end
    # end
    # ```
    def truncate(path, offset) : Int32 | Nil
      0
    end

    # Removes *path*.
    def unlink(path) : Int32 | Nil
      0
    end

    # Removes directory *path*.
    def rmdir(path) : Int32 | Nil
      0
    end

    # Makes directory at *path* with *mode* permissions.
    def mkdir(path, mode) : Int32 | Nil
      0
    end

    # Creates *path* with *mode* permissions.
    def create(path, mode, fi) : UInt64 | Int32 | Nil
      0u64
    end

    # Moves *path* to *newpath*.
    def rename(path, newpath) : Int32 | Nil
      0
    end

    # Reads an open file.  Returns the read bytes on success.
    #
    # ```
    # def read(path, handle, buffer, offset, fi)
    #   case path
    #   when "/file"
    #     text = "hello"
    #     len = text.size
    #     return 0 if offset >= len
    #     if offset + buffer.size > len
    #       to_copy = len - offset
    #     else
    #       to_copy = buffer.size
    #     end
    #     buffer.copy_from(text.to_unsafe + offset, to_copy)
    #     to_copy.to_i32
    #   end
    # end
    # ```
    def read(path, handle, buffer : Bytes, offset, fi) : Int32 | Nil
      nil
    end

    # Writes an open file. Returns the write bytes on success.
    #
    # ```
    # def write(path, handle, buffer, offset, fi)
    #   case path
    #   when "/file"
    #     text = "hello"
    #     new_text = text[...offset] + String.new(buffer)
    #     buffer.size
    #   end
    # end
    # ```
    def write(path, handle, buffer : Bytes, offset, fi) : Int32 | Nil
      nil
    end

    # Stops the file system.
    #
    # NOTE: Does not seem to work at the moment.
    def destroy() : Int32 | Nil
      nil # Binding wrong? Maybe 0 needs to be returned? Not looked into.
    end

    # Opens a directory at *path*.  Analogous to `#open`.
    def opendir(path) : UInt64 | Int32 | Nil
      0u64
    end

    # Closes a directory at *path*.  Analogous to `#release`.
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

      @operations.destroy = ->(void: Pointer(Void)) do
        invoke destroy
      end

      @operations.release = ->(path : LibC::Char*, fi : Binding::FileInfo*) do
        result invoke_file release, path, fi
      end

      @operations.read = ->(path : LibC::Char*, buf : LibC::Char*, size : LibC::SizeT, offset : LibC::OffT, fi : Binding::FileInfo*) do
        r = invoke_file read, path, fi, buf.as(UInt8*).to_slice(size), offset

        return r if r.is_a?(Int32)
        result r
      end

      @operations.utimens = ->(path : LibC::Char*, time: LibC::Timespec[2]) do
        result invoke_path utimens, path, time
      end

      @operations.access = ->(path : LibC::Char*, mode : LibC::Int) do
        result invoke_path access, path, mode
      end

      @operations.truncate = ->(path : LibC::Char*, offset : LibC::OffT) do
        result invoke_path truncate, path, offset
      end

      @operations.unlink = ->(path : LibC::Char*) do
        result invoke_path unlink, path
      end

      @operations.rmdir = ->(path : LibC::Char*) do
        result invoke_path rmdir, path
      end

      @operations.mkdir = ->(path : LibC::Char*, mode : LibC::ModeT) do
        result invoke_path mkdir, path, mode
      end

      @operations.create = ->(path : LibC::Char*, mode : LibC::ModeT, fi : Binding::FileInfo*) do
        r = invoke_path create, path, mode, fi
        fi.value.file_handle = r if r.is_a?(UInt64)
        result r
      end

      @operations.rename = ->(path : LibC::Char*, newpath : LibC::Char*) do
        result invoke_path rename, path, String.new(newpath)
      end

      @operations.write = ->(path : LibC::Char*, buf : LibC::Char*, size : LibC::SizeT, offset : LibC::OffT, fi : Binding::FileInfo*) do
        w = invoke_file write, path, fi, buf.as(UInt8*).to_slice(size), offset
        return w if w.is_a?(Int32)
        result w
      end

      @operations.opendir = ->(path : LibC::Char*, fi : Binding::FileInfo*) do
        r = invoke_path opendir, path
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

    private macro invoke_path(method, path, *arguments)
      invoke({{ method }}, String.new({{ path }}), {{ arguments.splat }})
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
