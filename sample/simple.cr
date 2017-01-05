# Showcases a hello world FUSE driver.  The FS contains a single static file
# named "hello", which contains the string "Hello, World!\n".
#
# To run this example:
#  1. Make sure you have FUSE installed.
#  2. Create a directory as mountpoint:
#       $ mkdir mnt
#  3. Start the example:
#       $ crystal run sample/simple.cr -- -d -s -f mnt
#  4. Now inspect your mounted folder
#  5. Stop the program either through Ctrl-C, or by doing
#       $ fusermount -u mnt

require "../src/fuse"

class HelloFs < Fuse::FileSystem
  FILE_DATA = "Hello, World!\n"

  def getattr(path)
    stat = LibC::Stat.new

    case path
    when "/"
      stat.st_mode = LibC::S_IFDIR | 0o755
      stat.st_nlink = 2
    when "/file"
      stat.st_mode = LibC::S_IFREG | 0o777
      stat.st_nlink = 1
      stat.st_size = FILE_DATA.size
    else
      return LibC::ENOENT
    end

    stat
  end

  def open(path)
    0u64
  end

  def read(path, handle, buffer, offset, fi)
    return nil unless path == "/file"

    len = FILE_DATA.size
    return 0 if offset >= len

    if offset + buffer.size > len
      to_copy = len - offset
    else
      to_copy = buffer.size
    end

    buffer.copy_from(FILE_DATA.to_unsafe + offset, to_copy)
    to_copy.to_i32
  end

  def readdir(path, handle, offset, fi)
    [ "file" ] if path == "/"
  end
end

HelloFs.new.run!
